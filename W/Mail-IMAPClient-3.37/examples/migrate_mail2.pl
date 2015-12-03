#!/usr/local/bin/perl
#$Id$
#
# An example of how to migrate from a Netscape server
# (which uses a slash as a separator and which does
# not allow subfolders under the INBOX, only next to it)
# to a Cyrus server (which uses a dot (.) as a separator
# and which requires subfolders to be under "INBOX").
# There are also some allowed-character differences taken
# into account but this is by no means complete AFAIK.
#
# This is an example. If you are doing mail migrations 
# then this may in fact be a very helpful example but
# it is unlikely to work 100% correctly as-is. 
# A good place to start is by testing a rather large-volume
# transfer of actual mail from the source server with the
# -v option turned on and redirect output to a file for
# perusal. Examine the output carefully for unexpected
# results, such as a number of messages being skipped because
# they're already in the target folder when you know darn
# well this is the first time you ran the script. This
# would indicate an incompatibility with the logic for
# detecting duplicates, unless for some reason the source 
# mailbox contains a lot of duplicate messages to begin with.
# (The latter case is an example of why you should use an
# actual mailbox stuffed with actual mail for test; if you
# generate test messages and then test migrating those you
# will only prove that your test messages are migratable.
# 
# Also, you may need to play with the rules
# for translating folder names based on what kind of
# names your target server and source server support.
#
# You may also need to play with the logic that determines
# whether or not a message has already been migrated, 
# especially if your source server has messages that 
# did not come from an SMTP gateway or something like that.
#
# Some servers allow folders to contain mail and subfolders,
# some allow folders to only contain either mail or subfolders.
# If you are migrating from a "mixed use" type to a "single use"
# type server then you'll have to figure out how to deal 
# with this. (This script deals with this by creating folders like
# "/blah_mail", "/blah/blah_mail", and "/blah/blah/blah_mail"
# to hold mail if the source folder contains mail and subfolders
# and the target server supports only single-use folders. 
# You may not choose a different strategy.)
#
# Finally, it's possible that in some server-to-server
# copies, the source server supports messages that the
# target server considers unacceptable. For example, some
# but not all IMAP servers flat out refuse to accept 
# messages with "base newlines", which is to say messages
# whose lines are match the pattern /[^\r]\n$/. There is
# no logic in this script that deals with the situation;
# you will have to identify it if it exists and figure
# out how you want to handle it.
# 
# This is probably not an exhaustive list of issues you'll
# face in a migration, but it's a start.
#
# If you're just migrating from an old version to a newer
# version of the same server then you'll probably have
# a much easier time of it.
#
#

use Mail::IMAPClient;
use Data::Dumper;
use IO::File;
use File::Basename ;
use Getopt::Std;
use strict;
use vars qw/ 	$opt_B $opt_D $opt_T $opt_U
		$opt_W $opt_b $opt_d $opt_h
		$opt_t $opt_u $opt_w $opt_v
		$opt_s $opt_S $opt_W $opt_p
		$opt_P $opt_f $opt_F $opt_m 
		$opt_M
/;

getopts('vs:S:u:U:dDb:B:f:F:w:W:p:P:t:T:hm:M:');

if ( $opt_h ) {
	print STDERR <<"HELP";

$0 - 	an example script demonstrating the use of the Mail::IMAPClient's
	migrate method.

Syntax:
	$0 -s source_server -u source_user -w source_password -p source_port \
	   -d debug_source -f source_debugging_file -b source_buffsize       \
	   -t source_timeout -m source_auth_mechanism                        \
	   -S target_server -U target_user -W target_password -P target_port \
	   -D debug_target -F target_debugging_file -B target_buffsize       \
	   -T target_timeout -M target_auth_mechanism                        \
	   -v

where "source" refers to the "copied from" mailbox, target is the 
"copied to" mailbox, and -v turns on verbose output.
Authentication mechanisms default to "PLAIN".

HELP
	exit;
}
$opt_v and ++$|;
print "$0: Started at ",scalar(localtime),"\n" if $opt_v;

$opt_p||=143;
$opt_P||=143;

# Make a connection to the source mailbox:
my $imap = Mail::IMAPClient->new(
				Server  => $opt_s,
				User    => $opt_u,
				Password=> $opt_w,
				Uid	=> 1,	
				Port	=> $opt_p,	
				Debug	=> $opt_d||0,
				Buffer	=> $opt_b||4096,
				Fast_io	=> 1,
				( $opt_m ? ( Authmechanism => $opt_m) : () ),
				Timeout	=> $opt_t,	 
				($opt_f ? ( Debug_fh=>IO::File->new(">$opt_f" )) : ()),
) or die "$@";

# Make a connection to the target mailbox:
my $imap2 = Mail::IMAPClient->new(	
				Server  => $opt_S,
				User    => $opt_U,
				Password=> $opt_W,
				Port	=> $opt_P,
				Uid	=> 1,	
				Debug	=> $opt_D||0,
				( $opt_M ? ( Authmechanism => $opt_M) : () ),
				($opt_F ? ( Debug_fh=>IO::File->new(">$opt_F")) : ()),
				Buffer	=> $opt_B||4096,
				Fast_io	=> 1,
				Timeout	=> $opt_T,			 # True value
) or die "$@";

# Turn off buffering on debug files:
$imap->Debug_fh->autoflush;
$imap2->Debug_fh->autoflush;

# Get folder hierarchy separator characters from source and target:
my $sep1 = $imap->separator;
my $sep2 = $imap2->separator;

# Find out if source and target support subfolders inside INBOX:
my $inferiorFlag1 = $imap->is_parent("INBOX");
my $inferiorFlag2 = $imap2->is_parent("INBOX");

# Set up a test folders to see if the source and target support mixed-use
# folders (i.e. folders with both subfolders and mail messages):
my $testFolder1 = "Migrate_Test_$$" ;		# Ex: Migrate_Test_1234
$testFolder1 = $inferiorFlag2 ? 
		"INBOX" . $sep2 . $testFolder1  : 
		$testFolder1 ;

# The following folder will be a subfolder of $testFolder1:
my $testFolder2 = "Migrate_Test_$$" . $sep2 . "Migrate_test_subfolder_$$" ;
$testFolder2 = $inferiorFlag2 ? "INBOX" . $sep2 . $testFolder2  : $testFolder2 ;

$imap2->create($testFolder2) ;	# Create the subfolder first; RFC2060 dictates that
				# the parent folder should be created at the same time


# The following line inspired the selectable method.  It was also made obsolete by it,
# but I'm leaving it as is to demonstrate use of lower-level method calls:
my $mixedUse2 = grep(/NoSelect/i,$imap2->list("",$testFolder1))? 0 : 1;

# Repeat the above with the source mailbox:
$testFolder2 = "Migrate_Test_$$" . $sep1 . "Migrate_test_subfolder_$$" ;
$testFolder2 = $inferiorFlag1 ? "INBOX" . $sep1 . $testFolder1  : $testFolder1 ;

$imap->create($testFolder2) ;

my $mixedUse1 = grep(/NoSelect/i,$imap->list("",$testFolder1))? 0 : 1;

print 	"Imap host $opt_s:$opt_p uses a '$sep1' as a separator and ",
	( defined($inferiorFlag1) ? "allows " : "does not allow "), 
	"children in the INBOX. It supports ",
	($mixedUse1?"mixed use ":"single use "), "folders.\n" if $opt_v;

print 	"Imap host $opt_S:$opt_P uses a '$sep2' as a separator and ",
	( defined($inferiorFlag2) ? "allows " : "does not allow "), 
	"children in the INBOX. It supports ",
	($mixedUse2?"mixed use ":"single use "), "folders.\n" if $opt_v;

for ($testFolder1,$testFolder2) {$imap->delete($_); $imap2->delete($_);}

my($totalMsgs, $totalBytes) = (0,0);

# Now we will migrate the folder. Here we are doing one message at a time
# so that we can do more granular status reporting and error checking.
# A lazier way would be to do all the messages in one migrate method call
# (specifying "ALL" as the message number) but then we wouldn't be able
# to print out which message we were migrating and it would be a little 
# bit tougher to control checking for duplicates and stuff like that.
# We could also check the size of the message on the target right after 
# the migrate as an extra safety check if we wanted to but I didn't bother
# here. (I saved as an exercise for the reader. Yeah! That's it! An exercise!)

# Iterate over all the folders in the source mailbox:
for my $f ($imap->folders) { 
	# Select the folder on the source side:
	$imap->select($f) ; 

	# Massage the foldername into an acceptable target-side foldername:
	my $targF = "";
	my $srcF = $f;
	$srcF =~ s/^INBOX$sep1//i;
	if ( $inferiorFlag2 ) {
		$targF = $srcF eq "INBOX" ? "INBOX" : "INBOX.$f" ;
	} else {
		$targF = $srcF ;
	}

	$targF =~ s/$sep1/$sep2/go unless $sep1 eq $sep2;
	$targF =~ tr/#\$\& '"/\@\@+_/;
	if ( $imap->is_parent($f) and !$mixedUse2 ) {
		$targF .= "_mail" ;
	}
	print "Migrating folder $f to $targF\n" if $opt_v;

	# Create the (massaged) folder on the target side:
	unless ( $imap2->exists($targF) ) {
		$imap2->create($imap2->Massage($targF))
			or warn "Cannot create $targF on " . $imap2->Server . ": $@\n" and next;
	}

	# ... and select it
	$imap2->select($imap2->Massage($targF))  
			or warn "Cannot select $targF on " . $imap2->Server . ": $@\n" and next;

	# now that we know the target folder is selectable, we can close it again:
	$imap2->close; 
	my $count = 0;
	my $expectedTotal = $imap->message_count($f) ;

	# Now start iterating over all the messages on the source side...
	for my $msg ($imap->messages) {
		++$count; 
		my $h = "";
		# Get some basic info about the message:
		eval { $h = ($imap->parse_headers($msg,"Message-id")||{})->{'Message-id'}[0]};
		my $tsize = $imap->size($msg);
		my $ret = 0 ; my $h2 = [];

		# Make sure we didn't already migrate the message in a previous pass:
		$imap2->select($targF);
		if ( 	$tsize and $h and $h2 = $imap2->search( 
					HEADER 	=> 'Message-id'	=> $imap2->Quote($h),
					NOT 	=>  SMALLER 	=> $tsize, 
					NOT	=>  LARGER	=> $tsize
			)
		) {
			print  	
				"Skipping $f/$msg to $targF. ",
				"One or more messages (" ,join(", ",@$h2),
				") with the same size and message id ($h) ",
				"is already on the server. ",
				"\n" 
			if $opt_v;
			$imap2->close;

		} else {

			print  	
				"Migrating $f/$msg to $targF. ",
				"Message #$count of $expectedTotal has ",
				$tsize , " bytes.",
				"\n" if $opt_v;
			$imap2->close;

			# Migrate the message:
			my $ret = $imap->migrate($imap2,$msg,"$targF") ;
			$ret and ( $totalMsgs++ , $totalBytes += $tsize);
			$ret or warn "Cannot migrate $f/$msg to $targF on " . $imap2->Server . ": $@\n" ;
		}
	}
}

print "$0: Finished migrating $totalMsgs messages and $totalBytes bytes at ",scalar(localtime),"\n" 
	if $opt_v;
exit;


=head1 AUTHOR 
	
David J. Kernen

The Kernen Group, Inc.

imap@kernengroup.com

=head1 COPYRIGHT

This example and Mail::IMAPClient are Copyright (c) 2003 
by The Kernen Group, Inc. All rights reserved.

This example is distributed with Mail::IMAPClient and 
subject to the same licensing requirements as Mail::IMAPClient.

imtest is a utility distributed with Cyrus IMAP server, 
Copyright (c) 1994-2000 Carnegie Mellon University.  
All rights reserved. 

=cut

#$Log: migrate_mail2.pl,v $
#Revision 19991216.4  2003/06/12 21:38:33  dkernen
#
#Preparing 2.2.8
#Added Files: COPYRIGHT
#Modified Files: Parse.grammar
#Added Files: Makefile.old
#	Makefile.PL Todo sample.perldb
#	BodyStructure.pm
#	Parse.grammar Parse.pod
# 	range.t
# 	Thread.grammar
# 	draft-crispin-imapv-17.txt rfc1731.txt rfc2060.txt rfc2062.txt
# 	rfc2221.txt rfc2359.txt rfc2683.txt
#

#!/usr/local/bin/perl
# $Id$

use Mail::IMAPClient;
use Mozilla::LDAP::Conn;
use Getopt::Std;
use vars qw/$rootdn $opt_a/;
use Data::Dumper;

# It then connects to a user's mailhost and rummages around, 
#    looking for duplicate messages.
# It will optionally delete messages that are duplicates (based on 
#    msg-id header and number of bytes).
# For help, enter:
#	find_dup_msgs.pl -h  
#

getopts('ahdtvf:F:u:s:p:P:');

if ( $opt_h ) {
	print STDERR &usage;
	exit;
}

my $uid = $opt_u or die &usage;
$opt_s||='localhost';
$opt_p or die &usage;
$opt_P||=143;

$opt_t 		and 
	$opt_d 	and 
	die 	"ERROR: Don't specify -d and -t together.\n" . &usage;


my($pu,$pp) = get_admin(); 

print "Connecting to $host:$opt_P\n" if $opt_v;
my $imap = Imap->new(	Server	=> $opt_s,
			User	=> $opt_u,
			Password=> $opt_p,
			Port	=> $opt_P,
			Fast_io => 1,
) or die "couldn't connect to $host port $opt_P: $!\n";

my %folders; my %counts;

FOLDER: foreach my $f ( $opt_F ? $opt_F :  $imap->folders  ) {
	next if $opt_t and $f eq 'Trash';
	$folders{$f} = 0;
	$counts{$f} = $imap->message_count($f);
	print "Processing folder $f\n" if $opt_v;
	unless ( $imap->select($f)) {
		warn "Error selecting $f: " . $imap->LastError . "\n";
		next FOLDER;
	}
	my @msgs = $imap->search("ALL");
	my %hash = ();
	MESSAGE: foreach my $m (@msgs) {
		my $mid;
		if ($opt_a) {
			my $h = $imap->parse_headers(
				$m,"Date","Subject","From","Message-ID"
			) or next MESSAGE;
			$mid = 	"$h->{'Date'}[0]$;$h->{'Subject'}[0]$;".
				"$h->{'From'}[0]$;$h->{'Message-ID'}[0]";

		} else {
			$mid = $imap->parse_headers(
				$m,
				"Message-ID"
			)->{'Message-ID'}[0] 
			or next MESSAGE;
		}
		my $size = $imap->size($m);
		if ( exists $hash{$mid} and $hash{$mid} == $size ) { 
			if ($opt_f) {
				open F,">>$opt_f" or 
					die "can't open $opt_f: $!\n";
				print F $imap->message_string($m),
					"___END OF SAVED MESSAGE___","\n";
				close F;
			}
			$imap->move("Trash",$m) if $opt_t;
			$imap->delete_message($m) if $opt_d;
			$folders{$f}++;
			print "Found a duplicate in ${f}; key = $mid\n" if $opt_v;

		} else {

			$hash{$mid} = $size;
		}
	}
	print "$f hash:\n",Data::Dumper::Dumper(\%hash) if $opt_v;
	$imap->expunge if ($opt_t or $opt_d);
}

my $total; 	my $totms; 
map { $total += $_} values %folders;
map { $totms += $_ } values %counts;
print 	"Found $total duplicate messages in ${uid}'s mailbox. ",
	"The breakdown is:\n",
	"\tFolder\tNumber of Duplicates\tNumber of Msgs in Folder\n",
	"\t------\t--------------------\t------------------------\n",
	map { "\t$_\t$folders{$_}\t$counts{$_}\n" } keys %folders,
	"\tTOTAL\t$total\t$totms\n"
;


sub usage {
	return "Usage:\n" .
		"\t$0 [-d|-t] [-v] [-f filename] [-a] [-P port] \\\n".
		"\t\t-s server -u user -p password\n\n" .
		"\t-a\t\tdo an especially aggressive search for duplicates\n".
		"\t-d\t\tdelete duplicates (default is to just report them)\n".
		"\t-f file\t\tsave deleted messages in file named 'file'\n" .
		"\t-F fldr\t\tOnly check the folder named 'fldr' (default is to check all folders)\n" .
		"\t-h\t\tprint this help message (all other options are ignored)\n" .
		"\t-p password\tspecify the target user's password\n" .
		"\t-P port\t\tspecify the port to connect to (default is 143)\n" .
		"\t-s server\tspecify the target mail server\n" .
		"\t-u uid\t\tspecify the target user\n" .
		"\t-t\t\tmove deleted messages to trash folder\n" .
		"\t-v\t\tprint verbose status messages while processing\n".
		"\n" ;
}


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

# History:
# $Log: find_dup_msgs.pl,v $
# Revision 19991216.5  2003/06/12 21:38:32  dkernen
#
# Preparing 2.2.8
# Added Files: COPYRIGHT
# Modified Files: Parse.grammar
# Added Files: Makefile.old
# 	Makefile.PL Todo sample.perldb
# 	BodyStructure.pm
# 	Parse.grammar Parse.pod
#  	range.t
#  	Thread.grammar
#  	draft-crispin-imapv-17.txt rfc1731.txt rfc2060.txt rfc2062.txt
#  	rfc2221.txt rfc2359.txt rfc2683.txt
#
# Revision 1.1  2003/06/12 21:38:14  dkernen
#
# Preparing 2.2.8
# Added Files: COPYRIGHT
# Modified Files: Parse.grammar
# Added Files: Makefile.old
# 	Makefile.PL Todo sample.perldb
# 	BodyStructure.pm
# 	Parse.grammar Parse.pod
#  	range.t
#  	Thread.grammar
#  	draft-crispin-imapv-17.txt rfc1731.txt rfc2060.txt rfc2062.txt
#  	rfc2221.txt rfc2359.txt rfc2683.txt
#
# Revision 19991216.4  2002/08/23 14:34:51  dkernen
#
# Modified Files:	Changes IMAPClient.pm Makefile Makefile.PL test.txt for version 2.2.0
# Added Files: Makefile Makefile.PL Parse.grammar Parse.pm Parse.pod  version 2.2.0
# Added Files: parse.t  for version 2.2.0
# Added Files: bodystructure.t  for 2.2.0
# Modified Files: find_dup_msgs.pl  for v2.2.0
#
# Revision 1.6  2001/03/08 19:00:35  dkernen
#
# ----------------------------------------------------------------------
# Modified Files:
# 	copy_folder.pl 		delete_mailbox.pl 	find_dup_msgs.pl
# 	mbox_check.pl 		process_orphans.pl 	rename_id.pl
# 	scratch_indexes.pl
# to get ready for nsusmsg02 upgrade
# ----------------------------------------------------------------------
#
# Revision 1.5  2000/11/01 15:51:58  dkernen
#
# Modified Files: copy_folder.pl find_dup_msgs.pl restore_mbox.pl
#
# Revision 1.4  2000/04/13 21:17:18  dkernen
#
# Modified Files: find_dup_msgs.pl  - to add -a switch (for aggressive dup search)
# Added Files: 	copy_folder.pl 	  - a utility for copying a folder from one user's
# 				    mailbox to another's
#
# Revision 1.3  2000/03/14 16:40:21  dkernen
#
# Modified Files: find_dup_msgs.pl  -- to skip msgs with no message-id
#
# Revision 1.2  2000/03/13 19:05:50  dkernen
#
# Modified Files:
# 	delete_mailbox.pl find_dup_msgs.pl restore_mbox.pl -- to add cvs comments
# 	find_dup_msgs.pl -- to fix bug that occurred when -t (move-to-trash) switch is used
#

#!/usr/local/bin/perl
#$Id$
++$|;
use Getopt::Std;
use Mail::IMAPClient;
use vars qw/$opt_r $opt_h $opt_t $opt_f/;

getopts("t:f:F:N:rh");
if ( $opt_h ) {
	print &usage;
	exit;
}

my($to_id,$to_pass,$thost) = $opt_t =~ m{	
						([^/]+)		# everything up to / is the id
						/		# then a slash
						([^@]+)		# then everything up to @ is pswd
						@		# then an @-sign
						(.*)		# then everything else is the host
					}x ;
my($from_id,$from_pass,$fhost) = 
				$opt_f =~ m{
						([^/]+)		# everything up to / is the id
						/		# then a slash
						([^@]+)		# then everything up to @ is pswd
						@		# then an @-sign
						(.*)		# then everything else is the host
					  }x ;
$to_id and $from_id and $to_pass and $from_pass and $thost and $fhost 
	or die "Error: Must specify -t and -f (to and from)\n" . &usage;
$opt_F or 
	die 	"Error: Must specify '-F folder' or how will I know what folder to copy?\n" . 
	&usage	;

$opt_N ||= $opt_F;

	
print "Copying folder $opt_F from $from_id\@$fhost to ${to_id}'s $opt_N folder on $thost.\n";

my ($from) = Mail::IMAPClient->new( Server => $fhost,
				    User => $from_id,
				    Password=> $from_pass,
				    Fast_IO => 1,
				    Uid => 1,
				    Debug => 0,
);


my ($to) = Mail::IMAPClient->new( Server => $thost,
				    User => $to_id,
				    Password=> $to_pass,
				    Fast_IO => 1,
				    Uid => 1,
				    Debug => 0,
);

my @folders = $opt_r ? @{$from->folders($opt_F)} : ( $opt_F ) ;

foreach my $fold (@folders) {
	print "Processing folder $fold\n";
	$from->select($fold);
	if ($opt_F ne $opt_N) {
		$fold =~s/^$opt_F/$opt_N/o;
	}
	unless ($to->exists($fold)) { 
		$to->create($fold) or warn "Couldn't create $fold\n" and next; 
	}
	$to->select($fold);
	my @msgs = $from->search("ALL");
	# my %flaghash = $from->flags(\@msgs);
	foreach $msg (@msgs) {
		print "Processing message $msg in folder $fold.\n";
		my $string = $from->message_string($msg);
		# print "String = $string\n";
		my $new_id = $to->append($fold,$string) 
			or warn "Couldn't append msg #$msg to target folder $fold.\n";
		
		$to->store($new_id,"+FLAGS (" . join(" ",@{$from->flags($msg)}) . ")");
	}
}

sub usage {
	return "Syntax:\n\t$0 -t to_id/to_pass\@to.host -f from_id/from_pass\@from.host \\\n" .
	"\t\t-F folder [-N New_Folder] [-r]\n".
	"\tor\n\t$0 -h\n\n".
	"\twhere:\n\t\t".
	"to_id\t\tis the id to recieve the folder\n\t\t".
	"to_pass\t\tis the password for to_id\n\t\t".
	"from\t\tis the uid who currently has the folder\n\t\t".
	"from_pass\tis the password for from_id\n\t\t".
	"to.host\t\tis the optional host where the 'to' uid has a mailbox\n\t\t".
	"from.host\tis the optional host where the 'from' uid has a mailbox\n\t\t".
	"folder\t\tis the folder to copy from\n\t\t".
	"New_Folder\tis the folder to copy to (defaults to 'folder')\n\t\t".
	"-h\t\tprints this help message\n\t\t".
	"-r\t\tspecifies a recursive copy (only works on systems that support the idea " .
	"\n\t\t\t\tof recursive folders)\n\t\t".
	"\n"
	;
}


=head1 AUTHOR 
	
David J. Kernen

The Kernen Group, Inc.

imap@kernengroup.com

=head1 COPYRIGHT

This example and Mail::IMAPClient are Copyright (c) 1999,2000,2003 
by The Kernen Group, Inc. All rights reserved.

This example is distributed with Mail::IMAPClient and 
subject to the same licensing requirements as Mail::IMAPClient.

imtest is a utility distributed with Cyrus IMAP server, 
Copyright (c) 1994-2000 Carnegie Mellon University.  
All rights reserved. 

=cut

# History:
# $Log: copy_folder.pl,v $
# Revision 19991216.3  2003/06/12 21:38:30  dkernen
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
# Revision 19991216.2  2000/12/11 21:58:51  dkernen
#
# Modified Files:
# 	build_dist.pl build_ldif.pl copy_folder.pl find_dup_msgs.pl
# 	imap_to_mbox.pl populate_mailbox.pl
# to add CVS data
#

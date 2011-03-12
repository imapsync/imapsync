#!/usr/local/bin/perl

use Mail::IMAPClient;
use IO::File;
#
# Example that will also clean out your test account if interrupted 'make test' 
# runs have left junk folders there. Run from installation dir, installation/examples
# subdir, or supply full path to the test.txt file (created during 'perl Makefile.PL'
# and left in the installation dir until 'make clean').
# If you 've already run 'make clean' or said no to extended tests, 
# then you don't have the file anyway; re-run 'perl Makefile.PL', reply 'y' to the
# extended tests prompt, then supply the test account's credentials as prompted.
# Then try this again.
#
if ( -f "./test.txt" ) {
	$configFile = "./test.txt"
} elsif ( -f "../test.txt" ) {
	$configFile = "../test.txt"
} elsif ( $ARGV[0] and -f "$ARGV[0]" ) {
	$configFile = $ARGV[0];
} else {
	print STDERR "Can't find test.txt. Please run this from the installation directory ",
		"or supply the full path to test.txt as an argument on the command line.\n";
}
my $fh = IO::File->new("./test.txt") or die "./test.txt: $!\n";
while (my $input = <$fh>) {
	chomp $input;
	my($k,$v) = split(/=/,$input,2);
	$conf{$k}=$v;
}
my $imap = Mail::IMAPClient->new(Server=>$conf{server},User=>$conf{user},
	Password=>$conf{passed}) or die "Connecting to $conf{server}: $! $@\n";

for my $f ( grep(/^IMAPClient_/,$imap->folders) ) {
	print "Deleting $f\n";
	$imap->select($f);
	$imap->delete_messages(@{$imap->messages}) ;
	$imap->close($f);
	$imap->delete($f);
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


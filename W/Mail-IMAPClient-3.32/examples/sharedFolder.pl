#!/usr/local/bin/perl
#$Id$

use Mail::IMAPClient;
use Getopt::Std;
use File::Basename;
getopts('s:u:p:f:dh');

if ($opt_h) {
		
	print STDERR "$0	-- example of how to select shared folder\n",
	"\n\nUsage:\n",
	"\t-s	server	-- specify name or ip address of mail server\n",
	"\t-u	userid	-- specify login name of authenticating user\n",
	"\t-p	passwd	-- specify login password of authenticating user\n",
	"\t-f	folder	-- specify shared folder to access (i.e. '-f frank/INBOX')\n",
	"\t-h		   display this help message\n\n";
	"\t-d		   turn on debugging output\n\n";
	exit;	
}
		
my $server = $opt_s or die "No server name specified\n";
my $user   = $opt_u or die "No user name specified\n";
my $pass   = $opt_p or die "No password specified\n";
my $folder = $opt_f or die "No shared folder specified\n";

chomp $pass;
my $imap = Mail::IMAPClient->new(Server=>$server,User=>$user,Password=>$pass,Debug=>$opt_d)
	or die "Can't connect to $user\@$server: $@ $!\n";

my($prefix,$prefSep) = @{$imap->namespace->[1][0]}
	or die "Can't get shared folder namespace or separator: $@\n";


my $target =  	$prefix .  
		( $prefix =~ /\Q$prefSep\E$/ || $opt_f =~ /^\Q$prefSep/ ? "" : $prefSep ) . 
		$opt_f ;

print "Selecting $target\n";

$imap->select($target)
	or die "Cannot select $target: $@\n";

print "Ok: $target has ", $imap->message_count($target)," messages.\n";

$imap->logout;
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

#
#$Log: sharedFolder.pl,v $
#Revision 19991216.1  2003/06/12 21:38:35  dkernen
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
#

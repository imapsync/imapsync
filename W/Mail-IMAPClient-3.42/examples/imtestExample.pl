#!/usr/local/bin/perl

use Sys::Hostname;
use Mail::IMAPClient;
use IPC::Open3;
use IO::Socket::UNIX;
use IO::Socket;
use Socket;
use Getopt::Std;
&getopts('ha:df:i:o:p:r:m:u:x:w:p:s:');

if ($opt_h) {
	print <<"	HELP";
	$0 -- uses imtest to connect and authenticate to imap server
	
	Options:
	-h	 print this help message

	-a auth  authenticate as user 'auth'. This value is passed as the '-a' value
		 to imtest and defaults to whatever you supplied for -u.
	-d 	 turn on Mail::IMAPClient debugging 
	-f file	 write Mail::IMAPClient debugging info to file 'file'
	-m mech  use authentication mechanism "mech"; default is to not supply -m to 
		 imtest
	-i path  path to imtest executable; default is to let your shell find it via the
		 PATH environmental variable.
	-p port  port on mail server to connect to (default is 143)
	-r rlm   Use realm 'rlm' (default is name of mail server)
	-s srvr  Name of IMAP mail server (default is the localhost's hostname)
	-u usr   Use 'usr' as the user id (required)
	-w pswd  Use 'pswd' as the password for 'usr' (required)
	-x path  Path to Unix socket (fifo). Default is '/tmp/$0.sock'.
	-o 'ops' Pass the string 'ops' directy to imtest as additional options.
		 This is how you get "other" imtest options passed to imtest. (I only
		 included switches for options that are either really common or useful 
		 to the IMAPClient object as well as to imtest.)

	Many of these switches have the same function here as with imtest. I added a 
	few extras though!  

	Example:
	$0 	-o '-k 128 -l 128' -s imapmail -u test -w testpswd \
		-i /usr/local/src/cyrus/cyrus-imapd-2.1.11/imtest/ \
		-m DIGEST-MD5 

	It's a good idea to test your options by running imtest from the command line
	(but without the -x switch) first. Once you have it working by hand you should
	be able to get it to work from this script (or one remarkably like it) without
	too much bloodshed.

	HELP
	exit;
}

$opt_u and $opt_w or die "No userid/password credentials supplied. I hate that.\n";
$opt_a ||= $opt_u;

if ($opt_i ) {
	$opt_i =~ m#^[/\.]# or $opt_i = "./$opt_i";
	$opt_i =~ m#imtest$# or ( -x $opt_i  and -f $opt_i ) 
		or $opt_i .= ( $opt_i =~ m#/$# ? "imtest" : "/imtest") ;
	-x $opt_i and -f $opt_i or die "Cannot find executable $opt_i\n";
}


$opt_p ||= 143;
$opt_s ||= hostname;
$opt_r ||= $opt_s;
$opt_x ||= "/tmp/$0.sock";


my($rfh,$wfh,$efh) ;


my($imt) = 	($opt_i ? "$opt_i " : "imtest ") .
		($opt_m ? "-m $opt_m ":"" ) .
		qq(-r $opt_r -a $opt_a -u $opt_u ).
		qq(-x $opt_x -w $opt_w -p $opt_p $opt_s);

open3($wfh,$rfh,$efh,$imt);

my $line;

until ($line =~ /^Security strength factor:/i ) {
	$line = <$rfh> or die "EOF\n";
	print STDERR "Prolog: $line" if $opt_d;
}
sleep 5;
my $sock = IO::Socket::UNIX->new("$opt_x")
	or warn "No socket: $!\n" and exit;

print STDERR "<<<END OF PROLOG>>>\n" if $opt_d;
my $imap = Mail::IMAPClient->new;
$imap->Prewritemethod(\&Mail::IMAPClient::Strip_cr);
$imap->User("$opt_u");
$imap->Server("$opt_s");
$imap->Port("$opt_p");
$imap->Debug($opt_d);
$imap->Debug_fh($opt_f||\*STDERR);
$imap->State($imap->Connected);
$imap->Socket($sock);

# Your code goes here:

$imap->Select("INBOX");
for my $m (@{$imap->search("TEXT SUBJECT")} ) {
	print "Message $m:\t",$imap->subject($m),"\n";
}
# You should have finished your code by about here
$imap->logout;

print STDERR "<<<END>>>\n" if $opt_d;

exit;

=head1 NAME

imtestExample.pl -- uses imtest to connect and authenticate to imap server
	

=head1 DESCRIPTION

	
=head2 Options

=over 4

=item -h

print this help message

=item -a auth  

authenticate as user 'auth'. This value is passed as the '-a' value
to imtest and defaults to whatever you supplied for -u.

=item -d 	 

turn on Mail::IMAPClient debugging 

=item -f file	 

write Mail::IMAPClient debugging info to file 'file'

=item -m mech  

use authentication mechanism "mech"; default is to not supply -m to 
 imtest

=item -i path  

path to imtest executable; default is to let your shell find it via the
PATH environmental variable.

=item -p port  

port on mail server to connect to (default is 143)

=item -r rlm   

Use realm 'rlm' (default is name of mail server)

=item -s srvr  

Name of IMAP mail server (default is the localhost's hostname)

=item -u usr   

Use 'usr' as the user id (required)

=item -w pswd  

Use 'pswd' as the password for 'usr' (required)

=item -x path  

Path to Unix socket (fifo). Default is '/tmp/$0.sock'.

=item -o 'ops' 

Pass the string 'ops' directy to imtest as additional options.
This is how you get "other" imtest options passed to imtest. (I only
included switches for options that are either really common or useful 
to the IMAPClient object as well as to imtest.)

Many of these switches have the same function here as with imtest. I added a 
few extras though!  

=back

Example:

 	imtestExample.pl -o '-k 128 -l 128' -s imapmail -u test -w testpswd 	\
		-i /usr/local/src/cyrus/cyrus-imapd-2.1.11/imtest/ 		\
		-m DIGEST-MD5 

It's a good idea to test your options by running imtest from the command line
(but without the -x switch) first. Once you have it working by hand you should
be able to get it to work from this script (or one remarkably like it) without
too much bloodshed.

	
=head1 AUTHOR 
	
David J. Kernen

The Kernen Group, Inc.

imap@kernengroup.com

Based on a suggestion by Tara L. Andrews.

=head1 COPYRIGHT

This example and Mail::IMAPClient are Copyright (c) 2003 
by The Kernen Group, Inc. All rights reserved.

This example is distributed with Mail::IMAPClient and 
subject to the same licensing requirements as Mail::IMAPClient.

imtest is a utility distributed with Cyrus IMAP server, 
Copyright (c) 1994-2000 Carnegie Mellon University.  
All rights reserved. 

=cut


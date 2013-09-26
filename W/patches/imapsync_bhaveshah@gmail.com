#!/usr/bin/perl5.8.8

# structure
# pod documentation
# pragmas
# main program
# global variables initialisation
# default values
# folder loop
# subroutines
# IMAPClient 2.2.9 overrides
# IMAPClient 2.2.9 3.xx ads

# pod documentation

=pod

=head1 NAME 

imapsync - IMAP synchronisation, sync, copy or migration tool.
Synchronises mailboxes between two imap servers.
Good at IMAP migration. More than 52 different IMAP server softwares
supported with success, few failures.

$Revision: 1.564 $

=head1 SYNOPSIS

To synchronize imap account "foo" on "imap.truc.org"
           to  imap account "bar" on "imap.trac.org"
           with foo password "secret1"
           and  bar password "secret2":

  imapsync \
   --host1 imap.truc.org --user1 foo --password1 secret1 \
   --host2 imap.trac.org --user2 bar --password2 secret2

=head1 INSTALL

 imapsync works fine under any Unix OS with perl.
 imapsync works fine under Windows (2000, XP, Vista, Seven) 
 with Strawberry Perl (5.10, 5.12 or higher)
 or as a standalone binary software imapsync.exe

imapsync can be available directly on the following distributions:
FreeBSD, Debian, Ubuntu, Gentoo, Fedora,
NetBSD, Darwin, Mandriva and OpenBSD.

 Purchase latest imapsync at
 http://imapsync.lamiral.info/

 You'll receive a link to a compressed tarball called imapsync-x.xx.tgz
 where x.xx is the version number. Untar the tarball where
 you want (on Unix):

 tar xzvf  imapsync-x.xx.tgz

 Go into the directory imapsync-x.xx and read the INSTALL file.
 The INSTALL file is also at 
 http://imapsync.lamiral.info/INSTALL

 The freecode (was freshmeat) record is at 
 http://freecode.com/projects/imapsync

=head1 USAGE

 imapsync [options]

To get a description of each option just run imapsync like this:

  imapsync --help
  imapsync

The option list:

  imapsync [--host1 server1]  [--port1 <num>]
           [--user1 <string>] [--passfile1 <string>]
           [--host2 server2]  [--port2 <num>]
           [--user2 <string>] [--passfile2 <string>]
           [--ssl1] [--ssl2]
	   [--tls1] [--tls2]
           [--authmech1 <string>] [--authmech2 <string>]
           [--proxyauth1] [--proxyauth2]
	   [--domain1] [--domain2] 
           [--authmd51] [--authmd52]
           [--folder <string> --folder <string> ...]
           [--folderrec <string> --folderrec <string> ...]
           [--include <regex>] [--exclude <regex>]
           [--prefix2 <string>] [--prefix1 <string>] 
           [--regextrans2 <regex> --regextrans2 <regex> ...]
           [--sep1 <char>]
           [--sep2 <char>]
           [--justfolders] [--justfoldersizes] [--justconnect] [--justbanner]
           [--syncinternaldates]
           [--idatefromheader]
           [--syncacls]
           [--regexmess <regex>] [--regexmess <regex>]
           [--maxsize <int>]
	   [--minsize <int>]
           [--maxage <int>]
           [--minage <int>]
           [--search <string>]
           [--search1 <string>]
           [--search2 <string>]
           [--skipheader <regex>]
           [--useheader <string>] [--useheader <string>]
	   [--nouid1] [--nouid2] 
	   [--usecache]
           [--skipsize] [--allowsizemismatch]
           [--delete] [--delete2]
           [--expunge] [--expunge1] [--expunge2] [--uidexpunge2]
	   [--delete2folders] [--delete2foldersonly] [--delete2foldersbutnot]
           [--subscribed] [--subscribe] [--subscribe_all] 
           [--nofoldersizes] [--nofoldersizesatend] 
           [--dry]
           [--debug] [--debugimap][--debugimap1][--debugimap2]
           [--timeout <int>] 
           [--split1] [--split2] 
           [--reconnectretry1 <int>] [--reconnectretry2 <int>]
	   [--noreleasecheck]
	   [--pidfile <filepath>]
	   [--tmpdir  <dirpath>]
           [--version] [--help]
	   [--tests] [--tests_debug]
  
=cut
# comment

=pod

=head1 DESCRIPTION

The command imapsync is a tool allowing incremental and
recursive imap transfer from one mailbox to another. 

By default all folders are transferred, recursively, all 
possible flags (\Seen \Answered \Flagged etc.) are synced too.

We sometimes need to transfer mailboxes from one imap server to
another. This is called migration.

imapsync is a good tool because it reduces the amount
of data transferred by not transferring a given message 
if it is already on both sides. Same headers
and the transfer is done only once. All flags are
preserved, unread will stay unread, read will stay read,
deleted will stay deleted. You can stop the transfer at any
time and restart it later, imapsync works well with bad 
connections.

You can decide to delete the messages from the source mailbox
after a successful transfer, it can be a good feature when migrating
live mailboxes since messages will be only on one side.
In that case, use the --delete option. Option --delete implies 
also option --expunge so all messages marked deleted on host1 
will be really deleted.
(you can use --noexpunge to avoid this but I don't see any
good real world scenario for the combinaison --delete --noexpunge).

You can also just synchronize a mailbox B from another mailbox A
in case you just want to keep a "live" copy of A in B. 
In that case --delete2 can be used, it deletes messages in host2
folder B that are not in host1 folder A.

imapsync is not adequate for maintaining two active imap accounts 
in synchronization where the user plays independently on both sides.
Use offlineimap (written by John Goerzen) or mbsync (written by 
Michael R. Elkins) for 2 ways synchronizations.


=head1 OPTIONS

To get a description of each option just invoke: 

imapsync --help

=head1 HISTORY

I wrote imapsync because an enterprise (basystemes) paid me to install
a new imap server without losing huge old mailboxes located on a far
away remote imap server accessible by a low bandwidth link. The tool
imapcp (written in python) could not help me because I had to verify
every mailbox was well transferred and delete it after a good
transfer. imapsync started life as a copy_folder.pl patch.
The tool copy_folder.pl comes from the Mail-IMAPClient-2.1.3 perl
module tarball source (in the examples/ directory of the tarball).

=head1 EXAMPLE

While working on imapsync parameters please run imapsync in
dry mode (no modification induced) with the --dry
option. Nothing bad can be done this way.

To synchronize the imap account "buddy" (with password "secret1") 
on host "imap.src.fr" to the imap account "max" (with password "secret2") 
on host "imap.dest.fr":

 imapsync --host1 imap.src.fr  --user1 buddy --password1 secret1 \
          --host2 imap.dest.fr --user2 max   --password2 secret2

Then you will have max's mailbox updated from buddy's
mailbox.

=head1 SECURITY

You can use --passfile1  instead of --password1 to give the
password since it is safer. With --password1 option any user 
on your host can see the password by using the 'ps auxwwww'
command. Using a variable (like $PASSWORD1) is also
dangerous because of the 'ps auxwwwwe' command. So, saving
the password in a well protected file (600 or rw-------) is
the best solution.

imasync is not totally protected against sniffers on the
network since passwords may be transferred in plain text
if CRAM-MD5 is not supported by your imap servers.  Use
--ssl1 (or --tls1) and --ssl2 (or --tls2) to enable 
encryption on host1 and host2.

You may authenticate as one user (typically an admin user),
but be authorized as someone else, which means you don't
need to know every user's personal password.  Specify
--authuser1 "adminuser" to enable this on host1.  In this
case, --authmech1 PLAIN will be used by default since it
is the only way to go for now. So don't use --authmech1 SOMETHING
with --authuser1 "adminuser", it will not work.
Same behavior with the --authuser2 option.
Authenticate with an admin account must be supported by your
imap server to work with imapsync.

When working on Sun/iPlanet/Netscape IMAP servers you must use 
--proxyauth1 to enable administrative user to masquerade as another user. 
Can also be used on destination server with --proxyauth2 

You can authenticate with OAUTH when transfering from Google Apps.
The consumer key will be the domain part of the --user, and the
--password will be used as the consumer secret. It does not work
with Google Apps free edition. 

=head1 EXIT STATUS

imapsync will exit with a 0 status (return code) if everything went good.
Otherwise, it exits with a non-zero status.

So if you have an unreliable internet connection, you can use this loop 
in a Bourne shell:

        while ! imapsync ...; do 
              echo imapsync not complete
        done

=head1 LICENSE

imapsync is free, open, public but not always gratis software 
cover by the NOLIMIT Public License.
See the LICENSE file included in the distribution or just read this
simple sentence as it is the licence text:
No limit to do anything with this work and this license.

=head1 MAILING-LIST

The public mailing-list may be the best way to get free support.

To write on the mailing-list, the address is:
<imapsync@linux-france.org>

To subscribe, send any message (even empty) to:
<imapsync-subscribe@listes.linux-france.org>
then just reply to the confirmation message.

To unsubscribe, send a message to:
<imapsync-unsubscribe@listes.linux-france.org>

To contact the person in charge for the list:
<imapsync-request@listes.linux-france.org>

The list archives are available at:
http://www.linux-france.org/prj/imapsync_list/
So consider that the list is public, anyone
can see your post. Use a pseudonym or do not
post to this list if you want to stay private.

Thank you for your participation.

=head1 AUTHOR

Gilles LAMIRAL <gilles.lamiral@laposte.net>

Feedback good or bad is very often welcome.

Gilles LAMIRAL earns his living by writing, installing,
configuring and teaching free, open and often gratis
softwares. It used to be "always gratis" but now it is
"often" because imapsync is sold by its author, a good
way to stay maintening and supporting free open public 
softwares (see the license) over decades.

=head1 BUG REPORT GUIDELINES

Help us to help you: follow the following guidelines.

Report any bugs or feature requests to the public mailing-list 
or to the author.

Before reporting bugs, read the FAQ, the README and the
TODO files. http://imapsync.lamiral.info/

Upgrade to last imapsync release, maybe the bug
is already fixed.

Upgrade to last Mail-IMAPClient Perl module.
http://search.cpan.org/dist/Mail-IMAPClient/
maybe the bug is already fixed.

Make a good title with word "imapsync" in it (my spam filter won't filter it), 
Don't write an email title with just "imapsync" or "problem",
a good title is made of keywords summary, not too long (one visible line).

Don't write imapsync in uppercase in the email title, I'll
then know you run Windows and you haven't read this README yet.

Help us to help you: in your report, please include:

 - imapsync version.

 - output given with --debug --debugimap near the failure point.
   Isolate a message or two in a folder 'BUG' and use 

     imapsync ... --folder 'BUG' --debug --debugimap 

 - imap server software on both side and their version number.

 - imapsync with all the options you use,  the full command line
   you use (except the passwords of course). 

 - IMAPClient.pm version.

 - the run context. Do you run imapsync.exe, a unix binary 
   or the perl script imapsync.

 - operating system running imapsync.

 - virtual software context (vmware, xen etc.)

 - operating systems on both sides and the third side in case
   you run imapsync on a foreign host from the both.

Most of those values can be found as a copy/paste at the begining of the output,
so a copy of the output is a very easy and very good debug report for me.

One time in your life, read the paper 
"How To Ask Questions The Smart Way"
http://www.catb.org/~esr/faqs/smart-questions.html
and then forget it.

=head1 IMAP SERVERS 

Failure stories reported with the following 3 imap servers:

 - MailEnable 1.54 (Proprietary) but MailEnable 4.23 is supported. 
 - DBMail 0.9, 2.0.7 (GPL). But DBMail 1.2.1 is supported.
   Patient and confident testers are welcome.
 - Imail 7.04 (maybe).
 - (2011) MDaemon 12.0.3 as host2 but MDaemon is supported as host1.
   MDaemon is simply buggy with the APPEND IMAP command with 
   any IMAP email client.
 - Hotmail since hotmail.com does not provide IMAP access
 - Outlook.com since outlook.com does not provide IMAP access

Success stories reported with the following 55 imap servers 
(software names are in alphabetic order): 

 - 1und1 H mimap1 84498 [host1] H mibap4 95231 [host1]
 - a1.net imap.a1.net IMAP4 Ready [host1]
 - Apple Server 10.6 Snow Leopard [host1]
 - Archiveopteryx 2.03, 2.04, 2.09, 2.10 [host2], 3.0.0 [host2]
   (OSL 3.0) http://www.archiveopteryx.org/
 - Atmail 6.x [host1]
 - Axigen Mail Server Version 8.0.0
 - BincImap 1.2.3 (GPL) (http://www.bincimap.org/)
 - CommuniGatePro server (Redhat 8.0) (Solaris), CommuniGate Pro 5.2.17[host2] (CentOS 5.4)
 - Courier IMAP 1.5.1, 2.2.0, 2.1.1, 2.2.1, 3.0.8, 3.0.3, 4.1.1 (GPL) 
   (http://www.courier-mta.org/)
 - Critical Path (7.0.020)
 - Cyrus IMAP 1.5, 1.6, 
   2.1, 2.1.15, 2.1.16, 2.1.18 
   2.2.1, 2.2.2-BETA, 2.2.3, 2.2.6, 2.2.10, 2.2.12, 2.2.13,
   2.3-alpha (OSI Approved), 2.3.1, 2.3.7, 2.3.16
   (http://asg.web.cmu.edu/cyrus/)
 - David Tobit V8 (proprietary Message system).
 - Deerfield VisNetic MailServer 5.8.6 [host1] (http://www.deerfield.net/products/visnetic-mailserver/) 
 - DBMail 1.2.1, 2.0.4, 2.0.9, 2.2rc1 (GPL) (http://www.dbmail.org/).
   2.0.7 seems buggy.
 - DBOX 2.41 System [host1] (http://www.dbox.handshake.de/).
 - Deerfield VisNetic MailServer 5.8.6 [host1]
 - dkimap4 [host1]
 - Domino (Notes) 4.61 [host1], 6.5 [host1], 5.0.6, 5.0.7, 7.0.2, 6.0.2CF1, 
   7.0.1 [host1], 8.0.1 [host1], 8.5.2 [host2], 8.5.3 [host1]
 - Dovecot 0.99.10.4, 0.99.14, 0.99.14-8.fc4, 1.0-0.beta2.7, 
   1.0.0 [dest/source] (LGPL) (http://www.dovecot.org/)
 - Eudora WorldMail v2
 - Gimap (Gmail imap)
 - GMX IMAP4 StreamProxy.
 - Groupwise IMAP (Novell) 6.x and 7.0. Buggy so see the FAQ.
 - hMailServer 5.3.3 [host2], 4.4.1 [host1] (see FAQ)
 - iPlanet Messaging server 4.15, 5.1, 5.2
 - IMail 7.15 (Ipswitch/Win2003), 8.12, 11.03 [host1]
 - Kerio 7.2.0 Patch 1 [host12], Kerio 8 [host1]
 - Mail2World IMAP4 Server 2.5 [host1] (http://www.mail2world.com/)
 - MailEnable 4.23 [host1] [host2], 4.26 [host1][host2], 5 [host1]
 - MDaemon 7.0.1, 8.0.2, 8.1, 9.5.4 (Windows server 2003 R2 platform), 
   9.6.5 [host1], 12 [host2], 12.0.3 [host1], 12.5.5 [host1],
 - Mercury 4.1 (Windows server 2000 platform)
 - Microsoft Exchange Server 5.5, 6.0.6249.0[host1], 6.0.6487.0[host1], 
   6.5.7638.1 [host2], 6.5 [host1], Exchange 2007 SP1 (with Update Rollup 2), 
   Exchange2007-EP-SP2,
   Exchange 2010 RTM (Release to Manufacturing) [host2],
   Exchange 2010 SP1 RU2[host2],
 - Mirapoint, 4.1.9-GA [host1]
 - Netscape Mail Server 3.6 (Wintel !)
 - Netscape Messaging Server 4.15 Patch 7
 - Office 365 [host1] [host2]
 - OpenMail IMAP server B.07.00.k0 (Samsung Contact ?)
 - OpenWave
 - Oracle Beehive [host1]
 - Qualcomm Worldmail (NT)
 - QQMail IMAP4Server [host1] [host2] https://en.mail.qq.com/
 - Rockliffe Mailsite 5.3.11, 4.5.6
 - Samsung Contact IMAP server 8.5.0
 - Scalix v10.1, 10.0.1.3, 11.0.0.431, 11.4.6
 - SmarterMail, Smarter Mail 5.0 Enterprise, Smarter Mail 5.5 [host1], SmarterMail Professional 10.2 [host1].
 - Softalk Workgroup Mail 7.6.4 [host1].
 - SunONE Messaging server 5.2, 6.0 (SUN JES - Java Enterprise System)
 - Sun Java(tm) System Messaging Server 6.2-2.05,  6.2-7.05, 6.3
 - Surgemail 3.6f5-5, 6.3d-72 [host2]
 - UW-imap servers (imap-2000b) rijkkramer IMAP4rev1 2000.287
   (RedHat uses UW like 2003.338rh), v12.264 Solaris 5.7 (OSI Approved) 
   (http://www.washington.edu/imap/)
 - UW - QMail v2.1
 - VMS, Imap part of TCP/IP suite of VMS 7.3.2
 - Yahoo [host1]
 - Zarafa 6,40,0,20653 [host1] (http://www.zarafa.com/)
 - Zarafa ZCP 7.1.4 IMAP Gateway [host2]
 - Zimbra-IMAP 3.0.1 GA 160, 3.1.0 Build 279, 4.0.5, 4.5.2, 4.5.6, 
   Zimbra 5.0.24_GA_3356.RHEL4 [host1], 5.5, 6.x

Please report to the author any success or bad story with
imapsync and do not forget to mention the IMAP server
software names and version on both sides. This will help
future users. To help the author maintaining this section
report the two lines at the begining of the output if they
are useful to know the softwares. Example:

 Host1 software:* OK louloutte Cyrus IMAP4 v1.5.19 server ready
 Host2 software:* OK Courier-IMAP ready

You can use option --justconnect to get those lines.
Example:

  imapsync --host1 imap.troc.org --host2 imap.trac.org --justconnect


=head1 HUGE MIGRATION

Pay special attention to options 
--subscribed
--subscribe
--delete
--delete2
--delete2folders
--maxage
--minage
--maxsize
--useuid
--usecache

If you have many mailboxes to migrate think about a little
shell program. Write a file called file.txt (for example)
containing users and passwords.
The separator used in this example is ';'

The file.txt file contains:

user001_1;password001_1;user001_2;password001_2
user002_1;password002_1;user002_2;password002_2
user003_1;password003_1;user003_2;password003_2
user004_1;password004_1;user004_2;password004_2
user005_1;password005_1;user005_2;password005_2
...

On Unix the shell program can be:

 { while IFS=';' read  u1 p1 u2 p2; do 
	imapsync --host1 imap.side1.org --user1 "$u1" --password1 "$p1" \
                 --host2 imap.side2.org --user2 "$u2" --password2 "$p2" ...
 done ; } < file.txt

On Windows the batch program can be:

  FOR /F "tokens=1,2,3,4 delims=; eol=#" %%G IN (file.txt) DO imapsync ^
  --host1 imap.side1.org --user1 %%G --password1 %%H ^
  --host2 imap.side2.org --user2 %%I --password2 %%J ...

The ... have to be replaced by nothing or any imapsync option.

Welcome in shell programming !

=head1 Hacking

Feel free to hack imapsync as the NOLIMIT license permits it.

=head1 Links

Entries for imapsync:
  http://www.imap.org/products/showall.php


=head1 SIMILAR SOFTWARES

  imap_tools    : http://www.athensfbc.com/imap_tools
  offlineimap   : https://github.com/nicolas33/offlineimap
  mbsync        : http://isync.sourceforge.net/
  mailsync      : http://mailsync.sourceforge.net/
  mailutil      : http://www.washington.edu/imap/
                  part of the UW IMAP tookit.
  imaprepl      : http://www.bl0rg.net/software/
                  http://freecode.com/projects/imap-repl/
  imapcopy      : http://home.arcor.de/armin.diehl/imapcopy/imapcopy.html
  migrationtool : http://sourceforge.net/projects/migrationtool/
  imapmigrate   : http://sourceforge.net/projects/cyrus-utils/
  wonko_imapsync: http://wonko.com/article/554
                  see also file W/tools/wonko_ruby_imapsync
  exchange-away : http://exchange-away.sourceforge.net/
  pop2imap      : http://www.linux-france.org/prj/pop2imap/


Feedback (good or bad) will often be welcome.

$Id: imapsync,v 1.564 2013/08/18 19:28:47 gilles Exp gilles $

=cut


# pragmas

use strict;
use warnings;
++$|;
use Carp;
use Getopt::Long;
use Mail::IMAPClient 3.29 ;
use Digest::MD5  qw( md5 md5_hex md5_base64 );
use Digest::HMAC_SHA1 qw( hmac_sha1 ) ;
#use Term::ReadKey;
#use IO::Socket::SSL;
use MIME::Base64;
use English '-no_match_vars' ;
use File::Basename;
use POSIX qw(uname SIGALRM);
use Fcntl;
use File::Spec;
use File::Path qw(mkpath rmtree);
use IO::Socket qw(:crlf SOL_SOCKET SO_KEEPALIVE);
use Errno qw(EAGAIN EPIPE ECONNRESET);
use File::Glob qw( :glob ) ;
use IO::File;
use Time::Local ;
use Time::HiRes qw( time ) ;
use Test::More 'no_plan' ;
use IPC::Open3 'open3' ;
#use Unix::Sysexits ;

# global variables

my(
        $rcs, $pidfile, $pidfilelocking, 
	$debug, $debugimap, $debugimap1, $debugimap2, $debugcontent, $debugflags,
	$debugLIST, $debugsleep, $debugdev, 
	$nb_errors,
	$host1, $host2, $port1, $port2,
	$user1, $user2, $domain1, $domain2, 
	$password1, $password2, $passfile1, $passfile2,
        @folder, @include, @exclude, @folderrec,
        $prefix1, $prefix2, 
        @regextrans2, @regexmess, @regexflag,
	$flagsCase, $filterflags, $syncflagsaftercopy,
        $sep1, $sep2,
	$syncinternaldates,
        $idatefromheader,
        $syncacls,
        $fastio1, $fastio2, 
	$maxsize, $minsize, $maxage, $minage,
        $exitwhenover,
        $search, $search1, $search2, 
        $skipheader, @useheader,
        $skipsize, $allowsizemismatch, $foldersizes, $foldersizesatend, $buffersize,
	$delete, $delete2, $delete2duplicates,
        $expunge, $expunge1, $expunge2, $uidexpunge2, $dry,
        $justfoldersizes,
        $authmd5, $authmd51, $authmd52, 
        $subscribed, $subscribe, $subscribe_all,
	$version, $help, 
        $justconnect, $justfolders, $justbanner,
        $fast,
        
        $total_bytes_transferred,
        $total_bytes_skipped,
        $total_bytes_error,
        $nb_msg_transferred, 
	$nb_msg_skipped, 
	$nb_msg_skipped_dry_mode,
	$h1_nb_msg_duplicate,
	$h2_nb_msg_duplicate,
	$h1_nb_msg_noheader,
	$h2_nb_msg_noheader,
	$h1_total_bytes_duplicate,
	$h2_total_bytes_duplicate,
	$h1_nb_msg_deleted,
	$h2_nb_msg_deleted,
        
        $h1_bytes_processed, 
        $h1_nb_msg_processed,
        $h1_nb_msg_at_start, $h1_bytes_start,
        $h2_nb_msg_start, $h2_bytes_start, 
        $h1_nb_msg_end, $h1_bytes_end,
        $h2_nb_msg_end, $h2_bytes_end, 
        
        $timeout,
	$timestart, $timestart_int, $timeend,
        $timebefore,
        $ssl1, $ssl2, 
        $ssl1_SSL_version, $ssl2_SSL_version,
	$tls1, $tls2,
	$uid1, $uid2,
        $authuser1, $authuser2,
        $proxyauth1, $proxyauth2,
        $authmech1, $authmech2,
        $split1, $split2,
        $reconnectretry1, $reconnectretry2,
	$relogin1, $relogin2,
	$tests, $test_builder, $tests_debug,
	$allow3xx, $justlogin,
	$tmpdir,
	$releasecheck,
	$max_msg_size_in_bytes,
	$modules_version,
	$delete2folders, $delete2foldersonly, $delete2foldersbutnot,
	$usecache, $debugcache, $cacheaftercopy,
	$wholeheaderifneeded, %h1_msgs_copy_by_uid, $useuid, $h2_uidguess,
        $addheader,
        %h1, %h2,
        $checkselectable, $checkmessageexists,
        $expungeaftereach,
        $abletosearch,
        $showpasswords,
        $fixslash2,
        $messageidnodomain,
        $fixInboxINBOX,
        $maxlinelength,
	$uidnext_default,
);

# main program

# global variables initialisation

$rcs = '$Id: imapsync,v 1.564 2013/08/18 19:28:47 gilles Exp gilles $ ';

$total_bytes_transferred   = 0;
$total_bytes_skipped = 0;
$total_bytes_error   = 0;
$nb_msg_transferred = 0;
$nb_msg_skipped = $nb_msg_skipped_dry_mode = 0;
$h1_nb_msg_deleted = $h2_nb_msg_deleted = 0;
$h1_nb_msg_duplicate = $h2_nb_msg_duplicate = 0;
$h1_nb_msg_noheader = $h2_nb_msg_noheader = 0;
$h1_total_bytes_duplicate = $h2_total_bytes_duplicate = 0;


$h1_nb_msg_at_start     = $h1_bytes_start = 0 ;
$h2_nb_msg_start     = $h2_bytes_start = 0 ;
$h1_nb_msg_processed = $h1_bytes_processed = 0 ;

$h1_nb_msg_end = $h1_bytes_end = 0 ;
$h2_nb_msg_end = $h2_bytes_end = 0 ;

$nb_errors = 0;
$max_msg_size_in_bytes = 0;

my %month_abrev = (
   Jan => 0,
   Feb => 1,
   Mar => 2,
   Apr => 3,
   May => 4,
   Jun => 5,
   Jul => 6,
   Aug => 7,
   Sep => 8,
   Oct => 9,
   Nov => 10,
   Dec => 11,
);

sub EX_USAGE { 
	# 64 on my linux box.
        # See http://search.cpan.org/~jmates/Unix-Sysexits-0.02/lib/Unix/Sysexits.pm
	return( 64 ) ;
}


# @ARGV will be eat by get_options()
my @argv_copy = @ARGV;

get_options();

# $SIG{ INT } = \&catch_continue ;
local $SIG{ INT } = local $SIG{ QUIT } = local $SIG{ TERM } = \&catch_exit ;

$timestart = time(  );
$timestart_int = int( $timestart ) ;
$timebefore = $timestart;

my $timestart_str = localtime( $timestart ) ;
print   "Transfer started at $timestart_str\n";

$modules_version = defined($modules_version) ? $modules_version : 1;


$releasecheck = defined($releasecheck) ? $releasecheck : 1;
my $warn_release = ($releasecheck) ? check_last_release() : '';

# default values

$tmpdir ||= File::Spec->tmpdir();
$pidfile ||= $tmpdir . '/imapsync.pid';

$pidfilelocking = defined( $pidfilelocking ) ? $pidfilelocking : 0 ;

# allow Mail::IMAPClient 3.0.xx by default
$allow3xx = defined($allow3xx) ? $allow3xx : 1;

$wholeheaderifneeded  = defined( $wholeheaderifneeded )  ? $wholeheaderifneeded  : 1;

# turn on RFC standard flags correction like \SEEN -> \Seen
$flagsCase = defined( $flagsCase ) ? $flagsCase : 1 ;

# Use PERMANENTFLAGS if available
$filterflags = defined( $filterflags ) ? $filterflags : 1 ;

# sync flags just after an APPEND, some servers ignore the flags given in the APPEND
# like MailEnable IMAP server.
# Off by default since it takes time.
$syncflagsaftercopy = defined( $syncflagsaftercopy ) ? $syncflagsaftercopy : 0 ;



# turn on relogin 5 by default
$relogin1 = defined( $relogin1 ) ? $relogin1 : 5 ;
$relogin2 = defined( $relogin2 ) ? $relogin2 : 5 ;

if ( $fast ) {
	# $useuid = 1 ;
	# $foldersizes      = 0 ;
	# $foldersizesatend = 0 ;
}

# Activate --usecache if --useuid is set and no --nousecache
$usecache = 1 if ( $useuid and ( ! defined( $usecache ) ) ) ;
$cacheaftercopy = 1 if ( $usecache and ( ! defined( $cacheaftercopy ) ) ) ;

$checkselectable = defined( $checkselectable ) ? $checkselectable : 1 ;
$checkmessageexists = defined( $checkmessageexists ) ? $checkmessageexists : 0 ;
$expungeaftereach = defined( $expungeaftereach ) ? $expungeaftereach : 1 ;
$abletosearch = defined( $abletosearch ) ? $abletosearch : 1 ;
$checkmessageexists = 0 if ( not $abletosearch ) ;
$showpasswords = defined( $showpasswords ) ? $showpasswords : 0 ;
$fixslash2 = defined( $fixslash2 ) ? $fixslash2 : 1 ;
$fixInboxINBOX = defined( $fixInboxINBOX ) ? $fixInboxINBOX : 1 ;

$delete2duplicates = 1 if ( $delete2 and ( ! defined( $delete2duplicates ) ) ) ;

print banner_imapsync(@argv_copy);

print "Temp directory is $tmpdir\n";

is_valid_directory($tmpdir);
write_pidfile($pidfile) if ($pidfile);

$modules_version and print "Modules version list:\n", modules_VERSION(), "\n";

check_lib_version() or 
  croak "imapsync needs perl lib Mail::IMAPClient release 3.25 or superior \n";

exit_clean(0) if ($justbanner);

# By default, 100 at a time, not more.
$split1 ||= 100;
$split2 ||= 100;

$host1 || missing_option("--host1") ;
$port1 ||= ( $ssl1 ) ? 993 : 143;

$host2 || missing_option("--host2") ;
$port2 ||= ( $ssl2 ) ? 993 : 143;

$debugimap1 = $debugimap2 = 1 if ( $debugimap ) ;
$debug = 1 if ( $debugimap1 or $debugimap2 ) ;

# By default, don't take size to compare 
$skipsize = (defined $skipsize) ? $skipsize : 1;

$uid1 = defined($uid1) ? $uid1 : 1;
$uid2 = defined($uid2) ? $uid2 : 1;

$subscribe = defined($subscribe) ? $subscribe : 1;

# Allow size mismatch by default
$allowsizemismatch = defined($allowsizemismatch) ? $allowsizemismatch : 1;

$delete2folders = 1 
    if ( defined( $delete2foldersbutnot ) or defined( $delete2foldersonly ) ) ;

if ($justconnect) {
	justconnect();
	exit_clean(0);
}

$user1 || missing_option("--user1");
$user2 || missing_option("--user2");

$syncinternaldates = defined($syncinternaldates) ? $syncinternaldates : 1;

# Turn on expunge if there is not explicit option --noexpunge and option 
# --delete is given.
# Done because --delete --noexpunge is very dangerous on the second run:
# the Deleted flag is then synced to all previously transfered messages.
# So --delete implies --expunge is a better usability default behaviour.
if ($delete) {
	if ( ! defined($expunge)) {
		$expunge = 1;
	}
}

if ( $uidexpunge2 and not Mail::IMAPClient->can( 'uidexpunge' ) ) {
        print "Failure: uidexpunge not supported (IMAPClient release < 3.17), use --expunge2 instead\n" ;
        exit_clean( 3 ) ;
}

if ( ( $delete2 or $delete2duplicates ) and not defined( $uidexpunge2 ) ) {
        if ( Mail::IMAPClient->can( 'uidexpunge' ) ) {
                print "Info: will act as --uidexpunge2\n" ;
		$uidexpunge2 = 1 ;
        }elsif ( not defined( $expunge2 ) ) {
                 print "Info: will act as --expunge2 (no uidexpunge support)\n" ;
                $expunge2 = 1 ;
        }
}

if ( $delete and $delete2 ) {
	print "Warning: using --delete and --delete2 together is almost always a bad idea, exiting imapsync\n" ;
	exit_clean( 4 ) ;
}

if ($idatefromheader) {
	print "Turned ON idatefromheader, ",
	      "will set the internal dates on host2 from the 'Date:' header line.\n";
	$syncinternaldates = 0;
}

if ($syncinternaldates) {
	print "Info: turned ON syncinternaldates, ",
	      "will set the internal dates (arrival dates) on host2 same as host1.\n";
}else{
	print "Info: turned OFF syncinternaldates\n";
}



if (defined($authmd5) and ($authmd5)) {
	$authmd51 = 1 ;
	$authmd52 = 1 ;
}

if (defined($authmd51) and ($authmd51)) {
	$authmech1 ||= 'CRAM-MD5';
}
else{
	$authmech1 ||= $authuser1 ? 'PLAIN' : 'LOGIN';
}

if (defined($authmd52) and ($authmd52)) {
	$authmech2 ||= 'CRAM-MD5';
}
else{
	$authmech2 ||= $authuser2 ? 'PLAIN' : 'LOGIN';
}

$authmech1 = uc($authmech1);
$authmech2 = uc($authmech2);

if (defined $proxyauth1 && !$authuser1) {
        missing_option("With --proxyauth1, --authuser1");
}

if (defined $proxyauth2 && !$authuser2) {
        missing_option("With --proxyauth2, --authuser2");
}

$authuser1 ||= $user1;
$authuser2 ||= $user2;

print "Info: will try to use $authmech1 authentication on host1\n";
print "Info: will try to use $authmech2 authentication on host2\n";

$timeout = defined( $timeout ) ? $timeout : 120 ;
print "Info: imap connexions timeout is $timeout seconds\n";


$syncacls = (defined($syncacls)) ? $syncacls : 0 ;
$foldersizes = (defined($foldersizes)) ? $foldersizes : 1 ;
$foldersizesatend = (defined($foldersizesatend)) ? $foldersizesatend : $foldersizes ;



$fastio1 = (defined($fastio1)) ? $fastio1 : 0;
$fastio2 = (defined($fastio2)) ? $fastio2 : 0;

$reconnectretry1 = (defined($reconnectretry1)) ? $reconnectretry1 : 3;
$reconnectretry2 = (defined($reconnectretry2)) ? $reconnectretry2 : 3;

# Since select_msgs() returns no messages when uidnext does not return something
# then $uidnext_default is never used. So I have to remove it.
$uidnext_default = 999999 ;

@useheader = ( "Message-Id", "Message-ID", "Received" ) unless ( @useheader ) ;

my %useheader ;

# Make a hash %useheader of each --useheader 'key' in uppercase
for ( @useheader ) { $useheader{ uc( $_ ) } = undef } ;

#require Data::Dumper ;
#print Data::Dumper->Dump( [ \%useheader ] ) ;
#exit ;

print "Host1: IMAP server [$host1] port [$port1] user [$user1]\n";
print "Host2: IMAP server [$host2] port [$port2] user [$user2]\n";

$password1 || $passfile1 || do {
        $password1 = ask_for_password($authuser1 || $user1, $host1) unless ($authmech1 eq "EXTERNAL");
};

$password1 = (defined($passfile1)) ? firstline ($passfile1) : $password1;

#$password1 || $passfile1 || 'PREAUTH' eq $authmech1 || do {
#	$password1 = ask_for_password( $authuser1 || $user1, $host1 ) ;
#} ;

#$password1 = ( defined( $passfile1 ) ) ? firstline ( $passfile1 ) : $password1 ;

$password2 || $passfile2 || 'PREAUTH' eq $authmech2 || do {
	$password2 = ask_for_password( $authuser2 || $user2, $host2 ) ;
} ;

$password2 = ( defined( $passfile2 ) ) ? firstline ( $passfile2 ) : $password2 ;


my $dry_message = '' ;
$dry_message = "\t(not really since --dry mode)" if $dry ;

$search1 ||= $search if ( $search ) ;
$search2 ||= $search if ( $search ) ;


if ( @regexmess ) {
	my $string = regexmess( '' ) ;
        # string undef means one of the eval regex was bad.
        if ( not ( defined( $string ) ) ) {
        	die_clean( "Error: one of --regexmess option is bad, check it" ) ;
        }
}

if ( @regexflag and not ( defined( flags_regex( '' ) ) ) ) {
        die_clean( "Error: one of --regexmess option is bad, check it" ) ;
}

my $imap1 = ();
my $imap2 = ();

$debugimap1 and print "Host1 connection\n";
$imap1 = login_imap($host1, $port1, $user1, $domain1, $password1, 
		   $debugimap1, $timeout, $fastio1, $ssl1, $tls1,
		   $authmech1, $authuser1, $reconnectretry1,
		   $proxyauth1, $uid1, $split1, 'Host1', $ssl1_SSL_version );

$debugimap2 and print "Host2 connection\n";
$imap2 = login_imap($host2, $port2, $user2, $domain2, $password2, 
		 $debugimap2, $timeout, $fastio2, $ssl2, $tls2,
		 $authmech2, $authuser2, $reconnectretry2,
		 $proxyauth2, $uid2, $split2, 'Host2', $ssl2_SSL_version );


$debug and print "Host1 Buffer I/O: ", $imap1->Buffer(), "\n";
$debug and print "Host2 Buffer I/O: ", $imap2->Buffer(), "\n";



die_clean( 'Not authenticated on host1' ) unless $imap1->IsAuthenticated( ) ;
print "Host1: state Authenticated\n";
die_clean( 'Not authenticated on host2' ) unless   $imap2->IsAuthenticated( ) ;
print "Host2: state Authenticated\n";

print "Host1 capability: ", join(" ", @{ $imap1->capability_update() || [] }), "\n";
print "Host2 capability: ", join(" ", @{ $imap2->capability_update() || [] }), "\n";


exit_clean(0) if ($justlogin);

# 
# Folder stuff
#

my (
@h1_folders_all, %h1_folders_all, @h1_folders_wanted, %requested_folder, 
%h1_subscribed_folder, %h2_subscribed_folder, 
@h2_folders_all, %h2_folders_all, 
@h2_folders_from_1_wanted, %h2_folders_from_1_wanted, 
%h2_folders_from_1_several, 
%h2_folders_from_1_all,
);


# Make a hash of subscribed folders in both servers.

for ( $imap1->subscribed(  ) ) { $h1_subscribed_folder{ $_ } = 1 } ;
for ( $imap2->subscribed(  ) ) { $h2_subscribed_folder{ $_ } = 1 } ;

# All folders on host1 and host2
@h1_folders_all = sort $imap1->folders();
@h2_folders_all = sort $imap2->folders();

for ( @h1_folders_all ) { $h1_folders_all{ $_ } = 1 } ;
for ( @h2_folders_all ) { $h2_folders_all{ $_ } = 1 } ;

if ( $fixInboxINBOX and ( my $reg = fix_Inbox_INBOX_mapping( \%h1_folders_all, \%h2_folders_all ) ) ) {
	#print "RRRRRR $reg\n" ;
	push( @regextrans2, $reg ) ;
} 

if (scalar(@folder) or $subscribed or scalar(@folderrec)) {
	# folders given by option --folder
	if (scalar(@folder)) {
		add_to_requested_folders(@folder);
	}
	
	# option --subscribed
	if ( $subscribed ) {
		add_to_requested_folders( keys ( %h1_subscribed_folder ) ) ;
	}
	
	# option --folderrec
	if (scalar(@folderrec)) {
		foreach my $folderrec (@folderrec) {
			add_to_requested_folders($imap1->folders($folderrec));
		}
	}
}
else {
	# no include, no folder/subscribed/folderrec options => all folders
	if (not scalar(@include)) {
		add_to_requested_folders(@h1_folders_all);
	}
}


# consider (optional) includes and excludes
if ( scalar( @include ) ) {
	foreach my $include ( @include ) {
		my @included_folders = grep { /$include/x } @h1_folders_all ;
		add_to_requested_folders( @included_folders ) ;
		print "Including folders matching pattern '$include': @included_folders\n" ;
	}
}

if ( scalar( @exclude ) ) {
	foreach my $exclude ( @exclude ) {
		my @requested_folder = sort( keys( %requested_folder ) ) ;
		my @excluded_folders = grep { /$exclude/x } @requested_folder ;
		remove_from_requested_folders( @excluded_folders ) ;
		print "Excluding folders matching pattern '$exclude': @excluded_folders\n" ;
	}
}

# Remove no selectable folders

$checkselectable and do {
	foreach my $folder (keys(%requested_folder)) {
        	if ( not $imap1->selectable($folder)) {
			print "Warning: ignoring folder $folder because it is not selectable\n";
                	remove_from_requested_folders($folder);
        	}
	}
} ;

my @requested_folder = sort(keys(%requested_folder));

@h1_folders_wanted = @requested_folder;

#my $h1_namespace = $imap1->namespace() ;
#my $h2_namespace = $imap2->namespace() ;
#require Data::Dumper ;
#$debug and print "Host1 namespace:\n", Data::Dumper->Dump([$h1_namespace]) ;
#$debug and print "Host2 namespace:\n", Data::Dumper->Dump([$h2_namespace]) ;

my($h1_sep,$h2_sep); 
# what are the private folders separators for each server ?

$debug and print "Getting separators\n";
$h1_sep = get_separator($imap1, $sep1, "--sep1");
$h2_sep = get_separator($imap2, $sep2, "--sep2");

my($h1_prefix,$h2_prefix); 
$h1_prefix = get_prefix($imap1, $prefix1, "--prefix1");
$h2_prefix = get_prefix($imap2, $prefix2, "--prefix2");


print "Host1 separator and prefix: [$h1_sep][$h1_prefix]\n";
print "Host2 separator and prefix: [$h2_sep][$h2_prefix]\n";

#my $h1_xlist_folders = $imap1->xlist_folders(  ) ;
#my $h2_xlist_folders = $imap2->xlist_folders(  ) ;
#require Data::Dumper ;
#print "Host1 xlist:\n", Data::Dumper->Dump([$h1_xlist_folders]) ;
#print "Host2 xlist:\n", Data::Dumper->Dump([$h2_xlist_folders]) ;

#exit ;

foreach my $h1_fold ( @h1_folders_wanted ) {
	my $h2_fold ;
	$h2_fold = imap2_folder_name( $h1_fold ) ;
	$h2_folders_from_1_wanted{ $h2_fold }++ ;
        if ( 1 < $h2_folders_from_1_wanted{ $h2_fold } ) {
        	$h2_folders_from_1_several{ $h2_fold }++ ;
        }
} 
@h2_folders_from_1_wanted = sort keys(%h2_folders_from_1_wanted);

foreach my $h1_fold (@h1_folders_all) {
	my $h2_fold;
	$h2_fold = imap2_folder_name($h1_fold);
	$h2_folders_from_1_all{$h2_fold}++;
}


if ( $foldersizes ) {
	( $h1_nb_msg_at_start, $h1_bytes_start ) = foldersizes( "Host1", $imap1, $search1, @h1_folders_wanted ) ;
	( $h2_nb_msg_start, $h2_bytes_start ) = foldersizes( "Host2", $imap2, $search2, @h2_folders_from_1_wanted ) ;
	$fast or sleep( 2 ) ;
}


exit_clean(0) if ($justfoldersizes);

print 
  "++++ Listing folders\n",
  "Host1 folders list:\n", map( { "[$_]\n" } @h1_folders_all ), "\n",
  "Host2 folders list:\n", map( { "[$_]\n" } @h2_folders_all ), "\n" ;

print 
  "Host1 subscribed folders list: ", 
  map( { "[$_] " } sort keys( %h1_subscribed_folder ) ), "\n" 
  if ( $subscribed ) ;

my @h2_folders_not_in_1;
@h2_folders_not_in_1 = list_folders_in_2_not_in_1();

print "Folders in host2 not in host1:\n", 
  map( { "[$_]\n" } @h2_folders_not_in_1 ), "\n" ;

delete_folders_in_2_not_in_1() if $delete2folders;

# folder loop
print "++++ Looping on each folder\n";

my $begin_transfer_time = time ;


my %uid_candidate_for_deletion ;
my %uid_candidate_no_deletion ;

FOLDER: foreach my $h1_fold ( @h1_folders_wanted ) {

        last FOLDER if $imap1->IsUnconnected();
        last FOLDER if $imap2->IsUnconnected();

	my $h2_fold = imap2_folder_name( $h1_fold ) ;
	#relogin1(  ) if ( $relogin1 ) ;
	printf( "%-35s -> %-35s\n", "[$h1_fold]", "[$h2_fold]" ) ;

	# host1 can not be fetched read only, select is needed because of expunge.
	select_folder( $imap1, $h1_fold, 'Host1' ) or next FOLDER ;
	#examine_folder( $imap1, $h1_fold, 'Host1' ) or next FOLDER ;
	
	
	if ( ! exists( $h2_folders_all{ $h2_fold } ) ) {
		create_folder( $imap2, $h2_fold, $h1_fold ) or next FOLDER ;
	}
	
	acls_sync( $h1_fold, $h2_fold ) ;
	
        # Sometimes the folder on host2 is listed (it exists) but is
        # not selectable but becomes selectable by a create (Gmail)
	select_folder( $imap2, $h2_fold, 'Host2' ) 
        or ( create_folder( $imap2, $h2_fold, $h1_fold ) 
             and select_folder( $imap2, $h2_fold, 'Host2' ) )
        or next FOLDER ;
	my @select_results = $imap2->Results(  ) ;
	
	#print "%%% @select_results\n" ;
	my $permanentflags2 = permanentflags( @select_results ) ;
	( $debug or $debugflags ) and print "permanentflags: $permanentflags2\n" ;

	if ( $expunge or $expunge1 ){
		print "Expunging host1 $h1_fold $dry_message\n" ;
		unless($dry) { $imap1->expunge() } ;
		#print "Expunging host2 $h2_fold\n" ;
		#unless($dry) { $imap2->expunge() } ;
	}
	
	if ( ( ( $subscribe and exists $h1_subscribed_folder{ $h1_fold } ) or $subscribe_all )
             and not exists( $h2_subscribed_folder{ $h2_fold } ) ) {
		print "Subscribing to folder $h2_fold on destination server\n" ;
		unless( $dry ) { $imap2->subscribe( $h2_fold ) } ;
	}
	
	next FOLDER if ($justfolders);

        last FOLDER if $imap1->IsUnconnected();
        last FOLDER if $imap2->IsUnconnected();

        my $h1_msgs_all_hash_ref = {  } ;
	my @h1_msgs = select_msgs( $imap1, $h1_msgs_all_hash_ref, $search1, $h1_fold );
	last FOLDER if $imap1->IsUnconnected();
        
        my $h1_msgs_nb = scalar( @h1_msgs ) ;
        $h1{ $h1_fold }{ 'messages_nb' } = $h1_msgs_nb ;

	( $debug or $debugLIST ) and print "Host1 LIST: $h1_msgs_nb messages [@h1_msgs]\n" ;
        $debug and print "Host1 selecting messages of folder [$h1_fold] took ", timenext(), " s\n";
        
        my $h2_msgs_all_hash_ref = {  } ;
	my @h2_msgs = select_msgs( $imap2, $h2_msgs_all_hash_ref, $search2, $h2_fold ) ;
	last FOLDER if $imap2->IsUnconnected();
        
        my $h2_msgs_nb = scalar( @h2_msgs ) ;
        $h2{ $h2_fold }{ 'messages_nb' } = $h2_msgs_nb ;

	( $debug or $debugLIST ) and print "Host2 LIST: $h2_msgs_nb messages [@h2_msgs]\n";
        $debug and print "Host2 selecting messages of folder [$h2_fold] took ", timenext(), " s\n";
        
	my $cache_base = "$tmpdir/imapsync_cache/$host1/$user1/$host2/$user2" ;
	my $cache_dir = cache_folder( $cache_base, $h1_fold, $h2_fold ) ;
	my ( $cache_1_2_ref, $cache_2_1_ref ) = ( {}, {} ) ;
        
	my $h1_uidvalidity = $imap1->uidvalidity(  ) || '' ;
	my $h2_uidvalidity = $imap2->uidvalidity(  ) || '' ;

        last FOLDER if $imap1->IsUnconnected() ;
        last FOLDER if $imap2->IsUnconnected() ;

	if ( $usecache ) {
		print "cache directory: $cache_dir\n" ;
		mkpath( "$cache_dir" ) ;
		( $cache_1_2_ref, $cache_2_1_ref ) 
                = get_cache( $cache_dir, \@h1_msgs, \@h2_msgs, $h1_msgs_all_hash_ref, $h2_msgs_all_hash_ref ) ;
		print "CACHE h1 h2: ", scalar( keys %$cache_1_2_ref ), " files\n" ; 
		$debug and print '[',
		    map ( { "$_->$cache_1_2_ref->{$_} " } keys %$cache_1_2_ref ), " ]\n";
	}
	
	my %h1_hash = ();
	my %h2_hash = ();
	
	my ( %h1_msgs, %h2_msgs ) ;
	@h1_msgs{ @h1_msgs } = ();
	@h2_msgs{ @h2_msgs } = ();
	
	my @h1_msgs_in_cache = sort { $a <=> $b } keys %$cache_1_2_ref ;
	my @h2_msgs_in_cache = keys %$cache_2_1_ref ;
	
	my ( %h1_msgs_not_in_cache, %h2_msgs_not_in_cache ) ;
	%h1_msgs_not_in_cache = %h1_msgs ;
	%h2_msgs_not_in_cache = %h2_msgs ;
	delete @h1_msgs_not_in_cache{ @h1_msgs_in_cache } ;
	delete @h2_msgs_not_in_cache{ @h2_msgs_in_cache } ;
	
	my @h1_msgs_not_in_cache = keys %h1_msgs_not_in_cache ;
	#print "h1_msgs_not_in_cache: [@h1_msgs_not_in_cache]\n" ;
	my @h2_msgs_not_in_cache = keys %h2_msgs_not_in_cache ;
	
	my @h2_msgs_delete2_not_in_cache = () ;
	%h1_msgs_copy_by_uid = (  ) ;
	
	if ( $useuid ) {
		# use uid so we have to avoid getting header
		@h1_msgs_copy_by_uid{ @h1_msgs_not_in_cache } = (  ) ;
		@h2_msgs_delete2_not_in_cache = @h2_msgs_not_in_cache if $usecache ;
		@h1_msgs_not_in_cache = (  ) ;
		@h2_msgs_not_in_cache = (  ) ;
		
		#print "delete2: @h2_msgs_delete2_not_in_cache\n";
	}
	
	$debug and print "Host1 parsing headers of folder [$h1_fold]\n";

	my ($h1_heads_ref, $h1_fir_ref) = ({}, {});
	$h1_heads_ref = $imap1->parse_headers([@h1_msgs_not_in_cache], @useheader) if (@h1_msgs_not_in_cache);
	$debug and print "Host1 parsing headers of folder [$h1_fold] took ", timenext(), " s\n";

	@$h1_fir_ref{@h1_msgs} = (undef);
        
	$debug and print "Host1 getting flags idate and sizes of folder [$h1_fold]\n" ;
        if ( $abletosearch ) {
		$h1_fir_ref = $imap1->fetch_hash( \@h1_msgs, "FLAGS", "INTERNALDATE", "RFC822.SIZE", $h1_fir_ref )
	  	if ( @h1_msgs ) ;
        }else{
		my $uidnext = $imap1->uidnext( $h1_fold ) || $uidnext_default ;
		$h1_fir_ref = $imap1->fetch_hash( "1:$uidnext", "FLAGS", "INTERNALDATE", "RFC822.SIZE", $h1_fir_ref )
		if ( @h1_msgs ) ;
        }
	$debug and print "Host1 getting flags idate and sizes of folder [$h1_fold] took ", timenext(), " s\n";
	unless ($h1_fir_ref) {
		print
		"Host1 folder $h1_fold: Could not fetch_hash ",
		scalar(@h1_msgs), " msgs: ", $imap1->LastError || '', "\n";
		$nb_errors++;
		next FOLDER;
	}

	my @h1_msgs_duplicate;
	foreach my $m (@h1_msgs_not_in_cache) {
		my $rc = parse_header_msg($imap1, $m, $h1_heads_ref, $h1_fir_ref, 'Host1', \%h1_hash);
		if (! defined($rc)) {
			my $h1_size = $h1_fir_ref->{$m}->{"RFC822.SIZE"} || 0;
			print "Host1 $h1_fold/$m size $h1_size ignored (no wanted headers so we ignore this message. To solve this: use --addheader)\n" ;
			$total_bytes_skipped += $h1_size;
			$nb_msg_skipped += 1;
			$h1_nb_msg_noheader +=1;
                        $h1_nb_msg_processed +=1 ;
		} elsif(0 == $rc) {
			# duplicate
			push(@h1_msgs_duplicate, $m);
			# duplicate, same id same size?
			my $h1_size = $h1_fir_ref->{$m}->{"RFC822.SIZE"} || 0;
			$nb_msg_skipped += 1;
			$h1_total_bytes_duplicate += $h1_size;
			$h1_nb_msg_duplicate += 1;
                        $h1_nb_msg_processed +=1 ;
		}
	}
        my $h1_msgs_duplicate_nb = scalar( @h1_msgs_duplicate ) ;
        $h1{ $h1_fold }{ 'duplicates_nb' } = $h1_msgs_duplicate_nb ;
        
        $debug and print "Host1 selected: $h1_msgs_nb  duplicates: $h1_msgs_duplicate_nb\n" ;
	$debug and print "Host1 whole time parsing headers took ", timenext(), " s\n";
        
	$debug and print "Host2 parsing headers of folder [$h2_fold]\n";
        
	my ($h2_heads_ref, $h2_fir_ref) = ( {}, {} );
	$h2_heads_ref =   $imap2->parse_headers([@h2_msgs_not_in_cache], @useheader) if (@h2_msgs_not_in_cache);
	$debug and print "Host2 parsing headers of folder [$h2_fold] took ", timenext(), " s\n" ;

	$debug and print "Host2 getting flags idate and sizes of folder [$h2_fold]\n" ;
	@$h2_fir_ref{@h2_msgs} = (  ); # fetch_hash can select by uid with last arg as ref


        if ( $abletosearch ) {
		$h2_fir_ref = $imap2->fetch_hash( \@h2_msgs, "FLAGS", "INTERNALDATE", "RFC822.SIZE", $h2_fir_ref)
		if (@h2_msgs) ;
        }else{
		my $uidnext = $imap2->uidnext( $h2_fold ) || $uidnext_default ;
		$h2_fir_ref = $imap2->fetch_hash( "1:$uidnext", "FLAGS", "INTERNALDATE", "RFC822.SIZE", $h2_fir_ref )
		if ( @h2_msgs ) ;
        }

	$debug and print "Host2 getting flags idate and sizes of folder [$h2_fold] took ", timenext(), " s\n" ;
	
	my @h2_msgs_duplicate;
	foreach my $m (@h2_msgs_not_in_cache) {
		my $rc = parse_header_msg($imap2, $m, $h2_heads_ref, $h2_fir_ref, 'Host2', \%h2_hash);
		my $h2_size = $h2_fir_ref->{$m}->{"RFC822.SIZE"} || 0;
		if (! defined($rc)) {
                        print "Host2 $h2_fold/$m size $h2_size ignored (no wanted headers so we ignore this message)\n" ;
			$h2_nb_msg_noheader += 1 ;
		} elsif(0 == $rc) {
			# duplicate
			$h2_nb_msg_duplicate += 1;
			$h2_total_bytes_duplicate += $h2_size;
			push(@h2_msgs_duplicate, $m);
		}
	}
        my $h2_msgs_duplicate_nb = scalar( @h2_msgs_duplicate ) ;
        $h2{ $h2_fold }{ 'duplicates_nb' } = $h2_msgs_duplicate_nb ;
        
        print "Host2 folder $h2_fold selected: $h2_msgs_nb messages,  duplicates: $h2_msgs_duplicate_nb\n" 
        	if ( $debug or $delete2duplicates or $h2_msgs_duplicate_nb ) ;
	$debug and print "Host2 whole time parsing headers took ", timenext(), " s\n";

	$debug and print "++++ Verifying [$h1_fold] -> [$h2_fold]\n";
	# messages in host1 that are not in host2
	
	my @h1_hash_keys_sorted_by_uid 
	  = sort {$h1_hash{$a}{'m'} <=> $h1_hash{$b}{'m'}} keys(%h1_hash);
	
	#print map { $h1_hash{$_}{'m'} . " "} @h1_hash_keys_sorted_by_uid;
	
	my @h2_hash_keys_sorted_by_uid 
	  = sort {$h2_hash{$a}{'m'} <=> $h2_hash{$b}{'m'}} keys(%h2_hash);

        
	if( $delete2duplicates and not exists( $h2_folders_from_1_several{ $h2_fold } ) ) {
		my @h2_expunge ;

		foreach my $h2_msg ( @h2_msgs_duplicate ) {
			print "msg $h2_fold/$h2_msg marked \\Deleted [duplicate] on host2 $dry_message\n" ;
			push( @h2_expunge, $h2_msg ) if $uidexpunge2 ;
			unless ( $dry ) {
				$imap2->delete_message( $h2_msg ) ;
				$h2_nb_msg_deleted += 1 ;
			}
		}
		my $cnt = scalar @h2_expunge ;
		if( @h2_expunge ) {
			print "uidexpunge $cnt message(s) $dry_message\n" ;
			$imap2->uidexpunge( \@h2_expunge ) if ! $dry ;
		}
        	if ( $expunge2 ){
                	print "Expunging host2 folder $h2_fold $dry_message\n" ;
                	$imap2->expunge(  ) if ! $dry ;
        	}
	}
        
	if( $delete2 and not exists( $h2_folders_from_1_several{ $h2_fold } ) ) {
        	# No host1 folders f1a f1b ... going all to same f2 (via --regextrans2)
		my @h2_expunge;
		foreach my $m_id (@h2_hash_keys_sorted_by_uid) {
			#print "$m_id ";
			unless (exists($h1_hash{$m_id})) {
				my $h2_msg  = $h2_hash{$m_id}{'m'};
				my $h2_flags  = $h2_hash{$m_id}{'F'} || "";
				my $isdel  = $h2_flags =~ /\B\\Deleted\b/x ? 1 : 0;
				print "msg $h2_fold/$h2_msg marked \\Deleted on host2 [$m_id] $dry_message\n"
				  if ! $isdel;
				push(@h2_expunge, $h2_msg) if $uidexpunge2;
				unless ($dry or $isdel) {
					$imap2->delete_message($h2_msg);
					$h2_nb_msg_deleted += 1;
				}
			}
		}
		foreach my $h2_msg ( @h2_msgs_delete2_not_in_cache ) {
			print "msg $h2_fold/$h2_msg marked \\Deleted [not in cache] on host2 $dry_message\n";
                        push(@h2_expunge, $h2_msg) if $uidexpunge2;
			unless ($dry) {
				$imap2->delete_message($h2_msg);
				$h2_nb_msg_deleted += 1;
			}
		}
		my $cnt = scalar @h2_expunge ;
		if( @h2_expunge ) {
			print "uidexpunge $cnt message(s) $dry_message\n" ;
			$imap2->uidexpunge( \@h2_expunge ) if ! $dry ;
		}
        	if ($expunge2){
                	print "Expunging host2 folder $h2_fold $dry_message\n" ;
                	$imap2->expunge(  ) if ! $dry ;
        	}
	}

	if( $delete2 and exists( $h2_folders_from_1_several{ $h2_fold } ) ) {
        	print "Host2 folder $h2_fold $h2_folders_from_1_several{ $h2_fold } folders left to sync there\n" ;
		my @h2_expunge;
		foreach my $m_id ( @h2_hash_keys_sorted_by_uid ) {
                	my $h2_msg  = $h2_hash{ $m_id }{ 'm' } ;
			unless ( exists( $h1_hash{ $m_id } ) ) {
				my $h2_flags  = $h2_hash{ $m_id }{ 'F' } || "" ;
				my $isdel  = $h2_flags =~ /\B\\Deleted\b/x ? 1 : 0 ;
				unless ( $isdel ) {
                                	$debug and print "msg $h2_fold/$h2_msg candidate for deletion on host2 [$m_id]\n" ;
					$uid_candidate_for_deletion{ $h2_fold }{ $h2_msg }++ ;
				}
			}else{
                        	$debug and print "msg $h2_fold/$h2_msg will cancel deletion on host2 [$m_id]\n" ;
                        	$uid_candidate_no_deletion{ $h2_fold }{ $h2_msg }++ ;
                        }
		}
		foreach my $h2_msg ( @h2_msgs_delete2_not_in_cache ) {
			print "msg $h2_fold/$h2_msg candidate for deletion [not in cache] on host2\n";
                        $uid_candidate_for_deletion{ $h2_fold }{ $h2_msg }++ ;
		}
                
		foreach my $h2_msg ( @h2_msgs_in_cache ) {
			print "msg $h2_fold/$h2_msg will cancel deletion [in cache] on host2\n";
                        $uid_candidate_no_deletion{ $h2_fold }{ $h2_msg }++ ;
		}
                
                
                if ( 0 == $h2_folders_from_1_several{ $h2_fold } ) {
                	# last host1 folder going to $h2_fold
                        print "Last host1 folder going to $h2_fold\n" ;
                        foreach my $h2_msg ( keys %{ $uid_candidate_for_deletion{ $h2_fold } } ) {
                        	$debug and print "msg $h2_fold/$h2_msg candidate for deletion on host2\n" ;
                                if ( exists( $uid_candidate_no_deletion{ $h2_fold }{ $h2_msg } ) ) {
                                	$debug and print "msg $h2_fold/$h2_msg canceled deletion on host2\n" ;
                                }else{
                                	print "msg $h2_fold/$h2_msg marked \\Deleted on host2 $dry_message\n";
                                        push( @h2_expunge, $h2_msg ) if $uidexpunge2 ;
                                        unless ( $dry ) {
                                        	$imap2->delete_message( $h2_msg ) ;
                                        	$h2_nb_msg_deleted += 1 ;
                                        }
                                }
                        }
                }
                
		my $cnt = scalar @h2_expunge ;
		if( @h2_expunge ) {
			print "uidexpunge $cnt message(s) $dry_message\n" ;
			$imap2->uidexpunge( \@h2_expunge ) if ! $dry ;
		}
        	if ( $expunge2 ) {
                	print "Expunging host2 folder $h2_fold $dry_message\n" ;
                	$imap2->expunge(  ) if ! $dry ;
        	}

                $h2_folders_from_1_several{ $h2_fold }-- ;                
	}


	my $h2_uidnext = $imap2->uidnext( $h2_fold ) ;
        $debug and print "Host2 uidnext: $h2_uidnext\n" ;
	$h2_uidguess = $h2_uidnext ;
	MESS: foreach my $m_id (@h1_hash_keys_sorted_by_uid) {
        	last FOLDER if $imap1->IsUnconnected();
                last FOLDER if $imap2->IsUnconnected();
		#print "h1_nb_msg_processed: $h1_nb_msg_processed\n" ;
		my $h1_size  = $h1_hash{$m_id}{'s'};
		my $h1_msg   = $h1_hash{$m_id}{'m'};
		my $h1_idate = $h1_hash{$m_id}{'D'};

		unless (exists($h2_hash{$m_id})) {
			# copy
			my $h2_msg = copy_message( $h1_msg, $h1_fold, $h2_fold, $h1_fir_ref, $permanentflags2, $cache_dir ) ;
                        if( $delete2 and exists( $h2_folders_from_1_several{ $h2_fold } ) and $h2_msg ) {
                        	print "msg $h2_fold/$h2_msg will cancel deletion [fresh copy] on host2\n" ;
	                        $uid_candidate_no_deletion{ $h2_fold }{ $h2_msg }++ ;
                        }
                        last FOLDER if total_bytes_max_reached(  ) ;
			next MESS;
		}
		else{
		        # already on host2
			my $h2_msg   = $h2_hash{$m_id}{'m'} ;
			$debug and print "Host1 found msg $h1_fold/$h1_msg equals Host2 $h2_fold/$h2_msg\n" ;
			$total_bytes_skipped += $h1_size ;
			$nb_msg_skipped += 1 ;
                        $h1_nb_msg_processed +=1 ;
                        
                        if ( $usecache ) {
				$debugcache and print "touch $cache_dir/${h1_msg}_$h2_msg\n" ;
				touch( "$cache_dir/${h1_msg}_$h2_msg" ) 
                                or croak( "Couldn't touch $cache_dir/${h1_msg}_$h2_msg" ) ;
                        }
		}
		
		#$debug and print "MESSAGE $m_id\n";
		my $h2_msg  = $h2_hash{$m_id}{'m'};

                sync_flags_fir( $h1_fold, $h1_msg, $h2_fold, $h2_msg, $permanentflags2, $h1_fir_ref, $h2_fir_ref ) ;
                last FOLDER if $imap2->IsUnconnected() ;
	    	# Good
		my $h2_size = $h2_hash{$m_id}{'s'};
		$debug and print
		"Host1 size  msg $h1_fold/$h1_msg = $h1_size <> $h2_size = Host2 $h2_fold/$h2_msg\n";
		if( $delete ) {
                        my $expunge_message = '' ;
                        $expunge_message = "and expunged" if ( $expungeaftereach and ( $expunge or $expunge1 ) ) ;
			print "Host1 msg $h1_fold/$h1_msg marked deleted $expunge_message $dry_message\n" ;
			unless( $dry ) {
				$imap1->delete_message( $h1_msg ) ;
				$h1_nb_msg_deleted += 1 ;
				$imap1->expunge() if ( $expungeaftereach and ( $expunge or $expunge1 ) ) ;
			}
		}
		
	}
	# END MESS: loop
        last FOLDER if $imap1->IsUnconnected();
        last FOLDER if $imap2->IsUnconnected();
	MESS_IN_CACHE: foreach my $h1_msg ( @h1_msgs_in_cache ) {
		my $h2_msg = $cache_1_2_ref->{ $h1_msg } ;
		$debugcache and print "cache messages update flags $h1_msg->$h2_msg\n";
		sync_flags_fir( $h1_fold, $h1_msg, $h2_fold, $h2_msg, $permanentflags2, $h1_fir_ref, $h2_fir_ref ) ;
		my $h1_size = $h1_fir_ref->{ $h1_msg }->{ 'RFC822.SIZE' } || 0 ;
		$total_bytes_skipped += $h1_size;
		$nb_msg_skipped += 1;
                $h1_nb_msg_processed +=1 ;
                last FOLDER if $imap2->IsUnconnected();                
	}
	
	#print "Messages by uid: ", map { "$_ " } keys %h1_msgs_copy_by_uid, "\n" ;
	MESS_BY_UID: foreach my $h1_msg ( sort { $a <=> $b } keys %h1_msgs_copy_by_uid ) {
		# 
		$debug and print "Copy by uid $h1_fold/$h1_msg\n" ;
                last FOLDER if $imap1->IsUnconnected();
                last FOLDER if $imap2->IsUnconnected();
		my $h2_msg = copy_message( $h1_msg, $h1_fold, $h2_fold, $h1_fir_ref, $permanentflags2, $cache_dir ) ;
                if( $delete2 and exists( $h2_folders_from_1_several{ $h2_fold } ) and $h2_msg ) {
                	print "msg $h2_fold/$h2_msg will cancel deletion [fresh copy] on host2\n" ;
	                $uid_candidate_no_deletion{ $h2_fold }{ $h2_msg }++ ;
                }
		last FOLDER if total_bytes_max_reached(  ) ;
	}
	
	if ($expunge or $expunge1){
		print "Expunging host1 folder $h1_fold $dry_message\n";
		unless($dry) { $imap1->expunge() };
	}
	if ($expunge2){
		print "Expunging host2 folder $h2_fold $dry_message\n";
		unless($dry) { $imap2->expunge() };
	}

	$debug and print "Time: ", timenext(), " s\n";
}


sub total_bytes_max_reached {

	return( 0 ) if not $exitwhenover ;
	if ( $total_bytes_transferred >= $exitwhenover ) {
        	print "Maximum bytes transfered reached, $total_bytes_transferred >= $exitwhenover, ending sync\n" ;
        	return( 1 ) ;
        }  

}

print "++++ End looping on each folder\n";
$debug and print "Time: ", timenext(), " s\n";

#print memory_consumption();


if ( $foldersizesatend ) {
	timenext() ;
	( $h1_nb_msg_end, $h1_bytes_end ) = foldersizes( "Host1", $imap1, $search1, @h1_folders_wanted ) ;
	( $h2_nb_msg_end, $h2_bytes_end ) = foldersizes( "Host2", $imap2, $search2, @h2_folders_from_1_wanted ) ;
}

$imap1->logout(  ) unless lost_connection($imap1, "for host1 [$host1]");
$imap2->logout(  ) unless lost_connection($imap2, "for host2 [$host2]");


stats(  ) ;
exit_clean( 1 ) if ( $nb_errors ) ;
exit_clean( 0 ) ;

# END of main program

# subroutines


sub size_filtered_flag {
	my $h1_size = shift ;
	
	if (defined $maxsize and $h1_size >= $maxsize) {
		return( 1 ) ;
	}
	if (defined $minsize and $h1_size <= $minsize) {
		return( 1 ) ;
	}
	return( 0 ) ;
}

sub sync_flags_fir {
	my ( $h1_fold, $h1_msg, $h2_fold, $h2_msg, $permanentflags2, $h1_fir_ref, $h2_fir_ref ) = @_ ;

	my $h1_size = $h1_fir_ref->{$h1_msg}->{"RFC822.SIZE"} ;
	return(  ) if size_filtered_flag( $h1_size ) ;

	# used cached flag values for efficiency
	my $h1_flags = $h1_fir_ref->{ $h1_msg }->{ "FLAGS" } || '' ;
	my $h2_flags = $h2_fir_ref->{ $h2_msg }->{ "FLAGS" } || '' ;

	sync_flags( $h1_fold, $h1_msg, $h1_flags, $h2_fold, $h2_msg, $h2_flags, $permanentflags2 ) ;

        return(  ) ;
}

sub sync_flags_after_copy {
	my( $h1_fold, $h1_msg, $h1_flags, $h2_fold, $h2_msg, $permanentflags2 ) = @_ ;
        
        my @h2_flags = $imap2->flags( $h2_msg ) ;
        my $h2_flags = "@h2_flags" ;
        print "FLAGS $h2_msg: $h2_flags\n" ;
	sync_flags( $h1_fold, $h1_msg, $h1_flags, $h2_fold, $h2_msg, $h2_flags, $permanentflags2 ) ;
        return(  ) ;
}

sub sync_flags {
	my( $h1_fold, $h1_msg, $h1_flags, $h2_fold, $h2_msg, $h2_flags, $permanentflags2 ) = @_ ;

	( $debug or $debugflags ) and 
        print "Host1 flags init msg $h1_fold/$h1_msg flags( $h1_flags ) Host2 $h2_fold/$h2_msg flags( $h2_flags )\n" ;

	$h1_flags = flags_for_host2( $h1_flags, $permanentflags2 ) ;

	$h2_flags = flagsCase( $h2_flags ) ;

	( $debug or $debugflags ) and 
        print "Host1 flags filt msg $h1_fold/$h1_msg flags( $h1_flags ) Host2 $h2_fold/$h2_msg flags( $h2_flags )\n" ;

	
	# compare flags - set flags if there a difference
	my @h1_flags = sort split(' ', $h1_flags );
	my @h2_flags = sort split(' ', $h2_flags );
	my $diff = compare_lists( \@h1_flags, \@h2_flags );

	$diff and ( $debug or $debugflags ) 
		and     print "Host2 flags msg $h2_fold/$h2_msg replacing h2 flags( $h2_flags ) with h1 flags( $h1_flags )\n";
	# This sets flags so flags can be removed with this
	# When you remove a \Seen flag on host1 you want to it
	# to be removed on host2. Just add flags is not what 
	# we need most of the time.
	
	if ( not $dry and $diff and not $imap2->store( $h2_msg, "FLAGS.SILENT (@h1_flags)" ) ) {
		print "Host2 flags msg $h2_fold/$h2_msg could not add flags [@h1_flags]: ",
		  $imap2->LastError || '', "\n" ;
		#$nb_errors++ ;
	}

        return(  ) ;
}



sub _filter {
	my $str = shift or return "";
        my $sz  = 64;
        my $len = length($str);
        if ( not $debug and $len > $sz*2 ) {
                my $beg = substr($str, 0, $sz);
                my $end = substr($str, -$sz, $sz);
                $str = $beg . "..." . $end;
        }
        $str =~ s/\012?\015$//x;
        return "(len=$len) " . $str;
}



sub lost_connection {
	my($imap, $error_message) = @_;
        if ( $imap->IsUnconnected() ) {
                $nb_errors++;
                my $lcomm = $imap->LastIMAPCommand || "";
                my $einfo = $imap->LastError || @{$imap->History}[-1] || "";

                # if string is long try reduce to a more reasonable size
                $lcomm = _filter($lcomm);
                $einfo = _filter($einfo);
                print("Failure: last command: $lcomm\n") if ($debug && $lcomm);
                print("Failure: lost connection $error_message: ", $einfo, "\n");
                return(1);
        }
        else{
        	return(0);
        }
}

sub max {
	my @list = @_ ;
	return( undef ) if ( 0 == scalar( @list ) ) ;
	my @sorted = sort { $a <=> $b } @list ;
	return( pop( @sorted ) ) ;
}

sub tests_max {
	ok( 0 == max(0),   "max 0");
	ok( 1 == max(1),   "max 1");
	ok( -1 == max(-1), "max -1");
	ok( not ( defined( max(  ) ) ), "max no arg" ) ;
	ok( 100 == max( 1, 100 ), "max 1 100" ) ;
	ok( 100 == max( 100, 1 ), "max 100 1") ;
	ok( 100 == max( 100, 42, 1 ), "max 100 42 1") ;
	ok( 100 == max( 100, "42", 1 ), "max 100 42 1") ;
	ok( 100 == max( "100", "42", 1 ), "max 100 42 1") ;
	#ok( 100 == max( 100, "haha", 1 ), "max 100 42 1") ;
        return(  ) ;
}

sub keyval {
        my %hash = @_ ;
        return( join( " ", map( { "$_ => " . $hash{ $_ } } keys %hash ) ) . "\n" ) ;
}
        


sub check_lib_version {
	$debug and print "IMAPClient $Mail::IMAPClient::VERSION\n";
	if ($Mail::IMAPClient::VERSION eq '2.2.9') {
		print "imapsync no longer supports Mail::IMAPClient 2.2.9, upgrade it" ;
		return( 0 ) ;
	}
	else{
		# 3.x.x is no longer buggy with imapsync.
		return( 1 ) ;      
	}
}

sub module_version_str {
	my( $module_name, $module_version ) = @_ ;
	my $str = sprintf( "%-20s %s\n", $module_name, $module_version ) ;
        return( $str ) ;
}

sub modules_VERSION {

	my @list_version;

	my $v ;
	eval { require Mail::IMAPClient; $v = $Mail::IMAPClient::VERSION } or $v = "?" ;
	push ( @list_version, module_version_str( 'Mail::IMAPClient', $v ) ) ;

	eval { require IO::Socket; $v = $IO::Socket::VERSION } or $v = "?" ;
	push ( @list_version, module_version_str( 'IO::Socket', $v ) ) ;

	eval { require IO::Socket::IP; $v = $IO::Socket::IP::VERSION } or $v = "?" ;
	push ( @list_version, module_version_str( 'IO::Socket::IP', $v ) ) ;

	eval { require IO::Socket::INET; $v = $IO::Socket::INET::VERSION } or $v = "?" ;
	push ( @list_version, module_version_str( 'IO::Socket::INET', $v ) ) ;

	eval { require IO::Socket::SSL ; $v = $IO::Socket::SSL::VERSION } or $v = "?" ;
	push ( @list_version, module_version_str( 'IO::Socket::SSL ', $v ) ) ;

	eval { require Net::SSLeay ; $v = $Net::SSLeay::VERSION } or $v = "?" ;
	push ( @list_version, module_version_str( 'Net::SSLeay ', $v ) ) ;

	eval { require Digest::MD5; $v = $Digest::MD5::VERSION } or $v = "?" ;
	push ( @list_version, module_version_str( 'Digest::MD5', $v ) ) ;

	eval { require Digest::HMAC_MD5; $v = $Digest::HMAC_MD5::VERSION } or $v = "?" ;
	push ( @list_version, module_version_str( 'Digest::HMAC_MD5', $v ) ) ;

	eval { require Digest::HMAC_SHA1; $v = $Digest::HMAC_SHA1::VERSION } or $v = "?" ;
	push ( @list_version, module_version_str( 'Digest::HMAC_SHA1', $v ) ) ;

	eval { require Term::ReadKey; $v = $Term::ReadKey::VERSION } or $v = "?" ;
	push ( @list_version, module_version_str( 'Term::ReadKey', $v ) ) ;

	eval { require Authen::NTLM; $v = $Authen::NTLM::VERSION } or $v = "?" ;
	push ( @list_version, module_version_str( 'Authen::NTLM', $v ) ) ;

	eval { require File::Spec; $v = $File::Spec::VERSION } or $v = "?" ;
	push ( @list_version, module_version_str( 'File::Spec', $v ) ) ;

	eval { require Time::HiRes; $v = $Time::HiRes::VERSION } or $v = "?" ;
	push ( @list_version, module_version_str( 'Time::HiRes', $v ) ) ;

	eval { require URI::Escape; $v = $URI::Escape::VERSION } or $v = "?" ;
	push ( @list_version, module_version_str( 'URI::Escape', $v ) ) ;

	eval { require Data::Uniqid; $v = $Data::Uniqid::VERSION } or $v = "?" ;
	push ( @list_version, module_version_str( 'Data::Uniqid', $v ) ) ;

	return( @list_version ) ;
}


# Construct a command line copy with passwords replaced by MASKED.
sub command_line_nopassword {
	my @argv = @_;
	my @argv_nopassword;
        
        return("@argv") if $showpasswords ;
	while (@argv) {
		my $arg = shift(@argv); # option name or value
		if ($arg =~ m/-password[12]/x) {
			shift(@argv); # password value 
			push(@argv_nopassword, $arg, "MASKED"); # option name and fake value
		}else{
			push(@argv_nopassword, $arg); # same option or value
		}
	}
	return("@argv_nopassword");
}

sub tests_command_line_nopassword {

	ok('' eq command_line_nopassword(), 'command_line_nopassword void');
	ok('--blabla' eq command_line_nopassword('--blabla'), 'command_line_nopassword --blabla');
	#print command_line_nopassword((qw{ --password1 secret1 })), "\n";
	ok('--password1 MASKED' eq command_line_nopassword(qw{ --password1 secret1}), 'command_line_nopassword --password1');
	ok('--blabla --password1 MASKED --blibli' 
	eq command_line_nopassword(qw{ --blabla --password1 secret1 --blibli }), 'command_line_nopassword --password1 --blibli');
	$showpasswords = 1 ;
	ok('' eq command_line_nopassword(), 'command_line_nopassword void');
	ok('--blabla' eq command_line_nopassword('--blabla'), 'command_line_nopassword --blabla');
	#print command_line_nopassword((qw{ --password1 secret1 })), "\n";
	ok('--password1 secret1' eq command_line_nopassword(qw{ --password1 secret1}), 'command_line_nopassword --password1');
	ok('--blabla --password1 secret1 --blibli' 
	eq command_line_nopassword(qw{ --blabla --password1 secret1 --blibli }), 'command_line_nopassword --password1 --blibli');
        return(  ) ;
}

sub ask_for_password {
	my ($user, $host) = @_;
	print "What's the password for $user\@$host? ";
	Term::ReadKey::ReadMode(2);
	my $password = <>;
	chomp $password;
	printf "\n";
	Term::ReadKey::ReadMode(0);
	return $password;
}

sub catch_exit {
	my $signame = shift ;
	print "\nGot a SIG$signame!\n" ;
	stats(  ) ;
	exit_clean( 6 ) ;
        return(  ) ; # fake, for perlcritic
}

sub catch_continue {
	my $signame = shift ;
	print "\nGot a SIG$signame!\n" ;
        return(  ) ;
}



sub connect_imap {
	my( $host, $port, $mydebugimap, $ssl, $tls, $SSL_version ) = @_;
	my $imap = Mail::IMAPClient->new();
	if ( $ssl ) { set_ssl( $imap, $ssl, $SSL_version ) }
	$imap->Tls($tls) if ($tls);
	$imap->Server($host);
	$imap->Port($port);
	$imap->Debug($mydebugimap);
	$imap->connect()
	  or die_clean("Can not open imap connection on [$host]: $@\n");
	#myconnect($imap)
	#  or die_clean("Can not open imap connection on [$host]: $@\n");
        my $banner = $imap->Results()->[0] ;
        $imap->Banner( $banner ) ;
        $imap->starttls(  ) if ( $imap->Tls(  ) ) ;
        return( $imap ) ;
}

sub justconnect {

	$imap1 = connect_imap( $host1, $port1, $debugimap1, $ssl1, $tls1, $ssl1_SSL_version ) ;
	print "Host1 software: ", server_banner( $imap1 ) ;
	print "Host1 capability: ", join(" ", $imap1->capability(  ) ), "\n" ;
	$imap2 = connect_imap( $host2, $port2, $debugimap2, $ssl2, $tls2, $ssl2_SSL_version ) ;
	print "Host2 software: ", server_banner( $imap2 ) ;
	print "Host2 capability: ", join(" ", $imap2->capability(  ) ), "\n" ;
	$imap1->logout() ;
	$imap2->logout() ;
        return(  ) ;
}

sub relogin1 {
	$imap1 = relogin_imap(
		$imap1,
		$host1, $port1, $user1, $domain1, $password1, 
		$debugimap1, $timeout, $fastio1, $ssl1, $tls1,
		$authmech1, $authuser1, $reconnectretry1,
		$proxyauth1, $uid1, $split1) ;
		
	$relogin1-- if ( $relogin1 ) ;
        return(  ) ;
}

sub relogin2 {
	$imap2 = relogin_imap(
		$imap2,
		$host2, $port2, $user2, $domain2, $password2, 
		$debugimap2, $timeout, $fastio2, $ssl2, $tls2,
		$authmech2, $authuser2, $reconnectretry2,
		$proxyauth2, $uid2, $split2) ;
		
	$relogin2-- if ( $relogin2 )  ;
        return(  ) ;
}

sub relogin_imap {
	my($imap,
	   $host, $port, $user, $domain, $password, 
	   $mydebugimap, $mytimeout, $fastio, 
	   $ssl, $tls, $authmech, $authuser, $reconnectretry,
	   $proxyauth, $uid, $split) = @_;

	my $folder_current = $imap->Folder ;
	$imap->logout(  ) ;
	$imap = login_imap(
		$host, $port, $user, $domain, $password, 
		$mydebugimap, $mytimeout, $fastio, 
		$ssl, $tls, $authmech, $authuser, $reconnectretry,
		$proxyauth, $uid, $split
	) ;
	$imap->select( $folder_current ) if defined( $folder_current ) ;
	return( $imap ) ;
}


sub login_imap {

	my @allargs = @_ ;
	my($host, $port, $user, $domain, $password, 
	   $mydebugimap, $mytimeout, $fastio, 
	   $ssl, $tls, $authmech, $authuser, $reconnectretry,
	   $proxyauth, $uid, $split, $Side, $SSL_version ) = @allargs ;

	my $side = lc( $Side ) ;
	my $imap = init_imap( @allargs ) ;

	$imap->connect()
	  or die_clean("Failure: can not open imap connection on $side [$host] with user [$user]: $@\n");
	
        my $banner = $imap->Results()->[0] ;
        $imap->Banner( $banner ) ;
	print "$Side: ", server_banner($imap);

        if ( $authmech eq 'PREAUTH' ) {
        	if ( $imap->IsAuthenticated( ) ) {
        		$imap->Socket ;
			printf("%s: Assuming PREAUTH for %s\n", $Side, $imap->Server ) ;
        	}else{
                	die_clean( "Failure: error login on $side [$host] with user [$user] auth [PREAUTH]" ) ;
                }
        }

	$imap->starttls(  ) if ( $imap->Tls(  ) ) ;
	
        authenticate_imap( $imap, @allargs ) ;
	
	print "$Side: success login on [$host] with user [$user] auth [$authmech]\n" ;
	return( $imap ) ;
}


sub authenticate_imap {

	my($imap,
           $host, $port, $user, $domain, $password, 
	   $mydebugimap, $mytimeout, $fastio, 
	   $ssl, $tls, $authmech, $authuser, $reconnectretry,
	   $proxyauth, $uid, $split, $Side ) = @_ ;

	check_capability( $imap, $authmech, $Side ) ;

        if ( $proxyauth ) {
                $imap->Authmechanism("") ;
                $imap->User($authuser) ;
        } else {
                $imap->Authmechanism( $authmech ) unless ( $authmech eq 'LOGIN'  or $authmech eq 'PREAUTH' ) ;
                $imap->User($user) ;
        }
        
	$imap->Authcallback(\&xoauth) if $authmech eq "XOAUTH" ;
	$imap->Authcallback(\&plainauth) if $authmech eq "PLAIN" || ($authmech eq "EXTERNAL") ;

if ($proxyauth) {
                $imap->User($authuser);
                $imap->Domain($domain) if (defined($domain));
                $imap->Authuser($authuser);
                if ($authmech eq "EXTERNAL") {$password = "NULL"};
                $imap->Password($password);
        } else {
                $imap->User($user);
                $imap->Domain($domain) if (defined($domain));
                $imap->Authuser($authuser);
                if ($authmech eq "EXTERNAL") {$password = "NULL"};
                $imap->Password($password);
        }

	

#        $imap->Domain($domain) if (defined($domain)) ;
#        $imap->Authuser($authuser) ;
#        $imap->Password($password) ;
	
	unless ( $authmech eq 'PREAUTH' or $imap->login( ) ) {
		my $info  = "Failure: error login on [$host] with user [$user] auth" ;
		my $einfo = $imap->LastError || @{$imap->History}[-1] ;
		chomp( $einfo ) ;
		my $error = "$info [$authmech]: $einfo\n" ;
                if ( $authmech eq 'LOGIN' or $imap->IsUnconnected( ) or $authuser ) {
                	die_clean( $error ) ;
                }else{
			print $error ;
                }
		print "Info: trying LOGIN Auth mechanism on [$host] with user [$user]\n" ;
		$imap->Authmechanism("") ;
		$imap->login() or
		  die_clean("$info [LOGIN]: ", $imap->LastError, "\n") ;
	}

#        if ( $proxyauth ) {
#                if ( ! $imap->proxyauth( $user ) ) {
#                        my $info  = "Failure: error doing proxyauth as user [$user] on [$host] using proxy-login as [$authuser]" ;
#                        my $einfo = $imap->LastError || @{$imap->History}[-1] ;
#                        chomp( $einfo ) ;
#                        die_clean( "$info: $einfo\n" ) ;
#                }
#        }

	return(  ) ;
}

sub check_capability {

	my( $imap, $authmech, $Side ) = @_ ;
        
	if ($imap->has_capability("AUTH=$authmech")
	    or $imap->has_capability($authmech)
	   ) {
		printf("%s: %s says it has CAPABILITY for AUTHENTICATE %s\n",
		       $Side, $imap->Server, $authmech);
	} 
	else {
		printf("%s: %s says it has NO CAPABILITY for AUTHENTICATE %s\n",
		       $Side, $imap->Server, $authmech);
		if ($authmech eq 'PLAIN') {
			print "$Side: frequently PLAIN is only supported with SSL, ",
			  "try --ssl or --tls options\n";
		}
	}
	return(  ) ;
}

sub set_ssl {
	my ( $imap, $ssl, $SSL_version ) = @_ ;
        # SSL_version can be
        #    SSLv3 SSLv2 SSLv23 SSLv23:!SSLv2 (last one is the default in IO-Socket-SSL-1.953)
        #
        $SSL_version = $SSL_version || '' ;
        #print "[$SSL_version]\n" ;
        IO::Socket::SSL::set_ctx_defaults( 
		SSL_verify_mode => 'SSL_VERIFY_PEER',
        	SSL_verifycn_scheme => 'imap',
                SSL_version => $SSL_version,
	) ;
        $imap->Ssl( $ssl ) ;
	return(  ) ;
}

sub init_imap {
	my($host, $port, $user, $domain, $password, 
	   $mydebugimap, $mytimeout, $fastio, 
	   $ssl, $tls, $authmech, $authuser, $reconnectretry,
	   $proxyauth, $uid, $split, $Side, $SSL_version ) = @_ ;

	my ( $imap ) ;
	
	$imap = Mail::IMAPClient->new() ;
	
	if ( $ssl ) { set_ssl( $imap, $ssl, $SSL_version ) }
	$imap->Tls($tls) if ($tls);
	$imap->Clear(1);
	$imap->Server($host);
	$imap->Port($port);
	$imap->Fast_io($fastio);
	$imap->Buffer($buffersize || 4096);
	$imap->Uid($uid);
	#$imap->Uid(0);
	$imap->Peek(1);
	$imap->Debug($mydebugimap);
	defined( $mytimeout ) and $imap->Timeout($mytimeout);

	$imap->Reconnectretry($reconnectretry) if ($reconnectretry);
	$imap->Ignoresizeerrors( $allowsizemismatch ) ;
	$split and $imap->Maxcommandlength( 10 * $split ) ;
	

	return( $imap ) ;

}

sub plainauth {
        my $code = shift;
        my $imap = shift;

        my $string = sprintf("%s\x00%s\x00%s", $imap->User,
                            $imap->Authuser, $imap->Password);
        return encode_base64("$string", "");
}

# xoauth() thanks to Eduardo Bortoluzzi Junior
sub xoauth {
               require URI::Escape  ;
               require Data::Uniqid ;

        my $code = shift;
        my $imap = shift;
               
        # The base information needed to construct the OAUTH authentication
        my $method = "GET";
        my $URL = sprintf("https://mail.google.com/mail/b/%s/imap/", $imap->User);
        my $URLparm = sprintf("xoauth_requestor_id=%s", URI::Escape::uri_escape($imap->User));
        
        # For Google Apps, the consumer key is the primary domain
        # TODO: create a command line argument to define the consumer key
        my @user_parts = split(/@/x, $imap->User);
        $debug and print "XOAUTH: consumer key: $user_parts[1]\n";
        
        # All the parameters needed to be signed on the XOAUTH
        my %hash = ();
        $hash { 'xoauth_requestor_id' } = URI::Escape::uri_escape($imap->User);
        $hash { 'oauth_consumer_key' } = $user_parts[1];
        $hash { 'oauth_nonce' } = md5_hex(Data::Uniqid::uniqid(rand(), 1==1));
        $hash { 'oauth_signature_method' } = 'HMAC-SHA1';
        $hash { 'oauth_timestamp' } = time();
        $hash { 'oauth_version' } = '1.0';

        # Base will hold the string to be signed
        my $base = "$method&" . URI::Escape::uri_escape($URL) . "&";
        
        # The parameters must be in dictionary order before signing
        my $baseparms = "";
        foreach my $key (sort keys %hash) {
                if(length($baseparms)>0) {
                        $baseparms .= "&";
                }
                
                $baseparms .= "$key=$hash{$key}";
        }
        
        $base .= URI::Escape::uri_escape($baseparms);
        $debug and print "XOAUTH: base request to sign: $base\n";
        # Sign it with the consumer secret, informed on the command line (password)
        my $digest = hmac_sha1($base, URI::Escape::uri_escape($imap->Password) . "&");
        
        # The parameters signed become a parameter and...
        $hash { 'oauth_signature' } = URI::Escape::uri_escape(substr(encode_base64($digest),0,-1));
        
        # ... we don't need the requestor_id anymore.
        delete $hash{'xoauth_requestor_id'};
        
        # Create the final authentication string
        my $string = $method . " " . $URL . "?" . $URLparm ." ";

        # All the parameters must be sorted
        $baseparms = "";
        foreach my $key (sort keys %hash) {
                if(length($baseparms)>0) {
                        $baseparms .= ",";
                }
                
                $baseparms .= "$key=\"$hash{$key}\"";
        }
        
        $string .= $baseparms;
        
        $debug and print "XOAUTH: authentication string: $string\n";
       
       # It must be base64 encoded     
        return encode_base64("$string", "");
}

sub server_banner {
	my $imap = shift;
	my $banner = $imap->Banner() ||  "No banner\n";
	return $banner;
 }


sub banner_imapsync {

	my @argv = @_ ;
	my $banner_imapsync = join("", 
		  '$RCSfile: imapsync,v $ ',
		  '$Revision: 1.564 $ ',
		  '$Date: 2013/08/18 19:28:47 $ ',
		  "\n",localhost_info(), "\n",
		  "Command line used:\n",
		  "$0 ", command_line_nopassword( @argv ), "\n",
	) ;
        return( $banner_imapsync ) ;
}

sub is_valid_directory {
	my $dir = shift;
	return(1) if (-d $dir and -r _ and -w _) ;
	# Trying to create it
	mkpath( $dir ) or croak "Error creating tmpdir $tmpdir : $!" ;
	croak "Error with tmpdir $tmpdir : $!" if not (-d $dir and -r _ and -w _) ;
	return( 1 ) ;
}


sub write_pidfile { 
	my $pid_filename = shift ;
	
	print "PID file is $pid_filename\n" ;
	if ( -e $pid_filename and $pidfilelocking ) {
		print "$pid_filename already exists, another imapsync may be curently running. Aborting imapsync.\n" ;
                exit( 8 ) ;
	} 
	if ( -e $pid_filename ) {
		print "$pid_filename already exists, overwriting it\n" ;
	}
        my $FILE_HANDLE ;
	open( $FILE_HANDLE, '>', $pid_filename ) or do {
		print "Could not open $pid_filename for writing" ;
		return ;
	} ;
	
	print $FILE_HANDLE $PROCESS_ID ;
	close $FILE_HANDLE ;
        
	return( $PROCESS_ID ) ;
} 

sub exit_clean {
	my $status = shift ;
	$status = defined( $status ) ? $status : 1 ;
	unlink( $pidfile ) ;
	exit( $status ) ;
}

sub die_clean {
	my @messages = @_ ;
	unlink( $pidfile ) ;
	croak @messages ;
} 

sub missing_option {
	my ($option) = @_;
	die_clean("$option option must be used, run $0 --help for help\n");
	return(  ) ;
}


sub fix_Inbox_INBOX_mapping {
	my( $h1_all, $h2_all ) = @_ ;

	my $regex = '' ;
	SWITCH: {
		if ( exists( $h1_all->{INBOX} ) and exists( $h2_all->{INBOX} ) ) { $regex = '' ; last SWITCH ; } ;
		if ( exists( $h1_all->{Inbox} ) and exists( $h2_all->{Inbox} ) ) { $regex = '' ; last SWITCH ; } ;
		if ( exists( $h1_all->{INBOX} ) and exists( $h2_all->{Inbox} ) ) { $regex = 's/^INBOX$/Inbox/x' ; last SWITCH ; } ;
		if ( exists( $h1_all->{Inbox} ) and exists( $h2_all->{INBOX} ) ) { $regex = 's/^Inbox$/INBOX/x' ; last SWITCH ; } ;
	} ;
        return( $regex ) ;
}

sub tests_fix_Inbox_INBOX_mapping {

	my( $h1_all, $h2_all ) ;
        
	$h1_all = { 'INBOX' => '' } ;
	$h2_all = { 'INBOX' => '' } ;
	ok( '' eq fix_Inbox_INBOX_mapping( $h1_all, $h2_all ), 'fix_Inbox_INBOX_mapping: INBOX INBOX' ) ;
        
	$h1_all = { 'Inbox' => '' } ;
	$h2_all = { 'Inbox' => '' } ;
	ok( '' eq fix_Inbox_INBOX_mapping( $h1_all, $h2_all ), 'fix_Inbox_INBOX_mapping: Inbox Inbox' ) ;
        
	$h1_all = { 'INBOX' => '' } ;
	$h2_all = { 'Inbox' => '' } ;
	ok( 's/^INBOX$/Inbox/x' eq fix_Inbox_INBOX_mapping( $h1_all, $h2_all ), 'fix_Inbox_INBOX_mapping: INBOX Inbox' ) ;
        
	$h1_all = { 'Inbox' => '' } ;
	$h2_all = { 'INBOX' => '' } ;
	ok( 's/^Inbox$/INBOX/x' eq fix_Inbox_INBOX_mapping( $h1_all, $h2_all ), 'fix_Inbox_INBOX_mapping: Inbox INBOX' ) ;
        
	$h1_all = { 'INBOX' => '' } ;
	$h2_all = { 'rrrrr' => '' } ;
	ok( '' eq fix_Inbox_INBOX_mapping( $h1_all, $h2_all ), 'fix_Inbox_INBOX_mapping: INBOX rrrrrr' ) ;
        
	$h1_all = { 'rrrrr' => '' } ;
	$h2_all = { 'Inbox' => '' } ;
	ok( '' eq fix_Inbox_INBOX_mapping( $h1_all, $h2_all ), 'fix_Inbox_INBOX_mapping: rrrrr Inbox' ) ;

	return(  ) ;
}

sub select_folder {
	my ( $imap, $folder, $hostside ) = @_ ;
	if ( ! $imap->select( $folder ) ) {
		print 
		"$hostside folder $folder: Could not select: ",
		$imap->LastError,  "\n" ;
		$nb_errors++ ;
		return( 0 ) ;
	}else{
		# ok select succeeded
		return( 1 ) ;
	}
}

sub examine_folder {
	my ( $imap, $folder, $hostside ) = @_ ;
	if ( ! $imap->examine( $folder ) ) {
		print 
		"$hostside folder $folder: Could not examine: ",
		$imap->LastError,  "\n" ;
		$nb_errors++ ;
		return( 0 ) ;
	}else{
		# ok examine succeeded
		return( 1 ) ;
	}
}


sub create_folder {
	my( $imap, $h2_fold, $h1_fold ) = @_ ;
	
	print "Creating folder [$h2_fold] on host2\n";
        if ( ( 'INBOX' eq uc( $h2_fold) )
         and ( $imap->exists( $h2_fold ) ) ) {
                print "Folder [$h2_fold] already exists\n" ;
                return( 1 ) ;
        }
	if ( ! $dry ){
		if ( ! $imap->create( $h2_fold ) ) {
			print( "Couldn't create folder [$h2_fold] from [$h1_fold]: ",
			$imap->LastError(  ), "\n" );
			$nb_errors++;
                        # success if folder exists ("already exists" error)
                        return( 1 ) if $imap->exists( $h2_fold ) ;
                        # failure since create failed
			return( 0 );
		}else{
			#create succeeded
			return( 1 );
		}
	}else{
		# dry mode, no folder so many imap will fail, assuming failure
		return( 0 );
	}
}



sub tests_folder_routines {
	ok( !is_requested_folder('folder_foo'), 'is_requested_folder folder_foo 1'               );
	ok(  add_to_requested_folders('folder_foo'), 'add_to_requested_folders folder_foo'       );
	ok(  is_requested_folder('folder_foo'), 'is_requested_folder folder_foo 2'               );
	ok( !is_requested_folder('folder_NO_EXIST'), 'is_requested_folder folder_NO_EXIST'       );
	ok( !remove_from_requested_folders('folder_foo'), 'removed folder_foo'                   );
	ok( !is_requested_folder('folder_foo'), 'is_requested_folder folder_foo 3'               );
	my @f ;
	ok(  @f = add_to_requested_folders('folder_bar', 'folder_toto'), "add result: @f"        );
	ok(  is_requested_folder('folder_bar'), 'is_requested_folder 4'                          );
	ok(  is_requested_folder('folder_toto'), 'is_requested_folder 5'                         );
	ok(  remove_from_requested_folders('folder_toto'), 'remove_from_requested_folders'       );
	ok( !is_requested_folder('folder_toto'), 'is_requested_folder 6'                         );
	return(  ) ;
}


sub is_requested_folder {
	my ( $folder ) = @_;
	
	return( defined( $requested_folder{ $folder } ) ) ;
}


sub add_to_requested_folders {
	my @wanted_folders = @_ ;
	
	foreach my $folder ( @wanted_folders ) {
	 	++$requested_folder{ $folder } ;
	}
	return( keys( %requested_folder ) ) ;
}

sub remove_from_requested_folders {
	my @wanted_folders = @_ ;
	
	foreach my $folder (@wanted_folders) {
	 	delete $requested_folder{$folder} ;
	}
	return( keys( %requested_folder ) ) ;
}

sub compare_lists {
	my ($list_1_ref, $list_2_ref) = @_;
	
	return(-1) if ((not defined($list_1_ref)) and defined($list_2_ref));
	return(0)  if ((not defined($list_1_ref)) and not defined($list_2_ref)); # end if no list
	return(1)  if (not defined($list_2_ref)); # end if only one list
	
	if (not ref($list_1_ref)) {$list_1_ref = [$list_1_ref]};
	if (not ref($list_2_ref)) {$list_2_ref = [$list_2_ref]};


	my $last_used_indice = -1;
	#print "\$#$list_1_ref:", $#$list_1_ref, "\n";
	#print "\$#$list_2_ref:", $#$list_2_ref, "\n";
	ELEMENT:
	foreach my $indice ( 0 .. $#$list_1_ref ) {
		$last_used_indice = $indice;
		
		# End of list_2
		return 1 if ($indice > $#$list_2_ref);
		
		my $element_list_1 = $list_1_ref->[$indice];
		my $element_list_2 = $list_2_ref->[$indice];
		my $balance = $element_list_1 cmp $element_list_2 ;
		next ELEMENT if ($balance == 0) ;
		return $balance;
	}
	# each element equal until last indice of list_1
	return -1 if ($last_used_indice < $#$list_2_ref) ;
	
	# same size, each element equal
	return 0 ;
}

sub tests_compare_lists {

	
	my $empty_list_ref = [];
	
	ok( 0 == compare_lists()               , 'compare_lists, no args');
	ok( 0 == compare_lists(undef)          , 'compare_lists, undef = nothing');
	ok( 0 == compare_lists(undef, undef)   , 'compare_lists, undef = undef');
	ok(-1 == compare_lists(undef , [])     , 'compare_lists, undef < []');
	ok(-1 == compare_lists(undef , [1])    , 'compare_lists, undef < [1]');
	ok(-1 == compare_lists(undef , [0])    , 'compare_lists, undef < [0]');
      	ok(+1 == compare_lists([])             , 'compare_lists, [] > nothing');
        ok(+1 == compare_lists([], undef)      , 'compare_lists, [] > undef');
	ok( 0 == compare_lists([] , [])        , 'compare_lists, [] = []');

	ok(-1 == compare_lists([] , [1])        , 'compare_lists, [] < [1]');
	ok(+1 == compare_lists([1] , [])        , 'compare_lists, [1] > []');

	
	ok( 0 == compare_lists([1],  1 )          , "compare_lists, [1] =  1 ") ;
	ok( 0 == compare_lists( 1 , [1])          , "compare_lists,  1  = [1]") ;
	ok( 0 == compare_lists( 1 ,  1 )          , "compare_lists,  1  =  1 ") ;
	ok(-1 == compare_lists( 0 ,  1 )          , "compare_lists,  0  <  1 ") ;
	ok(-1 == compare_lists(-1 ,  0 )          , "compare_lists, -1  <  0 ") ;
	ok(-1 == compare_lists( 1 ,  2 )          , "compare_lists,  1  <  2 ") ;
	ok(+1 == compare_lists( 2 ,  1 )          , "compare_lists,  2  >  1 ") ;


	ok( 0 == compare_lists([1,2], [1,2])   , "compare_lists, [1,2] = [1,2]") ;
	ok(-1 == compare_lists([1], [1,2])     , "compare_lists, [1] < [1,2]") ;
	ok(+1 == compare_lists([2], [1,2])     , "compare_lists, [2] > [1,2]") ;
	ok(-1 == compare_lists([1], [1,1])     , "compare_lists, [1] < [1,1]") ;
	ok(+1 == compare_lists([1, 1], [1])    , "compare_lists, [1, 1] > [1]") ;
	ok( 0 == compare_lists([1 .. 20_000] , [1 .. 20_000])
                                               , "compare_lists, [1..20_000] = [1..20_000]") ;
	ok(-1 == compare_lists([1], [3])       , 'compare_lists, [1] < [3]') ;
	ok( 0 == compare_lists([2], [2])       , 'compare_lists, [0] = [2]') ;
	ok(+1 == compare_lists([3], [1])       , 'compare_lists, [3] > [1]') ;
	
	ok(-1 == compare_lists(["a"], ["b"])   , 'compare_lists, ["a"] < ["b"]') ;
	ok( 0 == compare_lists(["a"], ["a"])   , 'compare_lists, ["a"] = ["a"]') ;
	ok( 0 == compare_lists(["ab"], ["ab"]) , 'compare_lists, ["ab"] = ["ab"]') ;
	ok(+1 == compare_lists(["b"], ["a"])   , 'compare_lists, ["b"] > ["a"]') ;
	ok(-1 == compare_lists(["a"], ["aa"])  , 'compare_lists, ["a"] < ["aa"]') ;
	ok(-1 == compare_lists(["a"], ["a", "a"]), 'compare_lists, ["a"] < ["a", "a"]') ;
	ok( 0 == compare_lists([split(" ", "a b")], ["a", "b"]), 'compare_lists, split') ;
	ok( 0 == compare_lists([sort split(" ", "b a")], ["a", "b"]), 'compare_lists, sort split') ;
        return(  ) ;
}



sub get_prefix {
	my( $imap, $prefix_in, $prefix_opt ) = @_ ;
	my( $prefix_out ) ;
	
	$debug and print "Getting prefix namespace\n" ;
	if ( defined( $prefix_in ) ) {
		print "Using [$prefix_in] given by $prefix_opt\n" ;
		$prefix_out = $prefix_in ;
		return( $prefix_out ) ;
	}
	$debug and print "Calling namespace capability\n" ;
	if ( $imap->has_capability( "namespace" ) ) {
		my $r_namespace = $imap->namespace(  ) ;
		$prefix_out = $r_namespace->[0][0][0] ;
		return($prefix_out) ;
	}
	else{
		print 
		  "No NAMESPACE capability in imap server ", 
		    $imap->Server(  ),"\n",
		      help_to_guess_prefix( $imap, $prefix_opt ) ;
		exit_clean( 1 ) ;
	}
        return(  ) ;
}


sub get_separator {
	my($imap, $sep_in, $sep_opt) = @_;
	my($sep_out);
	
	
	if ( defined( $sep_in ) ) {
		print "Using [$sep_in] given by $sep_opt\n" ;
		$sep_out = $sep_in ;
		return( $sep_out ) ;
	}
	$debug and print "Calling namespace capability\n" ;
	if ($imap->has_capability( "namespace" ) ) {
		$sep_out = $imap->separator(  ) ;
		return($sep_out) if defined $sep_out ;
		print 
		  "NAMESPACE request failed for ", 
		  $imap->Server(), ": ", $imap->LastError, "\n",
                  help_to_guess_sep( $imap, $sep_opt ) ;
		exit_clean( 1 ) ;
	}
	else{
		print
		  "No NAMESPACE capability in imap server ", 
		    $imap->Server(),"\n",
		      help_to_guess_sep( $imap, $sep_opt ) ;
		exit_clean( 1 ) ;
	}
        return(  ) ;
}

sub help_to_guess_sep {
	my( $imap, $sep_opt ) = @_ ;
	
	my $help_to_guess_sep = "Give the separator character with the $sep_opt option,\n"
	. "the folowing listing of folders may help you to find it:\n"
	. folders_list_to_help($imap)
	. "Most of the time it is character . or /\n"
	. "so try $sep_opt . or $sep_opt /\n" ;
	
	return( $help_to_guess_sep ) ;
}

sub help_to_guess_prefix {
	my( $imap, $prefix_opt ) = @_ ;
		      
	my $help_to_guess_prefix = "Give the prefix namespace with the $prefix_opt option,\n"
	. "the folowing listing of folders may help you to find it:\n"
	. folders_list_to_help( $imap )
	. "Most of the time it is INBOX. or an empty string\n"
	. "so try $prefix_opt INBOX. or $prefix_opt" . '""' . "\n" ;
	
	return( $help_to_guess_prefix ) ;
}


sub folders_list_to_help {
	my($imap) = @_ ;

	my @folders = $imap->folders ;
	my $listing = join('', map { "[$_]\n" } @folders) ;
	return( $listing ) ;
}


sub tests_separator_invert {
	$fixslash2 = 0 ;
	ok( not( defined( separator_invert(  ) ) ), 'separator_invert: no args' ) ;
	ok( not( defined( separator_invert( '' ) ) ), 'separator_invert: not enough args' ) ;
	ok( not( defined( separator_invert( '', '' ) ) ), 'separator_invert: not enough args' ) ;
	
	ok( '' eq separator_invert( '', '', '' ), 'separator_invert: 3 empty strings' ) ;
	ok( 'lalala' eq separator_invert( 'lalala', '', '' ), 'separator_invert: empty separator' ) ;
	ok( 'lalala' eq separator_invert( 'lalala', '/', '/' ), 'separator_invert: same separator /' ) ;
	ok( 'lal/ala' eq separator_invert( 'lal/ala', '/', '/' ), 'separator_invert: same separator / 2' ) ;
	ok( 'lal.ala' eq separator_invert( 'lal/ala', '/', '.' ), 'separator_invert: separators /.' ) ;
	ok( 'lal/ala' eq separator_invert( 'lal.ala', '.', '/' ), 'separator_invert: separators ./' ) ;
	ok( 'la.l/ala' eq separator_invert( 'la/l.ala', '.', '/' ), 'separator_invert: separators ./' ) ;

	ok( 'l/al.ala' eq separator_invert( 'l.al/ala', '/', '.' ), 'separator_invert: separators /.' ) ;
        $fixslash2 = 1 ;
	ok( 'l_al.ala' eq separator_invert( 'l.al/ala', '/', '.' ), 'separator_invert: separators /.' ) ;

	return(  ) ;
}

sub separator_invert {
	my( $h1_fold, $h1_separator, $h2_separator ) = @_ ;

	return( undef ) if ( not defined( $h1_fold ) or not defined( $h1_separator ) or not defined( $h2_separator ) ) ;
	# The separator we hope we'll never encounter: 00000000 == 0x00
	my $o_sep="\000" ;

	my $h2_fold = $h1_fold ;
	$h2_fold =~ s@\Q$h2_separator@$o_sep@xg ;
	$h2_fold =~ s@\Q$h1_separator@$h2_separator@xg ;
	$h2_fold =~ s@\Q$o_sep@$h1_separator@xg ;
        $h2_fold =~ s,/,_,xg if( $fixslash2 and '/' ne $h2_separator and '/' eq $h1_separator ) ;
	return( $h2_fold ) ;
} 


sub tests_imap2_folder_name {

$h1_prefix = $h2_prefix = '';
$h1_sep = '/';
$h2_sep = '.';

$debug and print <<"EOS"
prefix1: [$h1_prefix]
prefix2: [$h2_prefix]
sep1:[$h1_sep]
sep2:[$h2_sep]
EOS
;

$fixslash2 = 0 ;
ok('' eq imap2_folder_name(''), 'imap2_folder_name: empty string');
ok('blabla' eq imap2_folder_name('blabla'), 'imap2_folder_name: blabla');
ok('spam.spam' eq imap2_folder_name('spam/spam'), 'imap2_folder_name: spam/spam');
ok('spam/spam' eq imap2_folder_name('spam.spam'), 'imap2_folder_name: spam.spam');
ok('spam.spam/spam' eq imap2_folder_name('spam/spam.spam'), 'imap2_folder_name: spam/spam.spam');
ok('s pam.spam/sp  am' eq imap2_folder_name('s pam/spam.sp  am'), 'imap2_folder_name: s pam/spam.sp  am');
@regextrans2 = ('s,/,X,g');
ok('' eq imap2_folder_name(''), 'imap2_folder_name: empty string [s,/,X,g]');
ok('blabla' eq imap2_folder_name('blabla'), 'imap2_folder_name: blabla [s,/,X,g]');
ok('spam.spam' eq imap2_folder_name('spam/spam'), 'imap2_folder_name: spam/spam [s,/,X,g]');
ok('spamXspam' eq imap2_folder_name('spam.spam'), 'imap2_folder_name: spam.spam [s,/,X,g]');
ok('spam.spamXspam' eq imap2_folder_name('spam/spam.spam'), 'imap2_folder_name: spam/spam.spam [s,/,X,g]');

@regextrans2 = ('s, ,_,g');
ok('blabla' eq imap2_folder_name('blabla'), 'imap2_folder_name: blabla [s, ,_,g]');
ok('bla_bla' eq imap2_folder_name('bla bla'), 'imap2_folder_name: blabla [s, ,_,g]');

@regextrans2 = ('s,(.*),\U$1,');
ok('BLABLA' eq imap2_folder_name('blabla'), 'imap2_folder_name: blabla [s,\U(.*)\E,$1,]');

$fixslash2 = 1 ;
@regextrans2 = (  ) ;
ok('' eq imap2_folder_name(''), 'imap2_folder_name: empty string');
ok('blabla' eq imap2_folder_name('blabla'), 'imap2_folder_name: blabla');
ok('spam.spam' eq imap2_folder_name('spam/spam'), 'imap2_folder_name: spam/spam -> spam.spam');
ok('spam_spam' eq imap2_folder_name('spam.spam'), 'imap2_folder_name: spam.spam -> spam_spam');
ok('spam.spam_spam' eq imap2_folder_name('spam/spam.spam'), 'imap2_folder_name: spam/spam.spam -> spam.spam_spam');
ok('s pam.spam_spa  m' eq imap2_folder_name('s pam/spam.spa  m'), 'imap2_folder_name: s pam/spam.spa m -> s pam.spam_spa  m');

$h1_sep = '.';
$h2_sep = '/';
ok('' eq imap2_folder_name(''), 'imap2_folder_name: empty string');
ok('blabla' eq imap2_folder_name('blabla'), 'imap2_folder_name: blabla');
ok('spam.spam' eq imap2_folder_name('spam/spam'), 'imap2_folder_name: spam/spam -> spam.spam');
ok('spam/spam' eq imap2_folder_name('spam.spam'), 'imap2_folder_name: spam.spam -> spam/spam');
ok('spam.spam/spam' eq imap2_folder_name('spam/spam.spam'), 'imap2_folder_name: spam/spam.spam -> spam.spam/spam');

$fixslash2 = 0 ;
$h1_prefix = ' ';

ok('spam.spam/spam' eq imap2_folder_name('spam/spam.spam'), 'imap2_folder_name: spam/spam.spam -> spam.spam/spam');
ok('spam.spam/spam' eq imap2_folder_name(' spam/spam.spam'), 'imap2_folder_name:  spam/spam.spam -> spam.spam/spam');


return(  ) ;

}

sub imap2_folder_name {
	my ( $x_fold ) = @_ ;
	my ( $h2_fold ) ;
	# first we remove the prefix
	$x_fold =~ s/^\Q$h1_prefix\E//x ;
	$debug and print "removed host1 prefix: [$x_fold]\n";
	$h2_fold = separator_invert($x_fold,$h1_sep, $h2_sep);
	$debug and print "inverted  separators: [$h2_fold]\n";
	# Adding the prefix supplied by namespace or the --prefix2 option
	$h2_fold = $h2_prefix . $h2_fold 
	  unless(($h2_prefix eq "INBOX" . $h2_sep) and ($h2_fold =~ m/^INBOX$/xi));
	$debug and print "added   host2 prefix: [$h2_fold]\n";

	# Transforming the folder name by the --regextrans2 option(s)
	foreach my $regextrans2 (@regextrans2) {
	        my $h2_fold_before = $h2_fold;
		my $ret = eval( "\$h2_fold =~ $regextrans2 ; 1 ") ;
		$debug and print "[$h2_fold_before] -> [$h2_fold] using re [$regextrans2]\n" ;
                if ( not ( defined( $ret ) ) or $@ ) {
			die_clean("error: eval regextrans2 '$regextrans2': $@\n") ;
                }
	}
	return($h2_fold);
}

sub tests_decompose_regex {
	ok( 1, 'decompose_regex 1' ) ;
	ok( 0 == compare_lists( [ '', '' ], [ decompose_regex( '' ) ] ), 'decompose_regex empty string' ) ;
	ok( 0 == compare_lists( [ '.*', 'lala' ], [ decompose_regex( 's/.*/lala/' ) ] ), 'decompose_regex s/.*/lala/' ) ;
	return(  ) ;
}

sub decompose_regex {
	my $regex = shift ;
	my( $left_part, $right_part ) ;

	( $left_part, $right_part ) = $regex =~ m{^s/((?:[^/]|\\/)+)/((?:[^/]|\\/)+)/}x;
        return( '', '' ) if not $left_part ;
	return( $left_part, $right_part ) ;
}


sub foldersizes {

	my ( $side, $imap, $search_cmd, @folders ) = @_ ;
	my $total_size = 0 ;
	my $total_nb = 0 ;
	my $biggest_in_all = 0 ;
	
	print "++++ Calculating sizes on $side\n" ;
	foreach my $folder ( @folders )     {
		my $stot = 0 ;
		my $nb_msgs = 0 ;
		printf( "$side folder %-35s", "[$folder]" ) ;
                if ( 'Host2' eq $side and not exists( $h2_folders_all{ $folder } ) ) {
		        print(" does not exist yet\n") ;
			next ;
		}
                if ( 'Host1' eq $side and not exists( $h1_folders_all{ $folder } ) ) {
		        print( " does not exist\n" ) ;
			next ;
		}
                
		unless ( $imap->examine( $folder ) ) {
			print 
			  "$side Folder $folder: Could not examine: ",
			    $imap->LastError,  "\n" ;
			$nb_errors++ ;
			next ;
		}
		
		my $hash_ref = { } ;
		my @msgs = select_msgs( $imap, undef, $search_cmd, $folder ) ;
		$nb_msgs = scalar( @msgs ) ;
		my $biggest_in_folder = 0 ;
		@$hash_ref{ @msgs } = ( undef ) if @msgs ;
		if ( $nb_msgs > 0 and @msgs ) {
                	if ( $abletosearch ) {
				$imap->fetch_hash( \@msgs, "RFC822.SIZE", $hash_ref) or die_clean("$@" ) ;
                        }else{
				my $uidnext = $imap->uidnext( $folder ) || $uidnext_default ;
                        	$imap->fetch_hash( "1:$uidnext", "RFC822.SIZE", $hash_ref ) or die_clean( "$@" ) ;
                        }
			for ( keys %$hash_ref ) {
                        	my $size =  $hash_ref->{ $_ }->{ "RFC822.SIZE" } ;
                        	$stot    += $size ;
                                $biggest_in_folder =  max( $biggest_in_folder, $size ) ;
                        }
		}
		
		printf( " Size: %9s", $stot ) ;
		printf( " Messages: %5s", $nb_msgs ) ;
		printf( " Biggest: %9s\n", $biggest_in_folder ) ;
		$total_size += $stot ;
		$total_nb += $nb_msgs ;
                $biggest_in_all =  max( $biggest_in_all, $biggest_in_folder ) ;
	}
	printf ( "%s Nb messages:     %11s messages\n", $side, $total_nb ) ;
	printf ( "%s Total size:      %11s bytes (%s)\n", $side, $total_size, bytes_display_string( $total_size ) ) ;
	printf ( "%s Biggest message: %11s bytes (%s)\n", $side, $biggest_in_all, bytes_display_string( $biggest_in_all ) ) ;
	printf ( "%s Time spent:      %11.1f seconds\n", $side, timenext(  ) ) ;
        return( $total_nb, $total_size ) ;
}

sub timenext {
	my ( $timenow, $timediff ) ;
	# $timebefore is global, beurk !
	$timenow    = time ;
	$timediff   = $timenow - $timebefore ;
	$timebefore = $timenow ;
	return( $timediff ) ;
}

sub timesince {
	my $timeinit = shift ;
	my ( $timenow, $timediff ) ;
	$timenow    = time ;
	$timediff   = $timenow - $timeinit ;
	return( $timediff ) ;
}




sub tests_flags_regex {
	
	
	ok('' eq flags_regex(''), "flags_regex, null string ''");
	ok('\Seen NonJunk $Spam' eq flags_regex('\Seen NonJunk $Spam'), 'flags_regex, nothing to do');

	@regexflag = ('I am BAD' ) ;
        ok( not ( defined( flags_regex( '' ) ) ), 'flags_regex, bad regex' ) ;
        
	@regexflag = ('s/NonJunk//g');
	ok('\Seen  $Spam' eq flags_regex('\Seen NonJunk $Spam'), "flags_regex, remove NonJunk: 's/NonJunk//g'");
	@regexflag = ('s/\$Spam//g');
	ok('\Seen NonJunk ' eq flags_regex('\Seen NonJunk $Spam'), 'flags_regex, remove $Spam: '."'s/\$Spam//g'");
	
	@regexflag = ('s/\\\\Seen//g');
	
	ok(' NonJunk $Spam' eq flags_regex('\Seen NonJunk $Spam'), 'flags_regex, remove \Seen: '. "'s/\\\\\\\\Seen//g'");
	
	@regexflag = ('s/(\s|^)[^\\\\]\w+//g');
	ok('\Seen \Middle \End' eq flags_regex('\Seen NonJunk \Middle $Spam \End'), 'flags_regex, only \word [' . flags_regex('\Seen NonJunk \Middle $Spam \End'.']'));
	ok(' \Seen \Middle \End1' eq flags_regex('Begin \Seen NonJunk \Middle $Spam \End1 End'), 'flags_regex, only \word [' . flags_regex('Begin \Seen NonJunk \Middle $Spam \End1 End'.']'));

	@regexflag = ('s/.*?(Keep1|Keep2|Keep3)/$1 /g');
	ok('Keep1 Keep2  ReB' eq flags_regex('ReA Keep1 REM Keep2 ReB'), "Keep only regex");
	#ok('Keep1 Keep2' eq flags_regex('Keep1 Keep2 Remove1'), "Keep only regex");
	ok('Keep1 Keep2 ' eq flags_regex('REM REM Keep1 Keep2'), "Keep only regex");
	ok('Keep1 Keep2 ' eq flags_regex('Keep1 REM REM Keep2'), "Keep only regex");
	ok('Keep1 Keep2 ' eq flags_regex('REM Keep1 REM REM  Keep2'), "Keep only regex");
	ok('Keep1 Keep2 ' eq flags_regex('Keep1 Keep2'), "Keep only regex");
	ok('Keep1 ' eq flags_regex('REM Keep1'), "Keep only regex");

	@regexflag = ('s/(Keep1|Keep2|Keep3) (?!(Keep1|Keep2|Keep3)).*/$1 /g');
	ok('Keep1 Keep2 ' eq flags_regex('Keep1 Keep2 ReB'), "Keep only regex");
	ok('Keep1 Keep2 ' eq flags_regex('Keep1 Keep2 REM REM  REM'), "Keep only regex");
	ok('Keep2 ' eq flags_regex('Keep2 REM REM  REM'), "Keep only regex");
	#ok('' eq flags_regex('REM REM'), "Keep only regex");
	
	@regexflag = ('s/.*?(Keep1|Keep2|Keep3)/$1 /g', 
	's/(Keep1|Keep2|Keep3) (?!(Keep1|Keep2|Keep3)).*/$1 /g');
	ok('Keep1 Keep2 ' eq flags_regex('REM Keep1 REM Keep2 REM'), "Keep only regex");
	ok('Keep1 Keep2 ' eq flags_regex('Keep1 REM Keep2 REM'), "Keep only regex");
	ok('Keep1 Keep2 ' eq flags_regex('REM Keep1 Keep2 REM'), "Keep only regex");
	ok('Keep1 Keep2 ' eq flags_regex('REM Keep1 REM Keep2'), "Keep only regex");
	ok('Keep1 Keep2 Keep3 ' eq flags_regex('REM Keep1 REM Keep2 REM REM Keep3 REM'), "Keep only regex");
	ok('Keep1 ' eq flags_regex('REM  REM Keep1 REM REM REM '), "Keep only regex");
	ok('Keep1 Keep3 ' eq flags_regex('RE1 Keep1 RE2 Keep3 RE3 RE4 RE5 '), "Keep only regex");
	
	@regexflag = ('s/(.*)/$1 jrdH8u/');
	ok('REM  REM  REM REM REM jrdH8u' eq flags_regex('REM  REM  REM REM REM'), "Keep only regex 's/(.*)/\$1 jrdH8u/'") ;
	@regexflag = ('s/jrdH8u *//');
	ok('REM  REM  REM REM REM ' eq flags_regex('REM  REM  REM REM REM jrdH8u'), "Keep only regex s/jrdH8u *//") ;
	
	@regexflag = (
	's/(.*)/$1 jrdH8u/',
	's/.*?(Keep1|Keep2|Keep3|jrdH8u)/$1 /g', 
	's/(Keep1|Keep2|Keep3|jrdH8u) (?!(Keep1|Keep2|Keep3|jrdH8u)).*/$1 /g',
	's/jrdH8u *//'
	);
	
	ok('Keep1 Keep2 ' eq flags_regex('REM Keep1 REM Keep2 REM'), "Keep only regex 'REM Keep1 REM Keep2 REM'");
	ok('Keep1 Keep2 ' eq flags_regex('Keep1 REM Keep2 REM'), "Keep only regex");
	ok('Keep1 Keep2 ' eq flags_regex('REM Keep1 Keep2 REM'), "Keep only regex");
	ok('Keep1 Keep2 ' eq flags_regex('REM Keep1 REM Keep2'), "Keep only regex");
	ok('Keep1 Keep2 Keep3 ' eq flags_regex('REM Keep1 REM Keep2 REM REM Keep3 REM'), "Keep only regex");
	ok('Keep1 ' eq flags_regex('REM  REM Keep1 REM REM REM '), "Keep only regex");
	ok('Keep1 Keep3 ' eq flags_regex('RE1 Keep1 RE2 Keep3 RE3 RE4 RE5 '), "Keep only regex");
	ok('' eq flags_regex('REM  REM REM REM REM'), "Keep only regex");
	
	@regexflag = (
	's/(.*)/$1 jrdH8u/',
	's/.*?(\\\\Seen|\\\\Answered|\\\\Flagged|\\\\Deleted|\\\\Draft|jrdH8u)/$1 /g', 
	's/(\\\\Seen|\\\\Answered|\\\\Flagged|\\\\Deleted|\\\\Draft|jrdH8u) (?!(\\\\Seen|\\\\Answered|\\\\Flagged|\\\\Deleted|\\\\Draft|jrdH8u)).*/$1 /g',
	's/jrdH8u *//'
	);
	
	ok('\\Deleted \\Answered ' 
	eq flags_regex('Blabla $Junk \\Deleted machin \\Answered truc'), "Keep only regex: Exchange case");
	ok('' eq flags_regex(''), "Keep only regex: Exchange case, null string");
	ok('' 
	eq flags_regex('Blabla $Junk  machin  truc'), "Keep only regex: Exchange case, no accepted flags ");
	ok('\\Deleted \\Answered \\Draft \\Flagged ' 
	eq flags_regex('\\Deleted    \\Answered  \\Draft \\Flagged '), "Keep only regex: Exchange case");
	
	
	@regexflag = (
	's/.*?(?:(\\\\(?:Answered|Flagged|Deleted|Seen|Draft)\s?)|$)/defined($1)?$1:q()/eg'
	);
	
	ok('\\Deleted \\Answered ' 
	eq flags_regex('Blabla \$Junk \\Deleted machin \\Answered truc'), 
	"Keep only regex: Exchange case (Phil)");
	
	ok('' eq flags_regex(''), "Keep only regex: Exchange case, null string (Phil)");
	
	ok('' 
	eq flags_regex('Blabla $Junk  machin  truc'), 
	"Keep only regex: Exchange case, no accepted flags (Phil)");
	
	ok('\\Deleted \\Answered \\Draft \\Flagged ' 
	eq flags_regex('\\Deleted    \\Answered  \\Draft \\Flagged '), 
	"Keep only regex: Exchange case (Phil)");
	
	return(  ) ;
}

sub flags_regex {
	my ( $h1_flags ) = @_ ;
	foreach my $regexflag ( @regexflag ) {
		my $h1_flags_orig = $h1_flags ;
		$debugflags and print "eval \$h1_flags =~ $regexflag\n" ;
		my $ret = eval( "\$h1_flags =~ $regexflag ; 1 " ) ;
		$debugflags and print "regexflag $regexflag [$h1_flags_orig] -> [$h1_flags]\n" ;
                if( not ( defined $ret ) or $@ ) {
			print "Error: eval regexflag '$regexflag': $@\n" ;
                        return( undef ) ;
                }
	}
	return( $h1_flags ) ;
}

sub acls_sync {
	my($h1_fold, $h2_fold) = @_ ;
	if ( $syncacls ) {
		my $h1_hash = $imap1->getacl($h1_fold)
		  or print "Could not getacl for $h1_fold: $@\n";
		my $h2_hash = $imap2->getacl($h2_fold)
		  or print "Could not getacl for $h2_fold: $@\n";
		my %users = map({ ($_, 1) } (keys(%$h1_hash), keys(%$h2_hash)));
		foreach my $user (sort(keys(%users))) {
			my $acl = $h1_hash->{$user} || "none";
			print "acl $user: [$acl]\n";
			next if ($h1_hash->{$user} && $h2_hash->{$user} &&
				 $h1_hash->{$user} eq $h2_hash->{$user});
			unless ($dry) {
				print "setting acl $h2_fold $user $acl\n";
				$imap2->setacl($h2_fold, $user, $acl)
				  or print "Could not set acl: $@\n";
			}
		}
	}
        return(  ) ;
}


sub tests_permanentflags {
	
	my $string;
	ok('' eq permanentflags(' * OK [PERMANENTFLAGS (\* \Draft \Answered)] Limited'), 
	   'permanentflags \*');
	ok('\Draft \Answered' eq permanentflags(' * OK [PERMANENTFLAGS (\Draft \Answered)] Limited'), 
	   'permanentflags \Draft \Answered');
	ok('\Draft \Answered' 
	   eq permanentflags('Blabla', 
	                     ' * OK [PERMANENTFLAGS (\Draft \Answered)] Limited',
			     'Blabla'),
	   'permanentflags \Draft \Answered'
	);
	ok('' eq permanentflags('Blabla'), 'permanentflags nothing');
        return(  ) ;
}

sub permanentflags {
	my @lines = @_ ;

	foreach my $line (@lines) {
		if ( $line =~ m{\[PERMANENTFLAGS\s\(([^)]+?)\)\]}x ) {
			( $debugflags or $debug ) and print "permanentflags: $line" ;
			my $permanentflags = $1 ;
			if ( $permanentflags =~ m{\\\*}x ) {
				$permanentflags = '' ;
			}
			return($permanentflags) ;
		} ;
	}
        return( '' ) ;
}

sub tests_flags_filter {

	ok( '\Seen' eq flags_filter('\Seen', '\Draft \Seen \Answered'), 'flags_filter ' );
	ok( '' eq flags_filter('\Seen', '\Draft  \Answered'), 'flags_filter ' );
	ok( '\Seen' eq flags_filter('\Seen', '\Seen'), 'flags_filter ' );
	ok( '\Seen' eq flags_filter('\Seen', ' \Seen '), 'flags_filter ' );
	ok( '\Seen \Draft' 
	   eq flags_filter('\Seen \Draft', '\Draft \Seen \Answered'), 'flags_filter ' );
	ok( '\Seen \Draft' 
	   eq flags_filter('\Seen \Draft', ' \Draft \Seen \Answered '), 'flags_filter ' );
        return(  ) ;
}

sub flags_filter {
	my( $flags, $allowed_flags ) = @_ ;
	
	my @flags = split( /\s+/x, $flags ) ;
	my %allowed_flags = map { $_ => 1 } split(' ', $allowed_flags ) ;
	my @flags_out     = map { exists $allowed_flags{$_} ? $_ : () } @flags ;

	my $flags_out = join( ' ', @flags_out ) ;
	#print "%%%$flags_out%%%\n" ;
	return( $flags_out ) ;
}

sub flagsCase {
	my $flags = shift ;
	
	my @flags = split( /\s+/x, $flags );
	my %rfc_flags = map { $_ => 1 } split(' ', '\Answered \Flagged \Deleted \Seen \Draft' );
	my @flags_out = map { exists $rfc_flags{ ucsecond( lc( $_ ) ) } ? ucsecond( lc( $_ ) ) : $_ } @flags ;

	my $flags_out = join( ' ', @flags_out ) ;
	#print "%%%$flags_out%%%\n" ;
	return( $flags_out ) ;
}

sub tests_flagsCase {
	ok( '\Seen' eq flagsCase( '\Seen' ), 'flagsCase: \Seen -> \Seen' ) ;
	ok( '\Seen' eq flagsCase( '\SEEN' ), 'flagsCase: \SEEN -> \Seen' ) ;

	ok( '\Seen \Draft' eq flagsCase( '\SEEN \DRAFT' ), 'flagsCase: \SEEN \DRAFT -> \Seen \Draft' ) ;
	ok( '\Draft \Seen' eq flagsCase( '\DRAFT \SEEN' ), 'flagsCase: \DRAFT \SEEN -> \Draft \Seen' ) ;
	
	ok( '\Draft LALA \Seen' eq flagsCase( '\DRAFT  LALA \SEEN' ), 'flagsCase: \DRAFT  LALA \SEEN -> \Draft LALA \Seen' ) ;
	ok( '\Draft lala \Seen' eq flagsCase( '\DRAFT  lala \SEEN' ), 'flagsCase: \DRAFT  lala \SEEN -> \Draft lala \Seen' ) ;
        return(  ) ;
}

sub ucsecond {
	my $string = shift ;
	my $output ;
	
	return( $string )  if ( 1 >= length( $string ) ) ;
	$output = substr( $string, 0, 1) . uc( substr( $string, 1, 1 ) ) if ( 2 == length( $string ) ) ;
	$output = substr( $string, 0, 1) . uc( substr( $string, 1, 1 ) ) . substr( $string, 2 );
	#print "UUU $string -> $output\n" ;
	return( $output ) ;
}


sub tests_ucsecond {
	ok( 'aBcde' eq ucsecond( 'abcde' ), 'ucsecond: abcde -> aBcde' ) ;
	ok( 'ABCDE' eq ucsecond( 'ABCDE' ), 'ucsecond: ABCDE -> ABCDE'  ) ;
	ok( 'ABCDE' eq ucsecond( 'AbCDE' ), 'ucsecond: AbCDE -> ABCDE'  ) ;
	ok( 'ABCde' eq ucsecond( 'AbCde' ), 'ucsecond: AbCde -> ABCde'  ) ;
	ok( 'A'     eq ucsecond( 'A' ),     'ucsecond: A  -> A'  ) ;
	ok( 'AB'    eq ucsecond( 'Ab' ),    'ucsecond: Ab -> AB' ) ;
	ok( '\B'    eq ucsecond( '\b' ),    'ucsecond: \b -> \B' ) ;
	ok( '\Bcde' eq ucsecond( '\bcde' ), 'ucsecond: \bcde -> \Bcde' ) ;
        return(  ) ;
}


sub select_msgs {
	my ( $imap, $msgs_all_hash_ref, $search_cmd, $folder ) = @_ ;
	my ( @msgs ) ;

	if ( $abletosearch ) { 
		@msgs = select_msgs_by_search( $imap, $msgs_all_hash_ref, $search_cmd, $folder ) ;
	}else{
		@msgs = select_msgs_by_fetch( $imap, $msgs_all_hash_ref, $search_cmd, $folder ) ;
	}

}

sub select_msgs_by_search {
	my ( $imap, $msgs_all_hash_ref, $search_cmd, $folder ) = @_ ;
	my ( @msgs, @msgs_all ) ;
	
        # Need to have the whole list in msgs_all_hash_ref
        # without calling messages() several times.
        # Need all messages list to avoid deleting useful cache part 
        # in case of --search or --minage or --maxage

	if ( ( defined( $msgs_all_hash_ref ) and $usecache )
        or ( not defined( $maxage ) and not defined( $minage ) and not defined( $search_cmd ) )
        ) {

       		$debugdev and print "Calling messages()\n" ;
		@msgs_all = $imap->messages() ;

                return if ( $#msgs_all == 0 && !defined( $msgs_all[0] ) ) ;
                
                if ( defined( $msgs_all_hash_ref ) ) {
                        @{ $msgs_all_hash_ref }{ @msgs_all } =  () ;
                }
                # return all messages
                if ( not defined( $maxage ) and not defined( $minage ) and not defined( $search_cmd ) ) {
                        return( @msgs_all ) ;
                }
	}
        
        if ( defined( $search_cmd ) ) {
        	@msgs = $imap->search( $search_cmd ) ;
                return( @msgs ) ;
        }

	# we are here only if $maxage or $minage is defined
        @msgs = select_msgs_by_age( $imap ) ;
	return( @msgs );
}


sub select_msgs_by_fetch {
	my ( $imap, $msgs_all_hash_ref, $search_cmd, $folder ) = @_ ;
	my ( @msgs, @msgs_all, %fetch ) ;
	
        # Need to have the whole list in msgs_all_hash_ref
        # without calling messages() several times.
        # Need all messages list to avoid deleting useful cache part 
        # in case of --search or --minage or --maxage


	$debugdev and print "Calling fetch_hash()\n" ;
	my $uidnext = $imap->uidnext( $folder ) or return(  ) ;
	%fetch = %{$imap->fetch_hash( "1:$uidnext", "INTERNALDATE") } ;
        @msgs_all = sort { $a <=> $b } keys( %fetch ) ;
        $debugdev and print "Done fetch_hash()\n" ;

        return(  ) if ( $#msgs_all == 0 && !defined( $msgs_all[0] ) ) ;
               
        if ( defined( $msgs_all_hash_ref ) ) {
                 @{ $msgs_all_hash_ref }{ @msgs_all } =  () ;
        }
        # return all messages
        if ( not defined( $maxage ) and not defined( $minage ) and not defined( $search_cmd ) ) {
                return( @msgs_all ) ;
        }
	
        if ( defined( $search_cmd ) ) {
		print "Warning: strange to see --search with --noabletosearch, an error can happen\n" ;
        	@msgs = $imap->search( $search_cmd ) ;
                return( @msgs ) ;
        }

	# we are here only if $maxage or $minage is defined
	my( @max, @min, $maxage_epoch, $minage_epoch ) ;
	if ( defined( $maxage ) ) { $maxage_epoch = $timestart_int - 86400 * $maxage ; }
	if ( defined( $minage ) ) { $minage_epoch = $timestart_int - 86400 * $minage ; }
	foreach my $msg ( @msgs_all ) {
		my $idate = $fetch{ $msg }->{'INTERNALDATE'} ;
		#print "$idate\n" ;
		if ( defined( $maxage ) and ( epoch( $idate ) >= $maxage_epoch ) ) {
			push( @max, $msg ) ;
		}
		if ( defined( $minage ) and ( epoch( $idate ) <= $minage_epoch ) ) {
			push( @min, $msg ) ;
		}
	}
        @msgs = msgs_from_maxmin( \@max, \@min ) ;
	return( @msgs ) ;
}

sub select_msgs_by_age {
	my( $imap ) = @_ ;
        
	my( @max, @min, @msgs, @inter, @union ) ;
        
	if ( defined( $maxage ) ) {
		@max = $imap->sentsince( $timestart_int - 86400 * $maxage ) ;
	}
	if ( defined( $minage ) ) {
		@min = $imap->sentbefore( $timestart_int - 86400 * $minage ) ;
	}

	@msgs = msgs_from_maxmin( \@max, \@min ) ;
	return( @msgs ) ;
}

sub msgs_from_maxmin {
	my( $max_ref, $min_ref ) = @_ ;
	my( @max, @min, @msgs, @inter, @union ) ;

	@max = @$max_ref ;
	@min = @$min_ref ;

	SWITCH: {
		unless( defined( $minage ) ) { @msgs = @max ; last SWITCH } ;
		unless( defined( $maxage ) ) { @msgs = @min ; last SWITCH } ;
		my ( %union, %inter ) ; 
		foreach my $m ( @min, @max ) { $union{ $m }++ && $inter{ $m }++ }
		@inter = sort { $a <=> $b } keys( %inter ) ;
		@union = sort { $a <=> $b } keys( %union ) ;
		# normal case
		if ( $minage <= $maxage )  { @msgs = @inter ; last SWITCH } ;
		# just exclude messages between
		if ( $minage > $maxage )  { @msgs = @union ; last SWITCH } ;
		
	}
	return( @msgs );
}

sub tests_msgs_from_maxmin {
	my @msgs ;
	$maxage = 200 ;
	@msgs = msgs_from_maxmin( [ '1', '2' ], [ '2', '3' ] ) ;
	ok( 0 == compare_lists( [ '1', '2' ], \@msgs ), 'msgs_from_maxmin: maxage++' ) ;
	$minage = 100 ;
	@msgs = msgs_from_maxmin( [ '1', '2' ], [ '2', '3' ] ) ;
	ok( 0 == compare_lists( [ '2' ], \@msgs ), 'msgs_from_maxmin:  -maxage++minage-' ) ;
	$minage = 300 ;
	@msgs = msgs_from_maxmin( [ '1', '2' ], [ '2', '3' ] ) ;
	ok( 0 == compare_lists( [ '1', '2', '3' ], \@msgs ), 'msgs_from_maxmin:  ++maxage-minage++' ) ;
	$maxage = undef ;
	@msgs = msgs_from_maxmin( [ '1', '2' ], [ '2', '3' ] ) ;
	ok( 0 == compare_lists( [ '2', '3' ], \@msgs ), 'msgs_from_maxmin:  ++minage-' ) ;
}


sub lastuid {
	my $imap   = shift ;
	my $folder = shift ;
	my $lastuid_guess  = shift ;
	my $lastuid ;
	
	# rfc3501: The only reliable way to identify recent messages is to
	#          look at message flags to see which have the \Recent flag
	#          set, or to do a SEARCH RECENT.
	# SEARCH RECENT doesn't work this way on courrier.

	my @recent_messages ;
	# SEARCH RECENT for each transfer can be expensive with a big folder
	# Call commented for now
	#@recent_messages = $imap->recent(  ) ;
	#print "Recent: @recent_messages\n";
	
	my $max_recent ;
	$max_recent = max( @recent_messages ) ;
	 
	if ( defined( $max_recent ) and ($lastuid_guess <= $max_recent ) ) {
		$lastuid = $max_recent ;
	}else{
		$lastuid = $lastuid_guess
	}
	return( $lastuid ) ;
}

sub size_filtered {
	my( $h1_size, $h1_msg, $h1_fold, $h2_fold  ) = @_ ;
	
        $h1_size = 0 if ( ! $h1_size ) ; # null if empty or undef
	if (defined $maxsize and $h1_size > $maxsize) {
		print "msg $h1_fold/$h1_msg skipped ($h1_size exceeds maxsize limit $maxsize bytes)\n";
		$total_bytes_skipped += $h1_size;
		$nb_msg_skipped += 1;
		return( 1 ) ;
	}
	if (defined $minsize and $h1_size <= $minsize) {
		print "msg $h1_fold/$h1_msg skipped ($h1_size smaller than minsize $minsize bytes)\n";
		$total_bytes_skipped += $h1_size;
		$nb_msg_skipped += 1;
		return( 1 ) ;
	}
	return( 0 ) ;
}

sub message_exists {

	my( $imap, $msg ) = @_ ;
	return( 1 ) if not $imap->Uid(  ) ;
        
	my $search_uid ;
        ( $search_uid ) = $imap->search( "UID $msg" ) ;
        #print "$search ? $msg\n" ;
        return( 1 ) if ( $search_uid eq $msg ) ;
        return( 0 ) ;

}

sub copy_message {
	# copy
	
	my ( $h1_msg, $h1_fold, $h2_fold, $h1_fir_ref, $permanentflags2, $cache_dir ) = @_ ;
	( $debug or $dry) and print "msg $h1_fold/$h1_msg copying to $h2_fold $dry_message\n";

	my $h1_size  = $h1_fir_ref->{$h1_msg}->{"RFC822.SIZE"} || '' ;
	my $h1_flags = $h1_fir_ref->{$h1_msg}->{"FLAGS"} || '' ;
	my $h1_idate = $h1_fir_ref->{$h1_msg}->{"INTERNALDATE"} || '' ;
	
	
        if ( size_filtered( $h1_size, $h1_msg, $h1_fold, $h2_fold  ) ) {
        	$h1_nb_msg_processed +=1 ;
                return(  ) ;
        }
	
	do { print "SLEEP 5\n" and sleep 5 ; } if ( $debugsleep ) ;
	print "- msg $h1_fold/$h1_msg S[$h1_size] F[$h1_flags] I[$h1_idate] has RFC822.SIZE null!\n" if ( ! $h1_size ) ;

	
        if ( $checkmessageexists and not message_exists( $imap1, $h1_msg ) ) {
        	$h1_nb_msg_processed +=1 ;
                return(  ) ;
        }

	my ( $string, $string_len ) ;
        ( $string, $string_len ) = message_for_host2( $h1_msg, $h1_fold, $h1_size, $h1_flags, $h1_idate, $h1_fir_ref ) ;
        
        # Lines two long => do no copy
        if ( ( defined ( $maxlinelength ) ) 
         and ( max_line_length( $string ) > $maxlinelength ) ) {
         	my $subject = subject( $string ) ;
                #print "[$subject]\n" ;
         	print "- msg $h1_fold/$h1_msg skipped S[$h1_size] F[$h1_flags] I[$h1_idate] " 
                      . "(Subject:[$subject]) (line length exceeds maxlinelength $maxlinelength bytes)\n" ;
         	return(  ) ;
        }

	my $h1_date = date_for_host2( $h1_msg, $h1_idate ) ;

	( $debug or $debugflags ) and 
        print "Host1 flags init msg $h1_fold/$h1_msg date [$h1_date] flags [$h1_flags] size [$h1_size]\n" ;

	$h1_flags = flags_for_host2( $h1_flags, $permanentflags2 ) ;

	( $debug or $debugflags ) and 
        print "Host1 flags filt msg $h1_fold/$h1_msg date [$h1_date] flags [$h1_flags] size [$h1_size]\n" ;

	$h1_date = undef if ($h1_date eq "");
	
	my $new_id = append_message_on_host2( $string, $h1_fold, $h1_msg, $string_len, $h2_fold, $h1_size, $h1_flags, $h1_date, $cache_dir ) ;

	if ( $new_id and $syncflagsaftercopy ) {
        	sync_flags_after_copy( $h1_fold, $h1_msg, $h1_flags, $h2_fold, $new_id, $permanentflags2 ) ;
        }

        
        return( $new_id ) ;
}

sub message_for_host2 {
	my ( $h1_msg, $h1_fold, $h1_size, $h1_flags, $h1_idate, $h1_fir_ref ) = @_ ;
        
	my $string = $imap1->message_string( $h1_msg ) ;
	
	my $string_len = defined( $string ) ? length( $string ) : '' ; # length or empty string
	#print "- msg $h1_fold/$h1_msg {$string_len}\n" ;
	unless ( defined( $string ) and $string_len ) { # undef or 0 length
		print
		"- msg $h1_fold/$h1_msg {$string_len} S[$h1_size] F[$h1_flags] I[$h1_idate] could not be fetched: ",
		$imap1->LastError || '', "\n" ;
		$nb_errors++ ;
		$total_bytes_error += $h1_size if ( $h1_size ) ;
		#relogin1(  ) if ( $relogin1 ) ;
                $h1_nb_msg_processed +=1 ;
		return(  ) ;
	}
	
	if ( @regexmess ) {
		$string = regexmess( $string ) ;
                # string undef means the eval regex was bad.
                if ( not ( defined( $string ) ) ) {
                	print
			"- msg $h1_fold/$h1_msg {$string_len} S[$h1_size] F[$h1_flags] I[$h1_idate]" 
                        . " could not be transformed by --regexmess option\n" ;
                	return(  ) ;
                }
	}

        if ( $addheader and defined $h1_fir_ref->{$h1_msg}->{"NO_HEADER"} ) {
                my $header = add_header( $h1_msg ) ;
                $debug and print "msg $h1_fold/$h1_msg adding custom header [$header]\n" ;
                $string = $header . "\r\n" . $string ;
        }


	$debugcontent and print 
		"=" x80, "\n", 
		"F message content begin next line\n",
		$string,
		"F message content ended on previous line\n", "=" x 80, "\n";

	return( $string, $string_len ) ;
}

sub date_for_host2 {
	my( $h1_msg, $h1_idate ) = @_ ;

	my $h1_date = "" ;

	if ( $syncinternaldates ) {
		$h1_date = $h1_idate ;
		$debug and print "internal date from host1: [$h1_date]\n" ;
		$h1_date = good_date( $h1_date ) ;
		$debug and print "internal date from host1: [$h1_date] (fixed)\n" ;
	}
	
	if ( $idatefromheader ) {
		$h1_date = $imap1->get_header($h1_msg,"Date") ;
		$debug and print "header date from host1: [$h1_date]\n" ;
		$h1_date = good_date( $h1_date ) ;
		$debug and print "header date from host1: [$h1_date] (fixed)\n" ;
	}

	return( $h1_date ) ;
}

sub flags_for_host2 {
	my( $h1_flags, $permanentflags2 ) = @_ ;
	# RFC 2060: This flag can not be altered by any client
	$h1_flags =~ s@\\Recent\s?@@xgi ;
        my $h1_flags_re ;
        if ( @regexflag and defined( $h1_flags_re = flags_regex( $h1_flags ) ) ) {
                $h1_flags = $h1_flags_re ;
        }
	$h1_flags = flagsCase( $h1_flags ) if $flagsCase ;
        $h1_flags = flags_filter( $h1_flags, $permanentflags2) if ( $permanentflags2 and $filterflags ) ;
	
	return( $h1_flags ) ;
}

sub subject {
	my $string = shift ;
	my $subject = '' ;
        
        my $header = extract_header( $string ) ;

        if( $header =~ m/^Subject:\s*([^\n\r]*)\r?$/msx ) {  
        	#print "MMM[$1]\n" ;
        	$subject = $1 ;
        }
	return( $subject ) ;
}

sub tests_subject {
	ok( '' eq subject( '' ), 'subject: null') ;
	ok( 'toto le hero' eq subject( 'Subject: toto le hero' ), 'subject: toto le hero') ;
	ok( 'toto le hero' eq subject( 'Subject:toto le hero' ), 'subject: toto le hero blank') ;
	ok( 'toto le hero' eq subject( "Subject:toto le hero\r\n" ), 'subject: toto le hero\r\n') ;

        my $MESS ;
	$MESS = <<'EOF';
From: lalala
Subject: toto le hero
Date: zzzzzz

Boogie boogie
EOF
	ok( 'toto le hero' eq subject( $MESS ), 'subject: toto le hero 2') ;

	$MESS = <<'EOF';
Subject: toto le hero
From: lalala
Date: zzzzzz

Boogie boogie
EOF
	ok( 'toto le hero' eq subject( $MESS ), 'subject: toto le hero 3') ;


	$MESS = <<'EOF';
From: lalala
Subject: cuicui
Date: zzzzzz

Subject: toto le hero
EOF
	ok( 'cuicui' eq subject( $MESS ), 'subject: cuicui') ;

	$MESS = <<'EOF';
From: lalala
Date: zzzzzz

Subject: toto le hero
EOF
	ok( '' eq subject( $MESS ), 'subject: null but body could') ;


}


# GlobVar
# $dry
# $max_msg_size_in_bytes
# $imap2
# $imap1
# $nb_errors
# $total_bytes_error
# $h1_nb_msg_processed
# $h2_uidguess
# $total_bytes_transferred
# $nb_msg_transferred
# $begin_transfer_time
# $time_spent
# ...
#
#
sub append_message_on_host2 {
	my( $string, $h1_fold, $h1_msg, $string_len, $h2_fold, $h1_size, $h1_flags, $h1_date, $cache_dir ) = @_ ;
	
	my $new_id ;
	if ( ! $dry ) {
		$max_msg_size_in_bytes = max( $h1_size, $max_msg_size_in_bytes ) ;
		$new_id = $imap2->append_string( $h2_fold, $string, $h1_flags, $h1_date ) ;
		if ( ! $new_id){
                	my $subject = subject( $string ) ;
                        my $error = $imap2->LastError || '' ;
			print "- msg $h1_fold/$h1_msg {$string_len} couldn't append  (Subject:[$subject]) to folder $h2_fold: $error\n" ;
			  
			$nb_errors++;
			$total_bytes_error += $h1_size;
                        $h1_nb_msg_processed +=1 ;
			return(  ) ;
		}
		else{
			# good
			# $new_id is an id if the IMAP server has the 
			# UIDPLUS capability else just a ref
			if ( $new_id !~ m{^\d+$}x ) {
				$new_id = lastuid( $imap2, $h2_fold, $h2_uidguess ) ;
			}
			$h2_uidguess += 1 ;
			$total_bytes_transferred += $h1_size ;
			$nb_msg_transferred += 1 ;
                        $h1_nb_msg_processed +=1 ;

                        my $time_spent = timesince( $begin_transfer_time ) ;
                        my $rate = bytes_display_string( $total_bytes_transferred / $time_spent ) ;
                        my $eta = eta( $time_spent, $h1_nb_msg_processed, $h1_nb_msg_at_start, $nb_msg_transferred ) ;
                        
			printf( "msg %s/%-19s copied to %s/%-10s %.2f msgs/s  %s/s  %s\n", 
                        $h1_fold, "$h1_msg {$string_len}", $h2_fold, $new_id, $nb_msg_transferred/$time_spent, $rate, $eta );
                        
                        if ( $usecache and $cacheaftercopy and $new_id =~ m{^\d+$}x ) {
				$debugcache and print "touch $cache_dir/${h1_msg}_$new_id\n" ;
				touch( "$cache_dir/${h1_msg}_$new_id" ) 
                        	or croak( "Couldn't touch $cache_dir/${h1_msg}_$new_id" ) ;
                        }
			if ( $delete ) {
				delete_message_on_host1( $h1_msg, $h1_fold ) ;
			}
			#print "PRESS ENTER" and my $a = <> ;
                        return( $new_id ) ;
		}
	}
	else{
		$nb_msg_skipped_dry_mode += 1;
                $h1_nb_msg_processed +=1 ;
	}

	return(  ) ;
}



# 6 GlobVar: $dry_message $dry $imap1 $h1_nb_msg_deleted $expunge $expunge1 
sub delete_message_on_host1 {
	my( $h1_msg, $h1_fold ) = @_ ;
	print "msg $h1_fold/$h1_msg deleted on host1 $dry_message\n";
        if ( ! $dry ) {
        	$imap1->delete_message( $h1_msg ) ;
        	$h1_nb_msg_deleted += 1 ;
        	$imap1->expunge() if ( $expunge or $expunge1 ) ;
        }
        return(  ) ;
}


sub eta {
	my( $my_time_spent, $h1_nb_processed, $h1_nb_msg_start, $nb_transferred ) = @_ ;
	return( '' ) if not $foldersizes ;
        	
        my $time_remaining = time_remaining( $my_time_spent, $h1_nb_processed, $h1_nb_msg_start, $nb_transferred ) ;
        my $nb_msg_remaining = $h1_nb_msg_start - $h1_nb_processed ;
        my $eta_date = localtime( time + $time_remaining ) ;
        return( sprintf( "ETA: %s  %1.0f s  %s msgs left", $eta_date, $time_remaining, $nb_msg_remaining ) ) ;
}

sub time_remaining {

	my( $my_time_spent, $h1_nb_processed, $h1_nb_msg_start, $nb_transferred ) = @_ ;

	my $time_remaining = ( $my_time_spent / $nb_transferred ) * ( $h1_nb_msg_start - $h1_nb_processed ) ;
	return( $time_remaining ) ;
}


sub tests_time_remaining {

	ok( 1 == time_remaining( 1, 1, 2, 1 ), "time_remaining: 1, 1, 2, 1 -> 1") ;
	ok( 1 == time_remaining( 9, 9, 10, 9 ), "time_remaining: 9, 9, 10, 9 -> 1") ;
	ok( 9 == time_remaining( 1, 1, 10, 1 ), "time_remaining: 1, 1, 10, 1 -> 1") ;
	return(  ) ;
}


sub cache_map {
	my ( $cache_files_ref, $h1_msgs_ref, $h2_msgs_ref ) = @_;
	my ( %map1_2, %map2_1, %done2 ) ;
	
	my $h1_msgs_hash_ref = {  } ;
	my $h2_msgs_hash_ref = {  } ;
	
	@$h1_msgs_hash_ref{ @$h1_msgs_ref } = (  ) ;
	@$h2_msgs_hash_ref{ @$h2_msgs_ref } = (  ) ;
	
	foreach my $file ( sort @$cache_files_ref ) {
		$debugcache and print "C12: $file\n" ;
		( $uid1, $uid2 ) = match_a_cache_file( $file ) ;
		
		if (  exists( $h1_msgs_hash_ref->{ defined( $uid1 ) ? $uid1 : q{} } ) 
		  and exists( $h2_msgs_hash_ref->{ defined( $uid2 ) ? $uid2 : q{} } ) ) {
		  	# keep only the greatest uid2 
			# 130_2301 and
			# 130_231  => keep only 130 -> 2301
			
			# keep only the greatest uid1
			# 1601_260 and
			#  161_260 => keep only 1601 -> 260
		  	my $max_uid2 = max( $uid2, $map1_2{ $uid1 } || -1 ) ;
			if ( exists( $done2{ $max_uid2 } ) ) {
				if ( $done2{ $max_uid2 } < $uid1 )  {
					$map1_2{ $uid1 } = $max_uid2 ;
					delete( $map1_2{ $done2{ $max_uid2 } } ) ;
					$done2{ $max_uid2 } = $uid1 ;
				}
			}else{
				$map1_2{ $uid1 } = $max_uid2 ;
				$done2{ $max_uid2 } = $uid1 ;
			}
		};
		
	}
	%map2_1 = reverse( %map1_2 ) ;
	return( \%map1_2, \%map2_1) ;
}

sub tests_cache_map {
	#$debugcache = 1 ;
	my @cache_files = qw (
	100_200
	101_201
	120_220
	142_242
	143_243
	177_277
	177_278
	177_279
	155_255
	180_280
	181_280
	182_280
	130_231
	130_2301
	161_260
	1601_260
	) ;
	
	my $msgs_1 = [120, 142, 143, 144, 161, 1601,           177,      182, 130 ];
	my $msgs_2 = [     242, 243,       260,      299, 377, 279, 255, 280, 231, 2301 ];
	
	my( $c12, $c21 ) ;
	ok( ( $c12, $c21 ) = cache_map( \@cache_files, $msgs_1, $msgs_2 ), 'cache_map: 02' );
	my $a1 = [ sort { $a <=> $b } keys %$c12 ] ;
	my $a2 = [ sort { $a <=> $b } keys %$c21 ] ;
	ok( 0 == compare_lists( [ 130, 142, 143,      177, 182, 1601      ], $a1 ), 'cache_map: 03' );
	ok( 0 == compare_lists( [      242, 243, 260, 279, 280,      2301 ], $a2 ), 'cache_map: 04' );
	ok( ! $c12->{161},        'cache_map: ! 161 ->  260' );
	ok( 260  == $c12->{1601}, 'cache_map:  1601 ->  260' );
	ok( 2301 == $c12->{130},  'cache_map:   130 -> 2301' );
	#print $c12->{1601}, "\n";
	return(  ) ;

}

sub cache_dir_fix {
	my $cache_dir = shift ;
        $cache_dir =~ s/([;<>\*\|`&\$!#\(\)\[\]\{\}:'"\\])/\\$1/xg ;
        #print "cache_dir_fix: $cache_dir\n" ;
	return( $cache_dir ) ;
}

sub tests_cache_dir_fix {
	ok( 'lalala' eq  cache_dir_fix('lalala'),  'cache_dir_fix: lalala -> lalala' );
	ok( 'ii\\\\ii' eq  cache_dir_fix('ii\ii'), 'cache_dir_fix: ii\ii -> ii\\\\ii' );
	ok( 'ii@ii' eq  cache_dir_fix('ii@ii'),  'cache_dir_fix: ii@ii -> ii@ii' );
	ok( 'ii@ii\\:ii' eq  cache_dir_fix('ii@ii:ii'), 'cache_dir_fix: ii@ii:ii -> ii@ii\\:ii' );
	ok( 'i\\\\i\\\\ii' eq  cache_dir_fix('i\i\ii'), 'cache_dir_fix: i\i\ii -> i\\\\i\\\\ii' );
	ok( 'i\\\\ii' eq  cache_dir_fix('i\\ii'), 'cache_dir_fix: i\\ii -> i\\\\\\\\ii' );
	ok( '\\\\ ' eq  cache_dir_fix('\\ '), 'cache_dir_fix: \\  -> \\\\\ ' );
	ok( '\\\\ ' eq  cache_dir_fix('\ '), 'cache_dir_fix: \  -> \\\\\ ' );
	return(  ) ;

}

sub get_cache { 
	my ( $cache_dir, $h1_msgs_ref, $h2_msgs_ref, $h1_msgs_all_hash_ref, $h2_msgs_all_hash_ref ) = @_;

	$debugcache and print "Entering get_cache\n";

	-d $cache_dir or return( undef ); # exit if cache directory doesn't exist
	$debugcache and print "cache_dir    : $cache_dir\n";
	
	#$cache_dir =~ s{\\}{\\\\}g;
        $cache_dir = cache_dir_fix( $cache_dir ) if ( 'MSWin32' ne $OSNAME ) ;

	$debugcache and print "cache_dir_fix: $cache_dir\n" ;
        
	my @cache_files = bsd_glob( "$cache_dir/*" ) ;
	#$debugcache and print "cache_files: [@cache_files]\n" ;
        
	$debugcache and print( "cache_files: ", scalar( @cache_files ), " files found\n" ) ;
	
	my( $cache_1_2_ref, $cache_2_1_ref ) 
	  = cache_map( \@cache_files, $h1_msgs_ref, $h2_msgs_ref ) ;
	
	clean_cache( \@cache_files, $cache_1_2_ref, $h1_msgs_all_hash_ref, $h2_msgs_all_hash_ref ) ;
	
	#print "\n", map { "c12 $_ -> $cache_1_2_ref->{ $_ }\n" } keys %$cache_1_2_ref ;
	#print "\n", map { "c21 $_ -> $cache_2_1_ref->{ $_ }\n" } keys %$cache_2_1_ref ;

	$debugcache and print "Exiting get_cache\n";
	return ( $cache_1_2_ref, $cache_2_1_ref ) ;
}


sub tests_get_cache {
	
	ok( not( get_cache('/cache_no_exist') ), 'get_cache: /cache_no_exist' );
	ok( ( not -d 'W/tmp/cache/F1/F2' or rmtree( 'W/tmp/cache/F1/F2' )), 'get_cache: rmtree W/tmp/cache/F1/F2' ) ;
	ok( mkpath( 'W/tmp/cache/F1/F2' ), 'get_cache: mkpath W/tmp/cache/F1/F2' ) ;
	
	my @test_files_cache = ( qw( 
	W/tmp/cache/F1/F2/100_200
	W/tmp/cache/F1/F2/101_201
	W/tmp/cache/F1/F2/120_220
	W/tmp/cache/F1/F2/142_242
	W/tmp/cache/F1/F2/143_243
	W/tmp/cache/F1/F2/177_277
	W/tmp/cache/F1/F2/177_377
	W/tmp/cache/F1/F2/177_777
	W/tmp/cache/F1/F2/155_255
	) ) ;
	ok( touch( @test_files_cache ), 'get_cache: touch W/tmp/cache/F1/F2/...' ) ;
	
	
	# on cache: 100_200 101_201 142_242 143_243 177_277 177_377 177_777 155_255
	# on live:
	my $msgs_1 = [120, 142, 143, 144,          177      ];
	my $msgs_2 = [     242, 243,     299, 377, 777, 255 ];
        
        my $msgs_all_1 = { 120 => '', 142 => '', 143 => '', 144 => '', 177 => '' } ;
        my $msgs_all_2 = { 242 => '', 243 => '', 299 => '', 377 => '', 777 => '', 255 => '' } ;
	
	my( $c12, $c21 ) ;
	ok( ( $c12, $c21 ) = get_cache( 'W/tmp/cache/F1/F2', $msgs_1, $msgs_2, $msgs_all_1, $msgs_all_2 ), 'get_cache: 02' );
	my $a1 = [ sort { $a <=> $b } keys %$c12 ] ;
	my $a2 = [ sort { $a <=> $b } keys %$c21 ] ;
	ok( 0 == compare_lists( [ 142, 143, 177 ], $a1 ), 'get_cache: 03' );
	ok( 0 == compare_lists( [ 242, 243, 777 ], $a2 ), 'get_cache: 04' );
	ok( -f 'W/tmp/cache/F1/F2/142_242', 'get_cache: file kept 142_242');
	ok( -f 'W/tmp/cache/F1/F2/142_242', 'get_cache: file kept 143_243');
	ok( ! -f 'W/tmp/cache/F1/F2/100_200', 'get_cache: file removed 100_200');
	ok( ! -f 'W/tmp/cache/F1/F2/101_201', 'get_cache: file removed 101_201');
	
	# test clean_cache executed
	$maxage = 2 ;
	ok( touch(@test_files_cache), 'get_cache: touch W/tmp/cache/F1/F2/...' ) ;
	ok( ( $c12, $c21 ) = get_cache('W/tmp/cache/F1/F2', $msgs_1, $msgs_2, $msgs_all_1, $msgs_all_2 ), 'get_cache: 02' );
	ok( -f 'W/tmp/cache/F1/F2/142_242', 'get_cache: file kept 142_242');
	ok( -f 'W/tmp/cache/F1/F2/142_242', 'get_cache: file kept 143_243');
	ok( ! -f 'W/tmp/cache/F1/F2/100_200', 'get_cache: file NOT removed 100_200');
	ok( ! -f 'W/tmp/cache/F1/F2/101_201', 'get_cache: file NOT removed 101_201');
	
	
	# strange files
	#$debugcache = 1 ;
	$maxage = undef ;
	ok( ( not -d 'W/tmp/cache/rr\uee' or rmtree( 'W/tmp/cache/rr\uee' )), 'get_cache: rmtree W/tmp/cache/rr\uee' ) ;
	ok( mkpath( 'W/tmp/cache/rr\uee' ), 'get_cache: mkpath W/tmp/cache/rr\uee' ) ;
	
	@test_files_cache = ( qw( 
	W/tmp/cache/rr\uee/100_200
	W/tmp/cache/rr\uee/101_201
	W/tmp/cache/rr\uee/120_220
	W/tmp/cache/rr\uee/142_242
	W/tmp/cache/rr\uee/143_243
	W/tmp/cache/rr\uee/177_277
	W/tmp/cache/rr\uee/177_377
	W/tmp/cache/rr\uee/177_777
	W/tmp/cache/rr\uee/155_255
	) ) ;
	ok( touch(@test_files_cache), 'get_cache: touch strange W/tmp/cache/...' ) ;
	
	# on cache: 100_200 101_201 142_242 143_243 177_277 177_377 177_777 155_255
	# on live:
	$msgs_1 = [120, 142, 143, 144,          177      ] ;
	$msgs_2 = [     242, 243,     299, 377, 777, 255 ] ;
	
        $msgs_all_1 = { 120 => '', 142 => '', 143 => '', 144 => '', 177 => '' } ;
        $msgs_all_2 = { 242 => '', 243 => '', 299 => '', 377 => '', 777 => '', 255 => '' } ;
        
	ok( ( $c12, $c21 ) = get_cache('W/tmp/cache/rr\uee', $msgs_1, $msgs_2, $msgs_all_1, $msgs_all_2), 'get_cache: strange path 02' );
	$a1 = [ sort { $a <=> $b } keys %$c12 ] ;
	$a2 = [ sort { $a <=> $b } keys %$c21 ] ;
	ok( 0 == compare_lists( [ 142, 143, 177 ], $a1 ), 'get_cache: strange path 03' );
	ok( 0 == compare_lists( [ 242, 243, 777 ], $a2 ), 'get_cache: strange path 04' );
	ok( -f 'W/tmp/cache/rr\uee/142_242', 'get_cache: strange path file kept 142_242');
	ok( -f 'W/tmp/cache/rr\uee/142_242', 'get_cache: strange path file kept 143_243');
	ok( ! -f 'W/tmp/cache/rr\uee/100_200', 'get_cache: strange path file removed 100_200');
	ok( ! -f 'W/tmp/cache/rr\uee/101_201', 'get_cache: strange path file removed 101_201');
	return(  ) ;
}

sub match_a_cache_file {
	my $file = shift ;
	my ( $cache_uid1, $cache_uid2 ) ;
	
	return( ( undef, undef ) ) if ( ! $file ) ;
	if ( $file =~ m{(?:^|/)(\d+)_(\d+)$}x ) {
		$cache_uid1 = $1 ;
		$cache_uid2 = $2 ;
	}
	return( $cache_uid1, $cache_uid2 ) ;
}

sub tests_match_a_cache_file {
	my ( $tuid1, $tuid2 ) ;
	ok( ( $tuid1, $tuid2 ) = match_a_cache_file(  ), 'match_a_cache_file: no arg' ) ;
	ok( ! defined( $tuid1 ), 'match_a_cache_file: no arg 1' ) ;
	ok( ! defined( $tuid2 ), 'match_a_cache_file: no arg 2' ) ;
	
	ok( ( $tuid1, $tuid2 ) = match_a_cache_file( '' ), 'match_a_cache_file: empty arg' ) ;
	ok( ! defined( $tuid1 ), 'match_a_cache_file: empty arg 1' ) ;
	ok( ! defined( $tuid2 ), 'match_a_cache_file: empty arg 2' ) ;
	
	ok( ( $tuid1, $tuid2 ) = match_a_cache_file( '000_000' ), 'match_a_cache_file: 000_000' ) ;
	ok( '000' eq $tuid1, 'match_a_cache_file: 000_000 1' ) ;
	ok( '000' eq $tuid2, 'match_a_cache_file: 000_000 2' ) ;
	
	ok( ( $tuid1, $tuid2 ) = match_a_cache_file( '123_456' ), 'match_a_cache_file: 123_456' ) ;
	ok( '123' eq $tuid1, 'match_a_cache_file: 123_456 1' ) ;
	ok( '456' eq $tuid2, 'match_a_cache_file: 123_456 2' ) ;

	ok( ( $tuid1, $tuid2 ) = match_a_cache_file( '/tmp/truc/123_456' ), 'match_a_cache_file: /tmp/truc/123_456' ) ;
	ok( '123' eq $tuid1, 'match_a_cache_file: /tmp/truc/123_456 1' ) ;
	ok( '456' eq $tuid2, 'match_a_cache_file: /tmp/truc/123_456 2' ) ;

	ok( ( $tuid1, $tuid2 ) = match_a_cache_file( '/lala123_456' ), 'match_a_cache_file: NO /lala123_456' ) ;
	ok( ! $tuid1, 'match_a_cache_file: /lala123_456 1' ) ;
	ok( ! $tuid2, 'match_a_cache_file: /lala123_456 2' ) ;

	ok( ( $tuid1, $tuid2 ) = match_a_cache_file( 'la123_456' ), 'match_a_cache_file: NO la123_456' ) ;
	ok( ! $tuid1, 'match_a_cache_file: la123_456 1' ) ;
	ok( ! $tuid2, 'match_a_cache_file: la123_456 2' ) ;

	return(  ) ;
}

sub clean_cache {
	my ( $cache_files_ref, $cache_1_2_ref, $h1_msgs_all_hash_ref, $h2_msgs_all_hash_ref )  = @_ ;
	
	$debugcache and print "Entering clean_cache\n";
	
	$debugcache and print map { "$_ -> " . $cache_1_2_ref->{ $_ } . "\n" } keys %$cache_1_2_ref ;
	foreach my $file ( @$cache_files_ref ) {
		$debugcache and print "$file\n" ;
		my ( $cache_uid1, $cache_uid2 ) = match_a_cache_file( $file ) ;
		$debugcache and print( "u1: $cache_uid1 u2: $cache_uid2 c12: ", $cache_1_2_ref->{ $cache_uid1 } || '', "\n") ;
#		  or ( ! exists( $cache_1_2_ref->{ $cache_uid1 } ) )
#		  or ( ! ( $cache_uid2 == $cache_1_2_ref->{ $cache_uid1 } ) )
		if ( ( not defined( $cache_uid1 ) )
		  or ( not defined( $cache_uid2 ) )
                  or ( not exists( $h1_msgs_all_hash_ref->{ $cache_uid1 } ) )
                  or ( not exists( $h2_msgs_all_hash_ref->{ $cache_uid2 } ) )
                ) {
			$debugcache and print "remove $file\n" ;
			unlink( $file ) or print "$!" ;
		}
	}
	
	$debugcache and print "Exiting clean_cache\n";
	return( 1 ) ;
}

sub tests_clean_cache {

	ok( ( not -d  'W/tmp/cache/G1/G2' or rmtree( 'W/tmp/cache/G1/G2' )), 'clean_cache: rmtree W/tmp/cache/G1/G2' ) ;
	ok( mkpath( 'W/tmp/cache/G1/G2' ), 'clean_cache: mkpath W/tmp/cache/G1/G2' ) ;
	
	my @test_files_cache = ( qw( 
	W/tmp/cache/G1/G2/100_200
	W/tmp/cache/G1/G2/101_201
	W/tmp/cache/G1/G2/120_220
	W/tmp/cache/G1/G2/142_242
	W/tmp/cache/G1/G2/143_243
	W/tmp/cache/G1/G2/177_277
	W/tmp/cache/G1/G2/177_377
	W/tmp/cache/G1/G2/177_777
	W/tmp/cache/G1/G2/155_255
	) ) ;
	ok( touch(@test_files_cache), 'clean_cache: touch W/tmp/cache/G1/G2/...' ) ;
	
	ok( -f 'W/tmp/cache/G1/G2/100_200', 'clean_cache: 100_200 before' );
	ok( -f 'W/tmp/cache/G1/G2/142_242', 'clean_cache: 142_242 before' );
	ok( -f 'W/tmp/cache/G1/G2/177_277', 'clean_cache: 177_277 before' );
	ok( -f 'W/tmp/cache/G1/G2/177_377', 'clean_cache: 177_377 before' );
	ok( -f 'W/tmp/cache/G1/G2/177_777', 'clean_cache: 177_777 before' );
	ok( -f 'W/tmp/cache/G1/G2/155_255', 'clean_cache: 155_255 before' );
	
	my $cache = {
		142 => 242,
		177 => 777,
	} ;
        
        my $all_1 = {
                142 => '',
                177 => '',
        } ;
        
        my $all_2 = {
                200 => '',
                242 => '',
                777 => '',
        } ;
	ok( clean_cache( \@test_files_cache, $cache, $all_1, $all_2 ), 'clean_cache: ' ) ;
	
	ok( ! -f 'W/tmp/cache/G1/G2/100_200', 'clean_cache: 100_200 after' );
	ok(   -f 'W/tmp/cache/G1/G2/142_242', 'clean_cache: 142_242 after' );
	ok( ! -f 'W/tmp/cache/G1/G2/177_277', 'clean_cache: 177_277 after' );
	ok( ! -f 'W/tmp/cache/G1/G2/177_377', 'clean_cache: 177_377 after' );
	ok(   -f 'W/tmp/cache/G1/G2/177_777', 'clean_cache: 177_777 after' );
	ok( ! -f 'W/tmp/cache/G1/G2/155_255', 'clean_cache: 155_255 after' );
	return(  ) ;
}

sub tests_clean_cache_2 {

	ok( ( not -d  'W/tmp/cache/G1/G2' or rmtree( 'W/tmp/cache/G1/G2' )), 'clean_cache_2: rmtree W/tmp/cache/G1/G2' ) ;
	ok( mkpath( 'W/tmp/cache/G1/G2' ), 'clean_cache_2: mkpath W/tmp/cache/G1/G2' ) ;
	
	my @test_files_cache = ( qw( 
	W/tmp/cache/G1/G2/100_200
	W/tmp/cache/G1/G2/101_201
	W/tmp/cache/G1/G2/120_220
	W/tmp/cache/G1/G2/142_242
	W/tmp/cache/G1/G2/143_243
	W/tmp/cache/G1/G2/177_277
	W/tmp/cache/G1/G2/177_377
	W/tmp/cache/G1/G2/177_777
	W/tmp/cache/G1/G2/155_255
	) ) ;
	ok( touch(@test_files_cache), 'clean_cache_2: touch W/tmp/cache/G1/G2/...' ) ;
	
	ok( -f 'W/tmp/cache/G1/G2/100_200', 'clean_cache_2: 100_200 before' );
	ok( -f 'W/tmp/cache/G1/G2/142_242', 'clean_cache_2: 142_242 before' );
	ok( -f 'W/tmp/cache/G1/G2/177_277', 'clean_cache_2: 177_277 before' );
	ok( -f 'W/tmp/cache/G1/G2/177_377', 'clean_cache_2: 177_377 before' );
	ok( -f 'W/tmp/cache/G1/G2/177_777', 'clean_cache_2: 177_777 before' );
	ok( -f 'W/tmp/cache/G1/G2/155_255', 'clean_cache_2: 155_255 before' );
	
	my $cache = {
		142 => 242,
		177 => 777,
	} ;
        
        my $all_1 = {
                100 => '',
                142 => '',
                177 => '',
        } ;
        
        my $all_2 = {
                200 => '',
                242 => '',
                777 => '',
        } ;
        
        
        
	ok( clean_cache( \@test_files_cache, $cache, $all_1, $all_2 ), 'clean_cache_2: ' ) ;
	
	ok(   -f 'W/tmp/cache/G1/G2/100_200', 'clean_cache_2: 100_200 after' );
	ok(   -f 'W/tmp/cache/G1/G2/142_242', 'clean_cache_2: 142_242 after' );
	ok( ! -f 'W/tmp/cache/G1/G2/177_277', 'clean_cache_2: 177_277 after' );
	ok( ! -f 'W/tmp/cache/G1/G2/177_377', 'clean_cache_2: 177_377 after' );
	ok(   -f 'W/tmp/cache/G1/G2/177_777', 'clean_cache_2: 177_777 after' );
	ok( ! -f 'W/tmp/cache/G1/G2/155_255', 'clean_cache_2: 155_255 after' );
	return(  ) ;
}



sub tests_mkpath {

        my $long_path = "123456789/" x 30 ;
	ok( (-d "W/tmp/tests/long/$long_path" or  mkpath( "W/tmp/tests/long/$long_path" )), 'tests_mkpath: mkpath > 300 char' ) ;
	ok( (-d "W/tmp/tests/long/$long_path" and rmtree( "W/tmp/tests/long/" )),           'tests_mkpath: rmtree > 300 char' ) ;
        ok( 1 == 1, 'tests_mkpath: 1 == 1' ) ;
	return(  ) ;
}

sub tests_touch {

	ok( (-d 'W/tmp/tests/' or  mkpath( 'W/tmp/tests/' )), 'tests_touch: mkpath W/tmp/tests/' ) ;
	ok( 1 == touch( 'W/tmp/tests/lala'), 'tests_touch: W/tmp/tests/lala') ;
	ok( 1 == touch( 'W/tmp/tests/\y'), 'tests_touch: W/tmp/tests/\y') ;
	ok( 0 == touch( '/aaa'), 'tests_touch: not /aaa') ;
	ok( 1 == touch( 'W/tmp/tests/lili', 'W/tmp/tests/lolo'), 'tests_touch: 2 files') ;
	ok( 0 == touch( 'W/tmp/tests/\y', '/aaa'), 'tests_touch: 2 files, 1 fails' ) ;
	return(  ) ;
}


sub touch {
	my @files = @_ ;
	my $failures = 0 ;
	
	foreach my $file ( @files ) {
		my  $fh = IO::File->new ;
		if ( $fh->open(">> $file" ) ) {
			$fh->close ;
		}else{
                	print "Could not open file $file in write/append mode\n" ;
                	$failures++ ;
                }
	}
	return( ! $failures );
}

sub tests_cache_folder {

	ok( '/path/fold1/fold2' eq cache_folder( '/path', 'fold1', 'fold2'), 'cache_folder: /path, fold1, fold2 -> /path/fold1/fold2' ) ;
	ok( '/pa_th/fold1/fold2' eq cache_folder( '/pa*th', 'fold1', 'fold2'), 'cache_folder: /pa*th, fold1, fold2 -> /path/fold1/fold2' ) ;
	ok( '/_p_a__th/fol_d1/fold2' eq cache_folder( '/>p<a|*th', 'fol*d1', 'fold2'), 'cache_folder: />p<a|*th, fol*d1, fold2 -> /path/fol_d1/fold2' ) ;
	return(  ) ;
}

sub cache_folder {
	my( $cache_dir, $h1_fold, $h2_fold ) = @_ ;
	
	my $sep_1 = $h1_sep || '/';
	my $sep_2 = $h2_sep || '/';
	
	#print "$cache_dir h1_fold $h1_fold sep1 $sep_1 h2_fold $h2_fold sep2 $sep_2\n";
	$h1_fold = convert_sep_to_slash( $h1_fold, $sep_1 ) ;
	$h2_fold = convert_sep_to_slash( $h2_fold, $sep_2 ) ;
        
        my $cache_folder = "$cache_dir/$h1_fold/$h2_fold" ;
        $cache_folder = filter_forbidden_characters( $cache_folder ) ;
	#print "cache_folder [$cache_folder]\n" ;
        return( $cache_folder ) ;
}

sub filter_forbidden_characters {
	my $string = shift ;
        
        $string =~ s{[\Q*|?:"<>\E]}{_}xg ;
	return ( $string ) ;
}

sub tests_filter_forbidden_characters {

	ok( 'a_b' eq filter_forbidden_characters( 'a_b' ), 'filter_forbidden_characters: a_b -> a_b' ) ;
	ok( 'a_b' eq filter_forbidden_characters( 'a*b' ), 'filter_forbidden_characters: a*b -> a_b' );
	ok( 'a_b' eq filter_forbidden_characters( 'a|b' ), 'filter_forbidden_characters: a|b -> a_b' );
	ok( 'a_b' eq filter_forbidden_characters( 'a?b' ), 'filter_forbidden_characters: a?*b -> a_b' );
	ok( 'a_______b' eq filter_forbidden_characters( 'a*|?:"<>b' ), 'filter_forbidden_characters: a*|?:"<>b -> a_______b' );
	return(  ) ;
}

sub convert_sep_to_slash {
	my ( $folder, $sep ) = @_ ;
	
	$folder =~ s{\Q$sep\E}{/}xg ;
	return( $folder ) ;
}

sub tests_convert_sep_to_slash {

	ok('' eq convert_sep_to_slash('', '/'), 'convert_sep_to_slash: no folder');
	ok('INBOX' eq convert_sep_to_slash('INBOX', '/'), 'convert_sep_to_slash: INBOX');
	ok('INBOX/foo' eq convert_sep_to_slash('INBOX/foo', '/'), 'convert_sep_to_slash: INBOX/foo');
	ok('INBOX/foo' eq convert_sep_to_slash('INBOX_foo', '_'), 'convert_sep_to_slash: INBOX_foo');
	ok('INBOX/foo/zob' eq convert_sep_to_slash('INBOX_foo_zob', '_'), 'convert_sep_to_slash: INBOX_foo_zob');
	ok('INBOX/foo' eq convert_sep_to_slash('INBOX.foo', '.'), 'convert_sep_to_slash: INBOX.foo');
	ok('INBOX/foo/hi' eq convert_sep_to_slash('INBOX.foo.hi', '.'), 'convert_sep_to_slash: INBOX.foo.hi');
	return(  ) ;
}


sub tests_regexmess {
	
	ok("blabla" eq regexmess("blabla"), "regexmess, no regexmess, nothing to do");

	@regexmess = ('lalala') ;
	ok( not( defined( regexmess("popopo") ) ), "regexmess, bad regex lalala") ;
	
	@regexmess = ('s/p/Z/g');
	ok("ZoZoZo" eq regexmess("popopo"), "regexmess, s/p/Z/g");
	
	@regexmess = 's{c}{C}gxms';
	ok("H1: abC\nH2: Cde\n\nBody abC" 
		   eq regexmess("H1: abc\nH2: cde\n\nBody abc"), 
	   "regexmess, c->C");
	   
	@regexmess = 's{\AFrom\ }{From:}gxms';
	ok(          '' 
	eq regexmess(''),
	'From mbox 1 add colon blank');
	
	ok(          'From:<tartanpion@machin.truc>' 
	eq regexmess('From <tartanpion@machin.truc>'),
	'From mbox 2 add colo');
	
	ok(          "\n" . 'From <tartanpion@machin.truc>' 
	eq regexmess("\n" . 'From <tartanpion@machin.truc>'),
	'From mbox 3 add colo');
	
	ok(          "From: zzz\n" . 'From <tartanpion@machin.truc>' 
	eq regexmess("From  zzz\n" . 'From <tartanpion@machin.truc>'),
	'From mbox 4 add colo');
	
	@regexmess = 's{\AFrom\ [^\n]*(\n)?}{}gxms';
	ok(          '' 
	eq regexmess(''),
	'From mbox 1 remove, blank');
	
	ok(          '' 
	eq regexmess('From <tartanpion@machin.truc>'),
	'From mbox 2 remove');
	
	ok(          "\n" . 'From <tartanpion@machin.truc>' 
	eq regexmess("\n" . 'From <tartanpion@machin.truc>'),
	'From mbox 3 remove');
	
	#print "[", regexmess("From  zzz\n" . 'From <tartanpion@machin.truc>'), "]";
	ok(          ""            . 'From <tartanpion@machin.truc>' 
	eq regexmess("From  zzz\n" . 'From <tartanpion@machin.truc>'),
	'From mbox 4 remove');
	

	ok(
<<'EOM'
Date: Sat, 10 Jul 2010 05:34:45 -0700
From:<tartanpion@machin.truc>

Hello,
Bye.
EOM
	eq regexmess(
<<'EOM'
From  zzz
Date: Sat, 10 Jul 2010 05:34:45 -0700
From:<tartanpion@machin.truc>

Hello,
Bye.
EOM
), 'From mbox 5 remove');


@regexmess = 's{\A(.*?(?! ^$))(^Disposition-Notification-To:.*?\n)}{$1}gxms';

	ok(
<<'EOM'
Date: Sat, 10 Jul 2010 05:34:45 -0700
From:<tartanpion@machin.truc>

Hello,
Bye.
EOM
	eq regexmess(
<<'EOM'
Date: Sat, 10 Jul 2010 05:34:45 -0700
Disposition-Notification-To: Gilles LAMIRAL <gilles.lamiral@laposte.net>
From:<tartanpion@machin.truc>

Hello,
Bye.
EOM
	),
	'regexmess: 1 Delete header Disposition-Notification-To:');

	ok(
<<'EOM'
Date: Sat, 10 Jul 2010 05:34:45 -0700
From:<tartanpion@machin.truc>

Hello,
Bye.
EOM
	eq regexmess(
<<'EOM'
Date: Sat, 10 Jul 2010 05:34:45 -0700
From:<tartanpion@machin.truc>
Disposition-Notification-To: Gilles LAMIRAL <gilles.lamiral@laposte.net>

Hello,
Bye.
EOM
),
	'regexmess: 2 Delete header Disposition-Notification-To:');

	ok(
<<'EOM'
Date: Sat, 10 Jul 2010 05:34:45 -0700
From:<tartanpion@machin.truc>

Hello,
Bye.
EOM
	eq regexmess(
<<'EOM'
Disposition-Notification-To: Gilles LAMIRAL <gilles.lamiral@laposte.net>
Date: Sat, 10 Jul 2010 05:34:45 -0700
From:<tartanpion@machin.truc>

Hello,
Bye.
EOM
),
	'regexmess: 3 Delete header Disposition-Notification-To:');

	ok(
<<'EOM'
Date: Sat, 10 Jul 2010 05:34:45 -0700
From:<tartanpion@machin.truc>

Disposition-Notification-To: Gilles LAMIRAL <gilles.lamiral@laposte.net>
Bye.
EOM
	eq regexmess(
<<'EOM'
Disposition-Notification-To: Gilles LAMIRAL <gilles.lamiral@laposte.net>
Date: Sat, 10 Jul 2010 05:34:45 -0700
From:<tartanpion@machin.truc>

Disposition-Notification-To: Gilles LAMIRAL <gilles.lamiral@laposte.net>
Bye.
EOM
),
	'regexmess: 4 Delete header Disposition-Notification-To:');



return(  ) ;

}

sub regexmess {
	my ($string) = @_ ;
	foreach my $regexmess ( @regexmess ) {
		$debug and print "eval \$string =~ $regexmess\n" ;
		my $ret = eval( "\$string =~ $regexmess ; 1" ) ;
                #print "eval [$ret]\n" ;
                if ( ( not $ret ) or $@ ) {
			print "Error: eval regexmess '$regexmess': $@" ;
                        return( undef ) ;
                }
	}
	return( $string ) ;
}


sub tests_bytes_display_string {

	ok(    '0.000 KiB' eq bytes_display_string(       0 ), 'bytes_display_string:       0' ) ;
	ok(    '0.001 KiB' eq bytes_display_string(       1 ), 'bytes_display_string:       1' ) ;
	ok(    '0.010 KiB' eq bytes_display_string(      10 ), 'bytes_display_string:      10' ) ;
	ok(    '1.000 MiB' eq bytes_display_string( 1048575 ), 'bytes_display_string: 1048575' ) ;
	ok(    '1.000 MiB' eq bytes_display_string( 1048576 ), 'bytes_display_string: 1048576' ) ;

	ok(    '1.000 GiB' eq bytes_display_string( 1073741823 ), 'bytes_display_string: 1073741823 ' ) ;
	ok(    '1.000 GiB' eq bytes_display_string( 1073741824 ), 'bytes_display_string: 1073741824 ' ) ;

	ok(    '1.000 TiB' eq bytes_display_string( 1099511627775 ), 'bytes_display_string: 1099511627775' ) ;
	ok(    '1.000 TiB' eq bytes_display_string( 1099511627776 ), 'bytes_display_string: 1099511627776' ) ;

	ok(    '1.000 PiB' eq bytes_display_string( 1125899906842623 ), 'bytes_display_string: 1125899906842623' ) ;
	ok(    '1.000 PiB' eq bytes_display_string( 1125899906842624 ), 'bytes_display_string: 1125899906842624' ) ;

	ok( '1024.000 PiB' eq bytes_display_string( 1152921504606846975 ), 'bytes_display_string: 1152921504606846975' ) ;
	ok( '1024.000 PiB' eq bytes_display_string( 1152921504606846976 ), 'bytes_display_string: 1152921504606846976' ) ;

	ok( '1048576.000 PiB' eq bytes_display_string( 1180591620717411303424 ), 'bytes_display_string: 1180591620717411303424' ) ;
        
        #print  bytes_display_string( 1180591620717411303424 ), "\n" ;
	return(  ) ;
}

sub bytes_display_string { 
	my ( $bytes ) = @_ ;

	my $readable_value = '' ;
       
	SWITCH: {
        	if ( abs( $bytes ) < ( 1000 * 1024 ) ) {
        		$readable_value = sprintf( "%.3f KiB", $bytes / 1024) ; 
                	last SWITCH ;
        	}
        	if ( abs( $bytes ) < ( 1000 * 1024 * 1024 ) ) {
        		$readable_value = sprintf( "%.3f MiB", $bytes / (1024 * 1024) ) ;
        	        last SWITCH ;
        	}
        	if ( abs( $bytes ) < ( 1000 * 1024 * 1024 * 1024) ) {
			$readable_value = sprintf("%.3f GiB", $bytes / (1024 * 1024 * 1024) ) ;
        	        last SWITCH ;
        	}
        	if ( abs( $bytes ) < ( 1000 * 1024 * 1024 * 1024 * 1024) ) {
			$readable_value = sprintf( "%.3f TiB", $bytes / (1024 * 1024 * 1024 * 1024) ) ;
        	        last SWITCH ;
        	} else {
			$readable_value = sprintf( "%.3f PiB", $bytes / (1024 * 1024 * 1024 * 1024 * 1024) ) ;
        	}
		# if you have exabytes (EiB) of email to transfer, you have too much email
	}
        #print "$bytes = $readable_value\n" ;
        return( $readable_value ) ;
}

sub stats {
	$timeend = time(  );
	my $timediff = $timeend - $timestart ;

	my $timeend_str   = localtime( $timeend ) ;
        
	my $memory_consumption = memory_consumption(  ) || 0 ;
	my $memory_ratio = ($max_msg_size_in_bytes) ?  
		sprintf('%.1f', $memory_consumption / $max_msg_size_in_bytes) : "NA" ;

	my $host1_reconnect_count = $imap1->Reconnect_counter() || 0 ;
	my $host2_reconnect_count = $imap2->Reconnect_counter() || 0 ;

	print   "++++ Statistics\n" ;
	print   "Transfer started on               : $timestart_str\n";
	print   "Transfer ended on                 : $timeend_str\n";
	printf( "Transfer time                     : %.1f sec\n", $timediff ) ;
	print   "Messages transferred              : $nb_msg_transferred ";
	print   "(could be $nb_msg_skipped_dry_mode without dry mode)" if ($dry);
	print   "\n";
	print   "Messages skipped                  : $nb_msg_skipped\n";
	print   "Messages found duplicate on host1 : $h1_nb_msg_duplicate\n";
	print   "Messages found duplicate on host2 : $h2_nb_msg_duplicate\n";
	print   "Messages void (noheader) on host1 : $h1_nb_msg_noheader\n";
	print   "Messages void (noheader) on host2 : $h2_nb_msg_noheader\n";
	print   "Messages deleted on host1         : $h1_nb_msg_deleted\n";
	print   "Messages deleted on host2         : $h2_nb_msg_deleted\n";
        printf( "Total bytes transferred           : %d (%s)\n",
                $total_bytes_transferred,
                bytes_display_string($total_bytes_transferred));
        printf( "Total bytes duplicate host1       : %d (%s)\n",
                $h1_total_bytes_duplicate,
                bytes_display_string($h1_total_bytes_duplicate));
        printf( "Total bytes duplicate host2       : %d (%s)\n",
                $h2_total_bytes_duplicate,
                bytes_display_string($h2_total_bytes_duplicate));
        printf( "Total bytes skipped               : %d (%s)\n",
                $total_bytes_skipped,
                bytes_display_string($total_bytes_skipped));
        printf( "Total bytes error                 : %d (%s)\n",
                $total_bytes_error,
                bytes_display_string($total_bytes_error));
	$timediff ||= 1; # No division per 0
	printf ("Message rate                      : %.1f messages/s\n", $nb_msg_transferred / $timediff);
	printf ("Average bandwidth rate            : %.1f KiB/s\n", $total_bytes_transferred / 1024 / $timediff);
	print   "Reconnections to host1            : $host1_reconnect_count\n";
	print   "Reconnections to host2            : $host2_reconnect_count\n";
	printf ("Memory consumption                : %.1f MiB\n", $memory_consumption / 1024 / 1024);
	print   "Biggest message                   : $max_msg_size_in_bytes bytes\n";
#	print   "Memory/biggest message ratio      : $memory_ratio\n";
        if ( $foldersizesatend and $foldersizes ) {
	printf("Initial difference host2 - host1  : %s messages, %s bytes (%s)\n", $h2_nb_msg_start - $h1_nb_msg_at_start,
                                                        $h2_bytes_start  - $h1_bytes_start,
                                                        bytes_display_string( $h2_bytes_start  - $h1_bytes_start ) ) ;
	printf("Final   difference host2 - host1  : %s messages, %s bytes (%s)\n", $h2_nb_msg_end   - $h1_nb_msg_end,
                                                        $h2_bytes_end    - $h1_bytes_end,
                                                        bytes_display_string( $h2_bytes_end    - $h1_bytes_end ) ) ;
        }
	print   "Detected $nb_errors errors\n\n" ;

	print   $warn_release, "\n" ;
	print   thank_author();
	return(  ) ;
}

sub thank_author {
	return("Homepage: http://imapsync.lamiral.info/\n");
}


sub load_modules {

	if ( $ssl1 or $ssl2 or $tls1 or $tls2 ) {
        	require IO::Socket::SSL ;
                #$IO::Socket::SSL::DEBUG = 4 ;
        }

        require Term::ReadKey if (
	       ((not($password1 or $passfile1)) 
	    or (not($password2 or $passfile2)))
	and (not $help));

	#require Data::Dumper if ($debug);
	return(  ) ;
}



sub parse_header_msg {
	my ($imap, $m_uid, $s_heads, $s_fir, $side, $s_hash) = @_;
	
	my $head = $s_heads->{$m_uid};
	my $headnum =  scalar(keys(%$head));
	$debug and print "$side uid $m_uid head nb pass one: ", $headnum, "\n";
	
	if ( ( ! $headnum ) and ( $wholeheaderifneeded ) ){
		print "$side uid $m_uid no header by parse_headers so taking whole header with BODY.PEEK[HEADER]\n" ;
		$imap->fetch($m_uid, "BODY.PEEK[HEADER]");
		my $whole_header = $imap->_transaction_literals;
		
                #print $whole_header;
                $head = decompose_header( $whole_header ) ;
                
                $headnum =  scalar( keys( %$head ) ) ;
	        $debug and print "$side uid $m_uid head nb pass two: ", $headnum, "\n";
	}

        #require Data::Dumper ;
        #print Data::Dumper->Dump( [ $head, \%useheader ] ) ;

	my $headstr ;
        
        $headstr = header_construct( $head, $side, $m_uid ) ;
		
	if ( ( ! $headstr) and ( $addheader ) and ( $side eq "Host1" )){
        	my $header = add_header( $m_uid ) ;
		print "Host1 uid $m_uid no header found so adding our own [$header]\n";
		$headstr .= uc( $header ) ;
		$s_fir->{$m_uid}->{"NO_HEADER"} = 1;
	}

	return(  ) if ( ! $headstr ) ;
	
	my $size  = $s_fir->{$m_uid}->{"RFC822.SIZE"};
	my $flags = $s_fir->{$m_uid}->{"FLAGS"};
	my $idate = $s_fir->{$m_uid}->{"INTERNALDATE"};
	$size = length( $headstr ) unless ( $size ) ;
	my $m_md5 = md5_base64( $headstr ) ;
	$debug and print "$side uid $m_uid sig $m_md5 size $size idate $idate\n";
	my $key;
        if ($skipsize) {
                $key = "$m_md5";
        }
	else {
                $key = "$m_md5:$size";
        }
	# 0 return code is used to identify duplicate message hash
	return 0 if exists $s_hash->{"$key"};
	$s_hash->{"$key"}{'5'} = $m_md5;
	$s_hash->{"$key"}{'s'} = $size;
	$s_hash->{"$key"}{'D'} = $idate;
	$s_hash->{"$key"}{'F'} = $flags;
	$s_hash->{"$key"}{'m'} = $m_uid;

	return( 1 ) ;
}

sub header_construct {

	my( $head, $side, $m_uid ) = @_ ;
        
        my $headstr ;
	foreach my $h ( sort keys( %$head ) ) {
                next if ( not exists( $useheader{ uc( $h ) } )
                      and not exists( $useheader{ 'ALL' } )
                ) ;
		foreach my $val ( sort @{$head->{$h}} ) {
                	
                        my $H = header_line_normalize( $h, $val ) ;
                                                
			# show stuff in debug mode
			$debug and print "$side uid $m_uid header [$H]", "\n" ;
			
			if ($skipheader and $H =~ m/$skipheader/xi) {
				$debug and print "$side uid $m_uid skipping header [$H]\n" ;
				next ;
			}
			$headstr .= "$H" ;
		}
	}
	return( $headstr ) ;
}


sub header_line_normalize {
	my( $header_key,  $header_val ) = @_ ;
	
        # no 8-bit data in headers !
        $header_val =~ s/[\x80-\xff]/X/xog;

        # change tabulations to space (Gmail bug on with "Received:" on multilines)
        $header_val =~ s/\t/\ /xg ;

        # remove the first blanks ( dbmail bug? )
        $header_val =~ s/^\s*//xo;

        # remove successive blanks ( Mailenable does it )
        $header_val =~ s/\s+/ /gxo;

        # remove Message-Id value domain part ( Mailenable changes it )
        if ( ( $messageidnodomain ) and ( 'MESSAGE-ID' eq uc( $header_key ) ) ) { $header_val =~ s/^([^@]+).*$/$1/xo ; }

        # and uppercase header line 
        # (dbmail and dovecot)

        my $header_line = uc("$header_key: $header_val") ;

	return( $header_line ) ;

}

sub tests_header_line_normalize {

	ok( ': ' eq header_line_normalize( '', '' ), 'header_line_normalize: empty args' ) ;
	ok( 'HHH: VVV' eq header_line_normalize( 'hhh', 'vvv' ), 'header_line_normalize: hhh vvv ' ) ;
	ok( 'HHH: VVV' eq header_line_normalize( 'hhh', '  vvv' ), 'header_line_normalize: remove first blancs' ) ;
	ok( 'HHH: AA BB CCC ' eq header_line_normalize( 'hhh', 'aa  bb   ccc  ' ), 'header_line_normalize: remove succesive blancs' ) ;
	ok( 'HHH: VVV XX YY' eq header_line_normalize( 'hhh', "vvv\t\txx\tyy" ), 'header_line_normalize: tabs' ) ;
	ok( 'HHH: XABX' eq header_line_normalize( 'hhh', "\x80AB\xff" ), 'header_line_normalize: 8bit' ) ;

	return(  ) ;
}


sub firstline {
        # extract the first line of a file (without \n)

        my($file) = @_ ;
        my $line  = "" ;
        
        open( my $FILE, '<', $file ) or die_clean( "error [$file]: $! " ) ;
        chomp( $line = <$FILE> ) ;
        close $FILE ;
        $line = ( $line ) ? $line: "error !EMPTY! [$file]" ;
        return $line ;
}


sub file_to_string {
	my( $file ) = @_ ;
	my @string ;
	open( my $FILE, '<', $file )  or die_clean( "error [$file]: $! " ) ;
	@string = <$FILE> ;
	close $FILE ;
	return join('', @string) ;
}


sub string_to_file {
	my($string, $file) = @_;
	sysopen(FILE, $file,O_WRONLY|O_TRUNC|O_CREAT, 0600) or die_clean("$! $file");
	print FILE $string;
	close FILE;
	return(  ) ;
}

sub tests_is_a_release_number {
	ok(is_a_release_number(1.351), 'is_a_release_number 1.351');
	ok(is_a_release_number(42.4242), 'is_a_release_number 42.4242');
	ok(is_a_release_number(imapsync_version()), 'is_a_release_number imapsync_version()');
	ok(! is_a_release_number('blabla' ), '! is_a_release_number blabla');
	return(  ) ;
}

sub is_a_release_number {
	my $number = shift;
	
	return( $number =~ m{\d\.\d+}xo ) ;
}

sub check_last_release {

	my $public_release = not_long_imapsync_version_public(  ) ;
	#print "check_last_release: [$public_release]\n" ;
	return('unknown') if ($public_release eq 'unknown');
	return('timeout') if ($public_release eq 'timeout');
	return('unknown') if (! is_a_release_number($public_release));
	
	my $imapsync_here  = imapsync_version();
	
	if ($public_release > $imapsync_here) {
		return("New imapsync release $public_release available");
	}else{
		return("This current imapsync is up to date");
	}
}

sub imapsync_version  {
	my $rcs_imapsync = '$Id: imapsync,v 1.564 2013/08/18 19:28:47 gilles Exp gilles $ ' ;
        my $imapsync_version ;
        
	if ( $rcs_imapsync =~ m{,v\s+(\d+\.\d+)}xo ) {
		$imapsync_version = $1
        } else {
        	$imapsync_version = "UNKNOWN" ;
        }
	return( $imapsync_version ) ;
}

sub tests_imapsync_basename {

	ok('imapsync' eq imapsync_basename(), 'imapsync_basename: imapsync');
	ok('blabla'   ne imapsync_basename(), '! imapsync_basename: blabla');
	return(  ) ;
}

sub imapsync_basename {

	return basename($0);

}

sub imapsync_version_public {
	
	my $local_version = imapsync_version();
	my $imapsync_basename = imapsync_basename();
	my $agent_info = "$OSNAME system, perl " 
		. sprintf("%vd", $PERL_VERSION) 
		. ", Mail::IMAPClient $Mail::IMAPClient::VERSION"
		. " $imapsync_basename";
	my $sock = IO::Socket::INET->new(
		PeerAddr => 'imapsync.lamiral.info',
		PeerPort => '80',
		Proto => 'tcp' 
                ) ;
	return( 'unknown' ) if not $sock ;
	print $sock
		"GET /prj/imapsync/VERSION HTTP/1.0\n",
		"User-Agent: imapsync/$local_version ($agent_info)\n",
		"Host: ks.lamiral.info\n\n";
	my @line = <$sock>;
	close($sock);
	my $last_release = $line[-1];
	chomp($last_release);
	return($last_release);
}

sub not_long_imapsync_version_public {
	#print "Entering not_long_imapsync_version_public\n";

	my $val;
	
	# Doesn't work with gethostbyname (see perlipc)
	#local $SIG{ALRM} = sub { die "alarm\n" };
	
	if ('MSWin32' eq $OSNAME) {
		local $SIG{ALRM} = sub { die "alarm\n" };
	}else{
	
        	POSIX::sigaction(SIGALRM,
                         POSIX::SigAction->new(sub { croak "alarm" }))
        		or print "Error setting SIGALRM handler: $!\n";
	}
	
	my $ret = eval {
		alarm(3) ;
		{
			$val = imapsync_version_public(  ) ;
                        #sleep 4 ;
			#print "End of imapsync_version_public\n" ;
		}
		alarm(0) ;
                1 ;
	} ;
        #print "eval [$ret]\n" ;
	if ( ( not $ret ) or $@ ) {
		#print "$@";
		if ($@ =~ /alarm/) {
		# timed out
			return('timeout');
		}else{
			alarm(0);
			return('unknown'); # propagate unexpected errors
		}
	}else {
	# Good!
		return($val);
	}
}

sub localhost_info {
	
	my($infos) = join("", 
	    "Here is a [$OSNAME] system (", 
	    join(" ", 
	         uname(),
	         ),
                 ")\n",
	         "With perl ", 
	         sprintf("%vd", $PERL_VERSION),
	         " Mail::IMAPClient  $Mail::IMAPClient::VERSION",
            ) ;
	return($infos);
}

sub memory_consumption {
	# memory consumed by imapsync until now in bytes
	return( ( memory_consumption_of_pids(  ) )[0] );
}

sub memory_consumption_of_pids {

	my @pid = @_;
	@pid = (@pid) ? @pid : ($PROCESS_ID) ;
	
	#print "PIDs: @PID\n";
	my @val;
	if ('MSWin32' eq $OSNAME) {
		@val = memory_consumption_of_pids_win32(@pid);
	}else{
		# Unix
		#my @ps = qx{ ps -o vsz -p @pid };
                my @ps = backtick( "ps -o vsz -p @pid" ) ;
		shift @ps; # First line is column name "VSZ"
		chomp @ps; 
		# convert to 
		@val = map { $_ * 1024 } @ps;
	}
	return( @val ) ;
}

sub memory_consumption_of_pids_win32 {
	# Windows
	my @PID = @_;
	my %PID;
	# hash of pids as key values
	map { $PID{$_}++ } @PID;
	
	# Does not work but should reading the tasklist documentation
	#@ps = qx{ tasklist /FI "PID eq @PID" };
	
	#my @ps = qx{ tasklist /NH /FO CSV } ;
        my @ps = backtick( 'tasklist /NH /FO CSV' ) ;
	#print "-" x 80, "\n", @ps, "-" x 80, "\n";
	my @val;
	foreach my $line (@ps) {
		my($name, $pid, $mem) = (split(',', $line))[0,1,4];
		next if (! $pid);
		#print "[$name][$pid][$mem]";
		if ($PID{remove_qq($pid)}) {
			#print "MATCH !\n";
			chomp($mem);
			$mem = remove_qq($mem);
			$mem = remove_Ko($mem);
			$mem = remove_not_num($mem);
			#print "[$mem]\n";
			push(@val, $mem * 1024);
		}
	}
	return(@val);
}

sub backtick {
	my $command = shift ;
	my ($writer, $reader, $err);
        open3( $writer, $reader, $err, $command ) ;
        my @output = <$reader>;  #Output here
        #my @errors = <$err>;    #Errors here, instead of the console
        $debugdev and print @output ;
        return( @output ) ;
}

sub tests_backtick {
        
        my @output ;
        @output = backtick( "echo Hello World!" ) ;
        ok( "Hello World!\n" eq $output[0], 'backtick: echo Hello World!' ) ;
        
        @output = backtick( "echo Hello\necho World!" ) ;
        ok( "Hello\n" eq $output[0], 'backtick: echo Hello; echo World!' ) ;
        ok( "World!\n" eq $output[1], 'backtick: echo Hello; echo World!' ) ;
        #print @output ;
        if ('MSWin32' ne $OSNAME) {
        	my @output_1 = backtick( 'ls /' ) ;
                #my @output_2 = `ls /` ;
                #ok( 0 == compare_lists( \@output_1, \@output_2 ), 'backtick: ls /' ) ;
        }
        return(  ) ;
}

sub remove_not_num {
	
	my $string = shift;
	$string =~ tr/0-9//cd;
	#print "tr [$string]\n";
	return($string);
}

sub tests_remove_not_num {

	ok('123' eq remove_not_num(123), 'remove_not_num( 123 )');
	ok('123' eq remove_not_num('123'), "remove_not_num( '123' )");
	ok('123' eq remove_not_num('12 3'), "remove_not_num( '12 3' )");
	ok('123' eq remove_not_num('a 12 3 Ko'), "remove_not_num( 'a 12 3 Ko' )");
	return(  ) ;
}

sub remove_Ko {
	my $string = shift;
	if ($string =~ /^(.*)\sKo$/xo) {
		return($1);
	}else{
		return($string);
	}
}

sub remove_qq {
	my $string = shift;
	if ($string =~ /^"(.*)"$/xo) {
		return($1);
	}else{
		return($string);
	}
}

sub memory_consumption_ratio {

	my ($base) = @_;
	$base ||= 1;
	my $consu = memory_consumption();
	return($consu / $base);
}

sub tests_memory_consumption {

	ok(print join("\n", memory_consumption_of_pids()), " memory_consumption_of_pids\n");
	ok(print join("\n", memory_consumption_of_pids('1')), " memory_consumption_of_pids 1\n");
	ok(print join("\n", memory_consumption_of_pids('1', $PROCESS_ID)), " memory_consumption_of_pids 1 $PROCESS_ID\n");

	ok(print memory_consumption_ratio(), " memory_consumption_ratio \n");
	ok(print memory_consumption_ratio(1), " memory_consumption_ratio 1\n");
	ok(print memory_consumption_ratio(10), " memory_consumption_ratio 10\n");
	
	ok(print memory_consumption(), " memory_consumption\n");
	return(  ) ;
}

sub good_date {
        # two incoming formats:
        # header    Tue, 24 Aug 2010 16:00:00 +0200
	# internal       24-Aug-2010 16:00:00 +0200
	
        # outgoing format: internal date format
        #   24-Aug-2010 16:00:00 +0200
	
    my $d = shift ;
    return ('') if not defined($d);

	SWITCH: {
    	if ( $d =~ m{(\d?)(\d-...-\d{4})(\s\d{2}:\d{2}:\d{2})(\s(?:\+|-)\d{4})?}xo ) {
		#print "internal: [$1][$2][$3][$4]\n" ;
		my ($day_1, $date_rest, $hour, $zone) = ($1,$2,$3,$4) ;
		$day_1 = '0' if ($day_1 eq '') ;
		$zone  = ' +0000'  if not defined($zone) ;
		$d = $day_1 . $date_rest . $hour . $zone ;
                last SWITCH ;
        }
        
	if ($d =~ m{(?:\w{3,},\s)?(\d{1,2}),?\s+(\w{3,})\s+(\d{2,4})\s+(\d{1,2})(?::|\.)(\d{1,2})(?:(?::|\.)(\d{1,2}))?\s*((?:\+|-)\d{4})?}xo ) {
        	# Handles any combination of following formats
                # Tue, 24 Aug 2010 16:00:00 +0200 -- Standard
                # 24 Aug 2010 16:00:00 +0200 -- Missing Day of Week
                # Tue, 24 Aug 97 16:00:00 +0200 -- Two digit year
                # Tue, 24 Aug 1997 16.00.00 +0200 -- Periods instead of colons 
                # Tue, 24 Aug 1997  16:00:00 +0200 -- Extra whitespace between year and hour
                # Tue, 24 Aug 1997 6:5:2 +0200 -- Single digit hour, min, or second
                # Tue, 24, Aug 1997 16:00:00 +0200 -- Extra comma

                #print "header: [$1][$2][$3][$4][$5][$6][$7][$8]\n";
                my ($day, $month, $year, $hour, $min, $sec, $zone) = ($1,$2,$3,$4,$5,$6,$7,$8);
                $year = '19' . $year if length($year) == 2 && $year =~ m/^[789]/xo;
                $year = '20' . $year if length($year) == 2;
                 
                $month = substr $month, 0, 3 if length($month) > 4;
                $day = sprintf("%02d", $day);
                $hour = sprintf("%02d", $hour);
                $min = sprintf("%02d", $min);
                $sec  = '00' if not defined($sec);
                $sec = sprintf("%02d", $sec);
                $zone  = '+0000' if not defined($zone);
                $d = "$day-$month-$year $hour:$min:$sec $zone";
		last SWITCH ;
	}
    
	if ($d =~ m{(?:.{3})\s(...)\s+(\d{1,2})\s(\d{1,2}):(\d{1,2}):(\d{1,2})\s(?:\w{3})?\s?(\d{4})}xo ) {
        	# Handles any combination of following formats
                # Sun Aug 20 11:55:09 2006
                # Wed Jan 24 11:58:38 MST 2007
                # Wed Jan  2 08:40:57 2008

                #print "header: [$1][$2][$3][$4][$5][$6]\n";
                my ($month, $day, $hour, $min, $sec, $year) = ($1,$2,$3,$4,$5,$6);
                $day = sprintf("%02d", $day);
                $hour = sprintf("%02d", $hour);
                $min = sprintf("%02d", $min);
                $sec = sprintf("%02d", $sec);
                $d = "$day-$month-$year $hour:$min:$sec +0000";
		last SWITCH ;
	}

        if ($d =~ m{(\d{2})/(\d{2})/(\d{2})\s(\d{2}):(\d{2}):(\d{2})}xo ) {
                # Handles the following format
                # 02/06/09 22:18:08 -- Generated by AVTECH TemPageR devices

                #print "header: [$1][$2][$3][$4][$5][$6]\n";
                my ($month, $day, $year, $hour, $min, $sec) = ($1,$2,$3,$4,$5,$6);
                $year = '20' . $year;
                my %num2mon = qw(01 Jan 02 Feb 03 Mar 04 Apr 05 May 06 Jun 07 Jul 08 Aug 09 Sep 10 Oct 11 Nov 12 Dec);
                $month = $num2mon{$month};
                $d = "$day-$month-$year $hour:$min:$sec +0000";
		last SWITCH ;
	}
    
	if ($d =~ m{\w{6,},\s(\w{3})\w+\s+(\d{1,2}),\s(\d{4})\s(\d{2}):(\d{2})\s(AM|PM)}xo ) {
        	# Handles the following format
                # Saturday, December 14, 2002 05:00 PM - KBtoys.com order confirmations

                my ($month, $day, $year, $hour, $min, $apm) = ($1,$2,$3,$4,$5,$6);

                $hour += 12 if $apm eq 'PM';
                $day = sprintf("%02d", $day);
                $d = "$day-$month-$year $hour:$min:00 +0000";
                last SWITCH ;
	}
    
	if ($d =~ m{(\w{3})\s(\d{1,2})\s(\d{4})\s(\d{2}):(\d{2}):(\d{2})\s((?:\+|-)\d{4})}xo ) {
        	# Handles the following format
                # Saturday, December 14, 2002 05:00 PM - jr.com order confirmations

                my ($month, $day, $year, $hour, $min, $sec, $zone) = ($1,$2,$3,$4,$5,$6,$7);

                $day = sprintf("%02d", $day);
                $d = "$day-$month-$year $hour:$min:$sec $zone";
                last SWITCH ;
	}
    
	if ($d =~ m{(\d{1,2})-(\w{3})-(\d{4})}xo ) {
        	# Handles the following format
                # 21-Jun-2001 - register.com domain transfer email circa 2001

                my ($day, $month, $year) = ($1,$2,$3);
                $day = sprintf("%02d", $day);
                $d = "$day-$month-$year 11:11:11 +0000";
		last SWITCH ;
	}
        
    	# unknown or unmatch => return same string
    	return($d);
    }
    
    $d = qq("$d") ;
    return( $d ) ;
} 


sub tests_good_date {

	ok('' eq good_date(), 'good_date no arg');
	ok('"24-Aug-2010 16:00:00 +0200"' eq good_date('24-Aug-2010 16:00:00 +0200'), 'good_date internal 2digit zone');
	ok('"24-Aug-2010 16:00:00 +0000"' eq good_date('24-Aug-2010 16:00:00'), 'good_date internal 2digit no zone');
	ok('"01-Sep-2010 16:00:00 +0200"' eq good_date( '1-Sep-2010 16:00:00 +0200'), 'good_date internal SP 1digit');
	ok('"24-Aug-2010 16:00:00 +0200"' eq good_date('Tue, 24 Aug 2010 16:00:00 +0200'), 'good_date header 2digit zone');
	ok('"01-Sep-2010 16:00:00 +0000"' eq good_date('Wed, 1 Sep 2010 16:00:00'), 'good_date header SP 1digit zone');
	ok('"01-Sep-2010 16:00:00 +0200"' eq good_date('Wed, 1 Sep 2010 16:00:00 +0200'), 'good_date header SP 1digit zone');
	ok('"01-Sep-2010 16:00:00 +0200"' eq good_date('Wed, 1 Sep 2010 16:00:00 +0200 (CEST)'), 'good_date header SP 1digit zone');
        ok('"06-Feb-2009 22:18:08 +0000"' eq good_date('02/06/09 22:18:08'), 'good_date header TemPageR');
        ok('"02-Jan-2008 08:40:57 +0000"' eq good_date('Wed Jan  2 08:40:57 2008'), 'good_date header dice.com support 1digit day');
        ok('"20-Aug-2006 11:55:09 +0000"' eq good_date('Sun Aug 20 11:55:09 2006'), 'good_date header dice.com support 2digit day');
        ok('"24-Jan-2007 11:58:38 +0000"' eq good_date('Wed Jan 24 11:58:38 MST 2007'), 'good_date header status-now.com');
        ok('"24-Aug-2010 16:00:00 +0200"' eq good_date('24 Aug 2010 16:00:00 +0200'), 'good_date header missing date of week');
        ok('"24-Aug-2067 16:00:00 +0200"' eq good_date('Tue, 24 Aug 67 16:00:00 +0200'), 'good_date header 2digit year');
        ok('"24-Aug-1977 16:00:00 +0200"' eq good_date('Tue, 24 Aug 77 16:00:00 +0200'), 'good_date header 2digit year');
        ok('"24-Aug-1987 16:00:00 +0200"' eq good_date('Tue, 24 Aug 87 16:00:00 +0200'), 'good_date header 2digit year');
        ok('"24-Aug-1997 16:00:00 +0200"' eq good_date('Tue, 24 Aug 97 16:00:00 +0200'), 'good_date header 2digit year');
        ok('"24-Aug-2004 16:00:00 +0200"' eq good_date('Tue, 24 Aug 04 16:00:00 +0200'), 'good_date header 2digit year');
        ok('"24-Aug-1997 16:00:00 +0200"' eq good_date('Tue, 24 Aug 1997 16.00.00 +0200'), 'good_date header period time sep');
        ok('"24-Aug-1997 16:00:00 +0200"' eq good_date('Tue, 24 Aug 1997  16:00:00 +0200'), 'good_date header extra white space type1');
        ok('"24-Aug-1997 05:06:02 +0200"' eq good_date('Tue, 24 Aug 1997 5:6:2 +0200'), 'good_date header 1digit time vals');
        ok('"24-Aug-1997 05:06:02 +0200"' eq good_date('Tue, 24, Aug 1997 05:06:02 +0200'), 'good_date header extra commas');
        ok('"01-Oct-2003 12:45:24 +0000"' eq good_date('Wednesday, 01 October 2003 12:45:24 CDT'), 'good_date header no abbrev');
        ok('"11-Jan-2005 17:58:27 -0500"' eq good_date('Tue,  11  Jan 2005 17:58:27 -0500'), 'good_date extra white space');
        ok('"18-Dec-2002 15:07:00 +0000"' eq good_date('Wednesday, December 18, 2002 03:07 PM'), 'good_date kbtoys.com orders');
        ok('"16-Dec-2004 02:01:49 -0500"' eq good_date('Dec 16 2004 02:01:49 -0500'), 'good_date jr.com orders');
        ok('"21-Jun-2001 11:11:11 +0000"' eq good_date('21-Jun-2001'), 'good_date register.com domain transfer');

	return(  ) ;
}


sub tests_list_keys_in_2_not_in_1 {

	my @list;
	ok( ! list_keys_in_2_not_in_1( {}, {}), 'list_keys_in_2_not_in_1: {} {}');
	ok( 0 == compare_lists( [], [ list_keys_in_2_not_in_1( {}, {} ) ] ), 'list_keys_in_2_not_in_1: {} {}');
	ok( 0 == compare_lists( ['a','b'], [ list_keys_in_2_not_in_1( {}, {'a' => 1, 'b' => 1}) ]), 'list_keys_in_2_not_in_1: {} {a, b}');
	ok( 0 == compare_lists( ['b'],     [ list_keys_in_2_not_in_1( {'a' => 1}, {'a' => 1, 'b' => 1}) ]), 'list_keys_in_2_not_in_1: {a} {a, b}');
	ok( 0 == compare_lists( [],        [ list_keys_in_2_not_in_1( {'a' => 1, 'b' => 1}, {'a' => 1, 'b' => 1}) ]), 'list_keys_in_2_not_in_1: {a, b} {a, b}');
	ok( 0 == compare_lists( [],        [ list_keys_in_2_not_in_1( {'a' => 1, 'b' => 1, 'c' => 1}, {'a' => 1, 'b' => 1}) ]), 'list_keys_in_2_not_in_1: {a, b, c} {a, b}');
	ok( 0 == compare_lists( ['b'],     [ list_keys_in_2_not_in_1( {'a' => 1, 'c' => 1}, {'a' => 1, 'b' => 1}) ]), 'list_keys_in_2_not_in_1: {a, b, c} {a, b}');
	
	return(  ) ;
}

sub list_keys_in_2_not_in_1 {

	my $folders1_ref = shift;
	my $folders2_ref = shift;
	my @list;
	
	foreach my $folder ( sort keys %$folders2_ref ) {
		next if exists($folders1_ref->{$folder});
		push(@list, $folder);
	}
	return(@list);
}


sub list_folders_in_2_not_in_1 {

	my (@h2_folders_not_in_h1, %h2_folders_not_in_h1) ;
	@h2_folders_not_in_h1 = list_keys_in_2_not_in_1( \%h1_folders_all, \%h2_folders_all) ;
	map { $h2_folders_not_in_h1{$_} = 1} @h2_folders_not_in_h1 ;
	@h2_folders_not_in_h1 = list_keys_in_2_not_in_1( \%h2_folders_from_1_all, \%h2_folders_not_in_h1) ;
	
	return( reverse @h2_folders_not_in_h1 );
}

sub delete_folders_in_2_not_in_1 { 

	foreach my $folder (@h2_folders_not_in_1) {
		if ( defined( $delete2foldersonly ) and eval( "\$folder !~ $delete2foldersonly" ) ) {
			print "Not deleting $folder because of --delete2foldersonly $delete2foldersonly\n";
			next;
		}
		if ( defined( $delete2foldersbutnot ) and eval( "\$folder =~ $delete2foldersbutnot" ) ) {
			print "Not deleting $folder because of --delete2foldersbutnot $delete2foldersbutnot\n";
			next;
		}
		my $res = $dry ; # always success in dry mode!
		$imap2->unsubscribe( $folder ) if ( ! $dry ) ;
		$res = $imap2->delete( $folder ) if ( ! $dry ) ;
		if ( $res ) {
			print "Delete $folder", "$dry_message", "\n" ;
		}else{
			print "Delete $folder failure", "\n" ;
		}
	}
	return(  ) ;
}


sub extract_header {
        my $string = shift ;
        
        my ( $header ) = split( /\n\n/x, $string ) ;
        if ( ! $header ) { return( '' ) ; }
        #print "[$header]\n" ;
        return( $header ) ;
}

sub tests_extract_header {

        
my $h = <<'EOM';
Message-Id: <20100428101817.A66CB162474E@plume.est.belle>
Date: Wed, 28 Apr 2010 12:18:17 +0200 (CEST)
From: gilles@louloutte.dyndns.org (Gilles LAMIRAL)
EOM
chomp( $h ) ;
ok( $h eq extract_header(
<<'EOM'
Message-Id: <20100428101817.A66CB162474E@plume.est.belle>
Date: Wed, 28 Apr 2010 12:18:17 +0200 (CEST)
From: gilles@louloutte.dyndns.org (Gilles LAMIRAL)

body
lalala
EOM
), 'extract_header: 1') ;


     
	return(  ) ;
}

sub decompose_header{
        my $string = shift ;
        
        # a hash, for a keyword header KEY value are list of strings [VAL1, VAL1_other, etc]
        # Think of multiple "Received:" header lines.
        my $header = {  } ;
        
        my ($key, $val ) ;
        my @line = split( /\n|\r\n/x, $string ) ;
        foreach my $line ( @line ) {
                #print "DDD $line\n" ;
                # End of header
                last if ( $line =~ m{^$}xo ) ;
                # Key: value
                if ( $line =~ m/(^[^:]+):\s(.*)/xo ) {
                        $key = $1 ;
                        $val = $2 ;
                        $debugdev and print "DDD KV [$key] [$val]\n" ;
                        push( @{ $header->{ $key } }, $val ) ;
                # blanc and value => value from previous line continues
                }elsif( $line =~ m/^(\s+)(.*)/xo ) {
                        $val = $2 ;
                        $debugdev and print "DDD  V [$val]\n" ;
                        @{ $header->{ $key } }[ -1 ] .= " $val" if $key ;
                # dirty line?
                }else{
                        next ;
                }
        }
        #require Data::Dumper ;
        #print Data::Dumper->Dump( [ $header ] ) ;

        return( $header ) ;
}


sub tests_decompose_header{

        my $header_dec ;
        
        $header_dec = decompose_header(
<<'EOH'
KEY_1: VAL_1
KEY_2: VAL_2
  VAL_2_+
        VAL_2_++
KEY_3: VAL_3
KEY_1: VAL_1_other
KEY_4: VAL_4
	VAL_4_+
KEY_5 BLANC:  VAL_5

KEY_6_BAD_BODY: VAL_6
EOH
        ) ;
        
        ok( 'VAL_3' 
        eq $header_dec->{ 'KEY_3' }[0], 'decompose_header: VAL_3' ) ;

        ok( 'VAL_1' 
        eq $header_dec->{ 'KEY_1' }[0], 'decompose_header: VAL_1' ) ;

        ok( 'VAL_1_other' 
        eq $header_dec->{ 'KEY_1' }[1], 'decompose_header: VAL_1_other' ) ;

        ok( 'VAL_2 VAL_2_+ VAL_2_++' 
        eq $header_dec->{ 'KEY_2' }[0], 'decompose_header: VAL_2 VAL_2_+ VAL_2_++' ) ;

        ok( 'VAL_4 VAL_4_+' 
        eq $header_dec->{ 'KEY_4' }[0], 'decompose_header: VAL_4 VAL_4_+' ) ;

        ok( ' VAL_5' 
        eq $header_dec->{ 'KEY_5 BLANC' }[0], 'decompose_header: KEY_5 BLANC' ) ;

        ok( not( defined( $header_dec->{ 'KEY_6_BAD_BODY' }[0] ) ), 'decompose_header: KEY_6_BAD_BODY' ) ;

        
        $header_dec = decompose_header(
<<'EOH'
Message-Id: <20100428101817.A66CB162474E@plume.est.belle>
Date: Wed, 28 Apr 2010 12:18:17 +0200 (CEST)
From: gilles@louloutte.dyndns.org (Gilles LAMIRAL)
EOH
        ) ;

        ok( '<20100428101817.A66CB162474E@plume.est.belle>' 
        eq $header_dec->{ 'Message-Id' }[0], 'decompose_header: 1' ) ;

        $header_dec = decompose_header(
<<'EOH'
Return-Path: <gilles@louloutte.dyndns.org>
Received: by plume.est.belle (Postfix, from userid 1000)
        id 120A71624742; Wed, 28 Apr 2010 01:46:40 +0200 (CEST)
Subject: test:eekahceishukohpe
EOH
) ;
        ok( 
'by plume.est.belle (Postfix, from userid 1000) id 120A71624742; Wed, 28 Apr 2010 01:46:40 +0200 (CEST)' 
        eq $header_dec->{ 'Received' }[0], 'decompose_header: 2' ) ;

        $header_dec = decompose_header(
<<'EOH'
Received: from plume (localhost [127.0.0.1])
        by plume.est.belle (Postfix) with ESMTP id C6EB73F6C9
        for <gilles@localhost>; Mon, 26 Nov 2007 10:39:06 +0100 (CET)
Received: from plume [192.168.68.7]
        by plume with POP3 (fetchmail-6.3.6)
        for <gilles@localhost> (single-drop); Mon, 26 Nov 2007 10:39:06 +0100 (CET)
EOH
        ) ;
        ok(
        'from plume (localhost [127.0.0.1]) by plume.est.belle (Postfix) with ESMTP id C6EB73F6C9 for <gilles@localhost>; Mon, 26 Nov 2007 10:39:06 +0100 (CET)'
        eq $header_dec->{ 'Received' }[0], 'decompose_header: 3' ) ;
        ok(
        'from plume [192.168.68.7] by plume with POP3 (fetchmail-6.3.6) for <gilles@localhost> (single-drop); Mon, 26 Nov 2007 10:39:06 +0100 (CET)'
        eq $header_dec->{ 'Received' }[1], 'decompose_header: 3' ) ;

# Bad header beginning with a blank character
        $header_dec = decompose_header(
<<'EOH'
 KEY_1: VAL_1
KEY_2: VAL_2
  VAL_2_+
        VAL_2_++
KEY_3: VAL_3
KEY_1: VAL_1_other
EOH
        ) ;
        
        ok( 'VAL_3' 
        eq $header_dec->{ 'KEY_3' }[0], 'decompose_header: Bad header VAL_3' ) ;

        ok( 'VAL_1_other' 
        eq $header_dec->{ 'KEY_1' }[0], 'decompose_header: Bad header VAL_1_other' ) ;

        ok( 'VAL_2 VAL_2_+ VAL_2_++' 
        eq $header_dec->{ 'KEY_2' }[0], 'decompose_header: Bad header VAL_2 VAL_2_+ VAL_2_++' ) ;

	return(  ) ;
}

sub epoch {
        # incoming format:
	# internal date 24-Aug-2010 16:00:00 +0200
	
        # outgoing format: epoch


        my $d = shift ;
        return ('') if not defined($d);

        my ( $mday, $month, $year, $hour, $min, $sec, $sign, $zone_h, $zone_m ) ;
        my $time ;
        
        if ( $d =~ m{(\d{1,2})-([A-Z][a-z]{2})-(\d{4})\s(\d{2}):(\d{2}):(\d{2})\s((?:\+|-))(\d{2})(\d{2})}xo ) {
                #print "internal: [$1][$2][$3][$4][$5][$6][$7][$8][$9]\n" ;
                ( $mday, $month, $year, $hour, $min, $sec, $sign, $zone_h, $zone_m ) 
                =  ( $1,   $2,     $3,    $4,    $5,  $6,    $7,     $8,     $9 ) ;
                #print "( $mday, $month, $year, $hour, $min, $sec, $sign, $zone_h, $zone_m )\n" ;
                
                $sign = +1 if ( '+' eq $sign ) ;
                $sign = -1 if ( '-' eq $sign ) ;
                
                $time = timegm( $sec, $min, $hour, $mday, $month_abrev{$month}, $year ) 
                        - $sign * ( 3600 * $zone_h + 60 * $zone_m ) ;
                
                #print( "$time ", scalar(localtime($time)), "\n");
        }
        return( $time ) ;
}

sub tests_epoch {
        ok( '1282658400' eq epoch( '24-Aug-2010 16:00:00 +0200' ), 'epoch 24-Aug-2010 16:00:00 +0200 -> 1282658400' ) ;
        ok( '1282658400' eq epoch( '24-Aug-2010 14:00:00 +0000' ), 'epoch 24-Aug-2010 14:00:00 +0000 -> 1282658400' ) ;
        ok( '1282658400' eq epoch( '24-Aug-2010 12:00:00 -0200' ), 'epoch 24-Aug-2010 12:00:00 -0200 -> 1282658400' ) ;
        ok( '1282658400' eq epoch( '24-Aug-2010 16:01:00 +0201' ), 'epoch 24-Aug-2010 16:01:00 +0201 -> 1282658400' ) ;
        ok( '1282658400' eq epoch( '24-Aug-2010 14:01:00 +0001' ), 'epoch 24-Aug-2010 14:01:00 +0001 -> 1282658400' ) ;

        ok( '1280671200' eq epoch( '1-Aug-2010 16:00:00 +0200' ), 'epoch 1-Aug-2010 16:00:00 +0200 -> 1280671200' ) ;
        ok( '1280671200' eq epoch( '1-Aug-2010 14:00:00 +0000' ), 'epoch 1-Aug-2010 14:00:00 +0000 -> 1280671200' ) ;
        ok( '1280671200' eq epoch( '1-Aug-2010 12:00:00 -0200' ), 'epoch 1-Aug-2010 12:00:00 -0200 -> 1280671200' ) ;
        ok( '1280671200' eq epoch( '1-Aug-2010 16:01:00 +0201' ), 'epoch 1-Aug-2010 16:01:00 +0201 -> 1280671200' ) ;
        ok( '1280671200' eq epoch( '1-Aug-2010 14:01:00 +0001' ), 'epoch 1-Aug-2010 14:01:00 +0001 -> 1280671200' ) ;
	return(  ) ;
}

sub add_header {
	my $header_uid = shift || 'mistake' ;
	my $header_Message_Id = 'Message-Id: <' . $header_uid . '@imapsync>' ;
        return( $header_Message_Id ) ;
}

sub tests_add_header {
	ok( 'Message-Id: <mistake@imapsync>' eq add_header(), 'add_header no arg' ) ;
	ok( 'Message-Id: <123456789@imapsync>' eq add_header(123456789), 'add_header 123456789' ) ;

	return(  ) ;
}

sub tests_Banner{

	my $imap = Mail::IMAPClient->new(  ) ;
        ok( 'lalala' eq $imap->Banner('lalala'), "Banner set lalala" ) ;
        ok( 'lalala' eq $imap->Banner(), "Banner get lalala" ) ;
	return(  ) ;
}




sub max_line_length {
	my $string = shift ;
        my $max = 0 ;
        my $i ;
        while ( $string =~ m/([^\n]*\n?)/msxg ) {
        	$max = max( $max, length( $1 ) ) ;
                #++$i ;
        	#print "max $max $i\n" ;
        }
        #print "MAX $max $i\n\n" ;
	return( $max ) ;
}

sub tests_max_line_length {
	ok( 0 == max_line_length( '' ), 'max_line_length: 0 == null string' ) ;
	ok( 1 == max_line_length( "\n" ), 'max_line_length: 1 == \n' ) ;
	ok( 1 == max_line_length( "\n\n" ), 'max_line_length: 1 == \n\n' ) ;
	ok( 1 == max_line_length( "\n" x 500 ), 'max_line_length: 1 == 500 \n' ) ;
	ok( 1 == max_line_length( "a" ), 'max_line_length: 1 == a' ) ;
	ok( 2 == max_line_length( "a\na" ), 'max_line_length: 2 == a\na' ) ;
	ok( 2 == max_line_length( "a\na\n" ), 'max_line_length: 2 == a\na\n' ) ;
	ok( 3 == max_line_length( "a\nab\n" ), 'max_line_length: 3 == a\nab\n' ) ;
	ok( 3 == max_line_length( "a\nab\n" x 10000 ), 'max_line_length: 3 == 10000 a\nab\n' ) ;
	ok( 3 == max_line_length( "a\nab\nabc" ), 'max_line_length: 3 == a\nab\nabc' ) ;

	ok( 4 == max_line_length( "a\nab\nabc\n" ), 'max_line_length: 4 == a\nab\nabc\n' ) ;
	ok( 5 == max_line_length( "a\nabcd\nabc\n" ), 'max_line_length: 5 == a\nabcd\nabc\n' ) ;
	ok( 5 == max_line_length( "a\nabcd\nabc\n\nabcd\nabcd\nabcd\nabcd\nabcd\nabcd\nabcd\nabcd" ), 'max_line_length: 5 == a\nabcd\nabc\n\nabcd\nabcd\nabcd\nabcd\nabcd\nabcd\nabcd\nabcd' ) ;
	return(  ) ;
}

sub usage {
	my $localhost_info = localhost_info();
	my $thank = thank_author();
	my $imapsync_release = '';
	$imapsync_release = check_last_release() if (not defined($releasecheck));
        my $escape_char = ( 'MSWin32' eq $OSNAME ) ? '^' : '\\';
        print <<"EOF";

usage: $0 [options]

Several options are mandatory. 

--dry                  : Makes imapsync doing nothing, just print what would 
                         be done without --dry.

--host1       <string> : Source or "from" imap server. Mandatory.
--port1       <int>    : Port to connect on host1. Default is 143.
--user1       <string> : User to login on host1. Mandatory.
--showpasswords        : Shows passwords on output instead of "MASKED".
                         Useful to restart a complete run by just reading a log.
--password1   <string> : Password for the user1.
--host2       <string> : "destination" imap server. Mandatory.
--port2       <int>    : Port to connect on host2. Default is 143.
--user2       <string> : User to login on host2. Mandatory.
--password2   <string> : Password for the user2.

--passfile1   <string> : Password file for the user1. It must contain the 
                         password on the first line. This option avoids to show 
                         the password on the command line like --password1 does.
--passfile2   <string> : Password file for the user2. Contains the password.
--domain1     <string> : Domain on host1 (NTLM authentication).
--domain2     <string> : Domain on host2 (NTLM authentication).
--authuser1   <string> : User to auth with on host1 (admin user). 
                         Avoid using --authmech1 SOMETHING with --authuser1.
--authuser2   <string> : User to auth with on host2 (admin user).
--proxyauth1           : Use proxyauth on host1. Requires --authuser1.
                         Required by Sun/iPlanet/Netscape IMAP servers to
                         be able to use an administrative user.
--proxyauth2           : Use proxyauth on host2. Requires --authuser2.
                         Required by Sun/iPlanet/Netscape IMAP servers to
                         be able to use an administrative user

--authmd51             : Use MD5 authentification for host1.
--authmd52             : Use MD5 authentification for host2.
--authmech1   <string> : Auth mechanism to use with host1:
                         PLAIN, LOGIN, CRAM-MD5 etc. Use UPPERCASE.
--authmech2   <string> : Auth mechanism to use with host2. See --authmech1
--ssl1                 : Use an SSL connection on host1.
--ssl2                 : Use an SSL connection on host2.
--tls1                 : Use an TLS connection on host1.
--tls2                 : Use an TLS connection on host2.
--timeout    <int>     : Connections timeout in seconds. Default is 120.
                         0 means no timeout.

--folder      <string> : Sync this folder.
--folder      <string> : and this one, etc.
--folderrec   <string> : Sync this folder recursively.
--folderrec   <string> : and this one, etc.
--include     <regex>  : Sync folders matching this regular expression
                         Blancs like in "foo bar" have to be written "foo\\ bar"
--include     <regex>  : or this one, etc.
                         in case both --include --exclude options are
                         use, include is done before.
--exclude     <regex>  : Skips folders matching this regular expression
                         Several folders to avoid:
			  --exclude 'fold1|fold2|f3' skips fold1, fold2 and f3.
--exclude     <regex>  : or this one, etc.
--regextrans2 <regex>  : Apply the whole regex to each destination folders.
--regextrans2 <regex>  : and this one. etc.
                         When you play with the --regextrans2 option, first
                         add also the safe options --dry --justfolders
                         Then, when happy, remove --dry, remove --justfolders.
                         Have in mind that --regextrans2 is applied after prefix 
                         and separator inversion.

--tmpdir      <string> : Where to store temporary files and subdirectories.
                         Will be created if it doesn't exist.
			 Default is system specific, Unix is /tmp but
                         it's often small and deleted at reboot.
                         --tmpdir /var/tmp should be better.
--pidfile     <string> : The file where imapsync pid is written.
--pidfilelocking       : Abort if pidfile already exists. Usefull to avoid 
                         concurrent transfers on the same mailbox.

--prefix1     <string> : Remove prefix to all destination folders 
                         (usually INBOX. or INBOX/ or an empty string "")
                         you have to use --prefix1 if host1 imap server
                         does not have NAMESPACE capability, all other
                         cases are bad.
--prefix2     <string> : Add prefix to all host2 folders. See --prefix1
--sep1        <string> : Host1 separator in case NAMESPACE is not supported.
--sep2        <string> : Host2 separator in case NAMESPACE is not supported.

--regexmess   <regex>  : Apply the whole regex to each message before transfer.
                         Example: 's/\\000/ /g' # to replace null by space.
--regexmess   <regex>  : and this one.
--regexmess   <regex>  : and this one, etc.
--regexflag   <regex>  : Apply the whole regex to each flags list.
                         Example: 's/\"Junk"//g' # to remove "Junk" flag.
--regexflag   <regex>  : and this one, etc.

--delete               : Deletes messages on host1 server after a successful 
                         transfer. Option --delete has the following behavior: 
                         it marks messages as deleted with the IMAP flag 
                         \\Deleted, then messages are really deleted with an 
                         EXPUNGE IMAP command.
--delete2              : Delete messages in host2 that are not in
                         host1 server. Useful for backup or pre-sync.
--delete2duplicates    : Delete messages in host2 that are duplicates.
                         Works only without --useuid since duplicates are 
                         detected with header part of each message.
--delete2folders       : Delete folders in host2 that are not in host1 server. 
                         For safety, first try it like this (it is safe):
			 --delete2folders --dry --justfolders --nofoldersizes
--delete2foldersonly   <regex>: Deleted only folders matching regex.
--delete2foldersbutnot <regex>: Do not delete folders matching regex.
                         Example: --delete2foldersbutnot "/Tasks|Contacts|Foo/"
--noexpunge            : Do not expunge messages on host1.
                         Expunge really deletes messages marked deleted.
                         Expunge is made at the beginning, on host1 only. 
                         Newly transferred messages are also expunged if 
			 option --delete is given.
                         No expunge is done on host2 account (unless --expunge2)
--expunge1             : Expunge messages on host1 after messages transfer.
--expunge2             : Expunge messages on host2 after messages transfer.
--uidexpunge2          : uidexpunge messages on the host2 account
                         that are not on the host1 account, requires --delete2

--syncinternaldates    : Sets the internal dates on host2 same as host1.
                         Turned on by default. Internal date is the date
			 a message arrived on a host (mtime).
--idatefromheader      : Sets the internal dates on host2 same as the 
                         "Date:" headers.

--maxsize     <int>    : Skip messages larger  (or equal) than <int> bytes
--minsize     <int>    : Skip messages smaller (or equal) than <int> bytes
--maxage      <int>    : Skip messages older than <int> days.
                         final stats (skipped) don't count older messages
			 see also --minage
--minage      <int>    : Skip messages newer than <int> days.
                         final stats (skipped) don't count newer messages
                         You can do (+ are the messages selected):
                         past|----maxage+++++++++++++++>now
                         past|+++++++++++++++minage---->now
                         past|----maxage+++++minage---->now (intersection)
                         past|++++minage-----maxage++++>now (union)

--search      <string> : Selects only messages returned by this IMAP SEARCH 
                         command. Applied on both sides.
--search1     <string> : Same as --search for selecting host1 messages only.
--search2     <string> : Same as --search for selecting host2 messages only.
                         --search CRIT equals --search1 CRIT --search2 CRIT

--exitwhenover   <int> : Stop syncing when total bytes transferred reached.
                         Gmail per day allows 2500000000 down 500000000 upload.

--maxlinelength <int>  : skip messages with line length longer than <int> bytes.
                         RFC 2822 says it must be no more than 1000 bytes.

--useheader   <string> : Use this header to compare messages on both sides.
                         Ex: Message-ID or Subject or Date.
--useheader   <string>   and this one, etc.

--subscribed           : Transfers subscribed folders.
--subscribe            : Subscribe to the folders transferred on the 
                         host2 that are subscribed on host1. On by default.
--subscribe_all        : Subscribe to the folders transferred on the 
                         host2 even if they are not subscribed on host1.

--nofoldersizes        : Do not calculate the size of each folder in bytes
                         and message counts. Default is to calculate them.
--nofoldersizesatend   : Do not calculate the size of each folder in bytes
                         and message counts at the end. Default is on.
--justfoldersizes      : Exit after having printed the folder sizes.

--syncacls             : Synchronises acls (Access Control Lists).
--nosyncacls           : Does not synchronize acls. This is the default.
                         Acls in IMAP are not standardized, be careful.

--usecache             : Use cache to speedup.
--nousecache           : Do not use cache. Caveat: --useuid --nousecache creates
                         duplicates on multiple runs.
--useuid               : Use uid instead of header as a criterium to recognize 
                         messages. Option --usecache is then implied unless 
                         --nousecache is used.  

--debug                : Debug mode.
--debugcontent         : Debug content of the messages transfered.
--debugflags           : Debug flags.
--debugimap1           : IMAP debug mode for host1. imap debug is very verbose.
--debugimap2           : IMAP debug mode for host2.
--debugimap            : IMAP debug mode for host1 and host2.

--version              : Print software version.
--noreleasecheck       : Do not check for new imapsync release (a http request).
--justconnect          : Just connect to both servers and print useful
                         information. Need only --host1 and --host2 options.
--justlogin            : Just login to both host1 and host2 with users 
                         credentials, then exit.
--justfolders          : Do only things about folders (ignore messages).

--help                 : print this help.

Example: to synchronize imap account "foo" on "imap.truc.org"
                    to  imap account "bar" on "imap.trac.org"
                    with foo password "secret1"
                    and  bar password "secret2"

$0 $escape_char
   --host1 imap.truc.org --user1 foo --password1 secret1 $escape_char
   --host2 imap.trac.org --user2 bar --password2 secret2

$localhost_info
$rcs
$imapsync_release

$thank
EOF
	return( 1 ) ;
}

sub usage_complete {
	print <<'EOF' ;
--skipheader  <regex>  : Don't take into account header keyword 
                         matching <string> ex: --skipheader 'X.*'
        
--skipsize             : Don't take message size into account to compare 
                         messages on both sides. On by default.
			 Use --no-skipsize for using size comparaison.
--allowsizemismatch    : allow RFC822.SIZE != fetched msg size
                         consider also --skipsize to avoid duplicate messages
                         when running syncs more than one time per mailbox

--reconnectretry1 <int>: reconnect to host1 if connection is lost up to 
                         <int> times per imap command (default is 3)
--reconnectretry2 <int>: same as --reconnectretry1 but for host2
--split1     <int>     : split the requests in several parts on host1.
                         <int> is the number of messages handled per request.
                         default is like --split1 500.
--split2     <int>     : same thing on host2.
EOF
	return(  ) ;
}



sub get_options {
	my $numopt = scalar(@ARGV);
	my $argv   = join("¤", @ARGV);
	
	$test_builder = Test::More->builder;
	$test_builder->no_ending(1);

	if($argv =~ m/-delete¤2/x) {
		print "May be you mean --delete2 instead of --delete 2\n";
		exit 1;
	}
        my $opt_ret = GetOptions(
                                   "debug!"        => \$debug,
                                   "debugLIST!"    => \$debugLIST,
                                   "debugcontent!" => \$debugcontent,
				   "debugsleep!"   => \$debugsleep,
                                   "debugflags!"   => \$debugflags,
                                   "debugimap!"    => \$debugimap,
                                   "debugimap1!"   => \$debugimap1,
                                   "debugimap2!"   => \$debugimap2,
                                   "debugdev!"   => \$debugdev,
                                   "host1=s"     => \$host1,
                                   "host2=s"     => \$host2,
                                   "port1=i"     => \$port1,
                                   "port2=i"     => \$port2,
                                   "user1=s"     => \$user1,
                                   "user2=s"     => \$user2,
                                   "domain1=s"   => \$domain1,
                                   "domain2=s"   => \$domain2,
                                   "password1=s" => \$password1,
                                   "password2=s" => \$password2,
                                   "passfile1=s" => \$passfile1,
                                   "passfile2=s" => \$passfile2,
				   "authmd5!"    => \$authmd5,
				   "authmd51!"   => \$authmd51,
				   "authmd52!"   => \$authmd52,
                                   "sep1=s"      => \$sep1,
                                   "sep2=s"      => \$sep2,
				   "folder=s"    => \@folder,
				   "folderrec=s" => \@folderrec,
				   "include=s"   => \@include,
				   "exclude=s"   => \@exclude,
				   "prefix1=s"   => \$prefix1,
				   "prefix2=s"   => \$prefix2,
				   "fixslash2!"  => \$fixslash2,
                                   "fixInboxINBOX!" => \$fixInboxINBOX,
				   "regextrans2=s" => \@regextrans2,
				   "regexmess=s" => \@regexmess,
				   "regexflag=s" => \@regexflag,
				   "filterflags!" => \$filterflags,
				   "flagsCase!"  => \$flagsCase,
                                   "syncflagsaftercopy!" => \$syncflagsaftercopy,
                                   "delete|delete1!" => \$delete,
                                   "delete2!"    => \$delete2,
                                   "delete2duplicates!" => \$delete2duplicates,
				   "delete2folders!"    => \$delete2folders,
				   "delete2foldersonly=s" => \$delete2foldersonly,
				   "delete2foldersbutnot=s" => \$delete2foldersbutnot,
                                   "syncinternaldates!" => \$syncinternaldates,
                                   "idatefromheader!"   => \$idatefromheader,
                                   "syncacls!"   => \$syncacls,
				   "maxsize=i"   => \$maxsize,
				   "minsize=i"   => \$minsize,
				   "maxage=i"    => \$maxage,
				   "minage=i"    => \$minage,
                                   "search=s"    => \$search,
                                   "search1=s"   => \$search1,
                                   "search2=s"   => \$search2,
				   "foldersizes!" => \$foldersizes,
				   "foldersizesatend!" => \$foldersizesatend,
                                   "dry!"        => \$dry,
                                   "expunge!"    => \$expunge,
                                   "expunge1!"    => \$expunge1,
                                   "expunge2!"    => \$expunge2,
                                   "uidexpunge2!" => \$uidexpunge2,
                                   "subscribed!" => \$subscribed,
                                   "subscribe!"  => \$subscribe,
                                   "subscribe_all!"  => \$subscribe_all,
				   "justbanner!" => \$justbanner,
                                   "justconnect!"=> \$justconnect,
                                   "justfolders!"=> \$justfolders,
				   "justfoldersizes!" => \$justfoldersizes,
				   "fast!"       => \$fast,
                                   "version"     => \$version,
                                   "help"        => \$help,
                                   "timeout=i"   => \$timeout,
				   "skipheader=s" => \$skipheader,
				   "useheader=s" => \@useheader,
				   "wholeheaderifneeded!"   => \$wholeheaderifneeded,
                                   "messageidnodomain!" => \$messageidnodomain,
				   "skipsize!"   => \$skipsize,
				   "allowsizemismatch!" => \$allowsizemismatch,
				   "fastio1!"     => \$fastio1,
				   "fastio2!"     => \$fastio2,
				   "ssl1!"        => \$ssl1,
				   "ssl2!"        => \$ssl2,
				   "ssl1_SSL_version=s" => \$ssl1_SSL_version,
				   "ssl2_SSL_version=s" => \$ssl2_SSL_version,
				   "tls1!"        => \$tls1,
				   "tls2!"        => \$tls2,
				   "uid1!"        => \$uid1,
				   "uid2!"        => \$uid2,
				   "authmech1=s" => \$authmech1,
				   "authmech2=s" => \$authmech2,
				   "authuser1=s" => \$authuser1,
				   "authuser2=s" => \$authuser2,
				   "proxyauth1"        => \$proxyauth1,
				   "proxyauth2"        => \$proxyauth2,
				   "split1=i"    => \$split1,
				   "split2=i"    => \$split2,
				   "buffersize=i" => \$buffersize,
				   "reconnectretry1=i" => \$reconnectretry1,
				   "reconnectretry2=i" => \$reconnectretry2,
				   "relogin1=i"  => \$relogin1,
				   "relogin2=i"  => \$relogin2,
                                   "tests"       => \$tests,
                                   "tests_debug" => \$tests_debug,
                                   "allow3xx!"   => \$allow3xx,
                                   "justlogin!"  => \$justlogin,
				   "tmpdir=s"    => \$tmpdir,
				   "pidfile=s"    => \$pidfile,
				   "pidfilelocking!"    => \$pidfilelocking,                                 
				   "releasecheck!" => \$releasecheck,
				   "modules_version!" => \$modules_version,
				   "usecache!"    => \$usecache,
                                   "cacheaftercopy!" => \$cacheaftercopy,
				   "debugcache!" => \$debugcache,
				   "useuid!"      => \$useuid,
                                   "addheader!"   => \$addheader,
                                   "exitwhenover=i" => \$exitwhenover,
                                   "checkselectable!" => \$checkselectable,
                                   "checkmessageexists!" => \$checkmessageexists,
                                   "expungeaftereach!" => \$expungeaftereach,
                                   "abletosearch!" => \$abletosearch,
                                   "showpasswords!" => \$showpasswords,
                                   "maxlinelength=i" => \$maxlinelength, 
                                  );
	
        $debug and print "get options: [$opt_ret]\n";

	# just the version
        print imapsync_version(), "\n" and exit if ($version) ;
	
	if ($tests) {
		$test_builder->no_ending(0);
		tests();
		exit;
	}
	if ($tests_debug) {
		$test_builder->no_ending(0);
		tests_debug();
		exit;
	}
	
	$help = 1 if ! $numopt;
	load_modules();

	# exit with --help option or no option at all
        usage(  ) and exit(  ) if ( $help or not $numopt ) ;

	# don't go on if options are not all known.
        exit( EX_USAGE(  ) ) unless ( $opt_ret ) ;
	return(  ) ;
}


sub tests_debug {
	
      SKIP: {
		skip "No test in normal run" if ( not $tests_debug );
                tests_msgs_from_maxmin(  ) ;
	}
        return(  ) ;
}

sub tests {
	
      SKIP: {
		skip "No test in normal run" if (not $tests);
		tests_folder_routines();
		tests_compare_lists();
		tests_regexmess();
		tests_flags_regex();
		tests_permanentflags();
		tests_flags_filter(  ) ;
                tests_separator_invert(  ) ;
		tests_imap2_folder_name();
		tests_command_line_nopassword();
		tests_good_date();
		tests_max();
		tests_remove_not_num();
		tests_memory_consumption();
		tests_is_a_release_number();
		tests_imapsync_basename();
		tests_list_keys_in_2_not_in_1();
		tests_convert_sep_to_slash(  ) ;
		tests_match_a_cache_file(  ) ;
		tests_cache_map(  ) ;
		tests_get_cache(  ) ;
		tests_clean_cache(  ) ;
		tests_clean_cache_2(  ) ;
		tests_touch(  ) ;
		tests_ucsecond(  ) ;
		tests_flagsCase(  ) ;
                tests_mkpath(  ) ;
                tests_extract_header(  ) ;
                tests_decompose_header(  ) ;
                tests_epoch(  ) ;
                tests_add_header(  ) ;
                tests_cache_dir_fix(  ) ;
                tests_filter_forbidden_characters(  ) ;
                tests_cache_folder(  ) ;
                tests_time_remaining(  ) ;
                tests_decompose_regex(  ) ;
                tests_Banner(  ) ;
                tests_backtick(  ) ;
                tests_bytes_display_string(  ) ;
                tests_header_line_normalize(  ) ;
                tests_fix_Inbox_INBOX_mapping(  ) ;
                tests_max_line_length(  ) ;
                tests_subject(  ) ;
		tests_msgs_from_maxmin(  ) ;
	}
        return(  ) ;
}



# IMAPClient 3.xx ads

package Mail::IMAPClient;

sub Tls {
	my $self  = shift ;
	my $value = shift ;
	if ( defined( $value ) ) { $self->{TLS} = $value }
	return $self->{TLS};
}

sub Reconnect_counter {
	my $self  = shift ;
        my $value = shift ;
	$self->{Reconnect_counter} = 0 if ( not defined( $self->{Reconnect_counter} ) ) ;
	if ( defined( $value ) ) { $self->{Reconnect_counter} = $value }
	return( $self->{Reconnect_counter} ) ;
}


sub Banner {
	my $self  = shift ;
	my $value = shift ;
	if ( defined( $value ) ) { $self->{ BANNER } = $value }
	return $self->{ BANNER };
}

sub capability_update {
	my $self = shift ;
	
	delete $self->{CAPABILITY} ;
	return( $self->capability ) ;
}


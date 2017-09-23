#!/usr/bin/perl

# $Header: /mhub4/sources/imap-tools/imapcopy.cgi,v 1.9 2014/08/18 15:17:22 rick Exp $

#######################################################################
#   Program name    imapcopy.cgi                                      #
#   Written by      Rick Sanders                                      #
#                                                                     #
#   Description                                                       #
#                                                                     #
#   imapcopy.cgi is used to manage the imapcopy.pl script in CGI      #
#   mode.                                                             #
#######################################################################

use Socket;
use FileHandle;
use Fcntl;
use Getopt::Std;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use IO::Socket;
use POSIX 'setsid';
use Cwd;

   init();
   get_html();

   #  Check the source and dest logins in case the user has provided 
   #  invalid credentials or host names

   test_logins();

   #  To prevent someone from seeing the passwords in ps pass them
   #  as ENV variables.

   $ENV{SOURCEPWD} = $sourcePwd;
   $ENV{DESTPWD}   = $destPwd;
   
   my $cmd = "$imapcopy ";
   $cmd .= "-S $sourceHost/$sourceUser/SOURCEPWD ";
   $cmd .= "-D $destHost/$destUser/DESTPWD ";
   $cmd .= "-I " if $DEFAULTS{'SHOWIMAP'} == 1;
   $cmd .= "-d " if $DEFAULTS{'DEBUG'}    == 1;
   $cmd .= "-L $logfile "          if $logfile;
   $cmd .= "-m \"$mbxList\" "      if $mbxList;
   $cmd .= "-e \"$excludeMbxs\" "  if $excludeMbxs;
   $cmd .= "-a $sent_after "       if $sent_after;
   $cmd .= "-b $sent_before "      if $sent_before;
   $cmd .= "-U "                   if $update;
   $cmd .= "$DEFAULTS{ARGUMENTS} " if $DEFAULTS{ARGUMENTS};

   launch_daemon( $cmd );

   print STDOUT "<b><br>Your copy job has been started.  You will be notified when it has completed</b><br>";

   exit;


sub init {

   $os = $ENV{'OS'};

   print "Content-type: text/html\n\n<html>\n";
   print '<meta equiv="refresh" content="5">';
   print '</head>';
   print '<title>IMAP Copy</title>';
   print '<body style="background-color:#FFF8C6" bgproperties="fixed" bgcolor="#FFFFFF" text="#000000"
link="#050473" vlink="#6B6AF5" alink="#840000">';

   if ( -e "imapcopy.cf" ) {
      open(CF, "<imapcopy.cf") or print "Can't open imapcopy.cf: $!";
   }
   while( <CF> ) {
     chomp;
     ($kw,$value) = split(/\s*:\s*/, $_, 2);
     $DEFAULTS{$kw} = $value;
   }
   close CF;

   if ( $DEFAULTS{'IMAPCOPY'} ) {
      $imapcopy = $DEFAULTS{'IMAPCOPY'};
   } else {
      my $here = getcwd;
      $imapcopy = "$here/imapcopy.pl";
   }

   $logfile = $DEFAULTS{'LOGFILE'};
   if ( $logfile ) {
      if ( !open(LOG, ">> $logfile")) {
         print STDOUT "Can't open $logfile: $!\n";
         exit;
      } 
      select(LOG); $| = 1;
   }
   Log("$0 starting");

   $count = count_imapcopy_processes();
   if ( $DEFAULTS{PROCESS_LIMIT} ) {
      exit if $count > $DEFAULTS{PROCESS_LIMIT};
   }

   #  Determine whether we have SSL support via openSSL and IO::Socket::SSL
   $ssl_installed = 1;
   eval 'use IO::Socket::SSL';
   if ( $@ ) {
      $ssl_installed = 0;
   }

   #  Set up signal handling
   $SIG{'ALRM'} = 'signalHandler';
   $SIG{'HUP'}  = 'signalHandler';
   $SIG{'INT'}  = 'signalHandler';
   $SIG{'TERM'} = 'signalHandler';
   $SIG{'URG'}  = 'signalHandler';

}

sub launch_daemon {

my $cmd = shift;
my $parent = $$;
use POSIX 'setsid';

   #  The purpose of this routine is to launch imapcopy as a grandkid which detaches
   #  it from the Apache process so that it will not die if the user closes his browser.

   print STDOUT "Your copy job has been started.  You will be notified when it has completed.";

   if ( !defined (my $kid = fork) ) {
      print STDOUT "Cannot fork a child process:  $!<br>";
      Log("Cannot fork: $!");
      exit;
   }
   if ( $kid ) {
      exit(0);
   } else {
       close STDIN;
       close STDOUT;
       close STDERR;
       if ( !setsid ) {
          Log("Cannot execute 'setsid', exiting");
          exit;
       }

       umask(0027); # create files with perms -rw-r----- 
       if ( !chdir '/' ) {
          Log("Can't chdir to /: $!");
          exit;
       }

       if ( !(open STDIN,  '<', '/dev/null') ) {
          Log("Cannot redirect STDIN: $!");
          exit;
       }

       if ( !(open STDOUT, '>', '/dev/null') ) {
          Log("Cannot redirect STDOUT:  $!");
          exit;
       }

       if ( !(open STDERR, '>>', $logfile) ) {
          Log("Cannot redirect STDERR to $logfile:  $!");
          Log("Check the path and permissions on $logfile");
          exit;
       }

       if ( !defined (my $grandkid = fork) ) {
          exit;
       } else {
          if ( $grandkid != 0 and $$ != $parent ) {
             Log("Execute $cmd");
             $rc = `$cmd`;
             Log("rc = $rc");
          }
          exit(0);
       }
   }
}

sub get_html {

my $fields = shift;
my $formData=0;

   #  Get the HTML form values
   #
   my $query = new CGI;

   $sourceHost = $query->param('sourceHost');
   $sourceUser = $query->param('sourceUser');
   $sourcePwd  = $query->param('sourcePwd');

   $destHost = $query->param('destHost');
   $destUser = $query->param('destUser');
   $destPwd  = $query->param('destPwd');

   $mbxList      = $query->param('mbxList');
   $excludeMbxs  = $query->param('excludeMbxList');
   $sent_after   = $query->param('sent_after');
   $sent_before  = $query->param('sent_before');
   $update       = $query->param('update');

   $update = 1 if $update eq 'on';

}

sub Log {

my $str = shift;

   if ( $logfile ) {
      ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
      if ($year < 99) { $yr = 2000; }
      else { $yr = 1900; }
      $line = sprintf ("%.2d-%.2d-%d.%.2d:%.2d:%.2d %s\n",
                     $mon + 1, $mday, $year + $yr, $hour, $min, $sec,$str);
      print LOG "$line";
   }

}



#  login
#
#  login in at the source host with the user's name and password
#
sub login {

my $user = shift;
my $pwd  = shift;
my $host = shift;
my $conn = shift;
my $method = shift;

   Log("method $method") if $debug;

   return 1 if $method eq 'PREAUTH';   #  Server pre-authenticates users

   Log("Authenticating to $host as $user");
   if ( uc( $method ) eq 'CRAM-MD5' ) {
      #  A CRAM-MD5 login is requested
      Log("login method $method");
      my $rc = login_cram_md5( $user, $pwd, $conn );
      return $rc;
   }

   if ( $user =~ /(.+):(.+)/ ) {
      #  An AUTHENTICATE = PLAIN login has been requested
      $sourceUser  = $1;
      $authuser    = $2;
      login_plain( $sourceUser, $authuser, $pwd, $conn ) or exit;
      return 1;
   }  

   #  Otherwise do an ordinary login

   sendCommand ($conn, "1 LOGIN $user \"$pwd\"");
   while (1) {
	readResponse ( $conn );

        if ( $response =~ /Cyrus/i and $conn eq $dst ) {
           Log("Destination is a Cyrus server");
           $cyrus = 1;
        }

        if ( $response =~ /Microsoft Exchange/i and $conn eq $dst ) {
           #  The destination is an Exchange server
           unless ( $exchange_override ) {
              $exchange = 1; 
              Log("The destination is an Exchange server");
           }
        }
	last if $response =~ /^1 OK/i;

	if ($response =~ /^1 NO|^1 BAD|^\* BYE/i) {
           Log ("unexpected LOGIN response: $response");
           return 0;
	}
   }
   Log("Logged in as $user") if $debug;

   return 1;
}


sub login_cram_md5 {

my $user = shift;
my $pwd  = shift;
my $conn = shift;

   sendCommand ($conn, "1 AUTHENTICATE CRAM-MD5");
   while (1) {
        readResponse ( $conn );
        last if $response =~ /^\+/;
        if ($response =~ /^1 NO|^1 BAD|^\* BYE/i) {
           Log ("unexpected LOGIN response: $response");
           return 0;
        }
   }

   my ($challenge) = $response =~ /^\+ (.+)/;

   Log("challenge $challenge") if $debug;
   $response = cram_md5( $challenge, $user, $pwd );
   Log("response $response") if $debug;

   sendCommand ($conn, $response);
   while (1) {
        readResponse ( $conn );

        if ( $response =~ /Microsoft Exchange/i and $conn eq $dst ) {
           #  The destination is an Exchange server
           $exchange = 1;
           Log("The destination is an Exchange server");
        }

        last if $response =~ /^1 OK/i;
        if ($response =~ /^1 NO|^1 BAD|^\* BYE/i) {
           Log ("unexpected LOGIN response: $response");
           return 0;
        }
   }
   Log("Logged in as $user") if $debug;

   return 1;
}

#  login_plain
#
#  login in at the source host with the user's name and password.  If provided
#  with administrator credential, use them as this eliminates the need for the 
#  user's password.
#
sub login_plain {

my $user      = shift;
my $admin     = shift;
my $pwd       = shift;
my $conn      = shift;

   #  Do an AUTHENTICATE = PLAIN.  If an admin user has been provided then use it.

   if ( !$admin ) {
      # Log in as the user
      $admin = $user
   }

   $login_str = sprintf("%s\x00%s\x00%s", $user,$admin,$pwd);
   $login_str = encode_base64("$login_str", "");
   $len = length( $login_str );

   # sendCommand ($conn, "1 AUTHENTICATE \"PLAIN\" {$len}" );
   sendCommand ($conn, "1 AUTHENTICATE PLAIN" );

   my $loops;
   while (1) {
        readResponse ( $conn );
        last if $response =~ /\+/;
        if ($response =~ /^1 NO|^1 BAD|^\* BYE/i) {
           Log ("unexpected LOGIN response: $response");
           exit;
        }
        $last if $loops++ > 5;
   }

   sendCommand ($conn, "$login_str" );
   my $loops;
   while (1) {
        readResponse ( $conn );

        if ( $response =~ /Cyrus/i and $conn eq $dst ) {
           Log("Destination is a Cyrus server");
           $cyrus = 1;
        }

        if ( $response =~ /Microsoft Exchange/i and $conn eq $dst ) {
           #  The destination is an Exchange server
           $exchange = 1;
           Log("The destination is an Exchange server");
        }

        last if $response =~ /^1 OK/i;
        if ($response =~ /^1 NO|^1 BAD|^\* BYE/i) {
           Log ("unexpected LOGIN response: $response");
           exit;
        }
        $last if $loops++ > 5;
   }

   return 1;

}

#  logout
#
#  log out from the host
#
sub logout {

my $conn = shift;

   undef @response;
   sendCommand ($conn, "1 LOGOUT");
   while ( 1 ) {
	readResponse ($conn);
	if ( $response =~ /^1 OK/i ) {
		last;
	}
	elsif ( $response !~ /^\*/ ) {
		Log ("unexpected LOGOUT response: $response");
		last;
	}
   }
   close $conn;
   return;
}

#  Make a connection to a IMAP host

sub connectToHost {

my $host = shift;
my $conn = shift;

   Log("Connecting to $host") if $debug;
   
   ($host,$port) = split(/:/, $host);
   $port = 143 unless $port;

   # We know whether to use SSL for ports 143 and 993.  For any
   # other ones we'll have to figure it out.
   $mode = sslmode( $host, $port );

   if ( $mode eq 'SSL' ) {
      unless( $ssl_installed == 1 ) {
         warn("You must have openSSL and IO::Socket::SSL installed to use an SSL connection");
         Log("You must have openSSL and IO::Socket::SSL installed to use an SSL connection");
         exit;
      }
      Log("Attempting an SSL connection") if $debug;
      $$conn = IO::Socket::SSL->new(
         Proto           => "tcp",
         SSL_verify_mode => 0x00,
         PeerAddr        => $host,
         PeerPort        => $port,
         Domain          => AF_INET,
         Timeout         => 10,
      );

      unless ( $$conn ) {
        $error = IO::Socket::SSL::errstr();
        Log("Error connecting to $host: $error");
        print STDOUT "<font color=red><b>Error:  Can't connect to $host.<br>";
        print STDOUT "Hit the Back button on your browser, correct the info, and try again.";
        exit;
      }
   } else {
      #  Non-SSL connection
      Log("Attempting a non-SSL connection") if $debug;
      $$conn = IO::Socket::INET->new(
         Proto           => "tcp",
         PeerAddr        => $host,
         PeerPort        => $port,
         Timeout         => 10,
      );

      unless ( $$conn ) {
        Log("Error connecting to $host:$port: $@");
        print STDOUT "<font color=red><b>Error:  Can't connect to $host.<br>";
        print STDOUT "Hit the Back button on your browser, correct the info, and try again.";
        exit;
      }
   } 
   Log("Connected to $host on port $port");

}

sub sslmode {

my $host = shift;
my $port = shift;
my $mode;

   #  Determine whether to make an SSL connection
   #  to the host.  Return 'SSL' if so.

   if ( $port == 143 ) {
      #  Standard non-SSL port
      return '';
   } elsif ( $port == 993 ) {
      #  Standard SSL port
      return 'SSL';
   }
      
   unless ( $ssl_installed ) {
      #  We don't have SSL installed on this machine
      return '';
   }

   #  For any other port we need to determine whether it supports SSL

   my $conn = IO::Socket::SSL->new(
         Proto           => "tcp",
         SSL_verify_mode => 0x00,
         PeerAddr        => $host,
         PeerPort        => $port,
    );

    if ( $conn ) {
       close( $conn );
       $mode = 'SSL';
    } else {
       $mode = '';
    }

   return $mode;
}
 
sub test_logins {

   #  Verify that we can log in at the source and destination before launching 
   #  the copy job.

   print "<br><br>";
   if ( !connectToHost($sourceHost, \$src) ) {
      print STDOUT "<font color=red> <b>Error:  Can't connect to $sourceHost.  Check that $sourceHost is correct.<br>";
      print STDOUT "Hit the Back button on your browser, correct the info, and try again.";
      exit;
   } 
   if ( !login($sourceUser,$sourcePwd, $sourceHost, $src, $srcMethod) ) {
      print STDOUT "<font color=red><b>Error:  Can't login as $sourceUser.  Check your username and password<br>";
      print STDOUT "Hit the Back button on your browser, correct the info, and try again.";
      exit;
   }
   if ( !connectToHost($destHost, \$dst) ) {
      print STDOUT "<font color=red><b>Error:  Can't connect to $destHost.  Check that $destHost is correct.\n";
      print STDOUT "Hit the Back button on your browser, correct the info, and try again.";
      exit;
   }
   if ( !login($destUser,$destPwd, $destHost, $dst, $dstMethod) ) {
      print STDOUT "<font color=red><b>Error:  Can't login as $destUser.  Check your username and password<br>";
      print STDOUT "Hit the Back button on your browser, correct the info, and try again.";
      exit;
   }

}

sub sendCommand {

my $fd = shift;
my $cmd = shift;

    print $fd "$cmd\r\n";

    Log (">> $cmd") if $showIMAP;
}

#
#  readResponse
#
#  This subroutine reads and formats an IMAP protocol response from an
#  IMAP server on a specified connection.
#

sub readResponse {
    
my $fd = shift;

    $response = <$fd>;
    chop $response;
    $response =~ s/\r//g;
    push (@response,$response);
    Log ("<< $response") if $showIMAP;
}

sub count_imapcopy_processes {

my $count;

   #  Count how many imapcopy processes are currently running
   #  and exit if the max has been reached.

   foreach $_ ( `ps -ef | grep imapcopy.pl` ) {
      next unless /imapcopy.pl/;
      next if /grep/;
      $count++;
   }

   $process_limit = $DEFAULTS{PROCESS_LIMIT};
   if ( $process_limit > 0 and $count > $process_limit ) {
      print STDOUT "<br><br><b>The maximum number of IMAP copies is already running.  Please try again later.<br>";
   }
   return $count;

}


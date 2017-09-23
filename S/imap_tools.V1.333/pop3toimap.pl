#!/usr/bin/perl

# $Header: /mhub4/sources/imap-tools/pop3toimap.pl,v 1.10 2014/10/16 01:06:22 rick Exp $

########################################################################
#                                                                      #
#   Program Name    pop3toimap.pl                                      #
#   Written by      Rick Sanders                                       #  
#   Date            28 April 2008                                      #
#                                                                      #
#   Description                                                        #
#                                                                      #
#   pop3toimap.pl is a tool for copying a user's messages from a POP3  #
#   server to an IMAP4 server.  pop3toimap.pl makes a POP3 connection  #
#   to the POP3 host and logs in with the user's name and password.    #
#   It makes an IMAP connection to the IMAP host and logs in with the  #
#   user's IMAP username and password.  pop3toimap.pl then fetches     #
#   each message from the user's POP3 account and copies it to the     #
#   user's IMAP account.                                               #
#                                                                      #
#   If you supply 993 for the IMAP port then the connection will be    #
#   made over SSL.  Similarily for POP if you specify port 995. Note   #
#   you must have the IO::Socket::SSL Perl module installed as well    #
#   as openSSL.                                                        #
#                                                                      #
#   The usernames and passwords are supplied via a text file specified #
#   by the -u argument.  The format of the file of users is:           #
#      <popUsername> <password> <imapUsername> <password>              #
########################################################################

use Getopt::Std;
use Socket;
use IO::Socket;
use MIME::Base64 qw( encode_base64 decode_base64 );

   init();

   if ( $usersFile ) {
      $imapHost = $opt_i;
      $popHost  = $opt_p;
      getUsersList( $usersFile, \@users );
   } else {
      #  Single user
      ($imapHost,$imapUser,$imapPwd) = split(/\//, $opt_i);
      ($popHost,$popUser,$popPwd)    = split(/\//, $opt_p);
      push( @users, "$popUser $popPwd $imapUser $imapPwd" );
   }
   ($imapHost,$imapPort) = split(/:/, $imapHost);
   ($popHost,$popPort)  = split(/:/, $popHost);
   $imapPort = 143 unless $imapPort;
   $popPort  = 110 unless $popPort;

   foreach $line ( @users ) {
      $line =~ s/\s+/ /g;
      ($popUser,$popPwd,$imapUser,$imapPwd) = split(/ /, $line);

      #  Connect to the POP server and login
      connectToHost($popHost, $popPort, \$p_conn);
      next unless loginPOP( $popUser, $popPwd, $p_conn );

      #  Connect to the IMAP server and login
      connectToHost($imapHost, $imapPort, \$i_conn);
      next unless loginIMAP( $imapUser, $imapPwd, $i_conn );

      namespace( $i_conn, \$prefix, \$delim, $opt_x );

      $mailbox = mailboxName( $mailbox,$prefix,$delim );
      createMbx( $mailbox, $i_conn ) unless mbxExists( $mailbox, $i_conn);
      migrate( $p_conn, $i_conn );
      logoutPOP( $p_conn );
      logoutIMAP( $i_conn );
   }

   summary();
   exit;


#
#  migrate
#
#  Get a list of messages in the POP user's account, retrieve each one from
#  the POP server, and insert each one into the IMAP user's account.  Delete
#  the message from the POP server if the "delete" flag is set.
#
sub migrate {

my $p_conn = shift;
my $i_conn = shift;
my $copied;

   if ( $range ) {
      ($lower,$upper) = split(/-/, $range);
      Log("Migrating POP message numbers between $lower and $upper");
   }

   @popMsgList = getPOPMsgList( $p_conn );

   if ( $debug ) {
      Log("List the POP msgs by message number");
      foreach $msg ( @popMsgList ) {
         Log("$msg");
      }
   }

   $count = $#popMsgList + 1;
   Log("Migrating $popUser on $popHost to $imapUser on $imapHost ($count messages)");

   foreach $msgnum ( @popMsgList ) {
      if ( $range ) {
         Log("msgnum $msgnum") if $debug;
         next if $msgnum < $lower;
         next if $msgnum > $upper;
      }
      Log("Fetching POP message $msgnum") if $debug;
      $msg = getPOPMsg( $msgnum, $p_conn );

      getFlag( \$msg, \$flag );
      getDate( \$msg, \$date );

      next if $msg eq '';

      $mailbox = 'INBOX' unless $mailbox;
      selectMbx( $mailbox, $i_conn );

      if ( insertMsg(*msg, $mailbox, $date, $flag, $i_conn ) ) {
         $copied++;
         $grandTotal++;
         Log("$copied messages migrated") if $copied/100 == int($copied/100);

	 #  Delete the message from the POP server if the delete flag is set
	 deletePOPMsg( $msgnum, $p_conn ) if $delete;

      }
   }

   $usersMigrated++;
}


sub init {

   $version = "1.3";

   getopts( "Ip:L:i:u:n:drhR:t:m:A:" );

   $usersFile = $opt_u;
   $logFile   = $opt_L;
   $notify    = $opt_n;
   $range     = $opt_R;
   $timeout   = $opt_t;
   $mailbox   = $opt_m;
   $admin_user = $opt_A;
   $delete    = 1 if $opt_r;
   $debug     = 1 if $opt_d;
   $showIMAP  = 1 if $opt_I;

   usage() if $opt_h;

   #  Determine whether we have SSL support via openSSL and IO::Socket::SSL
   $ssl_installed = 1;
   eval 'use IO::Socket::SSL';
   if ( $@ ) {
      $ssl_installed = 0;
   }

   $logFile = "pop3toimap.log" unless $logFile;
   if (!open(LOG, ">> $logFile")) {
        print STDERR "Can't open logfile $logFile\n";
	exit;
   }
   select(LOG); $| = 1;
   Log("pop3toimap $version starting");

   $timeout = $opt_t;
   $timeout = 45 unless $timeout;

   if ( $opt_m ) {
      $mailbox = $opt_m;
   } else {
      $mailbox = 'INBOX';
   }

}

sub getUsersList {

my $usersFile = shift;
my $users = shift;

   #  Get the list of users to be migrated
   #
   unless ( -e $usersFile ) {
      print STDERR "$usersFile does not exist\n";
      exit;
   }

   if ( !open(USERS, "<$usersFile")) {
        print STDERR "pop3toimap, Can't open $usersFile for input\n";
        Log("Can't open $usersFile for input");
        exit 0;
   }
   while (<USERS>) {
         chomp;
	 next if /^\#/;
         push (@$users, $_) if $_;
   }
   close USERS;
   $totalUsers = $#users + 1;
   Log("There are $totalUsers users to be migrated");
}

sub procArgs {



}

#  Make a connection to a host

sub connectToHost {

my $host = shift;
my $port = shift;
my $conn = shift;

   Log("Connecting to $host") if $debug;
   
   # We know whether to use SSL for the well-known ports (143,993,110,995) but
   #  for any others we'll have to figure it out.
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
      );

      unless ( $$conn ) {
        $error = IO::Socket::SSL::errstr();
        Log("Error connecting to $host: $error");
        warn("Error connecting to $host: $error");
        exit;
      }
   } else {
      #  Non-SSL connection
      Log("Attempting a non-SSL connection") if $debug;
      $$conn = IO::Socket::INET->new(
         Proto           => "tcp",
         PeerAddr        => $host,
         PeerPort        => $port,
      );

      unless ( $$conn ) {
        Log("Error connecting to $host:$port: $@");
        warn "Error connecting to $host:$port: $@";
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

   if ( $port == 143 or $port == 110 ) {
      #  Standard non-SSL ports
      return '';
   } elsif ( $port == 993 or $port == 995 ) {
      #  Standard SSL ports
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

#  loginPOP
#
#  login in at the POP host with the user's name and password
#
sub loginPOP {

my $user = shift;
my $pwd  = shift;
my $conn = shift;
my $rc;

   Log("Authenticating to POP server as $user, password $pwd") if $debug;

   sendCommand ($conn, "USER $user" );
   while ( 1 ) {
        readResponse ($conn);
	if ( $response =~ /^-ERR/i ) {
	   Log("Error logging into the POP server as $popUser: $response");
	   $rc = 0;
	   last;
	}
        last if $response =~ /^(.+)OK Pass required/i;
        last if $response =~ /^(.+)OK /i;
   }

   Log("Send the password") if $debug;
   sendCommand ($conn, "PASS $pwd" );
   while ( 1 ) {
        readResponse ($conn);
	if ( $response =~ /^-ERR/i ) {
	   Log("Error logging into the POP server as $popUser: $response");
	   $rc = 0;
	   last;
	}
        if ( $response =~ /^\+OK/i ) {
	   $rc = 1;
	   Log("Logged in as $popUser") if $debug;
           last;
	}
   }

   return $rc;

}

#  loginIMAP
#
#  login in to the IMAP server
#
sub loginIMAP {

my $user = shift;
my $pwd  = shift;
my $conn = shift;

Log("imap user $user");
Log("pwd  $pwd");

   if ( $admin_user ) {
      #  An AUTHENTICATE = PLAIN login has been requested
      ($authuser,$pwd) = split(/:/, $admin_user);
      ($user) = split(/:/, $user);
      my $status = login_plain( $user, $authuser, $pwd, $conn );
      return $status;
   }
   
   if ( $pwd =~ /^oauth2:(.+)/i ) {
      $token = $1;
      Log("password is an OAUTH2 token");
      $status = login_xoauth2( $user, $token, $conn );
      return $status;
   }

   sendCommand ($conn, "1 LOGIN $user $pwd");
   while (1) {
	readResponse ($conn);
	if ($response =~ /^1 OK/i) {
		last;
	}
	elsif ($response !~ /^\*/) {
		Log ("Error logging into the IMAP server as $user: $response");
		return 0;
	}
   }
   Log("Logged in at $imapHost as $user") if $debug;

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
   sendCommand ($conn, "1 AUTHENTICATE PLAIN $login_str" );

   my $loops;
   while (1) {
        readResponse ( $conn );
        last if $response =~ /^1 OK/;
        if ($response =~ /^1 NO|^1 BAD|^\* BYE/i) {
           Log ("unexpected LOGIN response: $response");
           return 0;
        }
        if ( $response =~ /Microsoft Exchange/i and $conn eq $dst ) {
           #  The destination is an Exchange server
           $exchange = 1;
           Log("The destination is an Exchange server");
        }
        $last if $loops++ > 5;
   }

   return 1;

}

#  login_xoauth2
#
#  login in at the source host with the user's name and an XOAUTH2 token.  
#
sub login_xoauth2 {

my $user      = shift;
my $token     = shift;
my $conn      = shift;

   #  Do an AUTHENTICATE = XOAUTH2 login

   $login_str = encode_base64("user=". $user ."\x01auth=Bearer ". $token ."\x01\x01", '');
   sendCommand ($conn, "1 AUTHENTICATE XOAUTH2 $login_str" );

   my $loops;
   while (1) {
        readResponse ( $conn );
        if ( $response =~ /^\+ (.+)/ ) {
           $error = decode_base64( $1 );
           Log("XOAUTH authentication as $user failed: $error");
           return 0;
        }
        last if $response =~ /^1 OK/;
        if ($response =~ /^1 NO|^1 BAD|^\* BYE|failed/i) {
           Log ("unexpected LOGIN response: $response");
           return 0;
        }
        $last if $loops++ > 5;
   }

   Log("login complete") if $debug;

   return 1;

}

#
#  getPOPMsgList
#
#  Get a list of the messages in the POP user's account.
#
sub getPOPMsgList {

my $conn = shift;
my @msgList;

   sendCommand ($conn, "LIST" );
   while ( 1 ) {
	readResponse ($conn);

	next if $response =~ /^\+OK/i;
	if ( $response =~ /^\-ERR/i ) {
	   Log("Error getting list of POP messages: $response");
	}
        elsif ( $response eq '.' ) {
	   last;
	}
	else {
	   ($msgnum, $uid) = split(/ /, $response);
	   push(@msgList, $msgnum);
	}
   }

   return @msgList;
}


#
#  getPOPMsg
#
#  Fetch a message from the user's account on the POP server

sub getPOPMsg { 

my $msgnum = shift;
my $conn   = shift;
my $msg;

   sendCommand ($conn, "RETR $msgnum" );
   while ( 1 ) {
        readResponse ($conn);
        # Log("$response");

        next if $response =~ /^\+OK/i;

        if ( $response =~ /^\-ERR/i ) {
           Log("Error getting POP message $msg: $response");
	   $msg = '';
	   last;
        }
        elsif ( $response eq '.' ) {
           last;
        }
	else {
	   $msg .= "$response\r\n";
 	}
   }

   return $msg;

}


#
#  deletePOPMsg
#
#  Delete a message from the POP server

sub deletePOPMsg { 

my $msgnum = shift;
my $conn   = shift;
my $msg;

   sendCommand ($conn, "DELE $msgnum" );
   while ( 1 ) {
        readResponse ($conn);
        Log("$response") if $debug;

        last if $response =~ /^\+OK/i;

        if ( $response =~ /^\-ERR/i ) {
           Log("Error marking POP message $msg for delete: $response");
	   last;
        }
   }
   return;

}


#  readResponse
#
#  Read the response from the server on the designated socket.
#
sub readResponse {

my $fd = shift;

    @response = ();
    alarmSet ($timeout);
    $response = <$fd>;
    alarmSet (0);
    chop $response;
    $response =~ s/\r//g;
    push (@response,$response);
    Log ("<< $response") if $showIMAP;

    return $response;
}

#
#  alarmHandler
#
#  This subroutine catches response timeouts and attempts to reconnect
#  to the host so that processing can continue
#

sub alarmHandler {
    Log ("Timeout - no response from server after $timeout seconds");
    Log("Reconnect to server and continue");
	
    connectToPOP( $popHost );
    loginPOP( $popUser, $popPwd, $p_conn );

    connectToIMAP( $imapHost, $i_conn );
    loginIMAP( $imapUser, $imapPwd, $i_conn );

    return;
}


#  insertMsg
#
#  This routine inserts a messages into a user's IMAP INBOX
#
sub insertMsg {

local (*message, $mbx, $date, $flag, $conn) = @_;
local ($rsn,$lenx);

   $lenx = length($message);
   $totalBytes = $totalBytes + $lenx;
   $totalMsgs++;

   if ( $date ) {
      ($date,$time,$offset) = split(/\s+/, $date);
      ($hr,$min,$sec) = split(/:/, $time);
      $hr = '0' . $hr if length($hr) == 1;
      $date = "$date $hr:$min:$sec $offset";
      $cmd = "1 APPEND \"$mbx\" $flag \"$date\" \{$lenx\}";
   } else {
      $cmd = "1 APPEND \"$mbx\" $flag \{$lenx\}";
   }
   $cmd =~ s/\s+/ /g;
   sendCommand ($conn, "$cmd");
   readResponse ($conn);
   if ( $response !~ /^\+/ ) {
       Log ("unexpected APPEND response: $response");
       push(@errors,"Error appending message to $mbx for $user");
       return 0;
   }

   print $conn "$message\r\n";

   undef @response;
   while ( 1 ) {
       readResponse ($conn);
       if ( $response =~ /^1 OK/i ) {
	   last;
       }
       elsif ( $response !~ /^\*/ ) {
	   Log ("unexpected APPEND response: $response");
	   # next;
	   return 0;
       }
   }

   return 1;
}

#  alarmSet
#
#  This subroutine sets an alarm
#

sub alarmSet {
    local ($timeout) = @_;

    if ( $nt ) {
        alarm $timeout;
    }
}

#  Log
#
#  This subroutine formats and writes a log message to STDOUT and to the
#  logfile.
#
sub Log {

my $str = shift;
my $line;

    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
    if ($year < 99) { $yr = 2000; }
    else { $yr = 1900; }
    $line = sprintf ("%.2d-%.2d-%d.%.2d:%.2d:%.2d %s %s\n",
		     $mon + 1, $mday, $year + $yr, $hour, $min, $sec,$$,$str);

    print LOG "$line";
    print STDOUT "$str\n";
    
   if ( !$start ) {
         $start = sprintf ("%.2d-%.2d-%d %.2d:%.2d",
		     $mon + 1, $mday, $year + $yr, $hour, $min);
   }
}

#  sendCommand
#
#  This subroutine formats and sends a command  on the designated
#  socket
#
sub sendCommand {

my $fd = shift;
my $cmd = shift;

   print $fd "$cmd\r\n";
   Log (">> $cmd") if $debug;
}

#  logoutIMAP
#
#  log out from the IMAP host
#
sub logoutIMAP {

my $conn = shift;

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

#  logoutPOP
#
#  log out from the POP host
#
sub logoutPOP {

my $conn = shift;

   sendCommand ($conn, "QUIT");
   while ( 1 ) {
	readResponse ($conn);
	if ( $response =~ /^\+OK/i ) {
	   last;
	}
	else  {
	   Log ("unexpected POP QUIT response: $response");
	   last;
	}
   }
   close $conn;

}

sub summary {

   $line = "\n       Summary of POP3 -> IMAP migration\n\n";
   $line .= "Users migrated  $usersMigrated\n";
   $line .= "Total messages  $totalMsgs\n";
   $line .= "Total bytes     $totalBytes\n";

   Log($line);
   notify($notify,$line) if $notify;
}

sub usage {

   print "\n";
   print "pop3toimap.pl usage:\n";
   print "   -p <POP3 host/user/password>\n";
   print "   -i <IMAP host/user/password>\n";
   print "   -u <input file>\n";
   print "   -A <admin_user:admin_pwd>\n";
   print "   -d debug mode\n";
   print "   -n <notify e-mail address>\n";
   print "   -m <imap mailbox>  Default is INBOX. Format is mbx1/mbx2/mbx3\n";
   print "   -r delete POP3 message after migrating to IMAP\n";
   print "   -t <timeout>\n";
   print "   -L <logfile>\n";
   print "   -I show IMAP protocol exchanges\n";
   print "   -h print this message\n\n";
   print "\nYou can migrate a single user with -p POPhost/user/pwd -i IMAPhost/user/pwd\n";
   print "or a list of users with -i POPhost -i IMAPhost -u <list of users>.\n";
   print "The format of the input file is:\n\n";
   print "<POP3 username> <POP3 user password> <IMAP username> <IMAP user password>\n\n"; 

   exit;
}

#
#  Send an e-mail with the results of the migration
#
sub notify {

my $to = shift;
my $text = shift;

   Log("Notifying $to") if $debug;

   $end = sprintf ("%.2d-%.2d-%d %.2d:%.2d\n",
                     $mon + 1, $mday, $year + $yr, $hour, $min);

   $msgFn = "/tmp/msg.tmp.$$";
   open (MSG, ">$msgFn");
   print MSG "To: $to\n";
   print MSG "From: pop3toimap.migration\n";
   print MSG "Subject: pop3toimap migration has completed $end\n";
   print MSG "\n";
   print MSG "$line\n\n";
   print MSG "Start $start\n";
   print MSG "End   $end\n";
   close MSG;

   $status = system("/usr/lib/sendmail -t < $msgFn")/256;
   if ($status != 0) {
      print "Error sending report to $notify: $status\n";
   }
   unlink $msgFn;

}

sub getFlag {

my $msg  = shift;
my $flag = shift;

   #  The POP3 protocol does not indicate whether a message is SEEN or
   #  UNSEEN so we will look in the message itself for a Status: line.
   $$flag = '';
   foreach $_ ( split(/\n/, $$msg) ) {
      chomp;
      last unless $_;
      if ( /Status/i ) {
         $$flag = '(\\SEEN)' if /^Status:\s*R/i;
         last;
      }
   }

}

sub getDate {

my $msg  = shift;
my $Date = shift;
my $letter;
my $newdate;

   $$Date = '';
   foreach $line ( split(/\n/, $$msg) ) {
      next unless $line =~ /^Date: (.+)/i;
      chomp( $date = $1 );
      $date =~ s/\n|\r//g;
      ($day,$date) = split(/,\s*/, $date);

      my $changed;
      for $i ( 0 .. length($date) ) {
         $letter = substr($date, $i, 1);
         if ( substr($date, $i, 1) eq ' ') {
            $letter = "-" unless $changed > 1;
            $changed++;
         } 
         $newdate .= $letter;
      }
      last;
   }
   $newdate =~ s/EDT|EST|CDT|CST|PDT|PST|\(|\)/+0000/g;
   $newdate =~ s/\s+$//;
   unless ( $newdate =~ /\-(.+)\s*$/ ) {
       $newdate .= " -0000";
   }

   $newdate = '' if $newdate eq " -0000";

   $$Date = $newdate;

}

sub createMbx {

my $mbx  = shift;
my $conn = shift;

   #  Create the mailbox if necessary
   
   sendCommand ($conn, "1 CREATE \"$mbx\"");
   while ( 1 ) {
      readResponse ($conn);
      last if $response =~ /^1 OK/i;
      last if $response =~ /already exists/i;
      if ( $response =~ /^1 NO|^1 BAD|^\* BYE/ ) {
         Log ("Error creating $mbx: $response");
         last;
      }
      
   } 

}

sub namespace {

my $conn      = shift;
my $prefix    = shift;
my $delimiter = shift;
my $mbx_delim = shift;
my @response;

   #  Query the server with NAMESPACE so we can determine its
   #  mailbox prefix (if any) and hierachy delimiter.

   if ( $mbx_delim ) {
      #  The user has supplied a mbx delimiter and optionally a prefix.
      Log("Using user-supplied mailbox hierarchy delimiter $mbx_delim");
      ($$delimiter,$$prefix) = split(/\s+/, $mbx_delim);
      return;
   }

   @response = ();
   sendCommand( $conn, "1 NAMESPACE");
   while ( 1 ) {
      readResponse( $conn );
      push( @namespace, $response );
      if ( $response =~ /^1 OK/i ) {
         last;
      } elsif ( $response =~ /^1 NO|^1 BAD|^\* BYE/i ) {
         Log("Unexpected response to NAMESPACE command: $response");
         last;
      }
   }

   foreach $_ ( @namespace ) {
      if ( /NAMESPACE/i ) {
         my $i = index( $_, '((' );
         my $j = index( $_, '))' );
         my $val = substr($_,$i+2,$j-$i-3);
         ($val) = split(/\)/, $val);
         ($$prefix,$$delimiter) = split( / /, $val );
         $$prefix    =~ s/"//g;
         $$delimiter =~ s/"//g;
         last;
      }
      last if /^1 NO|^1 BAD|^\* BYE/;
   }

   unless ( $$delimiter ) {
      #  NAMESPACE command is not supported by the server
      #  so we will have to figure it out another way.
      $delim = getDelimiter( $conn );
      $$delimiter = $delim;
      $$prefix = '';
   }

   if ( $debug ) {
      Log("prefix  >$$prefix<");
      Log("delim   >$$delimiter<");
   }
}

sub mailboxName {

my $mailbox    = shift;
my $prefix = shift;
my $delim  = shift;
my $substChar = '_';

   #  Apply the prefix and mailbox delimiter to the 
   #  mailbox name

   if ( $prefix ) {
      $mailbox = $prefix . $mailbox;
   }
   if ( $delim ) {
      $mailbox =~ s/\//$delim/g;
   }

   return $mailbox;

}

sub getDelimiter  {

my $conn = shift;
my $delimiter;

   #  Issue a 'LIST "" ""' command to find out what the
   #  mailbox hierarchy delimiter is.

   sendCommand ($conn, '1 LIST "" ""');
   @response = '';
   while ( 1 ) {
	readResponse ($conn);
	if ( $response =~ /^1 OK/i ) {
		last;
	}
	elsif ( $response !~ /^\*/ ) {
		Log ("unexpected response: $response");
		return 0;
	}
   }

   for $i (0 .. $#response) {
        $response[$i] =~ s/\s+/ /;
        if ( $response[$i] =~ /\* LIST \((.*)\) "(.*)" "(.*)"/i ) {
           $delimiter = $2;
        }
   }

   return $delimiter;
}

sub mbxExists {

my $mbx  = shift;
my $conn = shift;
my $status = 1;

   #  Determine whether a mailbox exists
   sendCommand ($conn, "1 EXAMINE \"$mbx\"");
   while (1) {
        readResponse ($conn);
        last if $response =~ /^1 OK/i;
        if ( $response =~ /^1 NO|^1 BAD|^\* BYE/ ) {
           $status = 0;
           last;
        }
   }

   return $status;
}

sub selectMbx {

my $mbx = shift;
my $conn = shift;

   #  Some IMAP clients such as Outlook and Netscape) do not automatically list
   #  all mailboxes.  The user must manually subscribe to them.  This routine
   #  does that for the user by marking the mailbox as 'subscribed'.

   sendCommand( $conn, "1 SUBSCRIBE \"$mbx\"");
   while ( 1 ) {
      readResponse( $conn );
      if ( $response =~ /^1 OK/i ) {
         Log("Mailbox $mbx has been subscribed") if $debug;
         last;
      } elsif ( $response =~ /^1 NO|^1 BAD|\^* BYE/i ) {
         Log("Unexpected response to subscribe $mbx command: $response");
         last;
      }
   }

   #  Now select the mailbox
   sendCommand( $conn, "1 SELECT \"$mbx\"");
   while ( 1 ) {
      readResponse( $conn );
      if ( $response =~ /^1 OK/i ) {
         last;
      } elsif ( $response =~ /^1 NO|^1 BAD|^\* BYE/i ) {
         Log("Unexpected response to SELECT $mbx command: $response");
         last;
      }
   }

}


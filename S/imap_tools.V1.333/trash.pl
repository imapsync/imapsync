#!/usr/bin/perl

# $Header: /mhub4/sources/imap-tools/trash.pl,v 1.5 2014/10/16 01:18:31 rick Exp $

#######################################################################
#   Description                                                       #
#                                                                     #
#   This script checks a user's IMAP mailboxes for deleted messages   #
#   which it moves to the trash mailbox.  Optionally the trash        #
#   mailbox is emptied.                                               #       
#                                                                     #
#   trash.pl is called like this:                                     #
#       ./trash.pl -S host/user/password                              # 
#                                                                     #
#   Optional arguments:                                               #
#       -i <user file>  format: user password, omit pwd if -a         #
#	-d debug                                                      #
#       -t <trash mailbox name> (defaults to 'Trash')                 #
#       -e empty the trash mailbox (default is not to empty it)       #
#       -a <admin user:admin password>                                #
#       -L <logfile>                                                  #
#       -m mailbox list (check just certain mailboxes,see usage notes)#
#######################################################################

use Socket;
use FileHandle;
use Fcntl;
use Getopt::Std;
use MIME::Base64 qw(encode_base64 decode_base64);
use IO::Socket::INET;
use IO::Socket::SSL;

#################################################################
#            Main program.                                      #
#################################################################

init();
sigprc();

$n = scalar @users;
Log("There are $n users");

foreach $_ ( @users ) {
   s/^\s+|\s$//g;
   ($sourceUser,$sourcePwd) = split(/\s+/, $_);
   Log("$sourceUser");

   #  Get list of all messages on the source host by Message-Id
   #
   next unless connectToHost($sourceHost, \$src );

   if ( $admin_user ) {
      #  Do an admin login using AUTHENTICATION = PLAIN
      Log( "Login admin:" .$sourceUser."---". $admin_user ."---". $admin_pwd ) if $verbose;
      login_plain( $sourceUser, $admin_user, $admin_pwd, $src );
   } else {
      Log("Normal:".$sourceUser ."---".$sourcePwd) if $verbose;
      next unless login($sourceUser,$sourcePwd, $src);
   }

   createMbx( $trash, $src ) unless mbxExists( $trash, $src);

   @mbxs = getMailboxList($sourceUser, $src);

   Log("Checking mailboxes for deleted messages") if $debug;
   $total=0;
   foreach $mbx ( @mbxs ) {
       next if $mbx eq $trash;
       next if $nosel_mbxs{"$mbx"};
       Log("   Checking mailbox $mbx") if $verbose;
       %msgList = ();
       @sourceMsgs = ();
       find_deleted_msgs( $mbx, \$msglist, $src ); 
       moveToTrash( $mbx, $trash, \$msglist, $src );
       expungeMbx( $mbx, $src );
   }

   Log("$total messages were moved to $trash");

   if ( $emptyTrash and ($total > 0) ) {
      expungeMbx( $trash, $src );
      Log("The $trash mailbox has been emptied");
   }

   logout( $src );

   $total_users++;
   $total_moved += $total;
}

Log("Done.");
Log("Summary:");
Log("   Users processed  $total_users");
Log("   Messages moved   $total_moved");
exit;


sub init {

   $version = 'V1.0';
   $os = $ENV{'OS'};

   &processArgs;

   if ($timeout eq '') { $timeout = 60; }

   #  Open the logFile
   #
   if ( $logfile ) {
      if ( !open(LOG, ">> $logfile")) {
         print STDOUT "Can't open $logfile: $!\n";
      } 
      select(LOG); $| = 1;
   }
   Log("\n$0 starting");
   $total=0;

   #  Determine whether we have SSL support via openSSL and IO::Socket::SSL
   $ssl_installed = 1;
   eval 'use IO::Socket::SSL';
   if ( $@ ) {
      $ssl_installed = 0;
   }
}

#
#  sendCommand
#
#  This subroutine formats and sends an IMAP protocol command to an
#  IMAP server on a specified connection.
#

sub sendCommand
{
    local($fd) = shift @_;
    local($cmd) = shift @_;

    print $fd "$cmd\r\n";

    if ($showIMAP) { Log (">> $cmd",2); }
}

#
#  readResponse
#
#  This subroutine reads and formats an IMAP protocol response from an
#  IMAP server on a specified connection.
#

sub readResponse
{
    local($fd) = shift @_;

    $response = <$fd>;
    chop $response;
    $response =~ s/\r//g;
    push (@response,$response);
    if ($showIMAP) { Log ("<< $response",2); }
}

#
#  Log
#
#  This subroutine formats and writes a log message to STDERR.
#

sub Log {
 
my $str = shift;

   #  If a logile has been specified then write the output to it
   #  Otherwise write it to STDOUT

   if ( $logfile ) {
      ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
      if ($year < 99) { $yr = 2000; }
      else { $yr = 1900; }
      $line = sprintf ("%.2d-%.2d-%d.%.2d:%.2d:%.2d %s %s\n",
		     $mon + 1, $mday, $year + $yr, $hour, $min, $sec,$$,$str);
      print LOG "$line";
   } 
   print STDOUT "$str\n";

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
      );

      unless ( $$conn ) {
        $error = IO::Socket::SSL::errstr();
        Log("Error connecting to $host: $error");
        return 0;
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
        return 0;
      }
   } 
   Log("Connected to $host on port $port") if $debug;

   return 1;
}


#  trim
#
#  remove leading and trailing spaces from a string
sub trim {
 
local (*string) = @_;

   $string =~ s/^\s+//;
   $string =~ s/\s+$//;

   return;
}


#  login
#
#  login in at the source host with the user's name and password
#
sub login {

my $user = shift;
my $pwd  = shift;
my $conn = shift;

   if ( $pwd =~ /^oauth2:(.+)/i ) {
      $token = $1;
      Log("password is an OAUTH2 token");
      $status = login_xoauth2( $user, $token, $conn );
      return $status;
   }

   sendCommand ($conn, "1 LOGIN $user $pwd");
   while (1) {
	readResponse ( $conn );
	if ($response =~ /^1 OK/i) {
		last;
	}
	elsif ($response =~ /1 NO/) {
		Log ("unexpected LOGIN response: $response");
		return 0;
	}
   }
   Log("Logged in as $user") if $debug;

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


#  getMailboxList
#
#  get a list of the user's mailboxes from the source host
#
sub getMailboxList {

my $user = shift;
my $conn = shift;
my @mbxs;

   #  Get a list of the user's mailboxes
   #
  if ( $mbxList ) {
      #  The user has supplied a list of mailboxes so only processes
      #  the ones in that list
      @mbxs = split(/,/, $mbxList);
      for $i (0..$#mbxs ) { 
	$mbxs[$i] =~ s/^\s+//; 
	$mbxs[$i] =~ s/s+$//; 
      }
      return @mbxs;
   }

   if ($debugMode) { Log("Get list of user's mailboxes",2); }

   sendCommand ($conn, "1 LIST \"\" *");
   undef @response;
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

   %nosel_mbxs = ();
   undef @mbxs;
   for $i (0 .. $#response) {
	# print STDERR "$response[$i]\n";
	$response[$i] =~ s/\s+/ /;
	($dmy,$mbx) = split(/"\/"/,$response[$i]);
	$mbx =~ s/^\s+//;  $mbx =~ s/\s+$//;
	$mbx =~ s/"//g;

        if ($response[$i] =~ /NOSELECT/i) {
           $nosel_mbxs{"$mbx"} = 1;
        }
	if (($mbx =~ /^\#/) && ($user ne 'anonymous')) {
		#  Skip public mbxs unless we are migrating them
		next;
	}
	if ($mbx =~ /^\./) {
		# Skip mailboxes starting with a dot
		next;
	}
	push ( @mbxs, $mbx ) if $mbx ne '';
   }

   if ( $mbxList ) {
      #  The user has supplied a list of mailboxes so only processes
      #  those
      @mbxs = split(/,/, $mbxList);
   }

   return @mbxs;
}

#  getDeletedMsgs
#
#  Get a list of deleted messages in the indicated mailbox on
#  the source host
#
sub getDeletedMsgs {

my $mailbox = shift;
my $msgs    = shift;
my $conn    = shift;
my $seen;
my $empty;
my $msgnum;

   @$msgs = ();
   trim( *mailbox );
   sendCommand ($conn, "1 SELECT \"$mailbox\"");
   undef @response;
   $empty=0;
   while ( 1 ) {
	readResponse ( $conn );
	if ( $response =~ /^1 OK/i ) {
		# print STDERR "response $response\n";
		last;
        } elsif ( $response =~ / 0 EXISTS/i ) {
                $empty = 1;
	} elsif ( $response !~ /^\*/ ) {
		Log ("unexpected response: $response");
		print STDERR "Error: $response\n";
		return 0;
	}
        return 0 if $response =~ /^1 NO/;
   }

   return if $empty;

   sendCommand ( $conn, "1 FETCH 1:* (uid flags internaldate body[header.fields (Message-ID Subject)])");
   undef @response;
   while ( 1 ) {
	readResponse ( $conn );
	if ( $response =~ /^1 OK/i ) {
		# print STDERR "response $response\n";
		last;
	}
        elsif ( $response =~ /Broken pipe|Connection reset by peer/i ) {
              Log("Fetch from $mailbox: $response");
              return 0;
        }
   }

   #  Get a list of the msgs in the mailbox
   #
   undef @msgs;
   undef $flags;
   for $i (0 .. $#response) {
	$seen=0;
	$_ = $response[$i];

	last if /OK FETCH complete/;

	if ( $response[$i] =~ /FETCH \(UID / ) {
	   $response[$i] =~ /\* ([^FETCH \(UID]*)/;
	   $msgnum = $1;
	}

	if ($response[$i] =~ /FLAGS/) {
	    #  Get the list of flags
            $deleted = 0;
	    $response[$i] =~ /FLAGS \(([^\)]*)/;
	    $flags = $1;
            $deleted = 1 if $flags =~ /Deleted/i;
	}
        if ( $response[$i] =~ /INTERNALDATE ([^\)]*)/ ) {
	    $response[$i] =~ /INTERNALDATE ([^BODY]*)/i; 
            $date = $1;
            $date =~ s/"//g;
	}
        if ( $response[$i] =~ /^Subject:/ ) {
	   $response[$i] =~ /Subject: (.+)/;
           $subject = $1;
        }
	if ( $response[$i] =~ /^Message-Id:/ ) {
	    ($label,$msgid) = split(/: /, $response[$i]);
            trim(*msgid);
            $msgid =~ s/^\<//;
            $msgid =~ s/\>$//;
            push( @$msgs, $msgnum ) if $deleted;
	}
   }
}


#  getDeletedMsgs
#
#  Get a list of deleted messages in the indicated mailbox on
#  the source host
#
sub OLD_getDeletedMsgs {

my $mailbox = shift;
my $msgs    = shift;
my $conn    = shift;
my $seen;
my $empty;
my $msgnum;

   trim( *mailbox );
   sendCommand ($conn, "1 SELECT \"$mailbox\"");
   undef @response;
   $empty=0;
   while ( 1 ) {
	readResponse ( $conn );
	if ( $response =~ /^1 OK/i ) {
		# print STDERR "response $response\n";
		last;
        } elsif ( $response =~ / 0 EXISTS/i ) {
                $empty = 1;
	} elsif ( $response !~ /^\*/ ) {
		Log ("unexpected response: $response");
		print STDERR "Error: $response\n";
		return 0;
	}
        return 0 if $response =~ /^1 NO/;
   }

   return if $empty;

   sendCommand ( $conn, "1 FETCH 1:* (uid flags internaldate body[header.fields (Message-ID Subject)])");
   undef @response;
   while ( 1 ) {
	readResponse ( $conn );
	if ( $response =~ /^1 OK/i ) {
		# print STDERR "response $response\n";
		last;
	}
        elsif ( $response =~ /Broken pipe|Connection reset by peer/i ) {
              Log("Fetch from $mailbox: $response");
              return 0;
        }
   }

   #  Get a list of the msgs in the mailbox
   #
   undef @msgs;
   undef $flags;
   for $i (0 .. $#response) {
	$seen=0;
	$_ = $response[$i];

	last if /OK FETCH complete/;

	if ( $response[$i] =~ /FETCH \(UID / ) {
	   $response[$i] =~ /\* ([^FETCH \(UID]*)/;
	   $msgnum = $1;
	}

	if ($response[$i] =~ /FLAGS/) {
	    #  Get the list of flags
            $deleted = 0;
	    $response[$i] =~ /FLAGS \(([^\)]*)/;
	    $flags = $1;
            $deleted = 1 if $flags =~ /Deleted/i;
	}
        if ( $response[$i] =~ /INTERNALDATE ([^\)]*)/ ) {
	    $response[$i] =~ /INTERNALDATE ([^BODY]*)/i; 
            $date = $1;
            $date =~ s/"//g;
	}
        if ( $response[$i] =~ /^Subject:/ ) {
	   $response[$i] =~ /Subject: (.+)/;
           $subject = $1;
        }
	if ( $response[$i] =~ /^Message-Id:/ ) {
	    ($label,$msgid) = split(/: /, $response[$i]);
            trim(*msgid);
            $msgid =~ s/^\<//;
            $msgid =~ s/\>$//;
            push( @$msgs, $msgnum ) if $deleted;
	}
   }
}


sub fetchMsg {

my $msgnum = shift;
my $mbx    = shift;
my $conn   = shift;
my $message;

   Log("   Fetching msg $msgnum...") if $debug;
   sendCommand ($conn, "1 SELECT \"$mbx\"");
   while (1) {
        readResponse ($conn);
	last if ( $response =~ /^1 OK/i );
        return 0 if $response =~ /^1 NO/;
   }

   sendCommand( $conn, "1 FETCH $msgnum (rfc822)");
   while (1) {
	readResponse ($conn);
	if ( $response =~ /^1 OK/i ) {
		$size = length($message);
		last;
	} 
	elsif ($response =~ /message number out of range/i) {
		Log ("Error fetching uid $uid: out of range",2);
		$stat=0;
		last;
	}
	elsif ($response =~ /Bogus sequence in FETCH/i) {
		Log ("Error fetching uid $uid: Bogus sequence in FETCH",2);
		$stat=0;
		last;
	}
	elsif ( $response =~ /message could not be processed/i ) {
		Log("Message could not be processed, skipping it ($user,msgnum $msgnum,$destMbx)");
		push(@errors,"Message could not be processed, skipping it ($user,msgnum $msgnum,$destMbx)");
		$stat=0;
		last;
	}
	elsif 
	   ($response =~ /^\*\s+$msgnum\s+FETCH\s+\(.*RFC822\s+\{[0-9]+\}/i) {
		($len) = ($response =~ /^\*\s+$msgnum\s+FETCH\s+\(.*RFC822\s+\{([0-9]+)\}/i);
		$cc = 0;
		$message = "";
		while ( $cc < $len ) {
			$n = 0;
			$n = read ($conn, $segment, $len - $cc);
			if ( $n == 0 ) {
				Log ("unable to read $len bytes");
				return 0;
			}
			$message .= $segment;
			$cc += $n;
		}
	}
   }

   return $message;

}


sub usage {

   print STDOUT "usage:\n";
   print STDOUT " trash.pl -S sourceHost/sourceUser/sourcePassword\n";
   print STDOUT " Optional arguments:\n";
   print STDOUT "    -d debug\n";
   print STDOUT "    -v verbose\n";
   print STDOUT "    -I log IMAP commands and responses\n";
   print STDOUT "    -t <trash mailbox name>\n";
   print STDOUT "    -e empty trash mailbox\n";
   print STDOUT "    -L <logfile>\n";
   print STDOUT "    -m <mailbox list> (eg \"Inbox, Drafts, Notes\". Default is all mailboxes)\n";
   print STDOUT "    -a <admin_user:admin_password>\n";
   exit;

}

sub processArgs {

   if ( !getopts( "dvS:L:m:ht:ei:a:I" ) ) {
      usage();
   }

   ($sourceHost,$sourceUser,$sourcePwd) = split(/\//, $opt_S);
   $userList = $opt_i;
   $mbxList = $opt_m;
   $logfile = $opt_L;
   $trash   = $opt_t;
   $admin_user = $opt_a;
   Log("Admin user:" . $admin_user ) if $verbose;
   $emptyTrash = 1 if $opt_e;
   $debug      = 1 if $opt_d;
   $verbose    = 1 if $opt_v;
   $showIMAP   = 1 if $opt_I;

   usage() if $opt_h;
   $trash = 'Trash' if !$trash;

   if ( $userList ) {
      if ( !open(F, "<$userList") ) {
         Log("Error opening userlist $userList: $!");
         exit;
      }
      while( <F> ) {
         chomp;
         s/^\s+//;
         next if /^#/;
         push( @users, $_ );
      }
      close F;
   } else {
      push( @users, "$sourceUser $sourcePwd" );
   }

   if ( $admin_user ) {
      $admin_user =~ /(.+):(.+)/;
      $admin_user = $1;
      $admin_pwd  = $2;
   }

}

sub expungeMbx {

my $mbx   = shift;
my $conn  = shift;

   Log("      Purging mailbox $mbx") if $debug;

   sendCommand ($conn, "1 SELECT \"$mbx\"");
   while (1) {
        readResponse ($conn);
        last if ( $response =~ /^1 OK/i );
        return 0 if $response =~ /^1 NO/;
   }

   sendCommand ( $conn, "1 EXPUNGE");
   $expunged=0;
   while (1) {
        readResponse ($conn);
        $expunged++ if $response =~ /\* (.+) Expunge/i;
        last if $response =~ /^1 OK/;

	if ( $response =~ /^1 BAD|^1 NO/i ) {
	   print "Error purging messages: $response\n";
	   last;
	}
   }

   $totalExpunged += $expunged;

}


sub dieright {
   local($sig) = @_;
   print STDOUT "caught signal $sig\n";
   logout( $src );
   exit(-1);
}

sub sigprc {

   $SIG{'HUP'} = 'dieright';
   $SIG{'INT'} = 'dieright';
   $SIG{'QUIT'} = 'dieright';
   $SIG{'ILL'} = 'dieright';
   $SIG{'TRAP'} = 'dieright';
   $SIG{'IOT'} = 'dieright';
   $SIG{'EMT'} = 'dieright';
   $SIG{'FPE'} = 'dieright';
   $SIG{'BUS'} = 'dieright';
   $SIG{'SEGV'} = 'dieright';
   $SIG{'SYS'} = 'dieright';
   $SIG{'PIPE'} = 'dieright';
   $SIG{'ALRM'} = 'dieright';
   $SIG{'TERM'} = 'dieright';
   $SIG{'URG'} = 'dieright';
}

sub moveToTrash {

my $mbx     = shift;
my $trash   = shift;
my $msglist = shift;
my $conn    = shift;
my $moved;

   return if $mbx eq $trash;
   return if $$msglist eq '';

   my @moved = split(/,/, $$msglist);
   $moved = scalar @moved;

   sendCommand ($conn, "1 COPY $$msglist $trash");
   while (1) {
        readResponse ( $conn );
        last if $response =~ /^1 OK/i;
        if ($response =~ /NO/) {
           Log("unexpected COPY response: $response");
           Log("Please verify that mailbox $trash exists");
           return 0;
        }
   }
   Log("   Moved $moved messages from $mbx to $trash");
   $total += $moved;

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

   #sendCommand ($conn, "1 AUTHENTICATE PLAIN {$len}" );
   sendCommand ($conn, "1 AUTHENTICATE PLAIN $login_str" );

   #my $loops;
   #while (1) {
        #readResponse ( $conn );
        #last if $response =~ /\+/;
        #if ($response =~ /^1 NO|^1 BAD|^\* BYE/i) {
           #Log ("unexpected LOGIN response: $response");
           #exit;
        #}
        #$last if $loops++ > 5;
   #}

   #sendCommand ($conn, "$login_str" );
   my $loops;
   while (1) {
        readResponse ( $conn );
        last if $response =~ /^1 OK/i;
        if ($response =~ /^1 NO|^1 BAD|^\* BYE/i) {
           Log ("unexpected LOGIN response: $response");
           return 0;
        }
        $last if $loops++ > 5;
   }

   return 1;

}

sub sslmode {

my $host = shift;
my $port = shift;
my $mode;

Log("CONNEXION SSL") if $verbose;
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

sub find_deleted_msgs {

my $mbx   = shift;
my $msglist = shift;
my $conn  = shift;
my $msgnum;

   #  Issue a SEARCH DELETED command to get a list of messages
   #  marked for deletion.

   $$msglist = '';
   Log("SELECT $mbx") if $debug;
   sendCommand ( $conn, "1 SELECT \"$mbx\"");
   while (1) {
	readResponse ($conn);
	last if $response =~ /^1 OK/;
        return 0 if $response =~ /^1 NO/;
   }

   Log("Search for $msgid") if $debug;
   sendCommand ( $conn, "1 SEARCH DELETED");
   while (1) {
	readResponse ($conn);
	if ( $response =~ /\* SEARCH /i ) {
	   ($dmy, $$msglist) = split(/\* SEARCH /i, $response, 2);
           $$msglist =~ s/\s+/,/g;
           Log("msglist $$msglist") if $debug;
	}

	last if $response =~ /^1 OK/;
	last if $response =~ /complete/i;
   }

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
      if ( $response eq ''  or $response =~ /^1 NO/ ) {
         Log ("unexpected CREATE response: >$response<");
         Log("response is NULL");
         resume();
         last;
      }
      
   } 

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


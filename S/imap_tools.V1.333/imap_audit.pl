#!/usr/bin/perl

# $Header: /mhub4/sources/imap-tools/imap_audit.pl,v 1.21 2015/06/15 15:34:50 rick Exp $

#######################################################################
#  imap_audit is used to compare the contents of a user's account on  #
#  one IMAP server with an account on another IMAP server.  It is     #
#  often useful after migrating a user to another server to ensure    #
#  that all messages were successfully copied.                        #
#                                                                     #
#  See usage() for the command-line arguments                         #
#######################################################################

use Socket;
use IO::Socket;
use IO::Socket::INET;
use FileHandle;
use Fcntl;
use Getopt::Std;
use MIME::Base64 qw( encode_base64 decode_base64 );

init();

foreach $user ( @users ) {
   $user =~ s/oauth2:/oauth2---/g;
   ($sourceUser,$sourcePwd,$destUser,$destPwd) = split(/:/, $user);
   Log("Auditing $sourceUser");

   #  Get list of all messages on the source host by Message-Id
   #
   connectToHost($sourceHost, \$src)    or exit;
   if ( $kerio_src_master_pwd ) {
      next unless kerio_master_login( $kerio_src_master_pwd, $sourceUser, $src );
   } elsif ( $src_admin_user ) {
      #  An AUTHENTICATE = PLAIN login has been requested
      next unless login_plain( $sourceUser, $src_admin_user, $src );
   } else {
      #  Otherwise do an ordinary login
      next unless login($sourceUser,$sourcePwd, $src);
   }

   namespace( $src, \$srcPrefix, \$srcDelim, $opt_x );

   connectToHost( $destHost, \$dst ) or exit;
   if ( $kerio_dst_master_pwd ) {
      next unless kerio_master_login( $kerio_dst_master_pwd, $destUser, $dst );
   } elsif ( $dst_admin_user ) {
      #  An AUTHENTICATE = PLAIN login has been requested
      next unless login_plain( $destUser, $dst_admin_user, $dst );
   } else {
      #  Otherwise do an ordinary login
      next unless login($destUser,$destPwd, $dst);
   }
   namespace( $dst, \$dstPrefix, \$dstDelim, $opt_x );

   my @source_mbxs = getMailboxList( $src );

   #  Exclude certain ones if that's what the user wants
   exclude_mbxs( \@source_mbxs ) if $excludeMbxs;

   map_mbx_names( \%mbx_map, $srcDelim, $dstDelim );

   #  Check for missing messages
   check( \@source_mbxs, \%REVERSE, $src, $dst );

   if ( $msg_counts ) {
      Log("$missing");
   }

   logout( $src );
   logout( $dst );

}

exit;

sub init {

   $os = $ENV{'OS'};

   processArgs();

   if ( $users_file ) {
      ($sourceHost) = split(/\//, $opt_S);
      ($destHost)   = split(/\//, $opt_D);
      if ( !open(U, "<$users_file") ) {
         print STDERR "Error opening users file $users_file: $!\n";
         exit;
      }
      my $n;
      while( <U> ) {
         $n++;
         s/^\s+//g;
         next if /^#/;
         chomp;
         next unless $_;
if ( 0 ) {
         if ( !/(.+):(.+):(.+):(.+)/ ) {
            print STDERR "Error at line $n in users file\n";
            print STDERR "Not in srcuser:srcpwd:dstuser:dstpwd format\n";
            exit;
         } 
}
         push( @users, $_ );
      }
      close U;

   } else {
      ($sourceHost,$sourceUser,$sourcePwd) = split(/\//, $opt_S);
      ($destHost,  $destUser,  $destPwd)   = split(/\//, $opt_D);
      push( @users, "$sourceUser:$sourcePwd:$destUser:$destPwd" );
   }

   $timeout = 60 unless $timeout;

   #  Open the logFile
   #
   if ( $logfile ) {
      if ( !open(LOG, ">>$logfile")) {
         print STDOUT "Can't open $logfile: $!\n";
      } 
      # select(LOG); $| = 1;
   }
   Log("$0 starting\n");

   #  Determine whether we have SSL support via openSSL and IO::Socket::SSL
   $ssl_installed = 1;
   eval 'use IO::Socket::SSL';
   if ( $@ ) {
      $ssl_installed = 0;
   }

   validate_date( $before_date ) if $before_date;
   validate_date( $after_date )  if $after_date;

   Log("Generating dummy message-ids for each message") if $generate_msgids;
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

    if ( $response =~ /^\* BYE/ ) {
       # Log("The server closed the connection:  $response ");
       # exit;
    }
}

#
#  Log
#
#  This subroutine formats and writes a log message to STDERR.
#

sub Log {
 
my $str = shift;

   #  If a logfile has been specified then write the output to it
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

   # print STDOUT "$str\n" if $opt_Q;

}

#  insertMsg
#
#  This routine inserts an RFC822 messages into a user's folder
#

sub insertMsg {

local ($conn, $mbx, *message, $flags, $date, $msgid) = @_;
local ($lenx);

   Log("Inserting message $msgid") if $debug;
   $lenx = length($message);
   $totalBytes = $totalBytes + $lenx;
   $totalMsgs++;

   $flags = flags( $flags );
   fixup_date( \$date );

   sendCommand ($conn, "1 APPEND \"$mbx\" ($flags) \"$date\" \{$lenx\}");
   readResponse ($conn);
   if ( $response !~ /^\+/ ) {
       Log ("unexpected APPEND response: $response");
       # next;
       push(@errors,"Error appending message to $mbx for $user");
       return 0;
   }

   print $conn "$message\r\n";

   undef @response;
   my $i;
   while ( 1 ) {
       readResponse ($conn);
       last if $i++ > 9999999;
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

#  Make a connection to an IMAP host

sub connectToHost {

my $host = shift;
my $conn = shift;

   Log("Connecting to $host") if $verbose;
   
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
      Log("Attempting an SSL connection") if $verbose;
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
        exit;
      }
   } 
   Log("Connected to $host on port $port") if $verbose;

   return 1;
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

   if ( $admin_user ) {
      #  An AUTHENTICATE = PLAIN login has been requested
      ($authuser,$pwd) = split(/:/, $admin_user);
      ($user) = split(/:/, $user);
      my $status = login_plain( $user, $authuser, $pwd, $conn );
      return $status;
   }
 
   if ( $pwd =~ /^oauth2---(.+)/i ) {
      $token = $1;
      Log("password is an OAUTH2 token");
      login_xoauth2( $user, $token, $conn );
      return 1;
   }

   #  Otherwise do a normal login

   unless ( $user and $pwd ) {
      Log("You must supply both user and password in the users file (user:pwd)");
      return 0;
   }

   sendCommand ($conn, "1 LOGIN \"$user\" \"$pwd\"");
   my $i;
   while (1) {
	readResponse ( $conn );
        last if $i++ > 9999;
	if ($response =~ /^1 OK/i) {
		last;
	}
	elsif ($response =~ /NO|BYE|BAD/) {
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
my $conn      = shift;

   #  Do an AUTHENTICATE = PLAIN.  If an admin user has been provided then use it.

   my ($admin_user,$pwd) = split(/:/, $admin, 2);

   $login_str = sprintf("%s\x00%s\x00%s", $user,$admin_user,$pwd);
   $login_str = encode_base64("$login_str", "");
   $len = length( $login_str );

   sendCommand ($conn, "1 AUTHENTICATE PLAIN $login_str" );

   my $loops;
   while (1) {
        readResponse ( $conn );
        last if $response =~ /^1 OK/;
        if ($response =~ /^1 NO|^1 BAD|^\* BYE/i) {
           Log ("unexpected LOGIN response: $response");
           return 0;
        }
        $last if $loops++ > 5;
   }

   return 1;

}



sub kerio_master_login {

my $pwd   = shift;
my $user  = shift;
my $conn  = shift;

   sendCommand ($conn, "1 X-MASTERAUTH");
   while (1) {
        readResponse ( $conn );
        last if $response =~ /^\+/;
        if ($response =~ /^1 NO|^1 BAD|^\* BYE/i) {
           Log ("unexpected LOGIN response: $response");
           return 0;
        }
   }

   my ($challenge) = $response =~ /^\+ (.+)/;
   my $string = $challenge . $pwd;
   my $challenge_response = md5_hex( $string );

   if ( $debug ) {
      Log("challenge $challenge");
      Log("pwd       $pwd");
      Log("sending   $challenge_response");
   }

   sendCommand ($conn, $challenge_response);
   my $loops;
   while (1) {
        last if $loops++ > 9;
        readResponse ( $conn );
        last if $response =~ /^1 OK/i;
        if ($response =~ /^1 NO|^1 BAD|^\* BYE/i) {
           Log ("Failed to login as Kerio Master:  unexpected LOGIN response: $response");
           exit;
        }
   }

   #  Select the user

   Log("Selecting user $user") if $debug;
   sendCommand ($conn, "1 X-SETUSER \"$user\"" );
   while (1) {
        readResponse ( $conn );
        last if $response =~ /^1 OK/i;
        if ($response =~ /^1 NO|^1 BAD|^\* BYE/i) {
           Log ("unexpected LOGIN response: $response");
           return 0;
        }
   }

   Log("$user has been selected") if $debug;

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
   my $i;
   while ( 1 ) {
	readResponse ($conn);
        last if $i++ > 9999;
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

my $conn  = shift;
my $delim = shift;
my @mbxs;
my @mailboxes;

  #  Get a list of the user's mailboxes
  #
  if ( $mbxList ) {
      #  The user has supplied a list of mailboxes so only processes
      #  the ones in that list
      @mbxs = split(/,/, $mbxList);
      foreach $mbx ( @mbxs ) {
         # trim( *mbx );
         push( @mailboxes, $mbx );
      }
      return @mailboxes;
   }

   Log("Get list of mailboxes") if $verbose;

   sendCommand ($conn, "1 LIST \"\" *");
   undef @response;
   my $i;
   while ( 1 ) {
	readResponse ($conn);
        last if $i++ > 9999;
	if ( $response =~ /^1 OK/i ) {
		last;
	}
	elsif ( $response !~ /^\*/ ) {
		Log ("unexpected response: $response");
		return 0;
	}
   }

   @mbxs = ();

   for $i (0 .. $#response) {
        $response[$i] =~ s/\s+/ /;
        if ( $response[$i] =~ /"$/ ) {
           $response[$i] =~ /\* LIST \((.*)\) "(.+)" "(.+)"/i;
           $mbx = $3;
        } elsif ( $response[$i] =~ /\* LIST \((.*)\) NIL (.+)/i ) {
           $mbx   = $2;
        } else {
           $response[$i] =~ /\* LIST \((.*)\) "(.+)" (.+)/i;
           $mbx = $3;
        }

	$mbx =~ s/^\s+//;  $mbx =~ s/\s+$//;

        if ($response[$i] =~ /NOSELECT/i) {
           $nosel_mbxs{"$mbx"} = 1;
        }
	if ($mbx =~ /^\#|^Public Folders/i)  {
	   #  Skip public mbxs
	   next;
	}
	push ( @mbxs, $mbx ) if $mbx ne '';
   }

   return @mbxs;
}

#  exclude_mbxs 
#
#  Exclude certain mailboxes from the list if the user
#  has provided an exclude list with the -e argument

sub exclude_mbxs {

my $mbxs = shift;
my @new_list;
my %exclude;

   foreach my $exclude ( split(/,/, $excludeMbxs ) ) {
      $exclude{"$exclude"} = 1;
   }
   foreach my $mbx ( @$mbxs ) {
      next if $exclude{"$mbx"};
      push( @new_list, $mbx );
   }

   @$mbxs = @new_list;

}

#  getMsgList
#
#  Get a list of the user's messages in the indicated mailbox on
#  the source host
#

sub getMsgList {

my $mailbox = shift;
my $msgs    = shift;
my $conn    = shift;
my $seen;
my $empty;
my $msgnum;
my $from;
my $flags;
my $msgid;
my $count;

   #  Get a list of the msgs in this mailbox

   @$msgs = ();
   trim( *mailbox );
   return if $mailbox eq "";
   sendCommand ($conn, "1 EXAMINE \"$mailbox\"");
   undef @response;
   $empty=0;
   my $i;
   while ( 1 ) {
	readResponse ( $conn );
        last if $i++ > 9999;
	if ( $response =~ / (.+) EXISTS/i ) { 
           $count = $1;
           $empty=1 if $count == 0; 
        }
	if ( $response =~ /^1 OK/i ) {
		# print STDERR "response $response\n";
		last;
	}
	elsif ( $response !~ /^\*/ ) {
		Log ("unexpected response: $response");
		# print STDERR "Error: $response\n";
		return 0;
	}
   }
              
   return $count if $msg_counts;
   return if $empty;

   sendCommand ( $conn, "1 FETCH 1:* (uid flags internaldate body[header.fields (From Date Message-ID Subject)])");
   undef @response;
   my $nulls;
   my $i;
   while ( 1 ) {
	readResponse ( $conn );
        last if $i++ > 99999;
        if ( $response eq '' ) {
           $nulls++;
           last if $nulls > 9999;
        }
	if ( $response =~ /^1 OK/i ) {
		# print STDERR "response $response\n";
		last;
	} 
        last if $response =~ /^1 NO|^1 BAD/;
   }

   @$msgs  = ();
   $flags = '';
   for $i (0 .. $#response) {
	last if $response[$i] =~ /^1 OK FETCH complete/i;

        if ($response[$i] =~ /FLAGS/) {
           #  Get the list of flags
           $response[$i] =~ /FLAGS \(([^\)]*)/;
           $flags = $1;
           $flags =~ s/\\Recent|\\Forwarded//ig;
        }

        #  Consider the < and > to be part of the message-id.
        # if ( $response[$i] =~ /^Message-ID:\s*(.+)/i ) {

        if ( $response[$i] =~ /^Message-ID:\s*(.*)/i ) {
           $msgid = $1;
           if ( $msgid eq '' ) {
              # Line-wrap, get it from the next line
              $msgid = get_wrapped_msgid( \@response, $i );
           }
           $msgid =~ s/^\s+|\s+$;//g;
           if ( $msgid =~ /imapsync$/ ) {
              #  The msgid was inserted by Gilles Lamiral's imapsync tool
              #  while being copied to the destination.  That interferes
              #  with imap_audit's checking.  Blank it out so a dummy msgid
              #  will be generated.
              $msgid = '';
           }
        }

        if ( $response[$i] =~ /^Subject:\s*(.+)/i ) {
           $subject = $1;
        }

        if ( $response[$i] =~ /^From:\s*(.+)/i ) {
           $from = $1;
        }

        if ( $response[$i] =~ /^Date:\s*(.+)/i ) {
           $header_date = $1;
           check_date( \$header_date );
        }

        if ( $response[$i] =~ /INTERNALDATE/) {
           $response[$i] =~ /INTERNALDATE (.+) BODY/i;
           $date = $1;
           
           $date =~ /"(.+)"/;
           $date = $1;
           $date =~ s/"//g;
        }

        if ( $response[$i] =~ /\* (.+) FETCH/ ) {
           ($msgnum) = split(/\s+/, $1);
        }

        if ( $response[$i] =~ /^\)/ or ( $response[$i] =~ /\)\)$/ ) ) {
           if ( $msgid eq ''  or $generate_msgids ) {
              #  The msg lacks a msgid
              $msgid = build_dummy_msgid( $header_date, $subject, $from );
           }
	   push (@$msgs,"$msgid\t$subject");
           $msgnum=$msgid=$date=$flags=$subject=$from=$header_date='';
        }
   }
}

sub createMbx {

my $mbx  = shift;
my $conn = shift;
my $created;

   #  Create the mailbox if necessary

   sendCommand ($conn, "1 CREATE \"$mbx\"");
   my $i;
   while ( 1 ) {
      readResponse ($conn);
      last if $i++ > 9999;
      if ( $response =~ /^1 OK/i ) {
         $created = 1;
         last;
      }
      last if $response =~ /already exists/i;
      if ( $response =~ /^1 NO|^1 BAD/ ) {
         Log ("Error creating $mbx: $response");
         last;
      }

   }
   Log("Created mailbox $mbx") if $created;
}

sub fetchMsg {

my $msgnum = shift;
my $conn   = shift;
my $message;

   sendCommand( $conn, "1 FETCH $msgnum (rfc822)");
   my $i;
   while (1) {
	readResponse ($conn);
        last if $i++ > 9999;
	if ( $response =~ /^1 BAD|^1 NO/i ) {
           Log("Unexpected FETCH response: $response");
           return '';
        }
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
		Log("Message could not be processed, skipping it ($user,msgnum $msgnum,$dstMbx)");
		push(@errors,"Message could not be processed, skipping it ($user,msgnum $msgnum,$dstMbx)");
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

sub fetchMsgFlags {

my $msgnum = shift;
my $conn   = shift;
my $flags;

   #  Read the IMAP flags for a message

   sendCommand( $conn, "1 FETCH $msgnum (flags)");
   my $i;
   while (1) {
        readResponse ($conn);
        last if $i++ > 9999;
        if ( $response =~ /^1 OK|^1 BAD|^1 NO/i ) {
           last;
        }
        if ( $response =~ /\* $msgnum FETCH \(FLAGS \((.+)\)\)/i ) {
           $flags = $1;
           Log("   $msgnum - flags $flags") if $verbose;
        }
   }

   return $flags;
}

sub usage {

   print STDOUT "usage:\n";
   print STDOUT " imap_audit.pl -S sourceHost/sourceUser/sourcePassword\n";
   print STDOUT "               -D destHost/destUser/destPassword\n";
   print STDOUT "               -d debug\n";
   print STDOUT "               -I show IMAP commands/responses\n";
   print STDOUT "               -E <src admin_user:admin_pwd>\n";
   print STDOUT "               -F <dst admin_user:admin_pwd>\n";
   print STDOUT "               -a <source Kerio master password>\n";
   print STDOUT "               -c <destin Kerio master password>\n";
   print STDOUT "               -L logfile\n";
   print STDOUT "               -u <file of users> format srcuser:srcpwd:dstuser:dstpwd\n";
   print STDOUT "               -B <date>\n";
   print STDOUT "               -A <date>\n";
   print STDOUT "               [-m <mbx list> comma-separated list of mbxs to check]\n";
   print STDOUT "               [-n compare only mailbox msg counts]\n";
   exit;

}

sub processArgs {

   if ( !getopts( "dvE:F:S:D:L:m:e:hIx:y:FM:s:nNQu:A:B:gnRa:c:" ) ) {
      usage();
   }

   $mbxList     = $opt_m;
   $excludeMbxs = $opt_e;
   $logfile     = $opt_L;
   $mbx_map_fn  = $opt_M;
   $sync_since  = $opt_s;
   $users_file  = $opt_u;
   $before_date = $opt_B;
   $after_date  = $opt_A;
   $src_admin_user  = $opt_E;
   $dst_admin_user  = $opt_F;
   $kerio_src_master_pwd = $opt_a;
   $kerio_dst_master_pwd = $opt_c;
   $debug    = 1 if $opt_d;
   $verbose  = 1 if $opt_v;
   $showIMAP = 1 if $opt_I;
   $generate_msgids = 1 if $opt_g;
   #  opt_N is deprecated
   $include_nosel_mbxs = 1 if $opt_N;
   $include_msgid =1 if $opt_R;
   $msg_counts = 1 if $opt_n;

   usage() if $opt_h;
   if ( $kerio_src_master_pwd or $kerio_dst_master_pwd ) {
      use Digest::MD5 qw(md5_hex);
   }

}

sub findMsg {

my $msgid = shift;
my $conn  = shift;
my $msgnum;

   # Search a mailbox on the server for a message by its msgid.

   Log("   Search for $msgid") if $verbose;
   sendCommand ( $conn, "1 SEARCH header Message-Id \"$msgid\"");
   my $i;
   while (1) {
	readResponse ($conn);
        last if $i++ > 9999;
	if ( $response =~ /\* SEARCH /i ) {
	   ($dmy, $msgnum) = split(/\* SEARCH /i, $response);
	   ($msgnum) = split(/ /, $msgnum);
	}

	last if $response =~ /^1 OK|^1 NO|^1 BAD/;
	last if $response =~ /complete/i;
   }

   if ( $verbose ) {
      Log("$msgid was not found") unless $msgnum;
   }

   return $msgnum;
}

sub deleteMsg {

my $conn   = shift;
my $msgnum = shift;
my $rc;

   #  Mark a message for deletion by setting \Deleted flag

   Log("   msgnum is $msgnum") if $verbose;

   sendCommand ( $conn, "1 STORE $msgnum +FLAGS (\\Deleted)");
   my $i;
   while (1) {
        readResponse ($conn);
        last if $i++ > 9999;
        if ( $response =~ /^1 OK/i ) {
	   $rc = 1;
	   Log("   Marked $msgid for delete") if $verbose;
	   last;
	}

	if ( $response =~ /^1 BAD|^1 NO/i ) {
	   Log("Error setting \Deleted flag for msg $msgnum: $response");
	   $rc = 0;
	   last;
	}
   }

   return $rc;

}

sub expungeMbx {

my $conn  = shift;
my $mbx   = shift;
my $status;
my $loops;

   #  Remove the messages from a mailbox

   Log("Expunging $mbx mailbox") if $verbose;
   sendCommand ( $conn, "1 EXAMINE \"$mbx\"");
   my $i;
   while (1) {
        readResponse ($conn);
        last if $i++ > 9999;
        if ( $response =~ /^1 OK/ ) {
           $status = 1;
           last;
        }

	if ( $response =~ /^1 NO|^1 BAD/i ) {
	   Log("Error selecting mailbox $mbx: $response");
	   last;
	}
        if ( $loops++ > 1000 ) {
           Log("No response to EXAMINE command, skipping this mailbox"); 
           last;
        }
   }

   return unless $status;

   sendCommand ( $conn, "1 EXPUNGE");
   my $i;
   while (1) {
        readResponse ($conn);
        last if $i++ > 9999;
        last if $response =~ /^1 OK/;

	if ( $response =~ /^1 BAD|^1 NO/i ) {
	   print "Error expunging messages: $response\n";
	   last;
	}
   }

}

sub check {

my $source_mbxs = shift;
my $REVERSE     = shift;
my $src         = shift;
my $dst         = shift;
my @sourceMsgs;

   #  Compare the contents of the user's mailboxes on the source
   #  with those on the destination.

   my $total_msgs=$total_missing=0;
   foreach my $src_mbx ( @$source_mbxs ) {
        next if $src_mbx eq "";
        next if $nosel_mbxs{"$src_mbx"};
        # Log("Mailbox $src_mbx");
        if ( $include_nosel_mbxs ) {
           #  If a mailbox was 'Noselect' on the src but the user wants
           #  it created as a regular folder on the dst then do so.  They
           #  don't hold any messages so after creating them we don't need
           #  to do anything else.
           next if $nosel_mbxs{"$src_mbx"};
        }

        $dst_mbx = mailboxName( $src_mbx,$srcPrefix,$srcDelim,$dstPrefix,$dstDelim );

        #  Record the association between source and dest mailboxes
        $$REVERSE{"$dst_mbx"} = $src_mbx;
        next if $src_mbx eq "";

        selectMbx( $src_mbx, $src, 'EXAMINE' );

	@sourceMsgs=();

        #  Get list of messages on the source

        if ( $msg_counts ) {
           #  Just get a count of messages in the mailbox
           $src_count  = getMsgList( $src_mbx, \@sourceMsgs, $src );
           $dst_count  = getMsgList( $dst_mbx, \@destMsgs,   $dst );
           if ( $src_count > $dst_count ) {
              $missing .= "$src_mbx\n   Number of source msgs = $src_count\n";
              $missing .= "   Number of dest msgs   = $dst_count\n";
           }
           next;
        } elsif ( $before_date or $after_date ) {
           Log("Get list of messages on the source") if $debug;
           getDatedMsgList( $src_mbx, $before_date, $after_date, \@sourceMsgs, $src );
        } else {
           Log("Get list of messages on the source") if $debug;
           getMsgList( $src_mbx, \@sourceMsgs, $src );
        }

        my $src_count = scalar @sourceMsgs;
        Log("   There are $src_count messages in $src_mbx on the source");

        #  Get list of messages on the destination

        Log("Get list of messages on the destination") if $debug;
        getMsgList( $dst_mbx, \@dstMsgs, $dst );
        
        my %dstMsgs;
        foreach $_ ( @dstMsgs ) {
           ($msgid) = split(/\s+/, $_, 2);
           $dstMsgs{"$msgid"} = 1;
        }
            
        #  See if any are missing from the destination

        my @missing;
        my $missing;
        foreach $srcMsg ( @sourceMsgs ) {
           $total_msgs++;
           Log("   source $srcMsg") if $debug;
           ($msgid,$subject) = split(/\s+/, $srcMsg, 2);
              
           if ( !$dstMsgs{"$msgid"} ) {
              $line = "   $subject";
              $line .= "   *** $msgid " if $include_msgid;
              push( @missing, $line);
              $missing++;
              $total_missing++;
           }
        }

        if ( $missing ) {
           Log("   There are $missing messages missing from $src_mbx on the destination");
           foreach $_ ( @missing ) {
              Log("   $_");
           }
        } else {
           Log("   There are no missing messages on the destination") unless $missing;
        }
   }

   if ( $count_msgs ) {
      Log("Total messages    $total_msgs");
      Log("Missing messages  $total_missing");
   }
}

sub namespace {

my $conn      = shift;
my $prefix    = shift;
my $delimiter = shift;
my $mbx_delim = shift;
my $namespace;

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
   my $i;
   while ( 1 ) {
      readResponse( $conn );
      last if $i++ > 9999;
      if ( $response =~ /^1 OK/i ) {
         last;
      } elsif ( $response =~ /NO|BAD/i ) {
         Log("Unexpected response to NAMESPACE command: $response");
         $namespace = 0;
         last;
      }
   }

#  if ( !$namespace and !$opt_x ) {
#     #  Not implemented yet.  Needs more testing
#     #  NAMESPACE is not supported by the server so try to 
#     #  figure out the mbx delimiter and prefix
#     $$delimiter = get_mbx_delimiter( $conn );
#     $$prefix    = get_mbx_prefix( $delimiter, $conn );
#
#     return;
#  }

   foreach $_ ( @response ) {
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
      last if /^1 NO|^1 BAD/;
   }
 
   if ( $verbose ) {
      Log("prefix  $$prefix");
      Log("delim   $$delimiter");
   }

}

sub mailboxName {

my $srcmbx    = shift;
my $srcPrefix = shift;
my $srcDelim  = shift;
my $dstPrefix = shift;
my $dstDelim  = shift;
my $direction = shift;
my $dstmbx;

   #  Adjust the mailbox name if the source and destination server
   #  have different mailbox prefixes or hierarchy delimiters.

   #  Change the mailbox name if the user has supplied mapping rules.
   if ( $mbx_map{"$srcmbx"} ) {
      $srcmbx = $mbx_map{"$srcmbx"}
   }

   $dstmbx = $srcmbx;

   if ( $srcDelim ne $dstDelim ) {
       #  Need to substitute the dst's hierarchy delimiter for the src's one
       $srcDelim = '\\' . $srcDelim if $srcDelim eq '.';
       $dstDelim = "\\" . $dstDelim if $dstDelim eq '.';
       $dstmbx =~ s#$srcDelim#$dstDelim#g;
       $dstmbx =~ s/\\//g;
   }
   if ( $srcPrefix ne $dstPrefix ) {
       #  Replace the source prefix with the dest prefix
       $dstmbx =~ s#^$srcPrefix## if $srcPrefix;
       if ( $dstPrefix ) {
          $dstmbx = "$dstPrefix$dstmbx" unless uc($srcmbx) eq 'INBOX';
       }
       $dstDelim = '\.' if $dstDelim eq '.';
       $dstmbx =~ s#^$dstDelim##;
   } 

   return $dstmbx;
}

sub flags {

my $flags = shift;
my @newflags;
my $newflags;

   #  Make sure the flags list contains only standard
   #  IMAP flags.

   return unless $flags;

   $flags =~ s/\\Recent|\\Forwarded//ig;

   foreach $_ ( split(/\s+/, $flags) ) {
      next unless substr($_,0,1) eq '\\';
      push( @newflags, $_ );
   }

   $newflags = join( ' ', @newflags );

   $newflags =~ s/\\Deleted//ig if $opt_r;
   $newflags =~ s/^\s+|\s+$//g;

   return $newflags;
}

sub createDstMbxs {

my $mbxs = shift;
my $dst  = shift;

   #  Create a corresponding mailbox on the dst for each one
   #  on the src.

   foreach my $mbx ( @$mbxs ) {
      $dstmbx = mailboxName( $mbx,$srcPrefix,$srcDelim,$dstPrefix,$dstDelim );
      createMbx( $dstmbx, $dst ) unless mbxExists( $dstmbx, $dst );
   }
}

sub mbxExists {

my $mbx  = shift;
my $conn = shift;
my $status = 1;
my $loops;

   #  Determine whether a mailbox exists

   sendCommand ($conn, "1 EXAMINE \"$mbx\"");
   my $i;
   while (1) {
        readResponse ($conn);
        last if $i++ > 9999;
        last if $response =~ /^1 OK/i;
        if ( $response =~ /^1 NO|^1 BAD/ ) {
           $status = 0;
           last;
        }
        if ( $loops++ > 1000 ) {
           Log("No response to EXAMINE command, skipping this mailbox"); 
           last;
        }
   }

   return $status;
}

sub sort_flags {

my $flags = shift;
my @newflags;
my $newflags;

   #  Make sure the flags list contains only standard
   #  IMAP flags.  Sort the list to make comparision
   #  easier.

   return unless $$flags;

   $$flags =~ s/\\Recent|\\Forwarded//ig;
   foreach $_ ( split(/\s+/, $$flags) ) {
      next unless substr($_,0,1) eq '\\';
      push( @newflags, $_ );
   }

   @newflags = sort @newflags;
   $newflags = join( ' ', @newflags );
   $newflags =~ s/^\s+|\s+$//g;

   $$flags = $newflags;
}

sub setFlags {

my $msgnum    = shift;
my $new_flags = shift;
my $old_flags = shift;
my $conn      = shift;
my $rc;

   #  Set the message flags as indicated.

   if ( $verbose ) {
      Log("old flags   $old_flags");
      Log("new flags   $new_flags");
   }

   # Clear the old flags

   sendCommand ( $conn, "1 STORE $msgnum -FLAGS ($old_flags)");
   my $i;
   while (1) {
        readResponse ($conn);
        last if $i > 9999;
        if ( $response =~ /^1 OK/i ) {
           $rc = 1;
           last;
        }

        if ( $response =~ /^1 BAD|^1 NO/i ) {
           Log("Error setting flags for msg $msgnum: $response");
           $rc = 0;
           last;
        }
   }

   # Set the new flags

   sendCommand ( $conn, "1 STORE $msgnum +FLAGS ($new_flags)");
   my $i;
   while (1) {
        readResponse ($conn);
        last if $i > 9999;
        if ( $response =~ /^1 OK/i ) {
           $rc = 1;
           last;
        }

        if ( $response =~ /^1 BAD|^1 NO/i ) {
           Log("Error setting flags for msg $msgnum: $response");
           $rc = 0;
           last;
        }
   }
}

sub selectMbx {

my $mbx  = shift;
my $conn = shift;
my $type = shift;
my $status;
my $loops;

   #  Select the mailbox. Type is either SELECT (R/W) or EXAMINE (R).

   sendCommand( $conn, "1 $type \"$mbx\"");
   my $i;
   while ( 1 ) {
      readResponse( $conn );
      last if $i++ > 9999;
      if ( $response =~ /^1 OK/i ) {
         $status = 1;
         last;
      } elsif ( $response =~ /does not exist/i ) {
         $status = 0;
         last;
      } elsif ( $response =~ /^1 NO|^1 BAD/i ) {
         Log("Unexpected response to SELECT/EXAMINE $mbx command: $response");
         last;
      }
      
      if ( $loops++ > 1000 ) {
         Log("No response to $type command, skipping this mailbox"); 
         last;
      }
   }

   return $status;

}

sub map_mbx_names {

my $mbx_map = shift;
my $srcDelim = shift;
my $dstDelim = shift;

   #  The -M <file> argument causes imapcopy to read the
   #  contents of a file with mappings between source and
   #  destination mailbox names. This permits the user to
   #  to change the name of a mailbox when copying messages.
   #
   #  The lines in the file should be formatted as:
   #       <source mailbox name>: <destination mailbox name>
   #  For example:
   #       Drafts/2008/Save:  Draft_Messages/2008/Save
   #       Action Items: Inbox
   #
   #  Note that if the names contain non-ASCII characters such
   #  as accents or diacritical marks then the Perl module
   #  Unicode::IMAPUtf7 module must be installed.

   return unless $mbx_map_fn;

   unless ( open(MAP, "<$mbx_map_fn") ) {
      Log("Error opening mbx map file $mbx_map_fn: $!");
      exit;
   }
   $use_utf7 = 0;
   while( <MAP> ) {
      chomp;
      s/[\r\n]$//;   # In case we're on Windows
      s/^\s+//;
      next if /^#/;
      next unless $_;
      ($srcmbx,$dstmbx) = split(/\s*:\s*/, $_);

      #  Unless the mailbox name is entirely ASCII we'll have to use
      #  the Modified UTF-7 character set.
      $use_utf7 = 1 unless isAscii( $srcmbx );
      $use_utf7 = 1 unless isAscii( $dstmbx );

      $srcmbx =~ s/\//$srcDelim/g;
      $dstmbx =~ s/\//$dstDelim/g;

      $$mbx_map{"$srcmbx"} = $dstmbx;

   }
   close MAP;

   if ( $use_utf7 ) {
      eval 'use Unicode::IMAPUtf7';
      if ( $@ ) {
         Log("At least one mailbox map contains non-ASCII characters.  This means you");
         Log("have to install the Perl Unicode::IMAPUtf7 module in order to map mailbox ");
         Log("names between the source and destination servers.");
         print "At least one mailbox map contains non-ASCII characters.  This means you\n";
         print "have to install the Perl Unicode::IMAPUtf7 module in order to map mailbox\n";
         print "names between the source and destination servers.\n";
         exit;
      }
   }

   my %temp;
   foreach $srcmbx ( keys %$mbx_map ) {
      $dstmbx = $$mbx_map{"$srcmbx"};
      Log("Mapping src:$srcmbx to dst:$dstmbx");
      if ( $use_utf7 ){
         #  Encode the name in Modified UTF-7 charset
         $srcmbx = Unicode::IMAPUtf7::imap_utf7_encode( $srcmbx );
         $dstmbx = Unicode::IMAPUtf7::imap_utf7_encode( $dstmbx );
      }
      $temp{"$srcmbx"} = $dstmbx;
   }
   %$mbx_map = %temp;
   %temp = ();

}

sub isAscii {

my $str = shift;
my $ascii = 1;

   #  Determine whether a string contains non-ASCII characters

   my $test = $str;
   $test=~s/\P{IsASCII}/?/g;
   $ascii = 0 unless $test eq $str;

   return $ascii;

}

sub get_date {

my $days = shift;
my $time = time();
my @months = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );

   #  Generate a date in DD-MMM-YYYY format.  The 'days' parameter
   #  indicates how many days to go back from the present date.

   my ($sec,$min,$hr,$mday,$mon,$year,$wday,$yday,$isdst) =
        localtime( $time - $days*86400 );

   $mday = '0' . $mday if length( $mday ) == 1;
   my $month = $months[$mon];
   my $date = $mday . '-' . $month . '-' . ($year+1900);

   return $date;
}

sub fixup_date {

my $date = shift;

   #  Make sure the hrs part of the date is 2 digits.  At least
   #  one IMAP server expects this.

   $$date =~ s/^\s+//;
   $$date =~ /(.+) (.+):(.+):(.+) (.+)/;
   my $hrs = $2;

   return if length( $hrs ) == 2;

   my $newhrs = '0' . $hrs if length( $hrs ) == 1;
   $$date =~ s/ $hrs/ $newhrs/;

}

sub get_mbx_prefix {

my $delim  = shift;
my $conn   = shift;
my %prefixes;
my @prefixes;

   #  Not implemented yet.
   #  Try to figure out whether the server has a mailbox prefix
   #  and if so what it is.

   $$delim = "\\." if $$delim eq '.';

   my @mbxs = getMailboxList( $conn );
   my $num_mbxs = $#mbxs + 1;
   foreach $mbx ( @mbxs ) {
      next if uc( $mbx ) eq 'INBOX';
      ($prefix,$rest) = split(/$$delim/, $mbx);
      $prefixes{"$prefix"}++;
   }

   my $num_prefixes = keys %prefixes;
   if ( $num_prefixes == 1 ) {
      while(($$prefix,$count) = each(%prefixes)) {
          push( @prefixes, "$$prefix|$count");
      }
      ($$prefix,$count) = split(/\|/, pop @prefixes);
      $num_mbxs--;   # Because we skipped the INBOX
      if ( $num_mbxs != $count ) {
         # Did not find a prefix 
         $$prefix = '';
      }      

   }

   $$delim =~ s/\\//;
   $$prefix .= $$delim if $$prefix;

   Log("Determined prefix to be $$prefix") if $debug;

   return $$prefix;

}

sub get_mbx_delimiter {

my $conn = shift;
my $delimiter;

   #  Not implemented yet.
   #  Determine the mailbox hierarchy delimiter 

   sendCommand ($conn, "1 LIST \"\" INBOX");
   undef @response;
   my $i;
   while ( 1 ) {
        readResponse ($conn);
        last if $i++ > 9999;
        if ( $response =~ /INBOX/i ) {
           my @terms = split(/\s+/, $response );
           $delimiter = $terms[3];
           $delimiter =~ s/"//g;
        }
        last if $response =~ /^1 OK|^1 BAD|^1 NO/;
        last if $response !~ /^\*/;
   } 

   Log("Determined delimiter to be $delimiter") if $debug;
   return $delimiter;
}
   
sub validate_date {

my $date = shift;
my $status = 1;

    #  Make sure the date is in YYYY-MM-DD format

    my ($sec,$min,$hour,$mday,$mon,$this_year,$wday,$yday,$isdst) = localtime (time);
    $this_year += 1900;

    $date =~ s/\//-/g;
    $date =~ /(.+)-(.+)-(.+)/;

    my $day = $1;
    my $mon = $2;
    my $yr  = $3;

    $status = 0 unless ( $day >= 1 and $day <= 31 );
    $status = 0 unless ( $mon =~ /Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec/i );
    $status = 0 unless ( $yr > 1950 and $yr <= $this_year );

    if ( $status == 0 ) {
       Log("$date is not a valid date in the required DD-MMM-YYYY format.");
       exit;
    }

}


sub getDatedMsgList {

my $mbx    = shift;
my $before = shift;
my $after  = shift;
my $msgs   = shift;
my $conn   = shift;
my $msgnums;
my $msgid;
my $stat = 1;
my $search;

   #  Get a list of the messages in the date range requested

   my @msglist;

   #  Construct the search filter

   if ( $after and $before ) {
      $search = "(SINCE $after) (BEFORE $before)";
   } elsif ( $before ) {
      $search = "BEFORE $before";
   } elsif ( $after ) {
      $search = "SINCE $after";
   }

   Log("Executing search $search on $mbx") if $debug;

   Log("EXAMINE $mbx") if $debug;
   sendCommand ( $conn, "1 EXAMINE \"$mbx\"");
   my $i;
   while (1) {
	readResponse ($conn);
        last if $i++ > 9999;
	last if $response =~ /^1 OK/;
        if ( $response =~ /^1 NO|^1 BAD/ ) {
           return;
        }
   }

   sendCommand ( $conn, "1 SEARCH $search");
   my $loops;
   while (1) {
	readResponse ($conn);
        if ( $response =~ /BAD command syntax error/i ) {
           Log(" $response: $search");
           return -1;
        }
          
        last if $loops++ > 99;

	if ( $response =~ /\* SEARCH /i ) {
	   ($dmy, $msgnum) = split(/\* SEARCH /i, $response);
           @msglist = split(/ /, $msgnum);
	}
	last if $response =~ /^1 OK/;
        last if $response =~ /^1 NO/;
	last if $response =~ /complete/i;
   }

   #  Get the info we need on each message
   foreach my $msgnum ( @msglist ) {

      sendCommand ( $conn, "1 FETCH $msgnum (uid flags internaldate body[header.fields (From Date Message-ID Subject)])");
      undef @response;
      my $loops;
      while ( 1 ) {
	readResponse    ( $conn );
	if ( $response =~ /^1 OK/i ) {
	   last;
	}    
        last if $response =~ /^1 NO|^1 BAD/;
        last if $loops++ > 99;
      }

      $flags = '';
      for $i (0 .. $#response) {
	   last    if $response[$i] =~ /^1 OK FETCH complete/i;

           if ($response[$i] =~ /FLAGS/) {
              #  Get the list of flags
              $response[$i] =~ /FLAGS \(([^\)]*)/;
              $flags = $1;
              $flags =~ s/\\Recent|\\Forwarded//ig;
        }

        #  Consider the < and > to be part of the message-id.
        # if ( $response[$i] =~ /^Message-ID:\s*(.+)/i ) {
        if ( $response[$i] =~ /^Message-ID:\s*(.*)/i ) {
           $msgid = $1;
           if ( $msgid eq '' ) {
              # Line-wrap, get it from the next line
              $msgid = $response[$i+1];
           }
           $msgid =~ s/^\s+|\s+$;//g;
        }

        if ( $response[$i] =~ /^Subject:\s*(.+)/i ) {
           $subject = $1;
        }

        if ( $response[$i] =~ /^From:\s*(.+)/i ) {
           $from = $1;
        }

        if ( $response[$i] =~ /^Date:\s*(.+)/i ) {
           $header_date = $1;
           check_date( \$header_date );
        }

        if ( $response[$i] =~ /INTERNALDATE/) {
           $response[$i] =~ /INTERNALDATE (.+) BODY/i;
           $date = $1;
              
           $date =~ /"(.+)"/;
           $date = $1;
           $date =~ s/"//g;
        }

        if ( $response[$i] =~ /\* (.+) FETCH/ ) {
              ($msgnum) = split(/\s+/, $1);
        }

        if ( $response[$i] =~ /^\)/ ) {
           if ( $msgid eq '' or $generate_msgids ) {
              #  The msg lacks a msgid
              $msgid = build_dummy_msgid( $header_date, $subject, $from );
           }

	   push (@$msgs,"$msgid\t$subject");
           $msgnum=$msgid=$date=$flags=$subject=$from=$header_date='';
        }
      }
   }

}

sub build_dummy_msgid {

my $header_date = shift;
my $subject     = shift;
my $from        = shift;
my $msgid;

   #  Build a dummy msgid from the header_date, subject, and from address

   $header_date =~ s/\W//g;
   $subject =~ s/\W//g;
   $msgid = "$header_date$subject$from";
   $msgid =~ s/\s+//g;
   $msgid =~ s/\+|\<|\>|\?|\*|"|'|\(|\)//g;
   if ( $generate_msgids ) {
      Log("Building dummy msgid = $msgid") if $debug;
   } else {
      Log("Message has no msgid, built one as $msgid") if $debug;
   }

   return $msgid;
}

sub check_date {

my $date = shift;

   #  Some servers mess with the Date in the header, such as trimming leading
   #  '0' from dates.  Ugh.  Try to 'normalize' such dates.

   my @terms = split(/\s+/, $$date );
   my $old_dom = $new_dom = $terms[1];

   if ( length( $old_dom ) == 1 ) {
      #  Pad the day to two digits
      $new_dom = '0' . $old_dom;
      $$date =~ s/$old_dom/$new_dom/;
   }

   #  Strip off the timezone offset if present

   my $temp;
   foreach $_ ( split(/\s+/, $$date ) ) {
       $temp .= "$_ ";
       last if /(.+):(.+):(.+)/;
   }
   $temp =~ s/\s+$//g;
   $$date = $temp;

}

sub get_wrapped_msgid {

my $response = shift;
my $i = shift;
my $msgid;

    #  The Message-ID is not on the same line as the Message-ID: keyword
    #  Get it from the next line or lines (if it continues onto succeeding lines)

    $$response[$i+1] =~ s/^\s+//;
    $msgid = $$response[$i+1];
    $msgid =~ s/\s+$//g;

    my $j = 1;
    while ( 1 ) {
       if ( $msgid =~ /\>$/ ) {
          #  We've got all of it
          last;
       }
       $j++;
       #  The msgid continues onto the next line
       $$response[$i+$j] =~ s/^\s+//;
       $msgid .= $$response[$i+$j];
       if ( $msgid =~ /Message-ID:/i ) {
          ($start,$msgid) = split(/Message-ID:/, $msgid );
       }

       last if $j > 99;
   }

   return $msgid;

}


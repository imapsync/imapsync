#!/usr/bin/perl

# $Header: /mhub4/sources/imap-tools/delete_imap_mailboxes.pl,v 1.7 2014/10/17 15:23:46 rick Exp $

#######################################################################
#######################################################################

use Socket;
use FileHandle;
use Fcntl;
use Getopt::Std;
use IO::Socket;
use MIME::Base64 qw(decode_base64 encode_base64);

   #  Delete one or more mailboxes based on a regular expression supplied
   #  by the user.  For example:
   #
   #    -m "^thunder|^real|AA|^MOVED$|XXXX|zas"
   #
   #  It is advisable to do a test-run first to make sure that the regex
   #  will select the desired mailbox before actually deleting them.  Use
   #  the -t argument to select "show what would be deleted but don't delete
   #  it" mode.

   init();

   #  Get list of the user's mailboxes
   #
   connectToHost($sourceHost, \$src)   or exit;
   login($sourceUser,$sourcePwd, $src, $srcMethod) or exit;
   namespace( $src, \$prefix, \$delim, $opt_x );

   $filter = "$prefix" . $filter if $prefix; 

   @mbxs = getMailboxList( $srcPrefix, $src );

   #  Sort the mailboxes to make sure we delete submailboxes first

   foreach $mbx ( reverse sort @mbxs ) {
        Log("$mbx") if $debug;
        if ( $mbx =~ /$filter/ ) {
           # Log("$mbx matches $filter");
        }
        # next if $nosel_mbxs{"$mbx"};  #  We can delete NOSELECT mbxs
        push( @deletes, $mbx ) if $mbx =~ /$filter/;
   }

   foreach $mbx ( @deletes ) {
       if ( $testmode ) {
          Log("Would have deleted $mbx");
       } elsif ( uc( $mbx ) eq 'INBOX' ) {
          #  The INBOX cannot be deleted per IMAP standard so
          #  we will purge it of messages instead
          Log("INBOX cannot be deleted, purging it instead");
          purge_mbx( 'INBOX', $src );
       } else {
          delete_mailbox( $mbx, $src );
       }
   }


   logout( $src );

   exit;


sub init {

   processArgs();

   #  Open the logFile
   #
   if ( $logfile ) {
      if ( !open(LOG, ">> $logfile")) {
         print STDOUT "Can't open $logfile: $!\n";
         exit;
      } 
      select(LOG); $| = 1;
   }
   Log("$0 starting");

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

#
#  sendCommand
#
#  This subroutine formats and sends an IMAP protocol command to an
#  IMAP server on a specified connection.
#

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
    Log ("<< $response") if $showIMAP;1
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
      $line = sprintf ("%.2d-%.2d-%d.%.2d:%.2d:%.2d %s\n",
		     $mon + 1, $mday, $year + $yr, $hour, $min, $sec,$str);
      print LOG "$line";
   } 
   print STDOUT "$str\n" unless $quiet_mode;

}


sub delete_mailbox {

my $mbx  = shift;
my $conn = shift;
my $error;

   #  Create the mailbox if necessary
   
   return if uc( $mbx ) eq 'INBOX';

   sendCommand ($conn, "1 DELETE \"$mbx\"");
   while ( 1 ) {
      readResponse ($conn);
      last if $response =~ /^1 OK/i;
      if ( $response =~ /^1 NO|^1 BAD|^\* BYE/ ) {
         $error=1;
         Log ("Error creating $mbx: $response");
         last;
      }
      
   } 

   unless ( $error ) {
      Log("Successfully deleted $mbx");
   }

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
my $method = shift;

   if ( $admin_user ) {
      #  An AUTHENTICATE = PLAIN login has been requested
      ($authuser,$authpwd) = split(/:/, $admin_user );
      login_plain( $user, $authuser, $authpwd, $conn ) or exit;
      return 1;
   }

   if ( $pwd =~ /^oauth2:(.+)/i ) {
      $token = $1;
      Log("password is an OAUTH2 token");
      login_xoauth2( $user, $token, $conn );
      return 1;
   }

   if ( uc( $method ) eq 'CRAM-MD5' ) {
      #  A CRAM-MD5 login is requested
      Log("login method $method");
      my $rc = login_cram_md5( $user, $pwd, $conn );
      return $rc;
   }

   #  Otherwise do an ordinary login

   sendCommand ($conn, "1 LOGIN $user \"$pwd\"");
   while (1) {
	readResponse ( $conn );
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
        last if $response =~ /^1 OK/i;
        if ($response =~ /^1 NO|^1 BAD|^\* BYE/i) {
           Log ("unexpected LOGIN response: $response");
           return 0;
        }
   }
   Log("Logged in as $user") if $debug;

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

my $prefix = shift;
my $conn   = shift;
my @mbxs;

   #  Get a list of the user's mailboxes
   #

   Log("Get list of user's mailboxes",2) if $debugMode;

   if ( $mbxList ) {
      foreach $mbx ( split(/,/, $mbxList) ) {
         $mbx = $prefix . $mbx if $prefix;
         if ( $opt_R ) {
            # Get all submailboxes under the ones specified
            $mbx .= '*';
            @mailboxes = listMailboxes( $mbx, $conn);
            push( @mbxs, @mailboxes );
         } else {
            push( @mbxs, $mbx );
         }
      }
   } else {
      #  Get all mailboxes
      @mbxs = listMailboxes( '*', $conn);
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

#  listMailboxes
#
#  Get a list of the user's mailboxes
#
sub listMailboxes {

my $mbx  = shift;
my $conn = shift;

   sendCommand ($conn, "1 LIST \"\" \"$mbx\"");
   undef @response;
   while ( 1 ) {
        &readResponse ($conn);
        if ( $response =~ /^1 OK/i ) {
                last;
        }
        elsif ( $response !~ /^\*/ ) {
                &Log ("unexpected response: $response");
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
        push ( @mbxs, $mbx ) if $mbx ne '';
   }

   return @mbxs;
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
my $mode    = shift;
my $seen;
my $empty;
my $msgnum;
my $from;
my $flags;

   $mode = 'EXAMINE' unless $mode;
   sendCommand ($conn, "1 $mode \"$mailbox\"");
   undef @response;
   $empty=0;
   while ( 1 ) {
	readResponse ( $conn );
	if ( $response =~ / 0 EXISTS/i ) { $empty=1; }
	if ( $response =~ /^1 OK/i ) {
		last;
	}
	elsif ( $response !~ /^\*/ ) {
		Log ("unexpected response: $response");
		return 0;
	}
   }

   sendCommand ( $conn, "1 FETCH 1:* (uid flags internaldate body[header.fields (From Date)])");
   
   undef @response;
   while ( 1 ) {
	readResponse ( $conn );
	if ( $response =~ /^1 OK/i ) {
		last;
	} 
        last if $response =~ /^1 NO|^1 BAD|^\* BYE/;
   }

   @msgs  = ();
   $flags = '';
   for $i (0 .. $#response) {
	last if $response[$i] =~ /^1 OK FETCH complete/i;

        if ($response[$i] =~ /FLAGS/) {
           #  Get the list of flags
           $response[$i] =~ /FLAGS \(([^\)]*)/;
           $flags = $1;
           $flags =~ s/\\Recent//;
        }

        if ( $response[$i] =~ /INTERNALDATE/) {
           $response[$i] =~ /INTERNALDATE (.+) BODY/i;
           # $response[$i] =~ /INTERNALDATE "(.+)" BODY/;
           $date = $1;
           
           $date =~ /"(.+)"/;
           $date = $1;
           $date =~ s/"//g;
        }

        # if ( $response[$i] =~ /\* (.+) [^FETCH]/ ) {
        if ( $response[$i] =~ /\* (.+) FETCH/ ) {
           ($msgnum) = split(/\s+/, $1);
        }

        if ( $msgnum && $date ) {
	   push (@$msgs,"$msgnum|$date|$flags");
           $msgnum = $date = '';
        }
   }

   return 1;

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

sub fetchMsg {

my $msgnum = shift;
my $mbx    = shift;
my $conn   = shift;
my $message;

   Log("   Fetching msg $msgnum...") if $debug;

   sendCommand( $conn, "1 FETCH $msgnum (rfc822)");
   while (1) {
	readResponse ($conn);
        last if $response =~ /^1 NO|^1 BAD|^\* BYE/;
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

   print STDOUT "usage: delete_imap_mailboxes.pl\n";
   print STDOUT "     -S imapHost/user/password\n";
   print STDOUT "     -m <mailbox regular expression>\n";
   print STDOUT "     -t test mode, show what would have been deleted\n";
   print STDOUT "     -d debug\n";
   print STDOUT "     -I show IMAP protocol exchanges\n";
   print STDOUT "     -L logfile\n";
   exit;

}

sub processArgs {

   if ( !getopts( "dS:D:L:m:hIp:M:rqtx:y:e:Rt:TsA:" ) ) {
      usage();
   }

   ($sourceHost,$sourceUser,$sourcePwd,$srcMethod) = split(/\//, $opt_S);
   $filter   = $opt_m;
   $logfile  = $opt_L;
   $root_mbx = $opt_p;
   $tags     = $opt_T;
   $debug    = 1 if $opt_d;
   $showIMAP = 1 if $opt_I;
   $timeout = 45;
   $testmode = 1 if $opt_t;
   $admin_user = $opt_A;

   usage() if $opt_h;

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

sub namespace {

my $conn      = shift;
my $prefix    = shift;
my $delimiter = shift;
my $mbx_delim = shift;

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
      if ( $response =~ /^1 OK/i ) {
         last;
      } elsif ( $response =~ /^1 NO|^1 BAD^\* BYE/i ) {
         Log("Unexpected response to NAMESPACE command: $response");
         last;
      }
   }

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

my $srcmbx    = shift;
my $srcPrefix = shift;
my $srcDelim  = shift;
my $dstPrefix = shift;
my $dstDelim  = shift;
my $dstmbx;
my $substChar = '_';

   #  Change the mailbox name if the user has supplied mapping rules.
   if ( $mbx_map{"$srcmbx"} ) {
      $srcmbx = $mbx_map{"$srcmbx"} 
   }

   #  Adjust the mailbox name if the source and destination server
   #  have different mailbox prefixes or hierarchy delimiters.

   if ( ($srcmbx =~ /[$dstDelim]/) and ($dstDelim ne $srcDelim) ) {
      #  The mailbox name has a character that is used on the destination
      #  as a mailbox hierarchy delimiter.  We have to replace it.
      $srcmbx =~ s^[$dstDelim]^$substChar^g;
   }

   if ( $debug ) {
      Log("src mbx      $srcmbx");
      Log("src prefix   $srcPrefix");
      Log("src delim    $srcDelim");
      Log("dst prefix   $dstPrefix");
      Log("dst delim    $dstDelim");
   }

   $srcmbx =~ s/^$srcPrefix//;
   $srcmbx =~ s/\\$srcDelim/\//g;
 
   if ( ($srcPrefix eq $dstPrefix) and ($srcDelim eq $dstDelim) ) {
      #  No adjustments necessary
      $dstmbx = $srcmbx;
      if ( $root_mbx ) {
         #  Put folders under a 'root' folder on the dst
         $dstmbx =~ s/^$dstPrefix//;
         $dstDelim =~ s/\./\\./g;
         $dstmbx =~ s/^$dstDelim//;
         $dstmbx = $dstPrefix . $root_mbx . $dstDelim . $dstmbx;
         if ( uc($srcmbx) eq 'INBOX' ) {
            #  Special case for the INBOX
            $dstmbx =~ s/INBOX$//i;
            $dstmbx =~ s/$dstDelim$//;
         }
         $dstmbx =~ s/\\//g;
      }
      return $dstmbx;
   }

   $srcmbx =~ s#^$srcPrefix##;
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
       $dstDelim = "\\$dstDelim" if $dstDelim eq '.';
       $dstmbx =~ s#^$dstDelim##;
   } 
      
   if ( $root_mbx ) {
      #  Put folders under a 'root' folder on the dst
      $dstDelim =~ s/\./\\./g;
      $dstmbx =~ s/^$dstPrefix//;
      $dstmbx =~ s/^$dstDelim//;
      $dstmbx = $dstPrefix . $root_mbx . $dstDelim . $dstmbx;
      if ( uc($srcmbx) eq 'INBOX' ) {
         #  Special case for the INBOX
         $dstmbx =~ s/INBOX$//i;
         $dstmbx =~ s/$dstDelim$//;
      }
      $dstmbx =~ s/\\//g;
   }

   return $dstmbx;
}

sub flags {

my $flags = shift;
my @newflags;
my $newflags;

   #  Make sure the flags list contains standard 
   #  IMAP flags and optionally custom tags

   return unless $flags;

   $flags =~ s/\\Recent//i;
   foreach $_ ( split(/\s+/, $flags) ) {
      push( @newflags, $_ ) if substr($_,0,1) eq '\\';
      if ( $opt_T ) {
         #  Include user-defined flags
         push( @newflags, $_ ) if substr($_,0,1) eq '$';
      }
   }

   $newflags = join( ' ', @newflags );

   $newflags =~ s/\\Deleted//ig if $opt_r;
   $newflags =~ s/^\s+|\s+$//g;

   return $newflags;
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

#  Reconnect to the servers after a timeout error.
#
sub reconnect {

my $checkpoint = shift;
my $conn = shift;

   Log("Attempting to reconnect");

   my ($mbx,$shost,$suser,$spwd,$dhost,$duser,$dpwd) = split(/\|/, $checkpoint);

   close $src;
   close $dst;

   connectToHost($shost,\$src);
   login($suser,$spwd,$src);

   connectToHost($dhost,\$dst);
   login($duser,$dpwd,$dst);

   selectMbx( $mbx, $src );
   createMbx( $mbx, $dst );   # Just in case

}

#  Handle signals

sub signalHandler {

my $sig = shift;

   if ( $sig eq 'ALRM' ) {
      Log("Caught a SIG$sig signal, timeout error");
      $conn_timed_out = 1;
   } else {
      Log("Caught a SIG$sig signal, shutting down");
      exit;
   }
   Log("Resuming");
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

sub purge_mbx {

my $mbx  = shift;
my $conn = shift;
my @msgs;

   #  Remove all messages from a mailbox

   Log("Purging mailbox $mbx");
   getMsgList( $mbx, \@msgs, $conn, 'SELECT' ); 
   my $msgcount = $#msgs + 1;
   Log("$mbx has $msgcount messages") if $debug;

   return if $msgcount == 0;   #  No messages to delete

   $range = "1:$msgcount";

   deleteMsgs( $range, $conn );

   expungeMbx( $mbx, $conn );

}

sub deleteMsgs {

my $range = shift;
my $conn   = shift;
my $rc;

   sendCommand ( $conn, "1 STORE $range +FLAGS (\\Deleted)");
   while (1) {
        readResponse ($conn);
        if ( $response =~ /^1 OK/i ) {
	   $rc = 1;
	   Log("      Marked msgs $range for delete") if $debug;
	   last;
	}

	if ( $response =~ /^1 BAD|^1 NO/i ) {
	   Log("Error setting \Deleted flag for msgs $range: $response");
	   $rc = 0;
	   last;
	}
   }

   return $rc;

}

sub expungeMbx {

my $mbx   = shift;
my $conn  = shift;

   Log("Expunging mailbox $mbx");

   sendCommand ($conn, "1 SELECT \"$mbx\"");
   while (1) {
        readResponse ($conn);
        last if ( $response =~ /1 OK/i );
   }

   sendCommand ( $conn, "1 EXPUNGE");
   $expunged=0;
   while (1) {
        readResponse ($conn);
        $expunged++ if $response =~ /\* (.+) Expunge/i;
        last if $response =~ /^1 OK/;

	if ( $response =~ /^1 BAD|^1 NO/i ) {
	   Log("Error purging messages: $response");
	   last;
	}
   }

   $totalExpunged += $expunged;

   Log("$expunged messages expunged") if $debug;

}

sub cram_md5 {

my $challenge = shift;
my $user      = shift;
my $password  = shift;

eval 'use Digest::HMAC_MD5 qw(hmac_md5_hex)'; 
use MIME::Base64 qw(decode_base64 encode_base64); 

   # Adapated from script by Paul Makepeace <http://paulm.com>, 2002-10-12 
   # Takes user, key, and base-64 encoded challenge and returns base-64 
   # encoded CRAM. See, 
   # IMAP/POP AUTHorize Extension for Simple Challenge/Response: 
   # RFC 2195 http://www.faqs.org/rfcs/rfc2195.html 
   # SMTP Service Extension for Authentication: 
   # RFC 2554 http://www.faqs.org/rfcs/rfc2554.html 
   # Args: tim tanstaaftanstaaf PDE4OTYuNjk3MTcwOTUyQHBvc3RvZmZpY2UucmVzdG9uLm1jaS5uZXQ+ 
   # should yield: dGltIGI5MTNhNjAyYzdlZGE3YTQ5NWI0ZTZlNzMzNGQzODkw 

   my $challenge_data = decode_base64($challenge); 
   my $hmac_digest = hmac_md5_hex($challenge_data, $password); 
   my $response = encode_base64("$user $hmac_digest"); 
   chomp $response;

   if ( $debug ) {
      Log("Challenge: $challenge_data");
      Log("HMAC digest: $hmac_digest"); 
      Log("CRAM Base64: $response");
   }

   return $response;
}


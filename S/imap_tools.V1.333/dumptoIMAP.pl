#!/usr/bin/perl

#  $Header: /mhub4/sources/imap-tools/dumptoIMAP.pl,v 1.14 2014/11/10 12:55:43 rick Exp $

#######################################################################
#  dumptoIMAP.pl is used to load the mailboxes and messages exported  #
#  from an IMAP server by the imapdump.pl script.  See usage() notes  #
#  for a list of the arguments used to run it.                        #
#                                                                     #
#  If you ran imapdump.pl -S host/user/pwd -f /tmp/BACKUP             #
#  then you could restore all of the mailboxes & messages with the    #
#  following command:                                                 #
#                                                                     #
#  ./dumptoIMAP.pl -i host/user/pwd -D /tmp/BACKUP                    #
#                                                                     #
#  If you wanted to restore just the INBOX and the Sent mailboxes you #
#  would add -m "INBOX,Sent"                                          #
#######################################################################

use Socket;
use IO::Socket;
use FileHandle;
use File::Find;
use Fcntl;
use Getopt::Std;
use MIME::Base64 qw(decode_base64 encode_base64);

init();

connectToHost($imapHost, \$conn);

if ( $imapUser =~ /(.+):(.+)/ ) {
   #  An AUTHENTICATE = PLAIN login has been requested
   $imapUser  = $1;
   $authuser  = $2;
   login_plain( $imapUser, $authuser, $imapPwd, $conn ) or exit;
} else {
   if ( !login($imapUser,$imapPwd, $conn) ) {
      Log("Check your username and password");
      print STDOUT "Login failed: Check your username and password\n";
      exit;
   }
}

if ( $opt_y ) {
   #  User-supplied mbx delimiter and prefix
   ($mbx_delim,$prefix) = split(/\s+/, $opt_y );
} else {
   namespace( $conn, \$prefix, \$mbx_delim );
}

get_mbx_list( $dir, \@mbxs );

foreach $mbx ( @mbxs ) {
   $copied=0;
   Log("mbx = >$mbx<") if $debug;
   Log("Full path to $mbx is >$dir/$mbx<") if $debug;

   Log("Copying messages from $dir/$mbx to $mbx folder on the IMAP server");
   get_messages( "$dir/$mbx", \@msgs );
   $n = scalar @msgs;
   Log("$mbx has $n messages");

   $mbx =~ s/\//$mbx_delim/g unless $mbx_delim eq '/';
   if ( $prefix ) {
      $mbx = $prefix . $mbx unless $mbx =~ /^INBOX/i;
   }

   foreach $_ ( @msgs ) {
      next unless $_;
      my $msg; my $date; my $seen;

      $flags = '';
      if ( /,S$/ ) {
         $flags = '\\SEEN';
      }

      Log("Opening $_") if $debug;
      unless ( open(F, "<$_") ) {
         Log("Error opening $_: $!");
         next;
      }
      Log("Opened $_ successfully") if $debug;
      while( <F> ) {
         # Log("Reading line $_") if $debug;
         if ( /^Date: (.+)/ )  {
            $date = $1 unless $date;
            $date =~ s/\r|\m//g;
            chomp $date;
         }
         s/\r+$//g;
         $msg .= $_;
         chomp $msg;
         $msg .= "\r\n";
 
      }
      close F;
   
      $size = length( $msg );
      Log("The message is $size bytes") if $debug;
      # Log("$msg") if $debug;
 
      if ( $size == 0 ) {
         Log("The message file is empty") if $debug;
         next;
      }

      $copied++ if insertMsg($mbx, \$msg, $flags, $date, $conn);

      if ( $msgs_per_folder ) {
         #  opt_F allows us to limit number of messages copied per folder
         last if $copied == $msgs_per_folder;
      }

      if ( $copied/100 == int($copied/100)) { Log("$copied messages copied "); }
   }
   $total += $copied;

}

logout( $conn );

Log("Done. $total messages were copied.");
exit;


sub init {

   if ( !getopts('m:L:i:dD:Ix:XRA:F:y:') ) {
      usage();
   }

   $mbx_list = $opt_m;
   $dir      = $opt_D;
   $logfile  = $opt_L;
   $extension = $opt_x;
   $debug     = 1 if $opt_d;
   $showIMAP  = 1 if $opt_I;
   $admin_user = $opt_A;
   $msgs_per_folder = $opt_F;
   ($imapHost,$imapUser,$imapPwd) = split(/\//, $opt_i);

   if ( $logfile ) {
      if ( ! open (LOG, ">> $logfile") ) {
        print "Can't open logfile $logfile: $!\n";
        $logfile = '';
      }
   }
   Log("Starting");

   #  Determine whether we have SSL support via openSSL and IO::Socket::SSL
   $ssl_installed = 1;
   eval 'use IO::Socket::SSL';
   if ( $@ ) {
      $ssl_installed = 0;
   }
}



sub usage {

   print "Usage: dumptoIMAP.pl\n";
   print "    -D <path to the mailboxes>\n";
   print "    -i <server/username/password>\n";
   print "       (if the password is an OAUTH2 token then prefix it with 'oauth2:'\n";
   print "    [-A <admin_user:admin_pwd>\n";
   print "    [-m <mbx1,mbx2,..,mbxn> copy only the listed mailboxes]\n";
   print "    [-x <extension> Import only files with this extension\n";
   print "    [-L <logfile>]\n";
   print "    [-d debug]\n";
   print "    [-I log IMAP protocol exchanges]\n";

}

sub get_messages {

my $dir  = shift;
my $msgs = shift;

   #  Get a list of the message files 

   if ( $debug ) {
      Log("Get list of messages in $dir");
   }

   opendir D, $dir;
   my @files = readdir( D );
   closedir D;
   foreach $_ ( @files ) {
      next if /^\./;
      if ( $extension ) {
         next unless /$extension$/;
      }
      Log("   $dir/$_") if $debug;
      push( @$msgs, "$dir/$_");
   }
}

#  Print a message to STDOUT and to the logfile if
#  the opt_L option is present.
#

sub Log {

my $line = shift;
my $msg;

   ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime (time);
   $msg = sprintf ("%.2d-%.2d-%.4d.%.2d:%.2d:%.2d %s",
                  $mon + 1, $mday, $year + 1900, $hour, $min, $sec, $line);

   if ( $logfile ) {
      print LOG "$msg\n";
   }
   print STDOUT "$line\n";

}

#  connectToHost
#
#  Make an IMAP connection to a host
# 
sub connectToHost {

my $host = shift;
my $conn = shift;

   Log("Connecting to $host") if $debug;

   $sockaddr = 'S n a4 x8';
   ($name, $aliases, $proto) = getprotobyname('tcp');
   ($host,$port) = split(/:/, $host);
   $port = 143 unless $port;

   if ($host eq "") {
	Log ("no remote host defined");
	close LOG; 
	exit (1);
   }

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

   select( $$conn ); $| = 1;
   return 1;
}

#
#  login in at the IMAP host with the user's name and password
#
sub login {

my $user = shift;
my $pwd  = shift;
my $conn = shift;

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

   Log("Logging in as $user") if $debug;
   $rsn = 1;
   sendCommand ($conn, "$rsn LOGIN $user $pwd");
   while (1) {
	readResponse ( $conn );
	if ($response =~ /^$rsn OK/i) {
		last;
	}
	elsif ($response =~ /NO/) {
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
   sendCommand ($conn, "1 AUTHENTICATE PLAIN $login_str" );

   my $loops;
   while (1) {
        readResponse ( $conn );
        last if $response =~ /^1 OK/;
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
           exit;
        }
        last if $response =~ /^1 OK/;
        if ($response =~ /^1 NO|^1 BAD|^\* BYE|failed/i) {
           Log ("unexpected LOGIN response: $response");
           exit;
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

   ++$lsn;
   undef @response;
   sendCommand ($conn, "$lsn LOGOUT");
   while ( 1 ) {
	readResponse ($conn);
	if ( $response =~ /^$lsn OK/i ) {
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
    Log(">>$response") if $showIMAP;
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
    Log(">>$cmd") if $showIMAP;
}

#
#  insertMsg
#
#  Append a message to an IMAP mailbox
#

sub insertMsg {

my $mbx = shift;
my $message = shift;
my $flags = shift;
my $date  = shift;
my $conn  = shift;
my ($lsn,$lenx);

   Log("   Inserting message") if $debug;
   $lenx = length($$message);

   #  Log("$$message");

    ($date) = split(/\s*\(/, $date);
    if ( $date =~ /,/ ) {
       $date =~ /(.+),\s+(.+)\s+(.+)\s+(.+)\s+(.+)\s+(.+)/;
       $date = "$2-$3-$4 $5 $6";
    } else {
       $date =~ s/\s/-/;
       $date =~ s/\s/-/;
    }

   #  Create the mailbox unless we have already done so
   ++$lsn;
   if ($destMbxs{"$mbx"} eq '') {
	sendCommand ($conn, "$lsn CREATE \"$mbx\"");
	while ( 1 ) {
	   readResponse ($conn);
	   if ( $response =~ /^$rsn OK/i ) {
		last;
	   }
	   elsif ( $response !~ /^\*/ ) {
		if (!($response =~ /already exists|reserved mailbox name/i)) {
			Log ("WARNING: $response");
		}
		last;
	   }
       }
   } 
   $destMbxs{"$mbx"} = '1';

   $flags =~ s/\\Recent//i;

   if ( $date ) {
      sendCommand ($conn, "1 APPEND \"$mbx\" ($flags) \"$date\" \{$lenx\}");
   } else {
      sendCommand ($conn, "1 APPEND \"$mbx\" ($flags) \{$lenx\}");
   }
   readResponse ($conn);
   if ( $response !~ /^\+/ ) {
       Log ("unexpected APPEND response to $cmd");
       push(@errors,"Error appending message to $mbx for $user");
       return 0;
   }

   if ( $opt_X ) {
      print $conn "$$message\n";
   } else {
      print $conn "$$message\r\n";
   }

   undef @response;
   while ( 1 ) {
       readResponse ($conn);
       if ( $response =~ /^$lsn OK/i ) {
	   last;
       }
       elsif ( $response !~ /^\*/ ) {
	   Log ("unexpected APPEND response: $response");
	   return 0;
       }
   }

   return 1;
}

#  getMsgList
#
#  Get a list of the user's messages in the indicated mailbox on
#  the IMAP host
#
sub getMsgList {

my $mailbox = shift;
my $msgs    = shift;
my $conn    = shift;
my $seen;
my $empty;
my $msgnum;

   Log("Getting list of msgs in $mailbox") if $debug;
   trim( *mailbox );
   sendCommand ($conn, "$rsn EXAMINE \"$mailbox\"");
   undef @response;
   $empty=0;
   while ( 1 ) {
	readResponse ( $conn );
	if ( $response =~ / 0 EXISTS/i ) { $empty=1; }
	if ( $response =~ /^$rsn OK/i ) {
		last;
	}
	elsif ( $response !~ /^\*/ ) {
		Log ("unexpected response: $response");
		return 0;
	}
   }

   sendCommand ( $conn, "$rsn FETCH 1:* (uid flags internaldate body[header.fields (Message-Id)])");
   undef @response;
   while ( 1 ) {
	readResponse ( $conn );
	if ( $response =~ /^$rsn OK/i ) {
		last;
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
	    $response[$i] =~ /FLAGS \(([^\)]*)/;
	    $flags = $1;
   	    $flags =~ s/\\Recent//i;
	}
        if ( $response[$i] =~ /INTERNALDATE ([^\)]*)/ ) {
	    ### $response[$i] =~ /INTERNALDATE (.+) ([^BODY]*)/i; 
	    $response[$i] =~ /INTERNALDATE (.+) BODY/i; 
            $date = $1;
            $date =~ s/"//g;
	}
	if ( $response[$i] =~ /^Message-Id:/i ) {
	    ($label,$msgid) = split(/: /, $response[$i]);
	    push (@$msgs,$msgid);
	}
   }
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

sub get_mbx_list {

my $dir = shift;
my $mbxs = shift;
my %MBXS;

   if ( $mbx_list ) {
      #  The user has supplied a list of mailboxes.
      @$mbxs = split(/,/, $mbx_list );
      return;
   }

   @dirs = ();
   push( @dirs, $dir );
   @messages = ();
   find( \&findMsgs, @dirs );   #  Returns @messages
   foreach $fn ( @messages ) {
      Log("fn = $fn") if $debug;
      $fn =~ s/$dir//;
      Log("fn = $fn") if $debug;
      $i = rindex($fn,'/');
      Log("find rightmost slash, i = $i") if $debug;
      if ( $fn =~ /^\// ) {
         $mbx = substr($fn,1,$i);
      } else {
         $mbx = substr($fn,0,$i);
      }
      Log("mbx = $mbx") if $debug;
      $mbx =~ s/\/$//;
      Log("mbx = >$mbx<") if $debug;
      push( @$mbxs, $mbx ) if !$MBXS{"$mbx"};
      Log("Add >$mbx< to the list of mailboxes") if $debug;
      $MBXS{"$mbx"} = 1;
   }
}

sub findMsgs {

   return if not -f;

   my $fn = $File::Find::name;
   push( @messages, $fn );

}

sub namespace {

my $conn      = shift;
my $prefix    = shift;
my $delimiter = shift;

   #  Query the server with NAMESPACE so we can determine its
   #  mailbox prefix (if any) and hierachy delimiter.

   @response = ();
   sendCommand( $conn, "1 NAMESPACE");
   while ( 1 ) {
      readResponse( $conn );
      if ( $response =~ /^1 OK/i ) {
         last;
      } elsif ( $response =~ /^1 NO|^1 BAD|^\* BYE/i ) {
         Log("Unexpected response to NAMESPACE command: $response");
         Log("Cannot determine the mailbox delimiter and prefix.  Use -y '<delimiter prefix>' to supply it");
         exit;
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
      
         #  Experimental
         if ( $public_mbxs ) {
            #  Figure out the public mailbox settings
            /\(\((.+)\)\)\s+\(\((.+)\s+\(\((.+)\)\)/;
            $public = $3;
            $public =~ /"(.+)"\s+"(.+)"/;
            $src_public_prefix = $1 if $conn eq $src;
            $src_public_delim  = $2 if $conn eq $src;
            $dst_public_prefix = $1 if $conn eq $dst;
            $dst_public_delim  = $2 if $conn eq $dst;
         }
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

   if ( $public_mbxs ) {
      my ($public_src,$public_dst) = split(/:/, $public_mbxs );
      #  If the mailbox starts with the public mailbox prefix then
      #  map it to the public mailbox destination prefix

      if ( $srcmbx =~ /^$public_src/ ) {
         Log("src: $srcmbx is a public mailbox") if $debug;
         $dstmbx = $srcmbx;
         $dstmbx =~ s/$public_src/$public_dst/;
         Log("dst: $dstmbx") if $debug;
         return $dstmbx;
      }
   }

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
      # $dstmbx = $srcmbx;
      if ( lc( $srcmbx ) eq 'inbox' ) {
         $dstmbx = $srcmbx;
      } else {
         $dstmbx = $srcPrefix . $srcmbx;
      }
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


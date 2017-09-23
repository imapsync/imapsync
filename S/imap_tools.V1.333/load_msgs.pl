#!/usr/bin/perl

#  $Header$

#######################################################################
#
#######################################################################

use Socket;
use IO::Socket;
use FileHandle;
use File::Find;
use Fcntl;
use Getopt::Std;
use MIME::Base64 qw(decode_base64 encode_base64);

init();
@dirs = split(/,/, $dir);
my @msg_list;

foreach $dir ( @dirs ) {
   $copied=0;
   Log("Looking for $extension messages in $dir");
   get_messages( $dir, \@msgs );
   $n = scalar @msgs;
}
Log("There are $n msgs");
Log("Reading msg headers");
foreach $msgfn ( @msgs ) {
   $read++;
   Log("Read $read headers") if $read/1000 == int($read/1000);
   next unless $msgfn;
   next unless -e $msgfn;
   Log("Reading $msgfn") if $debug;

   ($from,$to,$cc,$date,$msgid) = read_header( $msgfn );
   update_msglist( $from, $to, $cc, $msgfn, $date, $msgid, \@msglist );
}

$n = scalar @msglist;
Log("There are $n messages to load");

@msglist = sort @msglist;
foreach $_ ( @msglist ) {
   ($user,$date,$folder,$msgid,$msgfn) = split(/\|/, $_);

   if ( $msgfn eq '' ) {
      Log("null msgfn");
      exit;
   }

   if ( $last_user ne $user ) {
      logout( $conn ) if $conn;
      $sent_created = $inbox_created = 0;
      connectToHost($imapHost, \$conn);
      login_plain( $user, $admin_user, $admin_pwd, $conn ) or next;
      create_mailbox( $sent_mbx, $conn )  unless $sent_created;
      create_mailbox( $inbox_mbx, $conn ) unless $inbox_created;
      $sent_created = $inbox_created = 1;
      Log("Loading msgs for $user");
      $last_user = $user;
   
      if ( $update ) {
         #  Get list of messages in the user's inbox and sent folders so we
         #  won't copy msgs that already exist
         %MSGIDS = ();
         getMsgIdList( $inbox_mbx, \%MSGIDS, $conn );
         getMsgIdList( $sent_mbx,  \%MSGIDS, $conn );
      }
   } 

   if ( !$namespace ) {
      if ( $opt_y ) {
         #  User-supplied mbx delimiter and prefix
         ($mbx_delim,$prefix) = split(/\s+/, $opt_y );
      } else {
         namespace( $conn, \$prefix, \$mbx_delim );
      }
      $namespace = 1;
   }

   $msgid = read_msg( $msgfn, \$msg );

    if ( $update ) {
       next if $MSGIDS{"$folder $msgid"};
    }

    Log("Need to add $msgid") if $debug;

   $USERS{"$user"}++;
   $copied++ if insertMsg($folder, \$msg, $flags, $date, $conn);
   Log("Copied $copied total msgs") if $copied/100 == int($copied/100);
   
}

Log("Done. $copied messages were copied.");
Log("Summary of per-user copied messages");
foreach $user ( sort keys %USERS ) {
   $copied = $USERS{"$user"};
   commafy( \$copied );
   $copied = pack("A10", $copied);
   Log("$copied   $user");
}
exit;


sub init {

   if ( !getopts('m:L:i:dD:Ix:XRA:l:y:t:S:M:u:U') ) {
      usage();
   }

   $dir             = $opt_D;
   $logfile         = $opt_L;
   $extension       = $opt_x;
   $admin_user      = $opt_A;
   $msg_limit       = $opt_l;
   $imapHost        = $opt_i;
   $debug           = 1 if $opt_d;
   $showIMAP        = 1 if $opt_I;
   $update          = 1 if $opt_U;
   $sent_mbx        = $opt_S;
   $inbox_mbx       = $opt_M;
   $our_domains     = $opt_m;
   $users           = $opt_u;

   $sent_mbx  = 'Sent' unless $sent_mbx;
   $inbox_mbx = 'INBOX' unless $inbox_mbx;
   $logfile   = 'load_msgs.log' unless $logfile;
   $msg_limit = 999999999 unless $msg_limit;
   $extension = 'EML' unless $extension;

   foreach $user ( split(/\s*,\s*/, $users ) ) {
      #  Only certain user msgs are to be loaded
      $user =~ s/^\s+|\s+$//g;
      chomp $user;
      $user = lc( $user );
      $USER{"$user"} = 1;
      $filter_users = 1;
   }

   if ( $logfile ) {
      if ( ! open (LOG, ">> $logfile") ) {
        print "Can't open logfile $logfile: $!\n";
        $logfile = '';
      }
   }
   Log("Starting");

   eval 'use MIME::Parser';
   if ( $@ ) {
      Log("The Perl module MIME::Parser must be installed to use this program.");
      exit;
   }

   #  Determine whether we have SSL support via openSSL and IO::Socket::SSL
   $ssl_installed = 1;
   eval 'use IO::Socket::SSL';
   if ( $@ ) {
      $ssl_installed = 0;
   }

   ($admin_user,$admin_pwd) = split(/\s*:\s*/, $admin_user);

   if ( !$admin_user or !$admin_pwd ) {
      print STDERR "\nYou must supply the admin username and password\n\n";
      usage();
   }

   if ( !$imapHost or !$dir or !$our_domains ) {
      print STDERR "\nYou must supply the hostname, backup directory, and domain names\n\n";
      exit;
   }

   Log("Our domain is $our_domains");
   foreach $domain ( split(/,/, $our_domains ) ) {
      $domain = lc( $domain );
      $our_domains{"$domain"} = 1;
   }

   if ( $users ) {
      Log("Only messages for $users will be loaded");
   }
}

sub usage {

   print "Usage: $0\n";
   print "    -D <path to the mailboxes>\n";
   print "    -i server\n";
   print "    -A admin_user:admin_pwd \n";
   print "    -m local domains\n";
   print "    [-S <sent mailbox>]\n";
   print "    [-M <INBOX mailbox>]\n";
   print "    [-x <extension>] Import only files with this extension\n";
   print "    [-L <logfile>]\n";
   print "    [-d] debug]\n";
   print "    [-I] log IMAP commands/responses]\n";
   print "    [-U] update mode, don't copy msg if it already exists\n";
   print "    [-t <user>]  Used to load all messages into a test account for review\n";
   print "    [-l <msg limit>]  Used to limit the number of messages being copied\n";

   exit;

}

sub get_messages {

my $dir  = shift;
my $msgs = shift;

   #  Get a list of the message files 

   Log("Get list of messages in $dir") if $debug;

   opendir D, $dir;
   my @files = readdir( D );
   closedir D;
   foreach $_ ( @files ) {
      next if /^\./;
      if ( $extension ) {
         next unless /$extension$/i;
      }
      Log("   $dir/$_") if $debug;

      if ( $loaded++ < $msg_limit ) { 
         push( @$msgs, "$dir/$_");
      }
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
      
   $user = $opt_t if $opt_t;   # For testing

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

   $destMbxs{"$mbx"} = '1';

   if ( $date ) {
      sendCommand ($conn, "1 APPEND \"$mbx\" ($flags) \"$date\" \{$lenx\}");
   } else {
      sendCommand ($conn, "1 APPEND \"$mbx\" ($flags) \{$lenx\}");
   }
   readResponse ($conn);
   if ( $response !~ /^\+/ ) {
       Log ("1 unexpected APPEND response to $cmd");
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
       if ( $response =~ /^1 OK/i ) {
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
   push( @messages, $fn ) if $fn =~ /\.$extension$/i;

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

sub read_header {

my $msgfn = shift;
my ($msg,$from,$to,$cc,$date,$msgid);

   #  Open the message and collect the From, To, CC addresses, Msgid and 
   #  the date.

   Log("Opening $msgfn") if $debug;
   unless ( open(F, "<$msgfn") ) {
      Log("Error opening $msgfn: $!");
      return ($from,$to,$cc,$date,$msgid);
   }
   
   while( <F> ) {
      $msg .= $_;
      chomp;
      s/\r//g;
      last if $_ eq '';
   }
   close F;

   my $parser = new MIME::Parser;
   $entity = $parser->parse_data( $msg );
   my $header = $entity->head();

   chomp( $from    = $header->get('From') );
   chomp( $to      = $header->get('To') );
   chomp( $cc      = $header->get('Cc') );
   chomp( $date    = $header->get('Date') );
   chomp( $msgid   = $header->get('Message-Id') );

   $from =~ s/^\s+|\r|\t|\n//g;
   $to   =~ s/^\s+|\r|\t|\n//g;
   $cc   =~ s/^\s+|\r|\t|\n//g;
   $date =~ s/^\s+|\r|\t|\n//g;

   if ( $debug ) {
      Log("From    $from");
      Log("To      $to");
      Log("Cc      $cc");
      Log("date    $date");
      Log("msgid   $msgid");
   }

   return ($from,$to,$cc,$date,$msgid);

}


sub OLDread_header {

my $msgfn = shift;
my ($from,$to,$cc,$date);

   #  Open the message and collect the From, To, and CC addresses

    Log("Opening $msgfn") if $debug;
    unless ( open(F, "<$msgfn") ) {
       Log("Error opening $msgfn: $!");
       return ($from,$to,$cc,$date);
    }
    
    Log("Opened $msgfn successfully") if $debug;
    while( <F> ) {
       # Log("Reading line $_") if $debug;
       if ( /^Date: (.+)/ )  {
          $date = $1;
          $date =~ s/\r$|\m$//g;
          chomp $date;
       }
       if ( /^From:\s+(.+)/i ) {
          $from = $1;
          # $from =~ s/\r|\m//g;
          chomp $from;
       }
       if ( /^To:\s+(.+)/i ) {
          $to = $1;
          # $to =~ s/\r|\m//g;
          chomp $to;
       }
       if ( /^CC:\s+(.+)/i ) {
          $cc = $1;
          # $cc =~ s/\r|\m//g;
          chomp $cc;
       }
 
       last if $_ eq '';
    }
    close F;

    return ($from,$to,$cc,$date);

}

sub update_msglist {

my $from = shift;
my $to   = shift;
my $cc   = shift;
my $msgfn = shift;
my $date  = shift;
my $msgid = shift;
my $list = shift;

   #  Sort through the addresses and add them to the
   #  list if they are local users (meaning we need to
   #  put a copy of the message in their mailboxes.
      
   if ( $debug ) {
      Log("update_msglist");
      Log("From $from");
      Log("To   $to");
      Log("CC   $cc");
      Log("Msgid $msgid");
   }

   foreach $_ ( split(/,/, $to ) ) {
      Log("to $_") if $debug;
      $addr = extract_addr( $_ );
      $addr =~ /(.+)\@(.+)/;
      $domain = lc( $2 );
      if ( %USER ) {
         if ( $USER{"$addr"} ) {
            #  Only certain users are to be loaded and this one is on the list
            push( @$list, "$addr|$date|$inbox_mbx|$msgid|$msgfn") if $our_domains{$domain};
         }
      } else {
         #  Copy messages for everyone
         push( @$list, "$addr|$date|$inbox_mbx|$msgid|$msgfn") if $our_domains{$domain};
      }
   }

   foreach $_ ( split(/,/, $cc ) ) {
      Log("cc $_") if $debug;
      $addr = extract_addr( $_ );
      $addr =~ /(.+)\@(.+)/;
      $domain = lc( $2 );

      if ( %USER ) {
         if ( $USER{"$addr"} ) {
            #  Only certain users are to be loaded and this one is on the list
            push( @$list, "$addr|$date|$inbox_mbx|$msgid|$msgfn") if $our_domains{$domain};
         }
      } else {
         #  Copy messages for everyone
         push( @$list, "$addr|$date|$inbox_mbx|$msgid|$msgfn") if $our_domains{$domain};
      }
   }
   
   $addr = extract_addr( $from );
   $addr =~ /(.+)\@(.+)/;
   $domain = lc( $2 );
   Log("from $from") if $debug;

   if ( %USER ) {
      if ( $USER{"$addr"} ) {
         #  Only certain users are to be loaded and this one is on the list
         push( @$list, "$addr|$date|$sent_mbx|$msgid|$msgfn") if $our_domains{$domain};
      }
   } else {
      #  Copy messages for everyone
      push( @$list, "$addr|$date|$sent_mbx|$msgid|$msgfn") if $our_domains{$domain};
   }

}

sub extract_addr {

my $addr = shift;

   #  Get the address from the value supplied (which may be enclosed
   #  in angled brackets

   if ( $addr =~ /\<(.+)\>/ ) {
      $addr = $1;
   }
   $addr =~ s/\r$//g;
   $addr = lc( $addr );
   $addr =~ s/^\s+|\s+$//g;

   return $addr;

}

sub create_mailbox {

my $mbx  = shift;
my $conn = shift;

   #  Create the mailbox if necessary

   return 1 if uc( $mbx ) eq 'INBOX';    #  Don't need to create an Inbox; it always exists

   my $status = 1;
   sendCommand ($conn, "1 CREATE \"$mbx\"");
   my $loops;
   while ( 1 ) {
      readResponse ($conn);
      last if $loops++ > 99;
      last if $response =~ /^1 OK/i;
      last if $response =~ /already exists/i;
      if ( $response =~ /^1 NO|^1 BAD|^\* BYE/ ) {
         Log ("Error creating $mbx: $response");
         $status = 0;
         last;
      }
   } 

   return $status;
}

sub read_msg {

my $msgfn = shift;
my $msg   = shift;

   #  Read the message and return its contents in $msg

   Log("Opening $msgfn") if $debug;
   unless ( open(MSG, "<$msgfn") ) {
       Log("Error opening $msgfn: $!");
       return 0;
   }
   Log("Opened $msgfn successfully") if $debug;

   $$msg = $msgid = '';
   while( <MSG> ) {
      # Log("Reading line $_") if $debug;
 
      if ( /^Message-ID:\s*(.+)/i ) {
         $msgid = $1 if !$msgid;
         $msgid =~ s/\r$//;
      }

      s/\r+$//g;
      $$msg .= $_;
      chomp $$msg;
      $$msg .= "\r\n";
 
   }
   close MSG;

   return $msgid;

}

sub commafy {

my $number = shift;

   $_ = $$number;
   1 while s/^([-+]?\d+)(\d{3})/$1,$2/;
   $$number = $_;

}

#  getMsgIdList
#
#  Get a list of the user's messages in a mailbox
#
sub getMsgIdList {

my $mailbox = shift;
my $msgids  = shift;
my $conn    = shift;
my $empty;
my $msgid;

   sendCommand ($conn, "1 SELECT \"$mailbox\"");
   @response = ();
   my $loops;
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
        last if $loops++ > 10;
   }

   if ( $empty ) {
      return;
   }

   Log("Fetch the header info") if $debug;

   sendCommand ( $conn, "1 FETCH 1:* (body.peek[header.fields (Message-Id)])");
   undef @response;
   while ( 1 ) {
	readResponse ( $conn );
	return if $conn_timed_out;
	if ( $response =~ /^1 OK/i ) {
	   last;
	} elsif ( $response =~ /could not be processed/i ) {
           Log("Error:  response from server: $response");
           return;
        } elsif ( $response =~ /^1 NO|^1 BAD/i ) {
           return;
        }
   }

   $flags = '';
   for $i (0 .. $#response) {
       $_ = $response[$i];
       last if /OK FETCH complete/;

       if ($response[$i] =~ /Message-ID:/i) {
          $response[$i] =~ /Message-Id: (.+)/i;
          $msgid = $1;
          trim(*msgid);
          if ( $msgid eq '' ) {
             # Line-wrap, get it from the next line
             $msgid = $response[$i+1];
             trim(*msgid);
          }
          $$msgids{"$mailbox $msgid"} = 1;
          $msgid = '';
       }

       # last if $response[$i] =~ /^\)/;
   }
}


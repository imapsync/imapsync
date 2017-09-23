#!/usr/bin/perl

# $Header: /mhub4/sources/imap-tools/list_imap_folders.pl,v 1.25 2015/02/16 23:02:51 rick Exp $

#######################################################################
#   list_imap_folders.pl is called like this:                         #
#      ./list_folders.pl -S host/user/password [-O <output file>]     # 
#                                                                     #
#  If you have mailboxes with non-ASCII characters then to render     #
#  them from the IMAP UTF-7 encoding you must install the Perl Module #
#  Encode::IMAPUTF7.  It's available from the CPAN web site.          #
#######################################################################

use Socket;
use FileHandle;
use Fcntl;
use Getopt::Std;
use IO::Socket;
use Encode qw/encode decode/;
use MIME::Base64 qw(encode_base64 decode_base64);

#################################################################
#################################################################

init();

get_user_list( $user_list, \@users );

if ( $output_file ) {
   open(OUT, ">$output_file") or die "Can't open output file $output_file: $!";
}

if ( $report_large_msgs ) {
   Log("Large messages will be written to large_msg_report.list");
   if ( !open(L, ">large_msg_report.list") ) {
      Log("Error creating ./large_msg_report.list: $!");
      exit;
   }
   Log("Created ./large_msg_report.list") if $debug;
   print L "Large message report \n";
}

$total_size=$total_msgs=0;
@large_msgs = ();
foreach $sourceUser ( @users ) {
   ($User) = split(/:/, $sourceUser);
   print STDOUT "======================================\n";
   print STDOUT "$User\n";
   print OUT    "======================================\n";
   print OUT    "$User\n";
   print L      "======================================\n";
   print L      "$User\n";

   connectToHost($sourceHost, \$src)   or next;
   if ( !login($sourceUser,$sourcePwd, $sourceHost, $src, $srcMethod) ) {
      print OUT "Login failed for $sourceUser\n";
      print STDOUT "Login failed for $sourceUser\n";
      next;
   }
   namespace( $src, \$srcPrefix, \$srcDelim, $opt_x );
   @mbxs = getMailboxList( $srcPrefix, $src );

   @mbxs = sort @mbxs;

   $prefix = 'NONE' if !$srcPrefix;
   print OUT "Mailbox delimiter = $srcDelim\n";
   print OUT "Mailbox prefix    = $prefix\n";
   print STDOUT "Mailbox delimiter = $srcDelim\n";
   print STDOUT "Mailbox prefix    = $prefix\n\n";

   foreach $mbx ( @mbxs ) {
         if ( $src_uwash_imap ) {
            $mailbox = 'Mail/' . $mbx unless uc( $mbx ) eq 'INBOX';
            ($msgcount,$size) = count_msgs( $mailbox, $src ) if $stats;
         } else {
            ($msgcount,$size) = count_msgs( $mbx, $src ) if $stats;
         }
         $total_size += $size;
         $total_msgs += $msgcount;
         $mbx =~ s/^$srcPrefix//;
         $mbx =~ s/[$srcDelim]/\//g;
         if ( $utf ) {
            $mbx = decode( 'IMAP-UTF-7', $mbx );
         }
         if ( $output_file ) {
            if ( $stats ) {
               print OUT "$mbx   ($msgcount msgs, $size)\n";
            } else {
               print OUT "$mbx\n";
            }
         } else {
            if ( $stats ) {
               print STDOUT "$mbx   ($msgcount msgs, $size)\n";
            } else {
               print STDOUT "$mbx\n";
            }
         }
   }

   if ( $stats ) {
      $total_size = sprintf("%.2f", $total_size/1000 );
      print STDOUT "\nTotal bytes   $total_size GB\n";
      print STDOUT "Total msgs    $total_msgs\n";
      print OUT "\nTotal bytes   $total_size GB\n";
      print OUT "Total msgs    $total_msgs\n";
      close OUT;
      print STDOUT "Wrote list of mailboxes to $output_file\n" if $output_file;
   }

   print STDOUT "======================================\n";
   print OUT "======================================\n";
   logout( $src );

   if ( $debug ) {
      Log("Writing the list of large messages to large_msg_report.list") if $debug;
      $n = scalar @large_msgs;
      Log("There are $n lines in the list of large messages");
   }

   if ( @large_msgs ) {
      @large_msgs = reverse sort { $a <=> $b } @large_msgs;
      foreach $_ ( @large_msgs ) {
         ($size,$mbx,$subject) = split(/\s+/, $_, 3);
         if ( $utf ) {
            $mbx = decode( 'IMAP-UTF-7', $mbx );
         }
         $size = sprintf("%.1f", $size/1000000) . ' MB';
         Log("Writing $mbx  ($size) $subject to large_msg_report.list") if $debug;
         print L "$mbx   ($size) $subject\n";
      }
      Log("\nLarge message report has been written to large_msg_report.list");
   }

}

close OUT;
close L;
exit;


sub init {

   $os = $ENV{'OS'};

   processArgs();

   if ($timeout eq '') { $timeout = 60; }

   #  Open the logFile
   #
   $logfile = "list_imap_folders.log";
   if ( $logfile ) {
      if ( !open(LOG, ">> $logfile")) {
         print STDOUT "Can't open $logfile: $!\n";
         exit;
      } 
      select(LOG); $| = 1;
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

   use MIME::Base64 qw(encode_base64);
   $utf = 1;
   eval 'use Encode::IMAPUTF7 qw/decode/';
   if ( $@ ) {
      $utf = 0;
   }
   no warnings 'utf8';
 
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
    Log( $cmd ) if $showIMAP;

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
    Log( $response ) if $showIMAP;
}

#  Make a connection to an IMAP host

sub connectToHost {

my $host = shift;
my $conn = shift;

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
my $host = shift;
my $conn = shift;
my $method = shift;

   if ( $pwd =~ /^oauth2:(.+)/i ) {
      $token = $1;
      Log("password is an OAUTH2 token");
      login_xoauth2( $user, $token, $conn );
      return 1;
   }

   if ( $user =~ /:/ ) {
      ($user,$pwd) = split(/:/, $user);
      $rc = login_plain( $user, $user, $pwd, $conn );
      return $rc;
   }

   if ( $admin_user ) {
      ($admin,$pwd) = split(/:/, $admin_user);
      $rc = login_plain( $user, $admin, $pwd, $conn ) or exit;
      return $rc;
   }

   if ( uc( $method ) eq 'CRAM-MD5' ) {
      #  A CRAM-MD5 login is requested
      my $rc = login_cram_md5( $user, $pwd, $conn );
      return $rc;
   }

   #  Otherwise do a ordinary login

   sendCommand ($conn, "1 LOGIN $user \"$pwd\"");
   while (1) {
	readResponse ( $conn );
	last if $response =~ /^1 OK/i;
	if ($response =~ /^1 NO|^1 BAD|^\* BYE/i) {
           return 0;
	}
   }

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

   #  Do an AUTHENTICATE = PLAIN.  

   $login_str = sprintf("%s\x00%s\x00%s", $user,$admin,$pwd);
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
           return 0;
        }
   }

   my ($challenge) = $response =~ /^\+ (.+)/;

   $response = cram_md5( $challenge, $user, $pwd );

   sendCommand ($conn, $response);
   while (1) {
        readResponse ( $conn );
        last if $response =~ /^1 OK/i;
        if ($response =~ /^1 NO|^1 BAD|^\* BYE/i) {
           return 0;
        }
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

   if ( $src_uwash_imap ) {
      my @temp;
      foreach $_ ( @mbxs ) {
         next if /^\./;     #  Skip if starting with a dot
         s/^Mail\///;
         push( @temp, $_);
      }
      @mbxs = @temp;
      @temp = ();
   }

   return @mbxs;
}

#  listMailboxes
#
#  Get a list of the user's mailboxes
#
sub listMailboxes {

my $prefix  = shift;
my $conn = shift;

   sendCommand ($conn, "1 LIST \"\" \"$prefix\"");
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
           next;
        }

        next if $mbx =~ /\[Gmail\]\/All Mail/; 

        push ( @mbxs, $mbx ) if $mbx ne '';
   }

   return @mbxs;
}

sub processArgs {

   if ( !getopts( "dS:L:O:uhHsU:IA:l:d" ) ) {
      usage();
      exit;
   }
   if ( $opt_S =~ /\\/ ) {
      ($sourceHost, $sourceUser, $sourcePwd,$srcMethod) = split(/\\/, $opt_S);
   } else {
      ($sourceHost, $sourceUser, $sourcePwd,$srcMethod) = split(/\//, $opt_S);
   }
   $showIMAP = 1 if $opt_I;
   $utf = 1 if $opt_u;
   $timeout = 45 unless $timeout;
   $output_file = $opt_O;
   $large_msg_threshold = $opt_U;
   $stats = 1 if $opt_s;
   $admin_user = $opt_A;
   $user_list  = $opt_l;
   $debug = 1  if $opt_d;

   $report_large_msgs = 1 if $large_msg_threshold > 0;

   if ( $opt_h or $opt_H ) {
      usage();
      exit;
   }

   unless( $sourceHost ) {
      usage();
      exit;
   }
   if ( !$sourceUser and !$user_list ) {
      usage();
      exit;
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
      } elsif ( $response =~ /^1 NO|^1 BAD|^\* BYE/i ) {
         Log("Unexpected response to NAMESPACE command: $response");
         last;
      }
   }

   foreach $_ ( @response ) {
      if ( /NAMESPACE/i ) {
         # $src_uwash_imap = 1 if ?\("\#mh/"?;
         $src_uwash_imap = 1 if /"\#mh\/"/;
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
   login($suser,$spwd,$shost,$src);

   connectToHost($dhost,\$dst);
   login($duser,$dpwd,$dhost,$dst);

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

sub count_msgs {

my $mbx  = shift;
my $conn = shift;
my @msgs;

   #  Get the msg count and size

   getMsgList( $mbx, \@msgs, $conn, 'SELECT' ); 
   my $msgcount = $#msgs + 1;

   my $total = 0;
   foreach my $size ( @msgs ) {
      $total += $size;
   }
   $total = sprintf("%.2f", $total/1000000);
   $total .= ' MB';
   my $count = scalar @msgs;

   return ($count,$total);

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

sub validate_date {

my $date = shift;
my $invalid;

   #  Make sure the "after" date is in DD-MMM-YYYY format

   my ($day,$month,$year) = split(/-/, $date);
   $invalid = 1 unless ( $day > 0 and $day < 32 );
   $invalid = 1 unless $month =~ /Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec/i;
   $invalid = 1 unless $year > 1900 and $year < 2999;
   if ( $invalid ) {
      Log("The 'Sent after' date $date must be in DD-MMM-YYYY format");
      exit;
   }
}

sub commafy {

my $number = shift;

   $_ = $$number;
   1 while s/^([-+]?\d+)(\d{3})/$1,$2/;

   $$number = $_;

}

sub usage {

   print STDERR "Usage: list_imap_folders.pl -S <host>/<user>/<password> [-O <output file>]\n";
   print STDERR "  [-A <admin_user:admin_password>]\n";
   print STDERR "  [-s]  Include count of messages and bytes for each mailbox\n";
   print STDERR "  [-U <size in bytes>] Write large_msg_report.list with each msg exceeding threshold\n";

}

sub Log {

my $str = shift;
 
   print STDERR "$str\n";
   print LOG "$str\n";

}

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
my $msgid;

   Log("large_msg_threshold $large_msg_threshold") if $debug;
   @$msgs  = ();
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

   return (0, 0) if $empty;

   my $start = 1;
   my $end   = '*';
   $start = $start_fetch if $start_fetch;
   $end   = $end_fetch   if $end_fetch;

   sendCommand ( $conn, "1 FETCH $start:$end (RFC822.SIZE body.peek[header.fields (Subject)])");
   
   @response = ();
   while ( 1 ) {
	readResponse ( $conn );

	if ( $response =~ /^1 OK/i ) {
		last;
	} 
        last if $response =~ /^1 NO|^1 BAD|^\* BYE/;

        if ( $response =~ /^\* BYE/ ) {
           Log("The server terminated our connection: $response");
           exit;
        }
   }

   $flags = '';
   for $i (0 .. $#response) {
        $response = $response[$i];
	last if $response[$i] =~ /^1 OK FETCH complete/i;

        if ( $response =~ /^\* BYE/ ) {
           Log("The server terminated our connection: $response[$i]");
           Log("msgnum $msgnum");
           exit;
        }

        if ( $response[$i] =~ /Subject:\s*(.+)/i ) {
           $subject = $1;
        }

        if ( $response[$i] =~ /INTERNALDATE (.+) RFC822\.SIZE/i ) {
           $date = $1;
           $date =~ /"(.+)"/;
           $date = $1;
           $date =~ s/"//g;
        }
           
        if ( $response[$i] =~ /\(RFC822\.SIZE (.+)\)/i) {
           ($size) = split(/\s+/, $1);
           Log("msg size $size") if $debug;
           if ( $report_large_msgs == 1 and $size > $large_msg_threshold) {
              Log("Added msg size $size to large_msg_report") if $debug;
              push( @large_msgs, "$size $mailbox $subject");
              $subject = '';
           }
        }

        if ( $size ) {
           push (@$msgs,$size);
           $size = '';
        }
   }

   return 1;

}

sub get_user_list {

my $file = shift;
my $list = shift;

   #  Build a list of the users to be checked

   if ( $sourceUser ) {
      push( @$list, $sourceUser );
      return;
   }

   if ( !open(F, "<$file") ) {
      print STDERR "Error opening $file: $!\n";
      exit;
   }
   while( <F> ) {
       chomp;
           s/^\s#//;
           next if /^#/;
           push( @$list, $_ ) if $_;
   }
   close F;

}


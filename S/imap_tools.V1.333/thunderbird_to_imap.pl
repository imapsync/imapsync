#!/usr/bin/perl

# $Header: /mhub4/sources/imap-tools/thunderbird_to_imap.pl,v 1.14 2015/03/15 23:57:02 rick Exp $

use Socket;
use FileHandle;
use File::Find;
use Fcntl;
use Getopt::Std;
use MIME::Base64 qw(encode_base64 decode_base64 );

######################################################################
#  Program name   thunderbird_to_imap.pl                             #
#  Written by     Rick Sanders                                       #
#  Date           15 July 2013                                       #
#                                                                    #
#  Description                                                       #
#                                                                    #
#  thunderbird_to_imap.pl is used to copy Thunderbird messages       #
#  to an IMAP server.  The script parses the Thunderbird folders     #
#  into separate messages which are inserted into IMAP mailboxes     #
#  with same name on the IMAP server (creating the mailboxes if      #
#  they do not already exist).                                       #
#                                                                    #
#  Usage: thunderbird_to_imap.pl -i host/username/password           #
#            -m <location of Tbird folders>                          #
#                                                                    #
#  See the Usage() for optional arguments                            #
#                                                                    #
######################################################################

init();
connectToHost($imapHost, \$conn);
login($imapUser,$imapPwd, $conn );
namespace( $conn, \$prefix, \$delim, $opt_x );

push( @dirs, $mbxroot );
find( \&getMailboxes, @dirs );   # Returns @mbxs

if ( $mbx_list ) {
   Log("mbx_list $mbx_list");
   foreach $_ ( split(/,/, $mbx_list ) ) {
       $MBXS{"$_"} = 1;
   }
}

foreach $mbxfn ( @mbxs ) {
   ## $count = count_msgs( $mbxfn );

   #  Build the IMAP mailbox name
   $imapmbx = $mbxfn;
   $imapmbx =~ s/$mbxroot//;
   $imapmbx =~ s/\.sbd//g;
   $imapmbx =~ s/^\///;

   if ( %MBXS ) {
       next unless $MBXS{"$imapmbx"};
   }

   next if $EXCLUDE_MBXS{"$imapmbx"};   # Skip these ones

   $imapmbx = mailbox_name( $imapmbx, $prefix, $delim );
   encode_ampersand( \$imapmbx);

   $mbxs++;
   createMbx( $imapmbx, $conn ) unless mbxExists( $imapmbx, $conn );
        
   if ( $update ) {
      Log("Get msgids on the destination") if $debug;
      getMsgIdList( $imapmbx, \%MSGIDS, $conn );
   }

   Log("Copying $imapmbx folder");
   $copied = load_folder_into_imap( $mbxfn, $imapmbx, \%MSGIDS, $conn );
   $total_copied += $copied;
}
Log("Done");
logout( $conn );

Log("\n\nSummary:\n");
Log("   Mailboxes copied    $mbxs");
Log("   Msgs copied         $total_copied");
Log("Done");
exit;


sub init {

   if ( !getopts('m:M:L:i:dIUE:A:F:x:XcR:') ) {
      usage();
   }

   ($sec,$min,$hour,$mday,$mon,$this_year,$wday,$yday,$isdst) = localtime (time);
   $this_year += 1900;

   $mbxroot  = $opt_m;
   $mbx_list = $opt_M;
   $logfile  = $opt_L;
   $exclude  = $opt_E;
   $range    = $opt_R;
   $debug    = 1 if $opt_d;
   $showIMAP = 1 if $opt_I;
   $update   = 1 if $opt_U;
   $crlf     = 1 if $opt_c;
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
   Log("Running in update mode") if $update;

   #  Determine whether we have SSL support via openSSL and IO::Socket::SSL
   $ssl_installed = 1;
   eval 'use IO::Socket::SSL';
   if ( $@ ) {
      $ssl_installed = 0;
   }

   $os = $ENV{'OS'};
   $os = '' if $crlf;   # Use Unix/Linx crlf handling

   foreach $_ ( split(/,/, $exclude ) ) {
      $EXCLUDE_MBXS{"$_"} = 1;
   }

   thunderbird_flags();

}

sub usage {

   print "Usage: ThunderbirdToIMAP.pl\n";
   print "    -m <root location of mailfiles>\n";
   print "    -i <server/username/password>\n";
   print "    [-E <exclude folder list> folder1.folder2, etc if want to not copy them]\n";
   print "    [-M <folder list>  folder1,folder2, etc if want to copy just certain folders]\n";
   print "    [-U update mode, don't copy duplicates]\n";
   print "    -R <start:end> range of message numbers to copy\n";
   print "    [-L <logfile>]\n";
   print "    [-d debug]\n";
   print "    [-I log IMAP protocol exchanges]\n";

}

sub Log {

my $line = shift;
my $msg;

   ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime (time);
   $year += 1900;
   $msg = sprintf ("%.2d-%.2d-%.4d.%.2d:%.2d:%.2d %s",
                  $mon + 1, $mday, $year, $hour, $min, $sec, $line);
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

   ($host,$port) = split(/:/, $host);

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

#
#  login in at the source host with the user's name and password
#
sub login {

my $user = shift;
my $pwd  = shift;
my $conn = shift;

   if ( $admin_user ) {
      ($admin_user,$admin_pwd) = split(/:/, $admin_user);
      login_plain( $user, $admin_user, $admin_pwd, $conn ) or exit;
      return 1;
   }

   if ( $pwd =~ /^oauth2:(.+)/i ) {
      $token = $1;
      Log("password is an OAUTH2 token");
      login_xoauth2( $user, $token, $conn );
      return 1;
   }

   # Log("Logging in as $user") if $debug;
   $rsn = 1;
   sendCommand ($conn, "$rsn LOGIN $user $pwd");
   while (1) {
	readResponse ( $conn );
	if ($response =~ /^$rsn OK/i) {
		last;
	}
	elsif ($response =~ /NO/) {
		Log ("unexpected LOGIN response: $response");
		exit;
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
	if ( $response =~ /1 OK/i ) {
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

   # Log("   Inserting message") if $debug;
   $lenx = length($$message);
   return if $lenx == 0;

   if ( $date ) {
      $header_date = $date;
      fix_date( \$date );
   }

   $flags =~ s/\\Recent//i;

   if ( $date ) {
      sendCommand ($conn, "1 APPEND \"$mbx\" ($flags) \"$date\" \{$lenx\}");
   } else {
      sendCommand ($conn, "1 APPEND \"$mbx\" ($flags) \{$lenx\}");
   }
   readResponse ($conn);
   if ( $response !~ /^\+/ ) {
       Log ("unexpected APPEND response: $response");
       if( $response =~ /invalid(.+)date/i ) {
          Log("date $header_date");
          return "INVALID_DATE";
       } 
       push(@errors,"Error appending message to $mbx for $user");
       return 0;
   }

   # print $conn "$$message\r\n";

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

#  trim
#
#  remove leading and trailing spaces from a string
sub trim {

local (*string) = @_;

   $string =~ s/^\s+//;
   $string =~ s/\s+$//;

   return;
}

#
#  getMailboxes
#
#  Get a list of the folders and populate @mbxs with the
#  mailbox filepath
#

sub getMailboxes {

my $fn;

   return if not -f;
   $fn = $File::Find::name;

   unless ( $fn =~ /\.sbd$|\.msf|\.dat|\.html/ ) {
        push( @mbxs, $fn );
   }
   
} 

sub fix_date {

my $date = shift;

   #  Try to make the date acceptable to IMAP

   return if $$date eq '';
   $$date =~ s/\s+/ /g;
   if ( $$date =~ /^(.+),/ ) {
      ($dmy,$$date) = split(/,/,$$date,2 );
   }
   $$date =~ s/,//g;
   $$date =~ s/^\s+//;
   $$date =~ s/\s/-/;
   $$date =~ s/\s/-/;
   $$date =~ s/"//g;

   #  Some dates don't pad the number of characters in the hr:min:sec part to 2 digits

   my @terms = split(/\s+|-/, $$date);
   foreach $term ( @terms ) {
      if ( ($term !~ /(.+):(.+):(.+)/) and ($term !~ /(.+):(.+)/) ) {
         next;
      }
      # next unless $term =~ /(.+):(.+):(.+) and $term =~ /(.+):(.+)/;

      my ($hr,$min,$sec);
      $hr = $1; $min = $2; $sec = $3;
      $sec = '00' if $sec eq '';
      $hr  = '0' . $hr  if length($hr)  == 1;
      $min = '0' . $min if length($min) == 1;
      $sec = '0' . $sec if length($sec) == 1;
      my $ts = "$hr:$min:$sec";
      $$date =~ s/$term/$ts/;
      last;
   }

   $$date =~ s/\./:/g;

   my ($dom) = split(/-/, $$date);
   if ( length( $dom ) == 1 ) {
      $$date = '0' . $$date;
   }
    
    #  Make sure there is a space between the date, timestamp, and offsest
    $str = $$date;
    eval '$_ = substr $str, 11, 1';
    eval 'substr $str, 11, 1, " "';

    eval '$_ = substr $str, 20, 1';
    eval 'substr $str, 20, 1, " "';
    $$date = $str;

    #  Strip off (GMT), (PST), etc

    my @terms = split(/\s+/, $$date );
    $terms[2] = '+0000' if $terms[2] !~ /^\+|^\-/;
    $$date = "$terms[0] $terms[1] $terms[2]";

    #  Remote some extraneous terms that can cause problems for
    #  certain IMAP servers

    $$date =~ s/-GM|PST|GMT|UTC//g;
    $$date =~ s/\s+$//;

    validate_date( $date );

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

sub mailbox_name {

my $mbx    = shift;
my $prefix = shift;
my $delim  = shift;

   #  Adjust the IMAP mailbox name using the prefix (if any) and the
   #  mailbox delimiter.

   if ( $delim ne '/' ) {
       #  Need to substitute the dst's hierarchy delimiter for the '/' character
       $srcDelim = '\\' . $srcDelim if $srcDelim eq '.';
       $mbx =~ s#/#$delim#g;
       $mbx =~ s/\\//g;
   }
   if ( $prefix ) {
       #  The IMAP server uses a mailbox prefix so insert it
       $mbx = "$prefix$mbx" unless uc($mbx) eq 'INBOX';
   }
   return $mbx;
}

sub load_folder_into_imap {

my $file    = shift;
my $mailbox = shift;
my $MSGIDS  = shift;
my $conn    = shift;
my @mail  = ();
my $mail  = [];
my $blank = 1;
local *FH;
local $_;
my ($message,$date,$copied,$marked_for_delete);

    #  read_folder returns the contents of a Thunderbird folder
    #  eg, all of the messages in it.

    open(FH,"< $file") or die "Can't open $file";

    if ( $range ) {
       Log("Range of messages to be copied = $range");
    }

    ($range_start,$range_end) = split(/:/, $range );

    $skip = 0;
    $blank=0;
    $msgnum=0;
    $flags='';
    while(<FH>) {
        if ( $os =~ /Windows/i ) {
           s/\r$//;
           s/;
           $//;
        } else {
           chomp;
        }
        # if($blank && /\AFrom .*\d{4}/) {
        if($blank && /\AFrom\s/) {
           #  End of the message, this is the first line of the next message
           #  load the message into IMAP
           # unless( $marked_for_delete ) {

           $msgnum++;
           if ( $range ) {
              if ( $msgnum > $range_end ) {
                 Log("End of range at $msgnum");
                 last;
              }
              next unless $msgnum >= $range_start;
          }

           unless( $skip ) {
              $flags = map_flags( $status, $status2 );
              $status = insertMsg( $mailbox, \$message, $flags, $date, $conn);
              $copied++;
              $flags = '';
              $skip = 0;
           }

           if ( $msgs_per_folder ) {
              #  opt_F allows us to limit number of messages copied per folder
              last if $copied == $msgs_per_folder;
           }

           if ( $copied > 0 ) {
              if ( $copied/500 == int($copied/500)) { Log("   $copied messages so far"); }
           }

           $message=$date=$flags=$status=$msgid=$marked_for_delete='';
           $blank = $skip = 0;

        } else {
            $blank = m#\A\Z#o ? 1 : 0;
            # push(@{$mail}, $_);
            # print STDOUT "line   $_\n";

            if ( $opt_X ) {
               $message .= "$_\n";
            } else {
               $message .= "$_\r\n";
            }

            if ( /^Date: (.+)/ ) {
               $date = $1 unless $date;
            }
            if ( /^Message-ID: (.+)/i ) {
               $msgid = $1 unless $msgid;
               if ( $update ) {
                  #  In update mode don't copy any messages that already exist in IMAP
                  $skip = 1 if $$MSGIDS{"$msgid"};
               }
            }
            if ( /X-Mozilla-Status:\s*(.+)/ ) {
               $status = $1 unless $status;
            }
            if ( /X-Mozilla-Status2:\s*(.+)/ ) {
               $status2 = $1 unless $status2;
            }
        }
    }

    #  Copy the final message in the folder

    unless ( $skip ) {
       $flags = map_flags( $status, $status2 );
       $status = insertMsg( $mailbox, \$message, $flags, $date, $conn);
       $copied++;
    }
    close(FH);

    return $copied;
}

sub count_msgs {

my $file    = shift;
my $mailbox = shift;
my $conn    = shift;
my @mail  = ();
my $mail  = [];
my $blank = 1;
local *FH;
local $_;
my ($message,$date,$count,$marked_for_delete);
my $seen_mask = 0x0001;
my $del_mask  = 0x0008;

    #  Count the number of messages in the folder

    open(FH,"< $file") or die "Can't open $file";

    $blank=$count=$marked_for_delete=0;
    $status='';
    while(<FH>) {
        s/\r$//;
        s/;
        $//;
        if($blank && /\AFrom .*\d{4}/) {
           #  End of the message, this is the first line of the next message
           $count++ unless $marked_for_delete;
           $message=$date=$flags=$status=$marked_for_delete='';
           $blank = 0;
        } else {
            $blank = m#\A\Z#o ? 1 : 0;
            if ( /X-Mozilla-Status:\s*(.+)/ ) {
               #  The X-Mozilla-Status mask does not seem to always
               #  accurately reflect the deleted status
               my $status = $1;
               # $marked_for_delete = 1 if $status & $del_mask;
            }
        }
    }

    #  Count the final message in the folder

    $count++ unless $marked_for_delete;
    close(FH);

    return $count;
}

#  Get a list of the user's messages in a mailbox
#
sub getMsgIdList {

my $mailbox = shift;
my $msgids  = shift;
my $conn    = shift;
my $empty;
my $msgnum;
my $from;
my $msgid;

   %$msgids  = ();
   sendCommand ($conn, "1 SELECT \"$mailbox\"");
   undef @response;
   $empty=0;
   while ( 1 ) {
        readResponse ( $conn );
        if ( $response =~ / 0 EXISTS/i ) { $empty=1; }
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

   if ( $empty ) {
      return;
   }

   Log("Fetch the header info") if $debug;

   # sendCommand ( $conn, "1 FETCH 1:* (body[header.fields (Message-Id)])");
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

       if ( $response[$i] =~ /\* (.+) FETCH/ ) {
          ($msgnum) = split(/\s+/, $1);
       }

       if ($response[$i] =~ /Message-ID:/i) {

          $response[$i] =~ /Message-Id: (.+)/i;
          $msgid = $1;
          trim(*msgid);
          if ( $msgid eq '' ) {
             # Line-wrap, get it from the next line
             $msgid = $response[$i+1];
             trim(*msgid);
          }
          $$msgids{"$msgid"} = $msgnum;
       }
   }

}

sub encode_ampersand {

my $mbx = shift;

   #  The IMAP RFC requires mailbox names with '&' be
   #  encoded as '&-'

   if ( $$mbx =~ /\&/ ) {
      if ( $$mbx !~ /\&-/ ) {
         #  Need to encode the '&' as '&-'
         $$mbx =~ s/\&/\&-/g;
         Log("Encoded $$mbx");
      }
   }

}

sub validate_date {

my $date = shift;
my ($sec,$min,$hour,$mday,$mon,$this_year,$wday,$yday,$isdst) = localtime (time);


    #  If the date doesn't conform to the standard return a null value

    ($day,$mon,$yr,$hr,$min,$sec,$offset) =~ /(.+)-(.+)-(.+) (.+):(.+):(.+) (.+)/;
    $$date =~ /(.+)-(.+)-(.+) (.+):(.+):(.+) (.+)/;

    my $day = $1;
    my $mon = $2;
    my $yr  = $3;
    my $hr  = $4;
    my $min = $5;
    my $sec = $6;
    my $offset = $7;
    $offset =~ s/\+|\-//g;
    $this_year += 1900;

    #  Make sure the date has valid values for each part and
    #  return a blank value if not so.
  
    my $save_date = $$date;

    $$date = '' unless ( $day >= 1 and $day <= 31 );
    $$date = '' unless ( $mon =~ /Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec/i );
    $$date = '' unless ( $yr > 1950 and $yr <= $this_year );
    $$date = '' unless ( $hr  >= 0 and $hr  <= 23 );
    $$date = '' unless ( $min >= 0 and $min <= 59 );
    $$date = '' unless ( $sec >= 0 and $sec <= 59 );
    $$date = '' unless ( $offset >= 0 and $offset <= 2400 );

    Log("$save_date is invalid, not using it") if $$date eq '';

}

sub thunderbird_flags {

   #  Define the Thunderbird flags

   #  Status codes for X-Mozilla-Status 

   $seen_mask     = 0x0001;
   $answered_mask = 0x0002;
   $marked_mask   = 0x0004;
   $del_mask      = 0x0008;
   $has_re_mask   = 0x0010;
   $elided_mask   = 0x0020;
   $offline_mask  = 0x0080;
   $watched_mask  = 0x0100;
   $authed_mask   = 0x0200;
   $partial_mask  = 0x0400;
   $queued_mask   = 0x0800;
   $forwarded_mask  = 0x1000;
   $priorities_mask = 0xE000;

   #  Status codes for X-Mozilla-Status2 

   $new_mask          = 0x00010000;
   $ignored_mask      = 0x00040000;
   $imap_deleted_mask = 0x00200000;
   $report_needed     = 0x00400000;
   $report_sent       = 0x00800000;
   $template          = 0x01000000; 
   $labels            = 0x0E000000; 
   $attachment        = 0x10000000;
}

sub map_flags {

my $status  = shift;
my $status2 = shift;
my $imap_flags;

   #  Only a few Thunderbird flags correspond to the standard IMAP flags.  However,
   #  IMAP supports 'custom' flags whose meaning is left undefined.  Create standard IMAP flags
   #  for the Thunderbird ones that align with IMAP and custom IMAP flags for the others.
   #
   #  See http://www.eyrich-net.org/mozilla/X-Mozilla-Status.html?en for a description of
   #  Thunderbird flags.

   if ( $debug ) {
      Log("X-Mozilla-Status   $status");
      Log("X-Mozilla-Status2  $status2");
   }

   #  Map the X-Mozilla-Status flags
   
    $imap_flags .= '\\SEEN '      if $status & $seen_mask;
    $imap_flags .= '\\ANSWERED '  if $status & $answered_mask;
    $imap_flags .= '$MARKED '     if $status & $marked_mask;
    #
    #  Don't mark messages as deleted because them they don't show up on the server
    #  $imap_flags .= '\\DELETED '   if $status & $del_mask;
    #
    $imap_flags .= '$HAS_RE '     if $status & $has_re_mask;
    $imap_flags .= '$ELIDED '     if $status & $elided_mask; 
    $imap_flags .= '$OFFLINE '    if $status & $offline_mask;
    $imap_flags .= '$WATCHED '    if $status & $watched_mask;
    $imap_flags .= '$AUTHED '     if $status & $authed_mask; 
    $imap_flags .= '$PARTIAL '    if $status & $partial_mask;
    $imap_flags .= '$QUEUED '     if $status & $queued_mask;
    $imap_flags .= '$FORWARDED '  if $status & $forwarded_mask;
    $imap_flags .= '$PRIORITIES ' if $status & $priorities_mask;

    #  Map the X-Mozilla-Status2 flags
   
    $imap_flags .= '$NEW '           if $status & $new_mask;
    $imap_flags .= '$IGNORED '       if $status & $ignored_mask;
    $imap_flags .= '$IMAP_DELETED '  if $status & $imap_deleted_mask;
    $imap_flags .= '$REPORT_NEEDED ' if $status & $report_needed_mask;
    $imap_flags .= '$REPORT_SENT '   if $status & $report_sent_mask;
    $imap_flags .= '$TEMPLATE '       if $status & $template_mask;
    $imap_flags .= '$LABELS '        if $status & $labels_mask;
    $imap_flags .= '$ATTACHMENT '    if $status & $attachment_mask;
   
    chop $imap_flags;

    return $imap_flags;

}

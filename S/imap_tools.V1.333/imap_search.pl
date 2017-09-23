#!/usr/bin/perl

# $Header: /mhub4/sources/imap-tools/imap_search.pl,v 1.4 2015/02/02 16:15:01 rick Exp $

use Socket;
use FileHandle;
use Fcntl;
use Getopt::Std;
use IO::Socket;
use MIME::Base64 qw(decode_base64 encode_base64); 

   #   Build the search filter which can have multiple criteria like
   #   "from joe@abc.com" "subject test message" 
   #
   #   ./imapsearch.pl "kw=value" "kw=value" etc.  The search AND's the
   #   filters together giving the results which match all the criteria.
   #
   #   IMAP SEARCH syntax. 'AND' is implied.
   #
   #   AND search1 search2 etc
   #   OR search1 search2 etc
   #   NOT search1 search2 etc

   init();

   $args = scalar @ARGV;
   $i = 1;
   for $i ( 1 .. $#ARGV ) {
        ($kw,$val) = split(/\s*=\s*/, $ARGV[$i]);
        $kw = "header $kw" if $kw =~ /message-id|date/i;
        $search_filter .= "$kw \"$val\" ";
        last if $ARGV[$i] eq '';
   }
   $search_filter =~ s/\s+$//;
   $search_filter =~ s/\s*""//g;

   connectToHost($sourceHost, \$src)   or exit;
   login($sourceUser,$sourcePwd, $sourceHost, $src, $srcMethod) or exit;
   namespace( $src, \$srcPrefix, \$srcDelim, $opt_x );

   if ( !@mbxs ) {
      @mbxs = getMailboxList( $srcPrefix, $src );
   }

   $search_filter =~ s/""//g;
   $search_filter =~ s/AND//g;
   $search_filter =~ s/\s+$//;
   $where = "in all folders\n";
   $where = "in $mbx folder" if $mbx;
   print "\nSearching for $search_filter $where\n";

   foreach $srcmbx ( @mbxs ) {
        $match = 0;
        examineMbx( $srcmbx, $src );

        #  Get messages matching the field=value input

        $nums = search( $srcmbx, $search_filter, $src );
        foreach $msgnum ( split(/\s+/, $nums) ) {
             $match = 1;
             ($date,$subj) = get_msg_header( $msgnum, $src );
             format_date( \$date );
             push( @output, "$srcmbx|$date|$subj");
        }
        if ( $match ) {
           $longest_mbx = length( $srcmbx ) if length( $srcmbx ) > $longest_mbx;
        }
   }
   logout( $src );

   if ( !@output ) {
      print "\nNo matches were found\n";
      exit;
   }

   $longest_mbx += 2;

   $line = pack("A$longest_mbx A34, A25", 'Folder', '    Date', 'Subject' );
   print "\n$line\n";
   print "===================================================================================\n";
   foreach $_ ( @output ) {
       ($mbx,$date,$subj) = split(/\|/, $_);
       $line = pack("A$longest_mbx A26", $mbx, $date );
       $line .= "   $subj";
       print "$line\n";
   }

   exit;


sub init {

   $os = $ENV{'OS'};

   #  Determine whether we have SSL support via openSSL and IO::Socket::SSL
   $ssl_installed = 1;
   eval 'use IO::Socket::SSL';
   if ( $@ ) {
      $ssl_installed = 0;
   }
   read_config();

   if ( $ARGV[0] =~ /(.+)\/(.+)\/oauth2:(.+)/ ) {
      $sourceHost = $1;
      $sourceUser = $2;
      $sourcePwd  = "oauth2:$3";
   } elsif ( $ARGV[0] =~ /(.+):(.+)\/(.+)\/(.+):(.+)/ ) {
      # host:port/user/pwd:mbx
      $sourceHost = $1 . ":$2";
      $sourceUser = $3;
      $sourcePwd  = $4;
      $mbx        = $5;
   } elsif ( $ARGV[0] =~ /(.+):(.+)\/(.+)\/(.+)/ ) {
      #  host:port/user/pwd
      $sourceHost = $1 . ":$2";
      $sourceUser = $3;
      $sourcePwd  = $4;
   } elsif ( $ARGV[0] =~ /(.+):(.+)/ ) {
      #  user:mbx
      $sourceUser = $1;
      $mbx = $2;
      $sourceUser = "$sourceUser/$admin_user";
      $sourcePwd  = $admin_pwd;
   } elsif ( $ARGV[0] and $ARGV[1] ) {
      #  user filter
      $sourceUser = "$ARGV[0]/$admin_user";
      $sourcePwd  = $admin_pwd;
   } elsif ( $ARGV[0] =~ /:/ ) {
      #  user:mbx filter
      ($ARGV[0],$mbx) = split(/:/, $ARGV[0] );
      $sourceUser = "$ARGV[0]/$admin_user";
      #  Just the username specified so we will use the admin credentials
      unless( $admin_user and $admin_pwd ) {
         usage();
         exit;
      }
   } else {
       print "\nUsage: $0 <host/user/password[:mbx]> <\"field1=value1\"> ... <\"fieldn=valuen\">\n\n";
       exit;
   }

   push( @mbxs, $mbx ) if $mbx;

   if ( $opt_h or $opt_H ) {
      usage();
   }
   unless( $sourceUser and $sourcePwd and $sourceHost ) {
      usage();
   }

   #  Set up signal handling

   $SIG{'ALRM'} = 'signalHandler';
   $SIG{'HUP'}  = 'signalHandler';
   $SIG{'INT'}  = 'signalHandler';
   $SIG{'TERM'} = 'signalHandler';
   $SIG{'URG'}  = 'signalHandler';

}

sub read_config {

   #  If there is a config file grab the host and admin credentials so
   #  the operator doesn't have to specify them in the command line

   my @dirs = qw( . /etc /var/tmp /usr/bin );
   foreach $dir ( @dirs ) {
     $cf = "$dir/imap_search.cf";
     if ( -e $cf ) {
        open( CF, "<$cf");
        while( <CF> ) {
           chomp;
           s/^\s+//;
           if ( /:/ ) {
              ($kw,$val) = split(/:/, $_, 2);
              $kw =~ s/\s+//g;
              $val =~ s/^\s+|\s+$//g;
              $KW{"$kw"} = $val;
           }
        }
        close CF;
        $sourceHost = $KW{server};
        $admin_user = $KW{admin_user};
        $admin_pwd  = $KW{admin_pwd};
        last;
     }

   }

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
    Log ("<< $response") if $showIMAP;

    if ( $response =~ /server unavailable|connection closed/i ) {
       resume();
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
      $line = sprintf ("%.2d-%.2d-%d.%.2d:%.2d:%.2d %s\n",
		     $mon + 1, $mday, $year + $yr, $hour, $min, $sec,$str);
      print LOG "$line";
   } 
   print STDOUT "$str\n" unless $quiet_mode;

}

sub today {
      
   my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
   if ($year < 99) { $yr = 2000; }
   else { $yr = 1900; }
   my $today = sprintf ("%.2d-%.2d-%d", $mon + 1, $mday, $year + $yr);
   return $today;
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

#  insertMsg
#
#  This routine inserts a message into a user's mailbox
#
sub insertMsg {

local ($conn, $mbx, *message, $flags, $date) = @_;
local ($lenx);

   $lenx = length($message);

   Log("   Inserting message") if $debug;
   my $mb = $lenx/1000000;

   if ( $max_size and $mb > $max_size ) {
      commafy( \$lenx );
      Log("   Skipping message because its size ($lenx) exceeds the $max_size MB limit");
      return;
   }

   $totalBytes = $totalBytes + $lenx;
   $totalMsgs++;

   $flags = flags( $flags );

   fixup_date( \$date );

   sendCommand ($conn, "1 APPEND \"$mbx\" ($flags) \"$date\" \{$lenx\}");
   readResponse ($conn);

   if ( $response !~ /^\+/ ) {
       Log ("1 unexpected APPEND response: >$response<");
       # if ( $response eq ''  or $response =~ /^1 NO/ ) {
       if ( $response eq '' ) {
          Log("response is NULL");
          resume();
          next;
       }
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

   Log("method $method") if $debug;

   if ( uc( $method ) eq 'CRAM-MD5' ) {
      #  A CRAM-MD5 login is requested
      Log("login method $method");
      my $rc = login_cram_md5( $user, $pwd, $conn );
      return $rc;
   }

   if ( $admin_user and $admin_pwd ) {
      #  An AUTHENTICATE = PLAIN login has been requested
      ($sourceUser,$authuser) = split(/\//, $user );
      ($sourceUser,$authuser) = split(/[:\/]/, $user );
      login_plain( $sourceUser, $authuser, $sourcePwd, $conn ) or exit;
      return 1;
   }  

   if ( $pwd =~ /^oauth2:(.+)/i ) {
      $token = $1;
      login_xoauth2( $user, $token, $conn );
      return 1;
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

# print "user $user\n";
# print "admin $admin\n";
# print "pwd   $pwd\n";
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

my $prefix = shift;
my $conn   = shift;
my @mbxs;

   #  Get a list of the user's mailboxes
   #

   Log("Get list of user's mailboxes",2) if $debugMode;

   if ( $mbxList ) {
      foreach $mbx ( split(/,/, $mbxList) ) {
         $mbx = encode( 'IMAP-UTF-7', $mbx );
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
#  Exclude certain mailboxes from the list if the user has provided an
#  exclude list of complete mailbox names with the -e argument.  He may 
#  also supply a list of regular expressions with the -g argument
#  which we will process separately.

sub exclude_mbxs {

my $mbxs = shift;
my @new_list;
my %exclude;
my (@regex_excludes,@final_list);

   #  Do the exact matches first
   if ( $excludeMbxs ) {
      foreach my $exclude ( split(/,/, $excludeMbxs ) ) {
         $exclude{"$exclude"} = 1;
      }
      foreach my $mbx ( @$mbxs ) {
         next if $exclude{"$mbx"};
         push( @new_list, $mbx );
      }
      @$mbxs = @new_list;
   }

   #  Next do the regular expressions if any
   my %excludes;
   @new_list = ();
   if ( $excludeMbxs_regex ) {
      my @regex_excludes;
      foreach $_ ( split(/,/, $excludeMbxs_regex ) ) {
         push( @regex_excludes, $_ );
      }
      foreach my $mbx ( @$mbxs ) {
         foreach $_ ( @regex_excludes ) {
             if ( $mbx =~ /$_/ ) {
                $excludes{"$mbx"} = 1;
             }
         }
      }
      foreach my $mbx ( @$mbxs ) {
         push( @new_list, $mbx ) unless $excludes{"$mbx"};
      }
      @$mbxs = @new_list;
   }

   @new_list = ();

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
           if ( $include_nosel_mbxs ) {
              $nosel_mbxs{"$mbx"} = 1;
           } else {
              Log("$mbx is set NOSELECT, skipping it") if $debug;
              next;
           }
        }
        if ($mbx =~ /^\./) {
                # Skip mailboxes starting with a dot
                next;
        }
        push ( @mbxs, $mbx ) if $mbx ne '';
   }

   return @mbxs;
}

sub get_msg_header {

my $msgnum  = shift;
my $conn    = shift;

   sendCommand( $conn, "1 FETCH $msgnum (body[header.fields (date from subject)])" );
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

   for $i (0 .. $#response) {
        last if $response[$i] =~ /^1 OK FETCH complete/i;

        if ( $response[$i] =~ /Subject: (.+)/ ) {
           $subj = $1;
           if ( substr($response[$i+1],0,1) eq ' ' ) {
              #  Line wrap
              $subj .= $response[$i+1];
           }
        }
        if ( $response[$i] =~ /Date: (.+)/ ) {
           $date = $1;
        }


   }

   return ($date,$subj);

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
my $msgid;

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
		print "Error: $response\n";
                exit;
		return 0;
	}
   }

   return 1 if $empty;

   my $start = 1;
   my $end   = '*';
   $start = $start_fetch if $start_fetch;
   $end   = $end_fetch   if $end_fetch;

   sendCommand ( $conn, "1 FETCH $start:$end (uid body[header.fields (From Date Subject])");
   
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
	last if $response[$i] =~ /^1 OK FETCH complete/i;

        if ( $response =~ /^\* BYE/ ) {
           Log("The server terminated our connection: $response[$i]");
           Log("msgnum $msgnum");
           exit;
        }

        if ($response[$i] =~ /FLAGS/) {
           #  Get the list of flags
           $response[$i] =~ /FLAGS \(([^\)]*)/;
           $flags = $1;
           $flags =~ s/\\Recent//;
        }

        if ( $response[$i] =~ /INTERNALDATE (.+) RFC822\.SIZE/i ) {
           $date = $1;
           $date =~ /"(.+)"/;
           $date = $1;
           $date =~ s/"//g;
        } elsif ( $response[$i] =~ /INTERNALDATE "(.+)" BODY/i ) {
           $date = $1;
           $date =~ /"(.+)"/;
           $date = $1;
           $date =~ s/"//g;
        } elsif ( $response[$i] =~ /INTERNALDATE "(.+)" FLAGS/i ) {
           $date = $1;
           $date =~ /"(.+)"/;
           $date = $1;
           $date =~ s/"//g;
        }
           
        if ( $response[$i] =~ /Subject/i) {
           $response[$i] =~ /Subject: (.+)/i;
           $subject = $1;
        }
        if ( $response[$i] =~ /RFC822\.SIZE/i) {
           $response[$i] =~ /RFC822\.SIZE ([0-9]+) BODY/i;
           $size = $1;
        }
				
        if ( $response[$i] =~ /^Message-Id:/i ) {
           $response[$i] =~ /^Message-Id: (.+)/i;
           $msgid = $1;
           trim(*msgid);
           if ( $msgid eq '' ) {
              # Line-wrap, get it from the next line
              $msgid = $response[$i+1];
              trim(*msgid);
           }
        }

        # if ( $response[$i] =~ /\* (.+) [^FETCH]/ ) {
        if ( $response[$i] =~ /\* (.+) FETCH/ ) {
           ($msgnum) = split(/\s+/, $1);
        }

        if ( $response[$i] =~ /^\)/ or ( $response[$i] =~ /\)\)$/ ) ) {
           push (@$msgs,"$msgnum|$date|$flags|$msgid|$subject");
           $msgnum = $date = $msgid = '';
        }
   }

   return 1;

}

sub search {

my $mailbox = shift;
my $filter  = shift;
my $conn = shift;
my $loops;

    @list  = ();
    @$msgs = ();

    sendCommand ($conn, "1 EXAMINE \"$mailbox\"");
    while ( 1 ) {
        readResponse ($conn);
        if ( $response =~ / EXISTS/i) {
            $response =~ /\* ([^EXISTS]*)/;
            # Log("     There are $1 messages in $mailbox");
        } elsif ( $response =~ /^1 OK/i ) {
            last;
        } elsif ( $response =~ /^1 NO/i ) {
            Log ("unexpected response: $response");
            return 0;
        } elsif ( $response !~ /^\*/ ) {
            Log ("unexpected response: $response");
            return 0;
        }
        last if $loops++ > 999;
    }

    $nums = "";

    $filter =~ s/\s+$//;

    $loops=0;
    sendCommand ($conn, "1 SEARCH $filter");
    while ( 1 ) {
        last if $loops++ > 25;
	readResponse ($conn);
	if ( $response =~ /^1 OK/i ) {
	    last;
	}
	elsif ( $response =~ /^\*\s+SEARCH/i ) {
	    ($nums) = ($response =~ /^\*\s+SEARCH\s+(.*)/i);
	}
	elsif ( $response !~ /^\*/ ) {
	    Log ("unexpected SEARCH response: $response: $filter");
            exit;
	}
    }
    Log("$nums") if $debug;
    if ( $nums eq "" ) {
	Log ("     $mailbox has no messages sent before $date") if $debug;
	return;
    }
    my @number = split(/\s+/, $nums);
    $n = $#number + 1;

    $nums =~ s/\s+/ /g;
    @msgList = ();
    @msgList = split(/ /, $nums);

    return $nums;
}

sub date_in_range {

my $list1 = shift;
my $list2 = shift;
my $newlist = shift;
my %MSGNUMS;

   #  Return a list of msgnums common to both lists passed
   #  to us.

   @$newlist = ();

   foreach $_ ( @$list1 ) {
      my ($msgnum) = split(/\|/, $_);
      $MSGNUMS{$msgnum} = $_;
   }

   foreach $_ ( @$list2 ) {
      my ($msgnum) = split(/\|/, $_);
      push( @$newlist, $_ ) if $MSGNUMS{$msgnum};
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

sub fetchMsg {

my $msgnum = shift;
my $size = shift;
my $message = shift;
my $mbx    = shift;
my $conn   = shift;

   Log("   Fetching msg $msgnum ($size bytes)...") if $debug;

   if ( $header_only ) {
      $item = 'RFC822.HEADER';
   } else {
      $item = 'RFC822';
      #  Some servers don't do 'RFC822' correctly
      $item = 'BODY[]';
   }

   $$message = '';
   sendCommand( $conn, "1 FETCH $msgnum ($item)");
   while (1) {
	readResponse ($conn);
        last if $response =~ /^1 NO|^1 BAD|^\* BYE/;

if ( $response eq '' ) {
        Log("RESP2 >$response<");
   resume();
   return 0;
}
	if ( $response =~ /^1 OK/i ) {
		$size = length($$message);
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
	   ($response =~ /^\*\s+$msgnum\s+FETCH\s+\(.*$item\s+\{[0-9]+\}/i) {
           $item =~ s/BODY\[\]/BODY\\[\\]/ if $response =~ /BODY/;
		($len) = ($response =~ /^\*\s+$msgnum\s+FETCH\s+\(.*$item\s+\{([0-9]+)\}/i);
		$cc = 0;
		$$message = "";
		while ( $cc < $len ) {
			$n = 0;
			$n = read ($conn, $segment, $len - $cc);
			if ( $n == 0 ) {
				Log ("unable to read $len bytes");
                                resume();
				return 0;
			}
			$$message .= $segment;
			$cc += $n;
		}
	} 
   }

   return 1;
}


sub examineMbx {

my $mbx = shift;
my $conn = shift;

   #  Now select the mailbox
   sendCommand( $conn, "1 EXAMINE \"$mbx\"");
   while ( 1 ) {
      readResponse( $conn );
      if ( $response =~ /^1 OK/i ) {
         last;
      } elsif ( $response =~ /^1 NO|^1 BAD|^\* BYE/i ) {
         print "Error examining $mbx: $response\n";
         exit;
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

sub flags {

my $flags = shift;
my @newflags;
my $newflags;
my %standard_flags = ( '\\Seen', 1, '\\Deleted', 1, '\\Draft', 1,
       '\\Answered', 1, '\\Flagged', 1, '\\Recent', 1 );

   #  Make sure the flags list contains standard 
   #  IMAP flags and optionally custom tags

   return unless $flags;

   $flags =~ s/\\Recent//i;
   foreach $_ ( split(/\s+/, $flags) ) {
      # push( @newflags, $_ ) if substr($_,0,1) eq '\\';
      if ( substr($_,0,1) eq '\\' ) {
         #  Should be a standard flag. Make sure it is.
         push( @newflags, $_ ) if $standard_flags{$_};
      } 
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
   #  Encode::IMAPUTF7 module must be installed.

   return unless $mbx_map_fn;

   unless ( open(MAP, "<$mbx_map_fn") ) {
      Log("Error opening mbx map file $mbx_map_fn: $!");
      exit;
   }
   while( <MAP> ) {
      chomp;
      s/[\r\n]$//;   # In case we're on Windows
      s/^\s+//;
      next if /^#/;
      next unless $_;
      ($srcmbx,$dstmbx) = split(/\s*:\s*/, $_);

      #  Unless the mailbox name is entirely ASCII we'll have to use
      #  the Modified UTF-7 character set.
      $srcmbx = encode( 'IMAP-UTF-7', $srcmbx ) unless isAscii( $srcmbx );
      $dstmbx = encode( 'IMAP-UTF-7', $dstmbx ) unless isAscii( $dstmbx );

      $srcmbx =~ s/\//$srcDelim/g;
      $dstmbx =~ s/\//$dstDelim/g;

      $$mbx_map{"$srcmbx"} = $dstmbx;

   }
   close MAP;

#  if ( $use_utf7 ) {
#     if ( $@ ) {
#        Log("At least one mailbox map contains non-ASCII characters.  This means you");
#        Log("have to install the Perl Encode::IMAPUTF7 module in order to map mailbox ");
#        Log("names between the source and destination servers.");
#        print "At least one mailbox map contains non-ASCII characters.  This means you\n";
#        print "have to install the Perl Encode::IMAPUTF7 module in order to map mailbox\n";
#        print "names between the source and destination servers.\n";
#        exit;
#     }
#  }

   my %temp;
   foreach $srcmbx ( keys %$mbx_map ) {
      $dstmbx = $$mbx_map{"$srcmbx"};
      Log("Mapping src:$srcmbx to dst:$dstmbx");
      $srcmbx = encode( 'IMAP-UTF-7', $srcmbx ) unless isAscii( $srcmbx );
      $dstmbx = encode( 'IMAP-UTF-7', $dstmbx ) unless isAscii( $dstmbx );
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
exit;

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
my ($hrs,$dom);

   #  Make sure the hrs part of the date is 2 digits.  At least
   #  one IMAP server expects this.  Same for the DOM.

   $$date =~ s/^\s+//;
   $$date =~ /(.+) (.+):(.+):(.+) (.+)/;
   $hrs = $2;
   ($dom) = split(/-/, $$date, 2);

   if ( length( $hrs ) == 1 ) {
      $$date =~ s/^\s+//;
      $$date =~ /(.+) (.+):(.+):(.+) (.+)/;
      $hrs = $2;
      my $newhrs = '0' . $hrs if length( $hrs ) == 1;
      $$date =~ s/ $hrs/ $newhrs/;
   }
   if ( length( $dom ) == 1 ) {
      $$date =~ s/^\s+//;
      my $newdom = '0' . $dom if length( $dom ) == 1;
      $$date =~ s/^$dom/$newdom/;
   }

}

sub init_mbx {

my $mbx  = shift;
my $conn = shift;
my @msgs;

   #  Remove all messages from a mailbox

   Log("Initializing mailbox $mbx");
   getMsgList( $mbx, \@msgs, $conn, 'SELECT' ); 
   my $msgcount = $#msgs + 1;
   Log("$mbx has $msgcount messages");

   return if $msgcount == 0;   #  No messages to delete

   foreach my $msgnum ( @msgs ) {
      ($msgnum) = split(/\|/, $msgnum);
      delete_msg( $msgnum, $conn );
   }
   expungeMbx( $mbx, $conn );

}

sub delete_msg_list {

my $msgnums = shift;
my $mbx     = shift;
my $conn    = shift;
my $rc;

   #  Mark a set of messages for deletion

   selectMbx( $mbx, $conn );

   foreach my $msgnum ( split(/\s+/, $msgnums ) ) {
      sendCommand ( $conn, "1 STORE $msgnum +FLAGS (\\Deleted)");
      while (1) {
         readResponse ($conn);
         if ( $response =~ /^1 OK/i ) {
  	    $rc = 1;
	    Log("      Marked msg number $msgnum for delete") if $debug;
	    last;
	 }

	 if ( $response =~ /^1 BAD|^1 NO/i ) {
	    Log("Error setting \Deleted flag for msg $msgnum: $response");
	    $rc = 0;
	    last;
	 }
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

   Log("$expunged messages expunged");

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

sub delete_msg {

my $msgnum = shift;
my $conn   = shift;
my $rc;

   sendCommand ( $conn, "1 STORE $msgnum +FLAGS (\\Deleted)");
   while (1) {
        readResponse ($conn);
        if ( $response =~ /^1 OK/i ) {
           $rc = 1;
           Log("      Marked msg number $msgnum for delete") if $debug;
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


sub resume {

   #  Disconnect, re-connect, and log back in.

   Log("Fatal error, lost connection to either the source or destination");
   # Log("checkpoint $checkpoint");
   Log("LAST $LAST");
   my ($mbx,$msgnum) = split(/\|/, $LAST);
   $srcmbx = $mbx;
   Log("mbx $mbx");
   Log("Disconnect from the source and destination servers");

   close $src;
   close $dst;
 
   Log("Sleeping 15 seconds before reconnecting");
   sleep 15;

   Log("Reconnect to source server and log back in");
   connectToHost($sourceHost, \$src)   or exit;
   login($sourceUser,$sourcePwd, $sourceHost, $src, $srcMethod) or exit;
   selectMbx( $mbx, $src );

   Log("Reconnect to destination server and log back in");
   connectToHost( $destHost, \$dst ) or exit;
   login( $destUser,$destPwd, $destHost, $dst, $dstMethod ) or exit;
   Log("Resuming");

   #  Just in case we were creating a mailbox when the connection
   #  was lost check and recreate it if necessary

   map_mbx_names( \%mbx_map, $srcDelim, $dstDelim );
   if ( $mbx_map{"$mbx"} ) {
      $dstmbx = $mbx_map{"$mbx"} 
   }

   createMbx( $dstmbx, $dst ) unless mbxExists( $dstmbx, $dst );

   return;

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

       if ($response[$i] =~ /Message-ID:/i) {
          $response[$i] =~ /Message-Id: (.+)/i;
          $msgid = $1;
          trim(*msgid);
          if ( $msgid eq '' ) {
             # Line-wrap, get it from the next line
             $msgid = $response[$i+1];
             trim(*msgid);
          }
          $$msgids{"$msgid"} = 1;
       }
   }

}

sub encode_ampersand {

my $mbx = shift;

   #  The IMAP RFC requires mailbox names with '&' be 
   #  encoded as '&-'

   #  The problem with this routine is a mailbox name may be
   #  encoded in Mod UTF7 which uses the '&' character for its
   #  own purposes, eg r&AOk-pertoire_XXX.  We have to leave it
   #  alone.  Anyway, this code was inserted because of an IMAP
   #  server which did not do its job so the usefulness of this
   #  conversion is limited.  

   if ( $$mbx =~ /\&/ ) {
      if ( $$mbx !~ /\&-/ ) {
         #  Need to encode the '&' as '&-'
         $$mbx =~ s/\&/\&-/g;
         Log("Encoded $$mbx");
      }
   }

}

sub usage {

   print "\nUsage: $0 <host/user/pwd> <field1=value1> ... <field2=value2>\n";
   exit;

}

sub format_date {

my $date = shift;

   #  Put the date into a more concise format

   #  Tue, 20 Sep 2011 21:57:09 -0600

   if ( $$date =~ /,/ ) {
      ($dd,$$date) = split(/,/, $$date);
   }
   if ( $$date =~ /[-+]/ ) {
      ($$date) = split(/[-+]/, $$date);
   }
   $$date =~ s/^\s+//;
}

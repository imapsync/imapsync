#!/usr/bin/perl

# $Header: /mhub4/sources/imap-tools/imapcopy.pl,v 1.160 2015/07/03 12:43:41 rick Exp $

#######################################################################
#   Program name    imapcopy.pl                                       #
#   Written by      Rick Sanders                                      #
#                                                                     #
#   Description                                                       #
#                                                                     #
#   imapcopy is a utility for copying a user's messages from one      #
#   IMAP server to another.                                           #
#                                                                     #
#   imapcopy is called like this:                                     #
#      ./imapcopy -S host1/user1/password1 -D host2/user2/password2   # 
#                                                                     #
#   Optional arguments:                                               #
#	-d debug                                                      #
#       -I show IMAP protocol exchanges                               #
#       -L logfile                                                    #
#       -m mailbox list (copy only certain mailboxes,see usage notes) #
#       -r reset the \DELETE flag on copied messages                  #
#       -p <root mailbox> put copied mailboxes under a root mbx       #
#       -M <file> mailbox mapping (eg, src:inbox -> dst:inbox_copied) #
#       -i initialize mailbox (remove existing msgs first)            #
#       -U run in "update" mode
#   Run imapcopy.pl -h to see complete set of arguments.              #
#######################################################################

use Socket;
use FileHandle;
use Fcntl;
use Getopt::Std;
use IO::Socket;
use Time::Local;
eval 'use Encode qw/encode decode/';
eval 'use Encode::IMAPUTF7 qw/encode decode/';
no warnings 'utf8';

#################################################################
#            Main program.                                      #
#################################################################

   init();

   #  Get list of all messages on the source host
   #

   connectToHost($sourceHost, \$src)   or exit;
   login($sourceUser,$sourcePwd, $sourceHost, $src, $srcMethod) or exit;
   namespace( $src, \$srcPrefix, \$srcDelim, $opt_x );

   connectToHost( $destHost, \$dst ) or exit;
   login( $destUser,$destPwd, $destHost, $dst, $dstMethod ) or exit;
   namespace( $dst, \$dstPrefix, \$dstDelim, $opt_y );

   @mbxs = getMailboxList( $srcPrefix, $src );

   if ( $dovecot_mbox_format ) {
      #  Both the source and destination are dovecot servers with a mbox
      #  database.  The mailboxes must be created in a special fashion).
      create_dovecot_mbxs( \@mbxs, $dst );
   }

   get_dest_mailboxes( \%DST_MBXS, $dst );
   if ( $debug ) {
      Log("LIST THE DST MAILBOXES");
      foreach $dstmbx ( keys %DST_MBXS ) {
         Log("   dstmbx $dstmbx");
      }
   }

   #  Exclude certain mbxs if that's what the user wants
   if ( $excludeMbxs or $excludeMbxs_regex ) {
      exclude_mbxs( \@mbxs, $src );
   }

   map_mbx_names( \%mbx_map, $srcDelim, $dstDelim );

   if ( $archive_dst_mbx ) {
      #  Create an archive mbx on the destination to receive copies of messsages
      $stat = createMbx( $archive_dst_mbx, $dst );
   }
   if ( $archive_src_mbx ) {
      #  Create an archive mbx on the source to receive copies of messsages
      $stat = createMbx( $archive_src_mbx, $src );
   }

   if ( $msgid_dbm_dir ) {
      #  Open a DBM to record msgids we copy
      openDBM( $sourceUser );
   }

   $total=$mbxs_processed = 0;
   my $delete_msg_list;
   $num_mbxs = $#mbxs + 1;
   Log("Number of mailboxes to process: $num_mbxs");
   foreach $_ ( @mbxs ) { Log("   $_") if $debug; }

   if ( $root_mbx ) {
      $rmbx = $dstPrefix . $root_mbx;
      unless ( $DST_MBXS{"$rmbx"} ) {
           $stat = createMbx( $rmbx, $dst );
           next if !$stat;
      }
   }

   if ( $num_children ) {
      @summary = copy_folders_parallel( \@mbxs );
   } else {
      foreach $srcmbx ( @mbxs ) {
         $copied = copy_folder( $srcmbx, $src, $dst );
         push( @summary, "Copied $copied messages from $srcmbx");
         expungeMbx( $srcmbx, $src ) if $update_rm_src_msg;
      }
   }

   Log("Done.");
   Log("Summary");
   Log("Copied $total total messages");
   foreach $_ ( @summary ) {
      Log("   $_");
   }

   if ( $ENV{'HTTP_CONNECTION'} ) {
      @too_large_1 = @too_large;
      notify_user( $sourceUser, $src, \@too_large, \@mbx_errors );
      notify_user( $destUser,   $dst, \@too_large_1, \@mbx_errors );
   }

   logout( $src );
   logout( $dst );

   exit;


sub init {

   $os = $ENV{'OS'};

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

   Log("Running in update mode") if $update;
   Log("Messages on the dest which are not on the source will be purged") if $del_from_dest;
   Log("Only Seen messages will be copied") if $skip_unread;
   Log("Only message headers will be copied") if $header_only;
   Log("Messages will be removed from the source after they have been copied") if $rem_src_msgs;
   Log("Duplicate msgs on the source will not be copied") if $dont_copy_source_dups;

   if ( $special_search ) {
      if ( $special_search !~ /SINCE|BEFORE/ ) {
         Log("Error:  Special search operators are SINCE and BEFORE.");
         exit;
      }
      Log("Only those messages matching the date criteria $special_search will be copied");
   }

   #  Determine whether we have SSL support via openSSL and IO::Socket::SSL
   $ssl_installed = 1;
   eval 'use IO::Socket::SSL';
   if ( $@ ) {
      $ssl_installed = 0;
   }

   if ( $num_children ) {
      if ( $OS =~ /Windows/i ) {
         Log("The -Y <processes> option is not supported on Windows");
         exit;
      }
      eval 'use Parallel::ForkManager';
      if ( $@ ) {
         Log("In order to run multiple copy processes you must install the Parallel::ForkManager Perl module.");
         exit;
      } 
      Log("Running in parallel mode, number of children = $num_children");
   }

   #  Set up signal handling
   $SIG{'ALRM'} = 'signalHandler';
   $SIG{'HUP'}  = 'signalHandler';
   $SIG{'INT'}  = 'signalHandler';
   $SIG{'TERM'} = 'signalHandler';
   $SIG{'URG'}  = 'signalHandler';

   if ( -e "imapcopy.skip" ) {
      $skip_msgids = 1;
      #  Read a file of message-ids we were to skip
      open( F, "<imapcopy.skip");
      while( <F> ) {
         chomp;
         Log("putting $_ in skip file");
         $SKIP{"$_"} = 1;
      }
      close F;
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

    #  If we've had to reconnect use the new connection
    if ( $CONNECTIONS{"$fd"} ) {
       $fd = $CONNECTIONS{"$fd"};
       Log("Using the new connection $fd");
    }

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

    #  If we've had to reconnect use the new connection
    if ( $CONNECTIONS{"$fd"} ) {
       $fd = $CONNECTIONS{"$fd"};
       Log("Using the new connection $fd");
    }

    $response = <$fd>;
    chop $response;
    $response =~ s/\r//g;
    push (@response,$response);
    Log ("<< $response") if $showIMAP;

    if ( $response =~ /\* BAD internal server error/i ) {
       Log("Fatal IMAP server error:  $response");
       exit;
    }

    if ( $exchange and $response =~ /^1 NO|^1 BAD/ ) {
       $errors++;
       exchange_workaround() if $errors == 9;
    }

    if ( $response =~ /connection closed/i ) {
       ($src,$dst) = reconnect();
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

   if ( $str =~ /^\>\> 1 LOGIN (.+) "(.+)"/ ) {
      #  Obscure the password for security's sake
      $str = ">> 1 LOGIN $1 XXXXX";
   }

   if ( $logfile ) {
      ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
      if ($year < 99) { $yr = 2000; }
      else { $yr = 1900; }
      $line = sprintf ("%.2d-%.2d-%d.%.2d:%.2d:%.2d %s\n",
		     $mon + 1, $mday, $year + $yr, $hour, $min, $sec,$str);
      print LOG "$line";
   } 
      
   select(STDOUT); $| = 1;
   print STDOUT "$str\n" unless $quiet_mode;

   $summary .= "$str\r\n";

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

   return 1 if uc( $mbx ) eq 'INBOX';    #  Don't need to create an Inbox; it always exists

   my $status = 1;
   sendCommand ($conn, "1 CREATE \"$mbx\"");
   while ( 1 ) {
      readResponse ($conn);
      last if $response =~ /^1 OK/i;
      last if $response =~ /already exists/i;
      if ( $response =~ /^1 NO|^1 BAD|^\* BYE/ ) {
         Log ("Error creating $mbx: $response");
         push( @mbx_errors, "$mbx:  $response");
         $status = 0;
         last;
      }
      if ( $response eq ''  or $response =~ /^1 NO/ ) {
         Log ("unexpected CREATE response: >$response<");
         Log("response is NULL");
         ($src,$dst) = reconnect();
         last;
      }
      
   } 

   return $status;
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

   $totalBytes = $totalBytes + $lenx;
   $totalMsgs++;

   $flags = flags( $flags );
   fixup_date( \$date );
   
if ( $CONNECTIONS{"$conn"} ) {
       $conn = $CONNECTIONS{"$conn"};
       Log("Using the new connection $conn");
}

   sendCommand ($conn, "1 APPEND \"$mbx\" ($flags) \"$date\" \{$lenx\}");
   readResponse ($conn);

   if ( $response !~ /^\+/ ) {
       Log ("unexpected APPEND response: >$response<");
       if ( $response =~ /^\* BYE/ ) {
          Log("The server terminated our session");
          exit;
       }

       if ( $response eq '' ) {
          Log("response is NULL");
          ($src,$dst) = reconnect();
          next;
       }
       push(@errors,"Error appending message to $mbx for $user");
       return 0;
   }

   print $conn "$message\r\n";

   undef @response;
   my $loops;
   while ( 1 ) {
       readResponse ($conn);
       $loops++;
       exit if $loops > 9;
       if ( $response =~ /^1 OK/i ) {
	   last;
       }
       elsif ( $response !~ /^\*/ ) {
	   Log ("unexpected APPEND response: $response");
        
           if ( $response eq '' ) {
              Log("response is NULL");
             ($src,$dst) = reconnect();
           }
           next;
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
   # Log("Connected to $host on port $port");

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

   return 1 if $method eq 'PREAUTH';   #  Server pre-authenticates users

   Log("Authenticating to $host as $user") if $debug;
   if ( uc( $method ) eq 'CRAM-MD5' ) {
      #  A CRAM-MD5 login is requested
      Log("login method $method");
      my $rc = login_cram_md5( $user, $pwd, $conn );
      return $rc;
   }

   if ( $pwd =~ /^oauth2:(.+)/i ) {
      $token = $1;
      Log("password is an OAUTH2 token");
      login_xoauth2( $user, $token, $conn );
      return 1;
   }

   if ( lc( $host ) eq 'imap.gmail.com:993' ) {
      #  Use AUTHENTICATE PLAIN with Gmail
      login_plain( $user, $user, $pwd, $conn ) or exit;
      return 1;
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
        if ( $response =~ /Microsoft Exchange/i and $conn eq $dst ) {
           #  The destination is an Exchange server
           $exchange = 1;
           Log("The destination is an Exchange server");
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
         $mbx = encode( 'IMAP-UTF-7', $mbx ) unless isAscii( $srcmbx );
         # $mbx = $prefix . $mbx if $prefix;
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
my $conn = shift;
my @new_list;
my %exclude;
my (@regex_excludes,@final_list);

   #  Do the exact matches first

   if ( $excludeMbxs ) {
      foreach my $exclude ( split(/,/, $excludeMbxs ) ) {
         if ( $opt_R ) {
            #  Include all submailboxes
            $exclude .= '*';
            @mailboxes = listMailboxes( $exclude, $conn);
            foreach $_ ( @mailboxes ) {
               Log("Excluding $_") if $debug;
               $exclude{"$_"} = 1;
            }
         } else {
            Log("Excluding $exclude") if $debug;
            $exclude{"$exclude"} = 1;
         }
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
my @mbxs;

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
my $msgid;
my %MESSAGEIDS;

   @$msgs  = ();
   $mode = 'SELECT' unless $mode;
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

   return 1 if $empty;

   my $start = 1;
   my $end   = '*';
   $start = $start_fetch if $start_fetch;
   $end   = $end_fetch   if $end_fetch;

   if ( $msgs_per_folder ) {
      $start = 1;
      $end   = $msgs_per_folder;
   }

   sendCommand ( $conn, "1 FETCH $start:$end (uid flags internaldate RFC822.SIZE body.peek[header.fields (From Date Message-Id Subject)])");
   
   @response = ();
   my $nulls;
   while ( 1 ) {
	readResponse ( $conn );

        if ( $response eq '' ) {
           $nulls++;
            if ( $nulls > 9 ) {
               Log("server has stopped responding after $nulls loops");
               ($src,$dst) = reconnect();
               return 0;
            }
        } else {
            $nulls = 0;
        }

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
   my $nulls;
   for $i (0 .. $#response) {
	last if $response[$i] =~ /^1 OK FETCH complete/i;

        if ( $response[$i] eq '' ) {
           $nulls++;
            if ( $nulls > 9 ) {
               Log("server has stopped responding after $nulls loops");
               ($src,$dst) = reconnect();
               return 0;
            }
        } else { 
            $nulls = 0;
        }

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
           
        if ( $response[$i] =~ /RFC822\.SIZE/i) {
           # $response[$i] =~ /RFC822\.SIZE ([0-9]+) BODY/i;
           $response[$i] =~ /RFC822\.SIZE ([0-9]+) /i;
           $size = $1;
        }

        if ( $response[$i] =~ /From:\s*(.+)/i) {
           $from = $1;
        }
        if ( $response[$i] =~ /Date:\s*(.+)/i) {
           $header_date = $1;
        }
				
        if ( $response[$i] =~ /Subject: (.+)/i) {
           $subject = $1;
        }
				
        if ( $response[$i] =~ /^Message-Id:/i ) {
           $response[$i] =~ /^Message-Id: (.+)/i;
           $msgid = $1;
           trim(*msgid);
           if ( $msgid eq '' ) {
              # Line-wrap, get it from the next line
              $msgid = get_wrapped_msgid( \@response, $i );
           }
        }

        # if ( $response[$i] =~ /\* (.+) [^FETCH]/ ) {
        if ( $response[$i] =~ /\* (.+) FETCH/ ) {
           ($msgnum) = split(/\s+/, $1);
        }

        if ( $response[$i] =~ /^\)/ or ( $response[$i] =~ /\)\)$/ ) ) {
           if ( $msgid eq '' ) {
              #  The message lacks a message-id so construct one.
              $header_date =~ s/\W//g;
              $subject =~ s/\W//g;
              $msgid = "$header_date$subject$from";
              $msgid =~ s/\s+//g;
              $msgid =~ s/\+|\<|\>|\?|\*|"|'|\(|\)//g;
              Log("msgnum $msgnum has no msgid, build one as $msgid") if $debug;
           }

           if ( $skip_msgids ) {
              #  The user said to not copy this message
              if ( $SKIP{"$msgid"} ) {
                 Log("Skipping $msgid because it's in the imapcopy.skip file");
                 next;
              }
           }

           push (@$msgs,"$msgnum|$date|$flags|$msgid|$size|$header_date");
           $msgnum = $date = $flags = $msgid = $from = $subject = $header_date = '';
        }
   }

   return 1;

}

#  getDatedMsgList
#
#  Get a list of the user's messages in a mailbox on
#  the host which were sent after the specified date
#

sub getDatedMsgList {

my $mailbox     = shift;
my $sent_before = shift;
my $sent_after  = shift;
my $msgs        = shift;
my $conn        = shift;
my ($seen, $empty, @list,$msgid);

    #  Get a list of messages sent in the range specified by $sent_before
    #  and $sent_after

    if ( $sent_before and $sent_after ) {
       $search = "(SINCE $sent_after) (BEFORE $sent_before)";
    } elsif ( $sent_after ) {
       $search = "SINCE $sent_after";
    } elsif ( $sent_before ) {
       $search = "BEFORE $sent_before";
    } 

    Log("Searching for messsages $search");

    @list  = ();
    @$msgs = ();

    sendCommand ($conn, "1 SELECT \"$mailbox\"");
    while ( 1 ) {
        readResponse ($conn);
        if ( $response =~ / EXISTS/i) {
            $response =~ /\* ([^EXISTS]*)/;
        } elsif ( $response =~ /^1 OK/i ) {
            last;
        } elsif ( $response =~ /^1 NO/i ) {
            Log ("unexpected response: $response");
            return 0;
        } elsif ( $response !~ /^\*/ ) {
            Log ("unexpected response: $response");
            return 0;
        }
    }

    my ($date,$ts) = split(/\s+/, $cutoff_date);

    #
    #  Get list of messages sent before/after the reference date
    #
    Log("Get messages sent $operator $date") if $debug;
    $nums = "";
    sendCommand ($conn, "1 SEARCH $search");
    while ( 1 ) {
	readResponse ($conn);
	if ( $response =~ /^1 OK/i ) {
	    last;
	}
	elsif ( $response =~ /^\*\s+SEARCH/i ) {
	    ($nums) = ($response =~ /^\*\s+SEARCH\s+(.*)/i);
	}
	elsif ( $response !~ /^\*/ ) {
	    Log ("unexpected SEARCH response: $response");
	    return;
	}
    }
    Log("$nums") if $debug;
    if ( $nums eq "" ) {
	Log ("     $mailbox has no messages $search") if $debug;
	return;
    }
    my @number = split(/\s+/, $nums);
    $n = $#number + 1;

    $nums =~ s/\s+/ /g;
    @msgList = ();
    @msgList = split(/ /, $nums);

    if ($#msgList == -1) {
	#  No msgs in this mailbox
	return 1;
    }

@$msgs  = ();
for $num (@msgList) {

     # sendCommand ( $conn, "1 FETCH $num (uid flags internaldate body[header.fields (Message-Id Date)])");
     sendCommand ( $conn, "1 FETCH $num (uid flags internaldate RFC822.SIZE body.peek[header.fields (Message-Id Date)])");
     
     @response = ();
     while ( 1 ) {
	readResponse   ( $conn );
	if   ( $response =~ /^1 OK/i ) {
		last;
	}   
        last if $response =~ /^1 NO|^1 BAD|^\* BYE/;
     }

     $flags = '';
     my $msgid;
     foreach $_ ( @response ) {
	last if /^1 OK FETCH complete/i;
          if ( /FLAGS/ ) {
             #  Get the list of flags
             /FLAGS \(([^\)]*)/;
             $flags = $1;
             $flags =~ s/\\Recent//;
          }
   
          if ( /Message-ID:\s*(.*)/i ) {
             $msgid = $1;
             if ( $msgid eq '' ) {
                # Line-wrap, get it from the next line
                $msgid = get_wrapped_msgid( \@response, $i );
             }
          }

          if ( /INTERNALDATE/i) {
             # /INTERNALDATE (.+) BODY/i;
             # /INTERNALDATE (.+) RFC822\.SIZE/i;
             /INTERNALDATE (.+) [RFC822\.SIZE|BODY|FLAGS]/i;
             $date = $1;
             $date =~ /"(.+)"/;
             $date = $1;
             $date =~ s/"//g;
             ####  next if check_cutoff_date( $date, $cutoff_date );
          }

          if ( /RFC822\.SIZE/i) {
             /RFC822\.SIZE ([0-9]+) BODY/i;
             $size = $1;
          }

          if ( /\* (.+) FETCH/ ) {
             ($msgnum) = split(/\s+/, $1);
          }

          if ( /^\)/  or /\)\)$/ )  {
             push (@$msgs,"$msgnum|$date|$flags|$msgid|$size");
             $msgnum=$msgid=$date=$flags=$size='';
          }

      }
   }

   foreach $_ ( @$msgs ) {
      Log("getDated found $_") if $debug;
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

   if ( $CONNECTIONS{"$conn"} ) {
       $fd = $CONNECTIONS{"$conn"};
       Log("Using the new connection $conn");
   }

   $$message = '';
   sendCommand( $conn, "1 FETCH $msgnum ($item)");
   my $nulls;
   while (1) {
	readResponse ($conn);
        last if $response =~ /^1 NO|^1 BAD|^\* BYE/;

        if ( $response eq '' ) {
           $nulls++;
            if ( $nulls > 9 ) {
               Log("RESP2 >$response<");
               ($src,$dst) = reconnect();
               return 0;
            }
        } else { 
            $nulls = 0;
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

                        if ( $CONNECTIONS{"$conn"} ) {
                           $conn = $CONNECTIONS{"$conn"};
                           Log("Using the new connection $conn");
                        }

			$n = read ($conn, $segment, $len - $cc);
			if ( $n == 0 ) {
				Log ("unable to read $len bytes");
                                ($src,$dst) = reconnect();
				return 0;
			}

                        strip_mult_line_terminators( \$segment ) if $strip_mult_line_terminators;

			$$message .= $segment;
			$cc += $n;
		}
	} 
   }

   return 1;
}


sub usage {

   print STDOUT "usage:\n";
   print STDOUT " imapcopy -S sourceHost/sourceUser/sourcePassword [/CRAM-MD5]\n";
   print STDOUT "          -D destHost/destUser/destPassword [/CRAM-MD5]\n";
   print STDOUT "             (if the password is an OAUTH2 token prefix it with 'oauth2:'\n";
   print STDOUT "          -d debug\n";
   print STDOUT "          -I show IMAP protocol exchanges\n";
   print STDOUT "          -L logfile\n";
   print STDOUT "          -m mailbox list (eg \"Inbox, Drafts, Notes\". Default is all mailboxes)\n";
   print STDOUT "          -R include submailboxes when used with -m\n\n";
   print STDOUT "          -e exclude mailbox list (using exact matches)\n";
   print STDOUT "          -g exclude mailbox list (using regular expressions)\n";
   print STDOUT "          -C remove msgs from source mbx after copying\n";
   print STDOUT "          -p <mailbox> put copied mailboxes under a root mailbox\n";
   print STDOUT "          -A <mailbox> copy to local mailbox from scrmbx\n";
   print STDOUT "          -o <mailbox> put all messages in this mbx on the destination\n";
   print STDOUT "          -x <mbx delimiter [mbx prefix]>  source (eg, -x '. INBOX.'\n";
   print STDOUT "          -y <mbx delimiter [mbx prefix]>  destination\n";
   print STDOUT "          -i initialize mailbox (remove existing messages first\n";
   print STDOUT "          -M <file> mailbox map file. Maps src mbxs to dst mbxs. ";
   print STDOUT "Each line in the file should be 'src mbx:dst mbx'\n";
   print STDOUT "          -q quiet mode (still writes to the logfile)\n";
   print STDOUT "          -t <timeout in seconds>\n";
   print STDOUT "          -T copy custom flags (eg, \$Label1,\$MDNSent,etc)\n";
   print STDOUT "          -a <DD-MMM-YYYY> copy only messages after this date\n";
   print STDOUT "          -b <DD-MMM-YYYY> copy only messages before this date\n";
   print STDOUT "          -X <megabytes> Skip any message exceeding this size\n";
   print STDOUT "          -U update mode, don't copy messages that already exist\n";
   print STDOUT "          -s In update mode delete messages from the destination which don't exist on the source\n";
   print STDOUT "          -B <msgnum>  Starting point for message fetch\n";
   print STDOUT "          -E <msgnum>  Ending point for message fetch\n";
   print STDOUT "          -u Don't copy unread (Unseen) messages\n";
   print STDOUT "          -H copy message headers only\n";
   print STDOUT "          -Z <directory> Record the msgids for copied messages in a DBM file at this location (eg -Z </var/tmp>).  Used to prevent copying dups messages.\n";
   print STDOUT "          -j <n> Display count every <n> msgs\n";
   print STDOUT "          -z  Don't require messsages to have Message-IDs in the header\n";
   print STDOUT "          -G  source is Gmail, strip the '[Gmail]' prefix from mailbox names\n";
   print STDOUT "          -c  destination is Cyrus, fix the line terminator characters\n";
   print STDOUT "          -Y <n> number of processes to run in parallel\n";
   print STDOUT "          -f In Update mode remove messages from the source if they exist on the destination\n";
   print STDOUT "          -l Duplicate messages on the source will not be copied\n";
   exit;

}

sub processArgs {

   if ( !getopts( "dS:D:L:m:hIp:M:rqx:y:e:Rt:Tia:b:X:vP:A:UB:E:uHzZ:j:g:CsnWwGF:cK:Y:kfQJ:lo:OV" ) ) {
      #  Remaining args:  N
      usage();
   }
   if ( $opt_S =~ /\\/ ) {
      ($sourceHost, $sourceUser, $sourcePwd,$srcMethod) = split(/\\/, $opt_S);
   } else {
      ($sourceHost, $sourceUser, $sourcePwd,$srcMethod) = split(/\//, $opt_S);
   }

   if ( $opt_D =~ /\\/ ) {
      ($destHost, $destUser, $destPwd,$dstMethod)     = split(/\\/, $opt_D);
   } else {
      ($destHost, $destUser, $destPwd,$dstMethod)     = split(/\//, $opt_D);
   }

   #  If the source and destination passwords have been passed as ENV vars
   #  then use them.

   $sourcePwd = $ENV{SOURCEPWD} if $sourcePwd eq 'SOURCEPWD';
   $destPwd   = $ENV{DESTPWD}   if $destPwd   eq 'DESTPWD';

   $mbxList  = $opt_m;
   $logfile  = $opt_L;
   $root_mbx = $opt_p;
   $timeout  = $opt_t;
   $tags     = $opt_T;
   $debug    = 1 if $opt_d;
   $verbose  = 1 if $opt_v;
   $showIMAP = 1 if $opt_I;
   $submbxs  = 1 if $opt_R;
   $init_mbx = 1 if $opt_i;
   $header_only = 1 if $opt_H;
   $quiet_mode  = 1 if $opt_q;
   $skip_unread = 1 if $opt_u;
   $update      = 1 if $opt_U;
   $del_from_dest = 1 if $opt_s;
   $rem_src_msgs  = 1 if $opt_C;
   $exchange_override = 1 if $opt_w;
   $dovecot_mbox_format = 1 if $opt_O;
   $cyrus = 1 if $opt_c;
   $mbx_map_fn  = $opt_M;
   $excludeMbxs = $opt_e;
   $excludeMbxs_regex = $opt_g;
   $sent_after  = $opt_a;
   $sent_before = $opt_b;
   $max_size    = $opt_X;
   $public_mbxs = $opt_P;
   $archive_src_mbx = $opt_A;
   $archive_dst_mbx = $opt_o;
   $start_fetch = $opt_B;
   $end_fetch   = $opt_E;
   $progress     = $opt_j;
   $msgid_dbm_dir = $opt_Z;
   $wrap_long_lines = 1 if $opt_W;
   $dont_need_msgid = 1 if $opt_z;
   #  -n deprecated. 
   #  $include_nosel_mbxs = 1 if $opt_n;
   $gmail_source = 1 if $opt_G;
   $timeout = 300 unless $timeout;
   $msgs_per_folder = $opt_F;
   $rem_src_msgs = 1 if $opt_r;
   $create_form  = $opt_K;
   $num_children = $opt_Y;
   # $strip_mult_line_terminators = 1 if $opt_k;
   $update_rm_src_msg = 1 if $opt_f;
   $reset_unseen = 1 if $opt_Q;
   $special_search = $opt_J;
   $dont_copy_source_dups = 1 if $opt_l;

   if ( $opt_Z ) {
      unless ( -d $opt_Z ) {
         print STDERR "The directory given by -Z $opt_Z does not exist\n";
         exit;
      }
   }
   validate_date( $sent_after )  if $sent_after;
   validate_date( $sent_before ) if $sent_before;

   $sourcePwd = prompt_for_pwd( 'source' ) if $sourcePwd eq 'PROMPT';
   $destPwd   = prompt_for_pwd( 'dest' )   if $destPwd eq 'PROMPT';

   usage() if $opt_h;

}

sub selectMbx {

my $mbx = shift;
my $conn = shift;

   #  Some IMAP clients such as Outlook and Netscape) do not automatically list
   #  all mailboxes.  The user must manually subscribe to them.  This routine
   #  does that for the user by marking the mailbox as 'subscribed'.

   #  Workaround for a certain customer
   $mbx =~ s/^INBOX.INBOX/INBOX/;

   sendCommand( $conn, "1 SUBSCRIBE \"$mbx\"");
   my $loops;
   while ( 1 ) {
      readResponse( $conn );
      if ( $response =~ /^1 OK/i ) {
         Log("Mailbox $mbx has been subscribed") if $debug;
         last;
      } elsif ( $response =~ /^1 NO|^1 BAD|\^* BYE/i ) {
         Log("Unexpected response to subscribe $mbx command: $response");
         last;
      }
      last if $loops++ > 99;
   }

   #  Now select the mailbox
   sendCommand( $conn, "1 SELECT \"$mbx\"");
   my $loops;
   while ( 1 ) {
      readResponse( $conn );
      if ( $response =~ /^1 OK/i ) {
         last;
      } elsif ( $response =~ /^1 NO|^1 BAD|^\* BYE/i ) {
         Log("Unexpected response to SELECT $mbx command: $response");
         last;
      }
last if $response =~ /\+ OK/i;
      last if $loops++ > 99;
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

   unless ( $srcmbx =~ /\[Gmail]\// ) {
      if ( ($srcmbx =~ /[$dstDelim]/) and ($dstDelim ne $srcDelim) ) {
         #  The mailbox name has a character that is used on the destination
         #  as a mailbox hierarchy delimiter.  We have to replace it.
         $srcmbx =~ s^[$dstDelim]^$substChar^g;
      }
   }

   if ( $debug ) {
      Log("src mbx      $srcmbx");
      Log("src prefix   $srcPrefix");
      Log("src delim    $srcDelim");
      Log("dst prefix   $dstPrefix");
      Log("dst delim    $dstDelim");
   }

   $srcmbx =~ s/^$srcPrefix//;
   #  $srcmbx =~ s/\\$srcDelim/\//g;
   $srcmbx =~ s/\\$srcDelim/$dstDelim/g;

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
         
         #  $dstmbx = $dstPrefix . $root_mbx . $dstDelim . $dstmbx unless uc( $srcmbx ) eq 'INBOX';
         $dstmbx = $dstPrefix . $root_mbx . $dstDelim . $dstmbx;

         # if ( uc($srcmbx) eq 'INBOX' ) {
         #  #  Special case for the INBOX
         #  $dstmbx =~ s/INBOX$//i;
         #  $dstmbx =~ s/$dstDelim$//;
         # }
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
my %standard_flags = ( 
       '\\Seen', 1, '\\Deleted', 1, '\\Draft', 1,
       '\\Answered', 1, '\\Flagged', 1, '\\Recent', 1,
       '\\SEEN', 1, '\\DELETED', 1, '\\DRAFT', 1,
       '\\ANSWERED', 1, '\\FLAGGED', 1, '\\RECENT', 1 );

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

      $srcmbx =~ s/\//$srcDelim/g unless $srcDelim eq '_';
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

# Reconnect to the servers after a timeout error.
#
sub reconnect {

   Log("Attempting to reconnect");

   Log("Sleeping 10 seconds");
   sleep 10;

   $old_src = $src;
   $old_dst = $dst;

   close $src;
   close $dst;

   connectToHost($sourceHost,\$src);
   login($sourceUser,$sourcePwd,$sourceHost,$src);
   selectMbx( $srcmbx, $src );

   connectToHost($destHost,\$dst);
   login($destUser,$destPwd,$destHost,$dst);

   createMbx( $dstmbx, $dst ) unless $DST_MBXS{"$dstmbx"};
   selectMbx( $dstmbx, $dst );

   Log("Reconnected");
   alarm 0;

   Log("reconnect NEW SRC = $src");
   Log("reconnect NEW DST = $dst");

   $CONNECTIONS{"$old_src"} = $src;
   $CONNECTIONS{"$old_dst"} = $dst;

   return ($src,$dst);

}

#  Handle signals

sub signalHandler {

my $sig = shift;

   if ( $sig eq 'ALRM' ) {
      Log("Caught a SIG$sig signal, timeout error");
      $conn_timed_out = 1;
      ($src,$dst) = reconnect();
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
my $MESSAGEIDS;
my $msgcount=0;

   %$msgids  = ();
   sendCommand ($conn, "1 SELECT \"$mailbox\"");
   undef @response;
   $empty=0;
   my $loops;
   while ( 1 ) {
	readResponse ( $conn );
	if ( $response =~ /\* (.+) EXISTS/i ) { 
           $msgcount = $1;
           $empty=1 if $msgcount == 0;
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
        last if $loops++ > 10;
   }

   if ( $empty ) {
      return 0 ;
   }

   Log("There are $msgcount messages in the mailbox");

   Log("Fetch the header info") if $debug;

   # sendCommand ( $conn, "1 FETCH 1:* (body[header.fields (Message-Id)])");
   sendCommand ( $conn, "1 FETCH 1:* (internaldate body.peek[header.fields (From Date Subject Message-Id)])");
   undef @response;
   my $nulls;
   while ( 1 ) {
	readResponse ( $conn );
 
       if ( $response eq '' ) {
           $nulls++;
            if ( $nulls > 9 ) {
               Log("server has stopped responding after $nulls loops");
               ($src,$dst) = reconnect();
               return 0;
            }
       } else {
         $nulls = 0;
       }

	return if $conn_timed_out;
	if ( $response =~ /^1 OK/i ) {
	   last;
	} elsif ( $response =~ /could not be processed/i ) {
           Log("Error:  response from server: $response");
           return 0;
        } elsif ( $response =~ /^1 NO|^1 BAD/i ) {
           return 0;
        }
   }

   $flags = '';
   my $nulls;
   for $i (0 .. $#response) {
       $_ = $response[$i];

       if ( $response[$i] eq '' ) {
           $nulls++;
            if ( $nulls > 9 ) {
               Log("server has stopped responding after $nulls loops");
               ($src,$dst) = reconnect();
               return 0;
            }
       } else {
         $nulls = 0;
       }

       last if /OK FETCH complete/;

       if ( $response[$i] =~ /\* (.+) FETCH/ ) {
          ($msgnum) = split(/\s+/, $1);
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

       if ($response[$i] =~ /Subject:\s*(.+)/i ) {
          $subject = $1;
       }

       if ($response[$i] =~ /From:\s*(.+)/i ) {
          $from = $1;
       }

       if ($response[$i] =~ /Date:\s*(.+)/i ) {
          $header_date = $1;
       }

       if ($response[$i] =~ /Message-ID:/i) {
          $response[$i] =~ /Message-Id: (.+)/i;
          $msgid = $1;
          trim(*msgid);
          if ( $msgid eq '' ) {
             # Line-wrap, get it from the next line
             $msgid = get_wrapped_msgid( \@response, $i );
          }
       }

       #  if ( $response[$i] =~ /^\)/ ) {

       if ( $response[$i] =~ /^\)/  or ( $response[$i] =~ /\)\)$/ ) ) {
          if ( $msgid eq '' ) {
             #  No msgid, construct one
             $header_date =~ s/\W//g;
             $subject =~ s/\W//g;
             $msgid = "$header_date$subject$from";
             $msgid =~ s/\s+//g;
             $msgid =~ s/\+|\<|\>|\?|\*|"|'|\(|\)//g;
             Log("msgnum $msgnum has no msgid, built one as $msgid") if $debug;
          }
          $$msgids{"$msgid"} = $msgnum;
          $msgid = '';
       }
   }
   return $msgcount;
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

sub openDBM {

my $user = shift;

   #  Open a DBM for this user

   my $dbm = $msgid_dbm_dir . '/' . $user;

   unless( dbmopen(%MSGID_DBM, $dbm, 0600) ) {
     print STDERR "Can't open $dbm: $!\n";
     exit;
   }

}

sub deleteMsg {

my $conn   = shift;
my $msgnum = shift;
my $rc;

   #  Mark a message for deletion by setting \Deleted flag

   Log("   msgnum is $msgnum") if $verbose;

   sendCommand ( $conn, "1 STORE $msgnum +FLAGS (\\Deleted)");
   while (1) {
        readResponse ($conn);
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

my $mbx   = shift;
my $conn  = shift;
my $status;
my $loops;

   #  Remove the messages from a mailbox

   sendCommand ( $conn, "1 SELECT \"$mbx\"");
   while (1) {
        readResponse ($conn);
        if ( $response =~ /^1 OK/ ) {
           $status = 1;
           last;
        }

	if ( $response =~ /^1 NO|^1 BAD/i ) {
	   Log("Error selecting mailbox $mbx: $response");
	   last;
	}
        if ( $loops++ > 100 ) {
           Log("No response to SELECT command, skipping this mailbox"); 
           last;
        }
   }

   return unless $status;

   my $expunged = 0;
   sendCommand ( $conn, "1 EXPUNGE");
   while (1) {
        readResponse ($conn);
        last if $response =~ /^1 OK/;

        if ( $response =~ /\* (.+) EXPUNGE/ ) {
           $expunged++;
        }
	if ( $response =~ /^1 BAD|^1 NO/i ) {
	   print "Error expunging messages: $response\n";
	   last;
	}
   }

   Log("   $expunged message(s) purged from $mbx");

}

sub wrap_long_line {

my $line = shift;

   #  Wrap lines too long to be accepted by an IMAP server (Office365 doesn't
   #  seem to like very long lines).  We'll wrap at 1000 characters since
   #  that seems to be acceptable to Office365.

   my $len1 = length( $line );
   my @output = ();
   @output = ( $line =~ m/.{1000}/g );
   my $new;
   $new .= "$_\r\n" foreach (@output );

   # Pick up the trailing chars

   my $temp = $new;
   $temp =~ s/\r|\n//g;
   my $len2 = length( $temp );
   $new .= substr( $line, $len2, $len1-$len2);   
   $new .= "\r\n";

   return $new;
}

sub exchange_workaround {

   #  Because Exchange limits the number of mailboxes you can create
   #  during a single IMAP session we have to get a new session before
   #  we can continue.

   Log("$errors errors have occurred, disconnecting and reconnecting to Exchange server");
   $errors = 0;
   logout( $dst );
   connectToHost( $destHost, \$dst );

   #  Log back into Exchange

   if ( $destUser =~ /(.+):(.+):(.+)/ ) {
      #  An AUTHENTICATE = PLAIN login has been requested
      Log("PLAIN login") if $debug;
      return 0 unless login_plain( $destUser, $dst );
   } else {
      #  Otherwise do an ordinary login
      unless ( login( $destUser,$destPwd, $destHost, $dst ) ) {
         logout( $src );
         return 0;
      }
   }

   return;

}

#  get_dest_mailboxes
#
#  get a list of the user's mailboxes on the destination host
#
sub get_dest_mailboxes {

my $MBXS = shift;
my $conn = shift;

   #  Get a list of the user's mailboxes on the destination

   %$MBXS = ();
   my @mbxs = listMailboxes( '*', $conn);
   foreach $_ ( @mbxs ) {
      $$MBXS{"$_"} = 1;
   }

}

sub fix_msg_line_terminators {

my $msg = shift;
my $tmp;

   #  Cyrus requires all lines in a message be terminated properly.  Most
   #  IMAP servers are tolerant about this but not Cyrus

   foreach $_ ( split(/\n/, $$msg ) ) {
      chomp;
      s/\r$//;
      $_ .= "\r\n";
      $tmp .= $_;
   }
 
   $$msg = $tmp;

}

sub notify_user {

my $user = shift;
my $conn = shift;
my $too_large = shift;
my $mbx_errors = shift;

   #  Insert the summary into the user's Inbox on the source and destination

   $now = localtime();
   $msgid = time() . '@imapcopy';

   my $message = 
"From: imapcopy <imapcopy>
To: $user
Subject: IMAP COPY completed at $now
Message-Id: <$msgid>
Date: $now
X-Mailer: IMAP Tools

Here is a summary of the job:
Completed at $now

";

   $report = summarize();
   $message .= $report;

   if ( @$too_large ) {
      $message .= "\nThe following messages were not copied because they exceeded the maximum size ($max_size megabytes):\n\n";
      foreach $_ ( @$too_large ) {
          ($size,$mbx,$subject) = split(/\|/, $_);
          commafy( \$size );
          $message .= "Subject:  $subject\n";
          $message .= "Folder:   $mbx\n";
          $message .= "Size:     $size bytes\n\n";
      }
   }
   if ( @mbx_errors ) {
      $message .= "\nThe following folders could not be created on the destination server:\n\n";
      foreach $_ ( @$mbx_errors ) {
          $message .= "$_\n";
      }
   }

   my ($dow,$mon,$dom,$ts,$yr) = split(/\s+/, $now);
   $dom = '0' . $dom if length( $dom ) == 1;
   my $date = "$dom-$mon-$yr $ts +0000";

   $flags = '';
   insertMsg( $conn, 'Inbox', \$message, $flags, $date );

}

sub summarize {

   #  Format the summary data nicely

   my $report = "Msgs Copied      Folder\r\n";
   $report .= "==================================================================\r\n";
   foreach $_ ( split(/\n/, $summary ) ) {
      if ( /Copied (.+) messages to (.+)/ ) {
         $copied = $1;
         $folder = $2;
         $copied = pack("A10", $copied );
         $report .= "$copied  $folder\n";
      }
   }

   return $report;

}

sub copy_folder {

my $srcmbx = shift;
my $src    = shift;
my $dst    = shift;
my $copied = 0;
           
        return if $srcmbx eq $archive_src_mbx;

        if ( $srcmbx eq '[Gmail]/All Mail' ) {
           # The Gmail 'All Mail' folder is where all msgs in Gmail are stored.
           # Gmail uses pointers to group the messages into folders. We don't
           # need to copy the contents of the All Mail folders because we'll
           # get them from the other 'folders'.
           Log("Skipping $srcmbx");
           next;
        }
        #  next if $srcmbx =~ /^\[Gmail]/;
        
        $archived=0;
        $mbxs_processed++;
        if ( $verbose ) {
           $line = "Processing $srcmbx " . '(' . $mbxs_processed . '/' . $num_mbxs . ')';
           Log("$line");
        }
        $dstmbx = mailboxName( $srcmbx,$srcPrefix,$srcDelim,$dstPrefix,$dstDelim );
        $dstmbx =~ s/\s+$//g;

        #  Workaround for a certain customer
        $dstmbx =~ s/^INBOX.INBOX/INBOX/;

        if ( $gmail_source ) {
           #  Change '[Gmail]' to 'Gmail'
           if ( $dstPrefix ) {
              $dstmbx =~ s/^$dstPrefix//;
              $dstmbx =~ s/^\[Gmail\]/Gmail/;
              $dstmbx = $dstPrefix . $dstmbx;
           } else {
              $dstmbx =~ s/^\[Gmail\]/Gmail/;
           }
        }

        #  Special for issue with Exchange IMAP which doesn't like
        #  trailing spaces in mailbox names.
        $dstmbx =~ s/\s+\//\//g;

        $dstmbx =~ s/\[Gmail\]// if $opt_g;

        # $LAST = "$dstmbx";
        $LAST = "$srcmbx";

        Log("Do we need to create dstmbx >$dstmbx<?") if $debug;
        unless ( $DST_MBXS{"$dstmbx"} ) {
           Log("Yes, create dstmbx $dstmbx") if $debug;
           $stat = createMbx( $dstmbx, $dst );
           next if !$stat;
        } else {
           Log("No, dstmbx >$dstmbx< already exists") if $debug;
        }

        #  Mbxs marked NOSELECT don't hold any messages so after creating them
        #  we don't need to do anything else.
        next if $nosel_mbxs{"$srcmbx"};

        selectMbx( $dstmbx, $dst );

        if ( $update ) {
           Log("Get msgids on the destination") if $debug;
           $msgcount = getMsgIdList( $dstmbx, \%DST_MSGS, $dst );
           $dst_count = keys %DST_MSGS;
           Log("There are $msgcount messages in $dstmbx on the dest ($dst_count with unique Message-IDs)");
        }

        init_mbx( $dstmbx, $dst ) if $init_mbx;

        $checkpoint  = "$srcmbx|$sourceHost|$sourceUser|$sourcePwd|";
        $checkpoint .= "$destHost|$destUser|$destPwd";

        if ( $sent_after or $sent_before ) {
           getDatedMsgList( $srcmbx, $sent_before, $sent_after, \@msgs, $src );
        } else {
           getMsgList( $srcmbx, \@msgs, $src, 'EXAMINE' );
        }

        my $msgcount = $#msgs + 1;
        Log("There are $msgcount messages in $srcmbx on the source");

        if ( $sent_after and $sent_before ) {
           Log("There are $msgcount messages between those dates");
        }
        Log("   Copying $msgcount messages in $srcmbx mailbox") if $verbose;
        if ( $msgcount == 0 ) {
           Log("   $srcmbx mailbox is empty") unless $ENV{'HTTP_CONNECTION'};
           next;
        }

        $copied=0;
        $delete_msg_list = '';
        %MSGIDS_COPIED = ();

        foreach $_ ( @msgs ) {
           alarm $timeout;
           ($msgnum,$date,$flags,$msgid,$size,$header_date) = split(/\|/, $_);

           if ( $special_search ) {
              next unless special_date_filtering( $date, $special_search );
           }

           if ( $skip_unread ) {
              next if $flags !~ /Seen/;
           }

           if ( $dont_copy_source_dups ) {
              #  Don't copy a message if we've already copied it 
              #  eg, there are dups on the source.
              next if $MSGIDS_COPIED{"$msgid"};
           }

           Log("   msgnum=$msgnum,msgid=$msgid") if $debug;
      
           next if $msgnum eq '';

           if ( $update ) {
              #  Don't insert the message if it already exists
              # next if $DST_MSGS{"$msgid"};

              if ( $DST_MSGS{"$msgid"} ) {
                 #  Msg exists on the destination
                 Log("$msgid exists on the destination, skip it") if $debug;
                 delete_msg( $msgnum, $src ) if $update_rm_src_msg; 
                 next;
              }
              Log("$msgid does not exist on the destination") if $debug;
           }

           if ( $msgid_dbm_dir ) {
              #  Don't copy the message if we have already done so 
              #  in the past
              next if $MSGID_DBM{"$msgid"};
           }

           #  Strip off TZ offset if it exists
           $date =~ s/\((.+)\)$//;
           $date =~ s/\s+$//g;

           # $LAST = "$dstmbx|$msgnum";
           $LAST = "$srcmbx|$msgnum";

           my $mb = $size/1000000;

           if ( $max_size and $mb > $max_size ) {
              commafy( \$lenx );
              Log("   Skipping message $msgnum because its size ($size) exceeds the $max_size MB limit");
              $subject = get_subject( $msgnum, $size, $srcmbx, $src );
              Log("subject $subject");
              push( @too_large, "$size|$srcmbx|$subject");
              next;
           }

           next unless fetchMsg( $msgnum, $size, \$message, $srcmbx, $src );

           if ( $flags !~ /SEEN/i and $reset_unseen ) {
              reset_unseen( $msgnum, $src ) if $reset_unseen;
           }

           alarm 0;

           fix_msg_line_terminators( \$message ) if $cyrus;

           if ( $wrap_long_lines ) {
              $new_message = '';
              foreach $_ ( split(/\r\n/, $message ) ) {
                 if ( length( $_ ) < 1000 ) {
                    $new_message .= "$_\r\n";
                    next;
                 }
                 $len = length( $_ );
                 Log("   Need to wrap this line: length = $len") if $debug;
                 #  Wrap the line in chunks of 1,000 chars
                 $line = wrap_long_line( $_ );
                 $new_message .= $line;
              }
              $message = $new_message;
           }

           next unless $message;

           if ( $archive_dst_mbx ) {
              # Put all messages being copied into the destination archive mailbox only
              # (eg, don't copy them to any other mbxs)
              $stat = insertMsg( $dst, $archive_dst_mbx, *message, $flags, $date );
              $copied++ if $stat;
              next;
           }
           if ( $archive_src_mbx ) {
              #  Put a copy of the message in the archive mbx on the source
              #  and copy it to the destination as well.
              if ( insertMsg( $src, $archive_src_mbx, *message, $flags, $date ) ) {
                 $archived++;
                 if ( $rem_src_msgs ) {
                    $delete_msg_list .= "$msgnum ";
                 }
              }
           }

           eval {
               alarm $timeout;
               local $SIG{ALRM} = sub { 
                   Log("$mbx mailbox: message number $msgnum timed out");                 
                   ($src,$dst) = reconnect();
                   next;  
               };

               $stat = insertMsg( $dst, $dstmbx, *message, $flags, $date );
               $MSGIDS_COPIED{"$msgid"} = 1;
               alarm 0;
           };


           if ( $stat ) {
              $copied++; 

              if ( $rem_src_msgs and !$archive_src_mbx ) {
                 #  User wants to delete msgs from src and they have been copied
                 if ( $rem_src_msgs ) {
                    $delete_msg_list .= "$msgnum ";
                 }
              }
           }

           if ( $progress ) {
              if ( $copied/$progress == int($copied/$progress ) ) {
                 Log("Copied $copied of $msgcount messages from $srcmbx");
              }
           }
 
           #  Record the msgid if -Z specified
           if ( $msgid_dbm_dir ) {
              $MSGID_DBM{"$msgid"} = today(0);
           }

           if ( $copied/100 == int($copied/100)) {
              Log("   Copied $copied messages so far") if $verbose;
           }
              
           if ( $msgs_per_folder ) {
              #  opt_F allows us to limit number of messages copied per folder
              last if $copied == $msgs_per_folder;
           }

           alarm 0;

           if ( $conn_timed_out ) {
              Log("$destHost timed out");
              reconnect( $checkpoint, $dst );
              $conn_timed_out = 0;
              next;
           }

        }

        if ( $update and $del_from_dest ) {
           %DST_MSGS = %SRC_MGS = ();
           Log("Get msgids on the destination") if $debug;
           selectMbx( $dstmbx, $dst );
           getMsgIdList( $dstmbx, \%DST_MSGS, $dst );

           selectMbx( $srcmbx, $src );
           Log("Get msgids on the source") if $debug;
           getMsgIdList( $srcmbx, \%SRC_MSGS, $src );

           my $dst_count = keys %DST_MSGS;
           my $src_count = keys %SRC_MSGS;
           $s = keys %SRC_MSGS;
           $d = keys %DST_MSGS;
           Log("There are $s msgs on the src and $d on the dest for $dstmbx") if $debug;
           Log("Remove msgs from the destination which aren't on the source") if $debug;

           $expunge = 0;
           foreach $msgid ( keys %DST_MSGS ) {
              next if $SRC_MSGS{"$msgid"};

              #  This message no longer exists on the source.  Delete it from the dest
              Log("$msgid is not on the source, delete it from the dest") if $debug;

              $dst_msgnum = $DST_MSGS{"$msgid"};
              deleteMsg( $dst, $dst_msgnum );
              $expunge = 1;
           }
           expungeMbx( $dstmbx, $dst ) if $expunge;
        }

        $total += $copied;
        $dstmbx = decode( 'IMAP-UTF-7', $dstmbx ) unless isAscii( $dstmbx );

        if ( $archive_dst_mbx ) {
           Log("   Copied $copied messages to $archive_dst_mbx on the destination");
        } else {
           if ( $verbose ) {
              $line = "   Copied $copied messages to $dstmbx  on the destination";
              $line .=  '(' . $mbxs_processed . '/' . $num_mbxs . ')';
              Log( "$line ");
           } else {
              Log("   Copied $copied messages to $dstmbx on the destination");
           }
        }

        if ( $archive_src_mbx ) {
           Log("   Copied $archived messages to $archive_src_mbx mailbox on the source");
           if ( $rem_src_msgs ) {
              #  Remove the messages from the source mailbox
              Log("Removing messages from $srcmbx on source");
              delete_msg_list( $delete_msg_list, $srcmbx, $src );
              expungeMbx( $srcmbx, $src );
           }
        } elsif ( $rem_src_msgs ) {
           Log("Removing messages from $srcmbx on source");
           delete_msg_list( $delete_msg_list, $srcmbx, $src );
           expungeMbx( $srcmbx, $src );
        }
   return $copied;
}

sub copy_folders_parallel {

my $mbxs = shift;
my $src  = shift;
my $dst  = shift;
my @summary;

   $parent_pid = $$;
   my $pm = Parallel::ForkManager->new( $num_children - 1 );
   foreach $srcmbx ( @$mbxs ) {

      $pm->run_on_finish( sub {
      my($pid,$exit_code,$ident,$exit_signal,$core_dump,$var,$v)=@_;
         ($copied,$mbx) = split(/,/, ${$var});
         $total += $copied;
         push( @summary, "Copied $copied messages from $mbx");
      });

      exit if $$ ne $parent_pid;    # Don't let a child try to launch another child

      $pm->start and next;

      #  This is the child process, copy the folder
 
      Log("I am child pid $$") if $debug;
      connectToHost($sourceHost, \$src)   or exit;
      login($sourceUser,$sourcePwd, $sourceHost, $src, $srcMethod) or exit;
      namespace( $src, \$srcPrefix, \$srcDelim, $opt_x );

      connectToHost( $destHost, \$dst ) or exit;
      login( $destUser,$destPwd, $destHost, $dst, $dstMethod ) or exit;
      namespace( $dst, \$dstPrefix, \$dstDelim, $opt_y );

      $count = copy_folder( $srcmbx, $src, $dst );
      $var = "$count,$srcmbx";
      $v   = '';
      $pm->finish(0, \$var, \$v );
   }

   $pm->wait_all_children;

   return @summary;

}

sub strip_mult_line_terminators {

my $segment = shift;

    #  This routine is disabled.
    return;

    #  This is an optional cleanup routine for cases where
    #  the source server is sending us lines with \r\r\r
    #  line terminators.  Ugh.

    my $temp;
    foreach $_ ( split(/\n/, $$segment ) ) {
         s/\r+$//g;
         $temp .= "$_\r\n";
    }
    $$segment = $temp;

}

sub reset_unseen {

my $msgnum = shift;
my $conn   = shift;

   #  Some servers (Smartermail is one) change a message from UNSEEN to
   #  SEEN even if the mailbox is opened in Examine mode.  This is a workaround
   #  for that.

   sendCommand ($conn, "1 STORE $msgnum -flags \\SEEN");
   my $loops;
   while ( 1 ) {
      last if $loops++ > 9;
      readResponse ($conn);
      last if $response =~ /^1 OK|^1 BAD|^1 NO/i;
   }

}

sub get_subject {

my $msgnum = shift;
my $size   = shift;
my $srcmbx = shift;
my $conn   = shift;
my $subject;

    #  Extract the subject field from a message

    my $saved = $header_only;
    $header_only = 1;
    fetchMsg( $msgnum, '', \$message, $srcmbx, $conn );
    $subject = $1 if $message =~ /Subject: (.+)/;
    $header_only = $saved;

    return $subject;
}


sub convert_date {

my $date = shift;

%months = ('JAN',0,'FEB',1,'MAR',2,'APR',3,'MAY',4,'JUN',5,'JUL',6,
           'AUG',7,'SEP',8,'OCT',9,'NOV',10,'DEC',11);

   my ($day,$mon,$yr) = split(/-/, $date);
   $mon = uc( $mon );
   $mon = $months{"$mon"};
   $mon = '0' . $mon if length( $mon == 1);
   $day = '0' . $day if length( $day == 1);

   return ($day,$mon,$yr);
}

sub compare_dates {

my $date1 = shift;
my $date2 = shift;
my $stat = 1;

    # Return 0 if $date1 is earlier than $date2

    ($day,$mon,$yr) = convert_date( $date1 );
    eval '$secs1 = timelocal(0,0,0,$day,$mon,$yr)';

    ($day,$mon,$yr) = convert_date( $date2 );
    eval '$secs2 = timelocal(0,0,0,$day,$mon,$yr)';

    $diff = $secs2 - $secs1;
    $stat = 0 if $diff > 0;

    return $stat;
}

sub special_date_filtering {

my $date = shift;
my $oper = shift;
my $status = 1;

   #  Return false unless the date satifies the search date criteria.  This code
   #  is used only when the IMAP server does not support the standard SINCE/BEFORE/
   #  etc searching.

   ($date) = split(/\s+/, $date);
   $date = uc( $date );
   Log("date = $date") if $debug;
   ($oper,$cutoff) = split(/=/, $oper);

   $rc = compare_dates( $date, $cutoff );

   #  rc=1 means later; 0 means earlier

   $status = 0;
   if ( $oper eq 'SINCE' ) {
      $status = 1 if $rc == 1;
   } elsif ( $oper eq 'BEFORE' ) {
      $status = 1 if $rc == 0;
   }

   if ( $status == 1 and $debug ) {
      Log("Include this message");
   }

   return $status;
}

sub prompt_for_pwd {

my $string = shift;

   #  Prompt the user for the password

   print STDOUT "Enter the $string user password: ";
   system('stty', '-echo');  # Disable echoing
   my $password = <>;
   chomp $password;
   system('stty', 'echo');   # Turn it back on
   print STDOUT "\n";

   return $password;

}

sub create_dovecot_mbxs {

my $mbxs = shift;
my $dst  = shift;
my @list;

   #  Sort mailboxes by length so they can be created in the right order.  This 
   #  is used with IMAP servers (such as Dovecot with mbox storage) that cannot
   #  have messages and child mailboxes in the same mailbox.

   foreach my $mailbox ( @$mbxs ) {
     my $len = length( $mailbox );
     push( @list, "$len $mailbox" );
   }

   @list = reverse sort {$a <=> $b} @list;

   @$mbxs = ();
   foreach $_ ( @list ) {
      my ($n,$mailbox) = split(/\s+/, $_, 2 );
      push( @$mbxs, $mailbox );
   }

   #  Now create the mailboxes in the right order, eg A/B/C/D before A/B/C

   foreach $mailbox ( @$mbxs ) {
      $stat = createMbx( $mailbox, $dst );
   }

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

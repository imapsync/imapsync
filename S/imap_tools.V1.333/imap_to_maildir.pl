#!/usr/bin/perl

# $Header: /mhub4/sources/imap-tools/imap_to_maildir.pl,v 1.6 2015/07/07 12:05:54 rick Exp $

################################################################################
# imap_to_maildir is a utility for copying mailboxes and messages              #
# from a user account on an IMAP server to a Maildir system.                   #
#                                                                              #
# imap_to_maildir.pl is called like this:                                      #
#      ./imap_to_maildir.pl -S imaphost/user/password -u <user> -M <maildir>   #
#                                                                              #
# For example:  ./imap_to_maildir.pl                  \                        #
#                  -S imap.gmail.com:993/rsanders/mypass  \                    #
#                  -u rick                            \                        #
#                  -M /users/rick/Maildir                                      #
# Optional arguments:                                                          #
#       -a <DD-MMM-YYYY> copy only messages after this date                    #
#	-d debug                                                               #
#       -I log IMAP protocol commands                                          #
#       -L logfile                                                             #
#       -m mailbox list (copies only the specified mailboxes, see usage()      #
################################################################################

use Socket;
use IO::Socket;
use FileHandle;
use Fcntl;
use Getopt::Std;
use File::Path qw(make_path);
use Time::HiRes;
use MIME::Base64 qw(encode_base64 decode_base64);

#################################################################
#            Main program.                                      #
#################################################################

   init();

   #  Get list of all messages on the IMAP server
   #
   connectToHost($sourceHost, \$conn);
   unless ( login($sourceUser,$sourcePwd, $conn) ) {
       Log("Check your username and password");
       print STDOUT "Login failed: Check your username and password\n";
       exit;
   }
   @mbxs = getMailboxList($sourceUser, $conn);
   namespace( $conn, \$prefix, \$delimiter, $opt_x );

   foreach $mbx ( @mbxs ) {
        if ( $exclude ) {
           #  Exclude the indicated mailboxes
           if ( $mbx =~ /$exclude/i ) {
              Log("Excluding $mbx");
              next;
           }
        }
  
        #  The messages in '[Gmail]All Mail' are dups of the messages in the IMAP folders
        #  so skip it.
        next if $mbx eq '[Gmail]All Mail';

        $dstmbx = $mbx;
        $dstmbx =~ s/^inbox/INBOX/i;
        $dstmbx =~ s/$prefix// if $prefix;

        if ( $strip_gmail ) {
           $dstmbx =~ s/^\[Gmail\]//;
           $dstmbx =~ s/^\///;
        }

        unless ( $delimiter eq '.' ) {
           # Mailboxes may not contain dots, replace them with -
           $dstmbx =~ s/\./-/g;   
        }

        Log("Copying messages in $mbx mailbox") if $dump_flags;
        my @msgs;

        if ( $sent_after ) {
           getDatedMsgList( $mbx, $sent_after, \@msgs, $conn, 'EXAMINE' );
        } else {
           getMsgList( $mbx, \@msgs, $conn, 'EXAMINE' );
        }
             
        my $i = $#msgs + 1;
        Log("   $mbx has $i messages");

        $folder = get_folder_name( $maildir, $dstmbx, $delimiter, $prefix );

        build_folder( $folder, $username );
        Log("folder $folder") if $debug;
        my $i = $#msgs + 1;
        my $msgnums;
        foreach $msgnum ( @msgs ) {
             ($msgnum,$date,$flags,$rfc822_size) = split(/\|/, $msgnum);
             $message = fetchMsg( $msgnum, $mbx, $conn );
             my $size = length( $message );

             $msgfile = generate_filename( $folder, $size, $rfc822_size, $flags );
             next if !$msgfile;   #  Failed to generate a unique filename
             if ( !open (M, ">$msgfile") ) {
                Log("Error opening $msgfile: $!");
                next;
             }
             Log("   Copying message $msgnum") if $debug;
             print M $message;
             close M;
             $added++;
 
             $msgnums .= "$msgnum ";
        }
   }

   logout( $conn );
   Log("Copied $added total messages");

   exit;


sub init {

   $version = 'V1.0';
   $os = $ENV{'OS'};

   processArgs();

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

   #  Determine whether we have SSL support via openSSL and IO::Socket::SSL
   $ssl_installed = 1;
   eval 'use IO::Socket::SSL';
   if ( $@ ) {
      $ssl_installed = 0;
   }
   if ( $dump_flags ) {
      Log("Dumping only those messages with one of the following flags: $dump_flags");
   }

   chomp( $localhost = `uname -n` );
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
   } else {
      print STDOUT "$str\n";
   }
print STDOUT "$str\n";
}

#  Make a connection to an IMAP host

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

   sendCommand ($conn, "1 LOGIN $user \"$pwd\"");
   while (1) {
	readResponse ( $conn );
	if ($response =~ /^1 OK/i) {
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


#  getMailboxList
#
#  get a list of the user's mailboxes from the source host
#
sub getMailboxList {

my $user = shift;
my $conn = shift;
my @mbxs;
my @mailboxes;

   #  Get a list of the user's mailboxes
   #
  if ( $mbxList ) {
      #  The user has supplied a list of mailboxes so only processes
      #  the ones in that list
      @mbxs = split(/,/, $mbxList);
      foreach $mbx ( @mbxs ) {
         trim( *mbx );
         push( @mailboxes, $mbx );
      }
      return @mailboxes;
   }

   if ($debug) { Log("Get list of user's mailboxes",2); }

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
        $response[$i] =~ s/\s+/ /;
        if ( $response[$i] =~ /"$/ ) {
           $response[$i] =~ /\* LIST \((.*)\) "(.+)" "(.+)"/i;
           $mbx = $3;
        } elsif ( $response[$i] =~ /\* LIST \((.*)\) NIL (.+)/i ) {
           $mbx= $2;
        } else {
           $response[$i] =~ /\* LIST \((.*)\) "(.+)" (.+)/i;
           $mbx = $3;
        }
	$mbx =~ s/^\s+//;  $mbx =~ s/\s+$//;

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

   sendCommand ( $conn, "1 FETCH 1:* (uid flags internaldate body[header.fields (From Date)] RFC822.SIZE)");
   
   undef @response;
   while ( 1 ) {
	readResponse ( $conn );
	if ( $response =~ /^1 OK/i ) {
		last;
	} 
        last if $response =~ /^1 NO|^1 BAD|^\* BYE/;
   }

   @msgs  = ();
   $flags = $rfc822_size = '';
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

        if ( $response[$i] =~ /RFC822.SIZE/ ) {
           $response[$i] =~ /RFC822.SIZE\s+(.+)(.*)/;
           ($rfc822_size) = split(/\s+/, $1);
           $rfc822_size =~ s/[^\d.]//g;
        }

        if ( $response[$i] =~ /\* (.+) FETCH/ ) {
           ($msgnum) = split(/\s+/, $1);
        }

        if ( $msgnum and $date and $rfc822_size ) {
	   push (@$msgs,"$msgnum|$date|$flags|$rfc822_size");
           $msgnum = $date = $rfc822_size = '';
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

my $mailbox = shift;
my $cutoff_date = shift;
my $msgs    = shift;
my $conn    = shift;
my $oper    = shift;
my ($seen, $empty, @list,$msgid, $rfc822_size);

    #  Get a list of messages sent after the specified date

    @list  = ();
    @$msgs = ();

    sendCommand ($conn, "1 $oper \"$mailbox\"");
    while ( 1 ) {
        readResponse ($conn);
        if ( $response =~ / EXISTS/i) {
            $response =~ /\* ([^EXISTS]*)/;
            # Log("     There are $1 messages in $mailbox");
        } elsif ( $response =~ /^1 OK/i ) {
            last;
        } elsif ( $response =~ /^1 NO/i ) {
            Log ("unexpected SELECT response: $response");
            return 0;
        } elsif ( $response !~ /^\*/ ) {
            Log ("unexpected SELECT response: $response");
            return 0;
        }
    }

    my ($date,$ts) = split(/\s+/, $cutoff_date);

    #
    #  Get list of messages sent before the reference date
    #
    Log("Get messages sent after $date") if $debug;
    $nums = "";
    sendCommand ($conn, "1 SEARCH SINCE \"$date\"");
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
	Log ("     $mailbox has no messages sent before $date") if $debug;
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

    $n = $#msgList + 1;
    Log("   $mailbox has $n messages after $sent_after");

@$msgs  = ();
for $num (@msgList) {

     sendCommand ( $conn, "1 FETCH $num (uid flags internaldate body[header.fields (Message-Id Date)] RFC822.SIZE)");
     
     undef @response;
     while ( 1 ) {
	readResponse   ( $conn );
	if   ( $response =~ /^1 OK/i ) {
		last;
	}   
        last if $response =~ /^1 NO|^1 BAD|^\* BYE/;
     }

     $flags = $rfc822_size = '';
     my $msgid;
     foreach $_ ( @response ) {
	  last if /^1 OK FETCH complete/i;
          if ( /FLAGS/ ) {
             #  Get the list of flags
             /FLAGS \(([^\)]*)/;
             $flags = $1;
             $flags =~ s/\\Recent//;
          }
   
          if ( /Message-Id:\s*(.+)/i ) {
             $msgid = $1;
          }

          if ( /INTERNALDATE/) {
             /INTERNALDATE (.+) BODY/i;
             $date = $1;
             $date =~ /"(.+)"/;
             $date = $1;
             $date =~ s/"//g;
             ####  next if check_cutoff_date( $date, $cutoff_date );
          }

          if ( /RFC822.SIZE/ ) {
             /RFC822.SIZE\s+(.+)(.*)/;
             $rfc822_size = $1;
             $rfc822_size =~ s/[^\d.]//g;
          }

          if ( /\* (.+) FETCH/ ) {
             ($msgnum) = split(/\s+/, $1);
          }

          if ( $msgnum and $date and $rfc822_size ) {
             push (@$msgs,"$msgnum|$date|$flags|$msgid|$rfc822_size");
             $msgnum=$msgid=$date=$flags=$rfc822_size='';
          }
      }
   }

   foreach $_ ( @$msgs ) {
      Log("getDated found $_") if $debug;
   }

   return 1;
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
	if ( $response =~ /^1 OK/i ) {
		$size = length($message);
		last;
	} 
	elsif ($response =~ /message number out of range/i) {
		Log ("Error fetching uid $uid: out of range",2);
		$stat=0;
		last;
	}
        elsif ( $response =~ /^1 NO|^1 BAD/ ) {
                Log("$response");
                return 0;
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
   print STDOUT " imap_to_maildir.pl -S Host/User/Password -u <user> -M <maildir>\n";
   print STDOUT " <dir> is the file directory to write the message structure\n";
   print STDOUT " Optional arguments:\n";
   print STDOUT "          -d debug\n";
   print STDOUT "          -I log IMAP commands\n";
   print STDOUT "          -L logfile\n";
   print STDOUT "          -m mailbox list (eg \"Inbox,Drafts,Notes\". Default is all mailboxes)\n";
   print STDOUT "          -a <DD-MMM-YYYY> copy only messages after this date\n";
   print STDOUT "          -e <mailboxes to exclude> Regular expression, eg -e \"Sales|Drafts|^Notes\"";
   print STDOUT "          -A <admin_user:admin_pwd>\n";
   print STDOUT "          -G source is Gmail; strip [Gmail] from folder names\n";
   exit;

}

sub processArgs {

   if ( !getopts( "dS:L:m:u:M::hf:F:Ia:x,e:A:F:G" ) ) {
      usage();
   }

   if ( $opt_S =~ /\\/ ) {
      ($sourceHost, $sourceUser, $sourcePwd) = split(/\\/, $opt_S);
   } else {
      ($sourceHost, $sourceUser, $sourcePwd) = split(/\//, $opt_S);
   }

   $username   = $opt_u;
   $maildir    = $opt_M;
   $mbxList    = $opt_m;
   $exclude    = $opt_e;
   $logfile    = $opt_L;
   $debug      = 1 if $opt_d;
   $showIMAP   = 1 if $opt_I;
   $strip_gmail = 1 if $opt_G;
   $sent_after = $opt_a;
   $admin_user = $opt_A;
   $msgs_per_folder = $opt_F;

   if ( !$maildir or !$username ) {
      print "You must specify the username and the directory where the user's Maildir is located\n";
      print "For example:  -u rick -M /mhub4/rick/Maildir.\n";
      usage();
      exit;
   }
   
   if ( !-d $maildir ) {
      #  Create the maildir directory
      make_path( $maildir );
   }

   validate_date( $sent_after ) if $sent_after;

   if ( $dump_flags ) {
      foreach my $flag ( split(/,/, $dump_flags) ) {
          $flag = ucfirst( lc($flag) );
          $flag = 'Seen'   if $flag eq 'Read';
          $flag = 'Unseen' if $flag eq 'Unread';
          $dump_flags{$flag} = 1;
      }
   }

   if ( $extension ) {
      $extension = '.' . $extension unless $extension =~ /^\./;
   }

   usage() if $opt_h;

}

sub flags_ok {

my $flags = shift;
my $ok = 0;

   #  If the user has specified that only messages with
   #  certain flags be dumped then honor his request.

   return 1 unless %dump_flags;

   $flags =~ s/\\//g;
   Log("flags $flags") if $debug;
   foreach $flag ( split(/\s+/, $flags) ) {
      $flag = ucfirst( lc($flag) );
      $ok = 1 if $dump_flags{$flag};
   }

   #  Special case for Unseen messages for which there isn't a 
   #  standard flag.  
   if ( $dump_flags{Unseen} ) {
      #  Unseen messages should be dumped too.
      $ok = 1 unless $flags =~ /Seen/;
   }

   return $ok;

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
   Log("Searching for messages after $date");
}

sub generate_filename {

my $folder      = shift;
my $size        = shift;
my $rfc822_size = shift;
my $flags       = shift;
my $status;
my $tries;
my $msgfn;
my $seen;

   #  Get a unique filename

   Log("Generate a filename") if $debug;
   $seen = ',S' if $flags =~ /Seen/;

   while( 1 ) {
      my $now = time();
      my ($sec, $msec) = Time::HiRes::gettimeofday();

      $msgfn = $sec . '.M' . $msec . 'P' . $$ . '.' . "$localhost,S=$size,W=$rfc822_size:2$seen";
      $msgfn = $folder . '/cur/' . $msgfn;
      last if $tries++ > 100;
      next if -e $msgfn;
   }

   return $msgfn;

}

sub get_folder_name {

my $maildir   = shift; 
my $mbx       = shift;
my $delimiter = shift;
my $prefix    = shift;

   #  Convert an IMAP mailbox name to a Maildir folder name.  IMAP mbxs
   #  are hierarchal while Maildir folders are flat and must start with
   #  a '.' character.

   Log("Convert IMAP mbx $mbx name to Maildir folder name") if $debug;

   my $folder = $maildir . '/';
   if ( uc( $mbx ) eq 'INBOX' ) {
      #  Inbox is special case
      return $maildir;
   }

   $delimiter = "\\." if $delimiter eq '.';

   foreach my $term ( split(/$delimiter/, $mbx ) ) {
       $folder .= '.' . $term;
   }

   return $folder;
}

sub build_folder {

my $folder   = shift;
my $username = shift;
my @subdirs = qw( new cur tmp );

   Log("Create the directories for the $folder folder");

   make_path( $folder );
   if ( !-d "$folder" ) {
      Log("Error creating $folder");
      exit;
   }

   foreach my $subdir ( @subdirs ) {
      my $dir = "$folder/$subdir";
      make_path( "$dir" ) if !-d "$dir";
      if ( !-d "$dir" ) {
         Log("Error creating $dir");
         exit;
      }
   }

   if ( $os !~ /Windows/i ) {
      my $stat = `chown -R $username "$folder" 2>&1`;
      if ( $stat ) {
         Log("Failed to chown $username for $folder: $stat");
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


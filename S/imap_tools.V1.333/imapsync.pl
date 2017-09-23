#!/usr/bin/perl

# $Header: /mhub4/sources/imap-tools/imapsync.pl,v 1.72 2015/07/06 12:45:54 rick Exp $

#######################################################################
#   Program name    imapsync.pl                                       #
#   Written by      Rick Sanders                                      #
#                                                                     #
#   Description                                                       #
#                                                                     #
#   imapsync is a utility for synchronizing a user's account on two   #
#   IMAP servers.  When supplied with host/user/password information  #
#   for two IMAP hosts imapsync does the following:                   #
#	1.  Adds any messages on the 1st host which aren't on the 2nd #
#       2.  Deletes any messages from the 2nd which aren't on the 1st #
#       3.  Sets the message flags on the 2nd to match the 1st's flags#  
#                                                                     #
#   imapsync is called like this (single user):                       #
#      ./imapsync -S host1/user1/password1 -D host2/user2/password2   # 
#      (multiple users)                                               #
#      ./imapsync -S host1 -D host2 -u <users file>                   # 
#                                                                     #
#   Optional arguments:                                               #
#	-d debug                                                      #
#       -u <users file>  src_user:src_pwd:dst_user:dst_pwd            #
#       -L logfile                                                    #
#       -m mailbox list (sync only certain mailboxes,see usage notes) #
#######################################################################

use Socket;
use IO::Socket;
use IO::Socket::INET;
use FileHandle;
use Fcntl;
use Getopt::Std;
use MIME::Base64 qw( encode_base64 decode_base64 );

#################################################################
#            Main program.                                      #
#################################################################

init();

foreach $user ( @users ) {
   $user =~ s/oauth2:/oauth2---/g;
   ($sourceUser,$sourcePwd,$destUser,$destPwd) = split(/:/, $user);

   #  Replace the placeholder for the : character if present
   $sourceUser =~ s/XXXXXX/:/g;
   $sourcePwd  =~ s/XXXXXX/:/g;
   $destUser   =~ s/XXXXXX/:/g;
   $destPwd    =~ s/XXXXXX/:/g;

   if ( $src_admin_user and !$destPwd ) {
      #  Do an admin login using AUTHENTICATION = PLAIN
      $sourceUser .= ":$src_admin_user";
      $src_admin_user =~ /(.+)\s*:\s*(.+)/;
      $src_admin_pwd  = $2;
   }

   if ( $dst_admin_user and !$destPwd ) {
      #  Do an admin login using AUTHENTICATION = PLAIN
      $destUser .= ":$dst_admin_user";
      $dst_admin_user =~ /(.+)\s*:\s*(.+)/;
      $dst_admin_pwd  = $2;
   }

   #  Get list of all messages on the source host by Message-Id
   #
   connectToHost($sourceHost, \$src)    or exit;
$SOURCE = $src;
   if ( $sourceUser =~ /(.+)[:;](.+)[:;](.+)/ ) {
      #  An AUTHENTICATE = PLAIN login has been requested
      next unless login_plain( $sourceUser, $src );
   } else {
      #  Otherwise do an ordinary login
      next unless login($sourceUser,$sourcePwd, $src);
   }
   namespace( $src, \$srcPrefix, \$srcDelim, $opt_x );

   connectToHost( $destHost, \$dst ) or exit;
$DEST = $dst;

   if ( $destUser =~ /(.+)[:;](.+)[:;](.+)/ ) {
      #  An AUTHENTICATE = PLAIN login has been requested
      next unless login_plain( $destUser, $dst );
   } else {
      #  Otherwise do an ordinary login
      unless ( login( $destUser,$destPwd, $dst ) ) {
         logout( $src );
         next;
      }
   }
   namespace( $dst, \$dstPrefix, \$dstDelim, $opt_y );

   #  Create mailboxes on the dst if they don't already exist
   my @source_mbxs = getMailboxList( $src );

   $n = scalar @source_mbxs;
   Log("There are $n mailboxes to sync");

   #  Exclude certain ones if that's what the user wants
   exclude_mbxs( \@source_mbxs ) if $excludeMbxs;

   map_mbx_names( \%mbx_map, $srcDelim, $dstDelim );

   createDstMbxs( \@source_mbxs, $dst );

   #  Check for new messages and existing ones with new flags
   $adds=$updates=$deletes=0;
   $would_have_added=$would_have_deleted=$would_have_updated=0;
   @moves = ();
   ($added,$updated,$deleted) = check_for_adds( \@source_mbxs, \%REVERSE, $src, $dst );

   logout( $src );
   logout( $dst );

   Log("\nSummary of results for $user");
   if ( $test ) {
      Log("   Would have added   $would_have_added");
      Log("   Would have updated $would_have_updated");
      Log("   Would have deleted $would_have_deleted");
   } else {
      Log("   Added   $added");
      Log("   Updated $updated");
      Log("   Deleted $deleted");
      if ( @moves ) {
         $moved = scalar @moves;
         Log("   Moved   $moved");
      }
   }

}

summarize();

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
         s/\\:/XXXXXX/g;    # Replace : with a placeholder
         if ( !/(.+):(.*):(.+):(.*)/ ) {
            print STDERR "Error at line $n in users file\n";
            print STDERR "Not in srcuser:srcpwd:dstuser:dstpwd format\n";
            exit;
         } 
         push( @users, $_ );
      }
      close U;

   } else {
      #  ($sourceHost,$sourceUser,$sourcePwd) = split(/\//, $opt_S);
      #  ($destHost,  $destUser,  $destPwd)   = split(/\//, $opt_D);

      if ( $opt_S =~ /\\/ ) {
         ($sourceHost, $sourceUser, $sourcePwd) = split(/\\/, $opt_S);
      } else {
         ($sourceHost, $sourceUser, $sourcePwd) = split(/\//, $opt_S);
      }

      if ( $opt_D =~ /\\/ ) {
         ($destHost, $destUser, $destPwd) = split(/\\/, $opt_D);
      } else {
         ($destHost, $destUser, $destPwd) = split(/\//, $opt_D);
      }
      push( @users, "$sourceUser:$sourcePwd:$destUser:$destPwd" );
   }

   $timeout = 60 unless $timeout;

   #  Open the logFile
   #
   if ( $logfile ) {
      if ( !open(LOG, ">>$logfile")) {
         print STDOUT "Can't open $logfile: $!\n";
      } 
      select(LOG); $| = 1;
   }
   Log("$0 starting\n");
   Log("Syncing messages after $opt_s") if $opt_s;

   if ( $source_archive ) {
      #  The user wants messages on the source in certain mailboxes to be moved
      #  to archive mailboxes on the source after being copied to the destination
      foreach $term ( split(/,/, $source_archive) ) {
         #  mbx1 is the source mbx and mbx2 is the archive mbx on the source
         ($mbx1,$mbx2) = split(/:/, $term);
         Log("Messages in $mbx1 on the source will be moved to $mbx2 on the source after syncing");
         $SOURCE_ARCHIVE{"$mbx1"} = $mbx2;
      }
   }
   #  Determine whether we have SSL support via openSSL and IO::Socket::SSL
   $ssl_installed = 1;
   eval 'use IO::Socket::SSL';
   if ( $@ ) {
      $ssl_installed = 0;
   }

   Log("Running in test mode, no changes will be made") if $test;

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

    $fd = $NEW{$fd} if $NEW{$fd};

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

    $fd = $NEW{$fd} if $NEW{$fd};

    $response = <$fd>;
    chop $response;
    $response =~ s/\r//g;
    push (@response,$response);
    if ($showIMAP) { Log ("<< $response",2); }

    if ( $response =~ /^\* BYE/ ) {
       # Log("The server closed the connection:  $response ");
       # exit;
    }

    if ( $exchange and $response =~ /^1 NO|^1 BAD/ ) {
       $errors++;
       if ( $errors == 9 ) {
          $newdst = exchange_workaround() if $errors == 9;
          $NEW{$dst} = $newdst;
       }
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

   if ( $line =~ /^\>\> 1 LOGIN (.+) "(.+)"/ ) {
      #  Obscure the password for security's sake
      $line = ">> LOGIN $1 \"XXXX\"";
   }

   if ( $logfile ) {
      ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
      if ($year < 99) { $yr = 2000; }
      else { $yr = 1900; }
      $line = sprintf ("%.2d-%.2d-%d.%.2d:%.2d:%.2d %s %s\n",
		     $mon + 1, $mday, $year + $yr, $hour, $min, $sec,$$,$str);
      print LOG "$line";

   } 

   if ( $quiet ) {
     print STDOUT "$str\n" unless $str =~ /^\>|^\<|^Inserting/g;
   } else {
      print STDOUT "$str\n";
   }

}

#  insertMsg
#
#  This routine inserts an RFC822 messages into a user's folder
#

sub insertMsg {

local ($conn, $mbx, *message, $flags, $date, $msgid) = @_;
local ($lenx);

   Log("Inserting message $msgid") if $debug;
   $totalMsgs++;

$conn = $NEW{$conn} if $NEW{$conn};

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

   $lenx = length($message);
   $totalBytes = $totalBytes + $lenx;

   $flags = flags( $flags );
   fixup_date( \$date );

   #  Use the new dst connection if we had to disconnect/reconnect because of Exchange
   #  10-error limit.
   $conn = $NEW{$conn} if $NEW{$conn};

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
   Log("Connected to $host on port $port");

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

   if ( $pwd =~ /^oauth2---(.+)/i ) {
      $token = $1;
      Log("password is an OAUTH2 token") if $debug;
      $status = login_xoauth2( $user, $token, $conn );
      return $status;
   }

   #  Use the new dst connection if we had to disconnect/reconnect because of Exchange
   #  10-error limit.
   $conn = $NEW{$conn} if $NEW{$conn};

   Log("Authenticating as $user");
   sendCommand ($conn, "1 LOGIN \"$user\" \"$pwd\"");
   while (1) {
	readResponse ( $conn );

        if ( $response =~ /Microsoft Exchange/i and $conn eq $dst ) {
           #  The destination is an Exchange server
           unless ( $exchange_override ) {
              $exchange = 1;
              Log("The destination is an Exchange server");
           }
        }

	last if $response =~ /^1 OK/i;
	if ($response =~ /^1 NO|^1 BAD/i) {
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

   #  Use the new dst connection if we had to disconnect/reconnect because of Exchange
   #  10-error limit.
   $conn = $NEW{$conn} if $NEW{$conn};

   undef @response;
   sendCommand ($conn, "1 LOGOUT");
   while ( 1 ) {
	readResponse ($conn);
	if ( $response =~ /^1 OK|^1 BYE/i ) {
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
my $COUNTER;

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

   #  Use the new dst connection if we had to disconnect/reconnect because of Exchange
   #  10-error limit.
   $conn = $NEW{$conn} if $NEW{$conn};

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
        $mbx =~ s/\s+/ /g if $trim_mbx_spaces;

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
my $list    = shift;
my $conn    = shift;
my $seen;
my $empty;
my $msgnum;
my $from;
my $flags;
my $msgid;
my $header_date;
my $from;
my $subject;
my $uid;

   #  Get a list of the msgs in this mailbox

   #  Use the new dst connection if we had to disconnect/reconnect because of Exchange
   #  10-error limit.
   $conn = $NEW{$conn} if $NEW{$conn};

   @$msgs = ();
   %$list = ();
   trim( *mailbox );
   return if $mailbox eq "";
   sendCommand ($conn, "1 EXAMINE \"$mailbox\"");
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

   return if $empty;

   #  Use the new dst connection if we had to disconnect/reconnect because of Exchange
   #  10-error limit.
   $conn = $NEW{$conn} if $NEW{$conn};

   sendCommand ( $conn, "1 FETCH 1:* (uid flags internaldate body[header.fields (From Date Message-ID Subject)])");
   undef @response;
   while ( 1 ) {
	readResponse ( $conn );
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

        if ( $response[$i] =~ /UID (.+)/ ) {
           ($uid) = split(/\s+/, $1);
        }

        if ( $response[$i] =~ /^Message-ID:\s*(.*)/i ) {
           $msgid = $1;
           if ( $msgid eq '' ) {
              # Line-wrap, get it from the next line
              $msgid = get_wrapped_msgid( \@response, $i );
           }
        }

        if ( $response[$i] =~ /INTERNALDATE/) {
           $response[$i] =~ /INTERNALDATE (.+) BODY/i;
           $date = $1;
           $date =~ /"(.+)"/;
           $date = $1;
           $date =~ s/"//g;
        }

        # if ( $response[$i] =~ /\* (.+) [^FETCH]/ ) {
        if ( $response[$i] =~ /\* (.+) FETCH/ ) {
           ($msgnum) = split(/\s+/, $1);
        }

        if ( $response[$i] =~ /Subject:\s*(.+)/i) {
           $subject = $1;
        }
     
        if ( $response[$i] =~ /Date:\s*(.+)/i) {
           $header_date = $1;
        }
     
        if ( $response[$i] =~ /From:\s*(.+)/i) {
           $from = $1;
        }
     
        # if ( $msgnum and $date and $msgid ) {

        if ( $response[$i] =~ /^\)/ or ( $response[$i] =~ /\)\)$/ ) ) {
           if ( $ignore_msgids ) {
              if ( $IGNORE_MSGIDS{"$msgid"} ) {
                 Log("Ignoring $msgid");
                 next;
              } 
           } 

           if ( $msgid eq '' ) {
              #  The message lacks a message-id so construct one.
              $header_date =~ s/\W//g;
              $subject =~ s/\W//g;
              $msgid = "$header_date$subject$from";
              $msgid =~ s/\s+//g;
              $msgid =~ s/\+|\<|\>|\?|\*|"|'|\(|\)//g;
              Log("msgnum $msgnum has no msgid, build one as $msgid") if $debug;
           }

	   push (@$msgs,"$msgid||||||$msgnum||||||$flags||||||$date||||||$header_date||||||$uid");
           $$list{"$msgid"} = "$msgnum,$flags";
           $msgnum=$msgid=$date=$flags=$header_date=$from=$subject=$uid='';
        }
   }


}

#  getDatedMsgList
#
#  Get a list of the user's messages in a mailbox on
#  the host which were sent after the specified date
#
sub getDatedMsgList {

my $mailbox = shift;
my $date    = shift;
my $msgs    = shift;
my $list    = shift;
my $conn    = shift;
my ($seen, $empty, @list,$msgid,$header_date,$from,$subject);
my $loops;
my $uid;

    #  Get a list of messages sent after the specified date

    my @list;
    @$msgs = ();
    %$list = ();

    #  Use the new dst connection if we had to disconnect/reconnect because of Exchange
    #  10-error limit.
    $conn = $NEW{$conn} if $NEW{$conn};

    if (  $date !~ /-/ ) {
       # Delta in days, convert to DD-MMM-YYYY
       $date = get_date( $sync_since ); 
    }
    sendCommand ($conn, "1 EXAMINE \"$mailbox\"");
    while ( 1 ) {
        readResponse ($conn);
        if ( $response =~ / EXISTS/i) {
            $response =~ /\* ([^EXISTS]*)/;
            Log("     There are $1 messages in $mailbox");
        } elsif ( $response =~ /^1 OK/i ) {
            last;
        } elsif ( $response !~ /^\*/ ) {
            Log ("unexpected EXAMINE response: $response");
            return 0;
        }
        if ( $loops++ > 100 ) {
           Log("No response to EXAMINE command, skipping this mailbox"); 
           last;
        }
    }

    #  Use the new dst connection if we had to disconnect/reconnect because of Exchange
    #  10-error limit.
    $conn = $NEW{$conn} if $NEW{$conn};

    #
    #  Get list of messages sent after the reference date
    #
    Log("     Get messages sent after $date") if $debug;
    $nums = "";
    sendCommand ($conn, "1 SEARCH SENTSINCE \"$date\"");
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
    if ( $nums eq "" ) {
	Log ("     $mailbox has no messages sent after $date") if $debug;
	return;
    }
    # Log("     Msgnums for messages in $mailbox sent after $date $nums") if $debug;
    $nums =~ s/\s+/ /g;
    @msgList = ();
    @msgList = split(/ /, $nums);

    my $n = scalar @msgList;
    if ( $n == 0 ) {
	#  No msgs in this mailbox
	return 1;
    } else {
        Log("     There are $n messages after $date");
   }

   #  Use the new dst connection if we had to disconnect/reconnect because of Exchange
   #  10-error limit.
   $conn = $NEW{$conn} if $NEW{$conn};

@$msgs  = ();
for $num (@msgList) {

     sendCommand ( $conn, "1 FETCH $num (uid flags internaldate body[header.fields (Message-Id From Subject Date)])");
     
     undef @response;
     while ( 1 ) {
	readResponse   ( $conn );
	if   ( $response =~ /^1 OK/i ) {
		last;
	}   
        last if $response =~ /^1 NO|^1 BAD|^\* BYE/;
     }

     $flags = '';
     foreach $_ ( @response ) {
          last   if /^1 OK FETCH complete/i;
          $response = $_;

          if ( /FLAGS/ ) {
             #  Get the list of flags
             /FLAGS \(([^\)]*)/;
             $flags = $1;
             $flags =~ s/\\Recent|\\Forwarded//ig;
          }
   
          if ( /Message-Id:\s*(.*)/i ) {
             $msgid = $1;
             if ( $msgid eq '' ) {
                # Line-wrap, get it from the next line
                $msgid = get_wrapped_msgid( \@response, $i );
             }
          }

          if ( $response[$i] =~ /UID (.+)/ ) {
             ($uid) = split(/\s+/, $1);
          }

          if ( /Date:\s*(.+)/i) {
             $header_date = $1;
          }

          if ( /Subject:\s*(.+)/i) {
             $subject = $1;
          }

          if ( /From:\s*(.+)/i) {
             $from = $1;
          }

          if ( /INTERNALDATE/) {
             /INTERNALDATE (.+) BODY/i;
             $date = $1;
             $date =~ /"(.+)"/;
             $date = $1;
             $date =~ s/"//g;
          }

          if ( /\* (.+) FETCH/ ) {
             ($msgnum) = split(/\s+/, $1);
          }

          # if ( $msgid and $msgnum and $date and $msgid ) {

          if ( /^\)/ or ( /\)\)$/ ) ) {
             # End of header
             if ( $msgid eq '' ) {
                 #  The message lacks a message-id so construct one.
                 $header_date =~ s/\W//g;
                 $subject =~ s/\W//g;
                 $msgid = "$header_date$subject$from";
                 $msgid =~ s/\s+//g;
                 $msgid =~ s/\+|\<|\>|\?|\*|"|'|\(|\)//g;
                 Log("msgnum $msgnum has no msgid, build one as $msgid") if $debug;
             }

             $$list{"$msgid"} = "$msgnum,$flags";
             push (@$msgs,"$msgid||||||$msgnum||||||$flags||||||$date||||||$header_date||||||$uid");
             $msgnum=$msgid=$date=$flags=$header_date=$from=$subject=$uid='';
          }
      }
   }

   return 1;
}

sub createMbx {

my $mbx  = shift;
my $conn = shift;
my $created;
my $loops;

   #  Create the mailbox if necessary

   return if uc( $mbx ) eq 'INBOX';

   #  Use the new dst connection if we had to disconnect/reconnect because of Exchange
   #  10-error limit.
   $conn = $NEW{$conn} if $NEW{$conn};

   sendCommand ($conn, "1 CREATE \"$mbx\"");
   while ( 1 ) {
      readResponse ($conn);
      if ( $response =~ /^1 OK/i ) {
         $created = 1;
         last;
      }
      last if $response =~ /already exists/i;
      if ( $response =~ /^1 NO|^1 BAD/ ) {
         Log ("Error creating $mbx: $response");
         last;
      }
      if ( $loops++ > 100 ) {
          Log("No response to CREATE command, skipping this mailbox"); 
          last;
       }

   }
   Log("Created mailbox $mbx") if $created;
}

sub fetchMsg {

my $msgnum = shift;
my $conn   = shift;
my $message;
my $loops;
my $error=1;

   $item = 'BODY[]';

   #  Use the new dst connection if we had to disconnect/reconnect because of Exchange
   #  10-error limit.
   $conn = $NEW{$conn} if $NEW{$conn};

   # sendCommand( $conn, "1 FETCH $msgnum (rfc822)");
   sendCommand( $conn, "1 FETCH $msgnum ($item)");
   while (1) {
        $loops++;
        # Log("loops = $loops") if $debug;
        if ( $loops > 99 ) {
           #  Something is wrong.  The server should have provided the
           #  message by now.  Break out of the loop and return an empty message.
           $message = '';
           Log("Error1: Unable to fetch message after 99 tries");
           last;
        }
	readResponse ($conn);
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
                ($response =~ /^\*\s+$msgnum\s+FETCH\s+\(.*$item\s+\{[0-9]+\}/i) {
                $item =~ s/BODY\[\]/BODY\\[\\]/ if $response =~ /BODY/;
                ($len) = ($response =~ /^\*\s+$msgnum\s+FETCH\s+\(.*$item\s+\{([0-9]+)\}/i);
		$cc = 0;
		$message = "";
                $loops = 0;
		while ( $cc < $len ) {
                        $loop++;
                        # Log("loops = $loops") if $debug;
                        if ( $loops > 99 ) {
                           #  Something is wrong.  The server should have provided the
                           #  message by now.  Break out of the loop and return an empty message.
                           $message = '';
                           Log("Error2: Unable to fetch message after 99 tries");
                           last;
                        }
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
my $loops;

   #  Read the IMAP flags for a message

   #  Use the new dst connection if we had to disconnect/reconnect because of Exchange
   #  10-error limit.
   $conn = $NEW{$conn} if $NEW{$conn};

   sendCommand( $conn, "1 FETCH $msgnum (flags)");
   while (1) {
        $loops++;
        Log("XXXLoops $loops") if $debug;
        if ( $loops > 99 ) {
           Log("fetchMsgFlags failed to receive the requested flags at $loops loops");
           Log("Giving up on this message");
           last;
        }
        readResponse ($conn);
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
   print STDOUT " imapsync -S sourceHost/sourceUser/sourcePassword\n";
   print STDOUT "          -D destHost/destUser/destPassword\n";
   print STDOUT "          -d debug\n";
   print STDOUT "          -L logfile\n";
   print STDOUT "          -s <since> Sync messages since this date (DD-MMM-YYYY) or number of days ago\n";
   print STDOUT "          -m mailbox list (eg \"Inbox, Drafts, Notes\". Default is all mailboxes)\n";
   print STDOUT "          -e exclude mailbox list\n";
   print STDOUT "          -u <file of users> format srcuser:srcpwd:dstuser:dstpwd\n";
   print STDOUT "          -n do not delete messages from destination\n";
   print STDOUT "          -E <admin_user:admin_password> source admin user and password\n";
   print STDOUT "          -F <adin_user:admin_password> destination admin user and password\n";
   print STDOUT "          -R collapse spaces in mbx names to 1 space (Gmail doesn't accept multiples\n";
   print STDOUT "          -W wrap lines longer than 1,000 characters\n";
   print STDOUT "          -t test run.  Say what would have been done but don't do it\n";
   exit;

}

sub processArgs {

   if ( !getopts( "dvS:D:L:m:e:hIx:y:M:s:nNqu:E:F:f:i:RWtA:" ) ) {
      usage();
   }

   $mbxList     = $opt_m;
   $excludeMbxs = $opt_e;
   $logfile     = $opt_L;
   $mbx_map_fn  = $opt_M;
   $sync_since  = $opt_s;
   $users_file  = $opt_u;
   $no_deletes  = 1 if $opt_n;
   $debug    = 1 if $opt_d;
   $verbose  = 1 if $opt_v;
   $showIMAP = 1 if $opt_I;
   $quiet    = 1 if $opt_q;
   $test     = 1 if $opt_t;
   #  -N option deprecated
   $include_nosel_mbxs = 1 if $opt_N;
   $src_admin_user = $opt_E;
   $dst_admin_user = $opt_F;
   $msgs_per_folder = $opt_f;
   $ignore_msgids   = $opt_i;
   $trim_mbx_spaces = 1 if $opt_R;
   $wrap_long_lines = 1 if $opt_W;
   $source_archive = $opt_A;

   usage() if $opt_h;

   if ( $ignore_msgids ) {
      # -i points to a file of msgids we are to ignore
      if (!open(I, "<$ignore_msgids") ) {
         print STDERR "Error opening $ignore_msgids: $!\n";
         exit;
      }
      while( <I> ) {
         chomp;
         s/^\s+|\s+$//g;
         next if /^#/;
         $IGNORE_MSGIDS{"$_"} = 1;
      }
      close I;
   }

}

sub deleteMsg {

my $conn   = shift;
my $msgnum = shift;
my $rc;

   #  Mark a message for deletion by setting \Deleted flag

   Log("   msgnum is >$msgnum<") if $debug;
   ($msgnum,$flags) = split(/,/,$msgnum);

   if ( $msgnum eq '' ) {
      Log("Error: msgnum is blank");
      return 0;
   }

   #  Use the new dst connection if we had to disconnect/reconnect because of Exchange
   #  10-error limit.
   $conn = $NEW{$conn} if $NEW{$conn};

   sendCommand ( $conn, "1 STORE $msgnum +FLAGS (\\Deleted)");
   while (1) {
        readResponse ($conn);
        if ( $response =~ /^1 OK/i ) {
	   $rc = 1;
	   Log("   Marked $msgid for delete") if $verbose;
	   last;
	}
	if ( $response =~ /^\* BYE/ ) {
           Log("Fatal error: $response");
           Log("The server has ended the session");
           $rc = -1;
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

   #  Use the new dst connection if we had to disconnect/reconnect because of Exchange
   #  10-error limit.
   $conn = $NEW{$conn} if $NEW{$conn};

   Log("Expunging $mbx mailbox") if $verbose;
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

   #  Use the new dst connection if we had to disconnect/reconnect because of Exchange
   #  10-error limit.
   $conn = $NEW{$conn} if $NEW{$conn};

   sendCommand ( $conn, "1 EXPUNGE");
   while (1) {
        readResponse ($conn);
        last if $response =~ /^1 OK/;

	if ( $response =~ /^1 BAD|^1 NO/i ) {
	   print "Error expunging messages: $response\n";
	   last;
	}
   }

}

sub check_for_adds {

my $source_mbxs = shift;
my $REVERSE     = shift;
my $src         = shift;
my $dst         = shift;
my @sourceMsgs;

   #  Compare the contents of the user's mailboxes on the source
   #  with those on the destination.  Add any new messages to the
   #  destination and update if necessary the flags on the existing
   #  ones.

   if ( %SOURCE_ARCHIVE ) {
      #  If the user wants source archiving create the archive mbxs if they don't exist
      while(($mbx,$archive_mbx) = each( %SOURCE_ARCHIVE ) ) {
          createMbx( $archive_mbx, $src ) unless mbxExists( $archive_mbx, $src );
      }
   }
      
   $total_added=$total_updated=$total_deleted=0;
   $would_have_added=$would_have_deleted=$would_have_updated=0;
   ($user) = split(/:/, $destUser);
   Log("Checking for adds & updates for $user");
   foreach my $src_mbx ( @$source_mbxs ) {
        my $added=$updated=0;
        next if $src_mbx eq "";
        
        #  Mbxs marked NOSELECT don't hold any messages so after creating them
        #  we don't need to do anything else.
        next if $nosel_mbxs{"$src_mbx"};

        expungeMbx( $src, $src_mbx ) unless $test;
        $dst_mbx = mailboxName( $src_mbx,$srcPrefix,$srcDelim,$dstPrefix,$dstDelim );
        $dst_mbx =~ s/\s+/ /g if $trim_mbx_spaces;

        #  Record the association between source and dest mailboxes
        $$REVERSE{"$dst_mbx"} = $src_mbx;
        next if $src_mbx eq "";

        next unless selectMbx( $src_mbx, $src, 'EXAMINE' );

	@sourceMsgs=();

        if ( $sync_since ) {
           getDatedMsgList( $src_mbx, $sync_since, \@sourceMsgs, \%sourceList, $src );
        } else {
           getMsgList( $src_mbx, \@sourceMsgs, \%sourceList, $src );
        }
        getMsgList( $dst_mbx, \@destMsgs, \%destList, $dst );

        # if ( $verbose ) {
        #    Log("     src_mbx $src_mbx has the following $n messages");
        #    foreach $_ ( @sourceMsgs ) {
        #       Log("     $_");
        #    }
        # }

        selectMbx( $dst_mbx, $dst, 'SELECT' );

        my $msgcount = $#sourceMsgs + 1;
        Log("source $src_mbx has $msgcount messages");
        foreach $_ ( @sourceMsgs ) {
           Log("   $_") if $verbose;
           ($msgid,$msgnum,$src_flags,$date,$header_date,$uid) = split(/\|\|\|\|\|\|/, $_,6);
           $src_flags = flags( $src_flags );
           next if $src_flags =~ /\\Deleted/;  # Don't sync deleted messages

           if ( !$destList{"$msgid"}  ) {
              #  The msg doesn't exist in the mailbox on the dst, need to add it.
     
              if ( $test ) {
                 Log("Would haves added msgnum $msgnum") if $verbose;
                 $would_have_added++;
                 next;
              }

              Log("   Need to insert $msgnum") if $verbose;
              $message = fetchMsg( $msgnum, $src );
              next unless $message;
              $src_flags = validate_flags( $src_flags );
              $added++ if insertMsg( $dst, $dst_mbx, *message, $src_flags, $date, $msgid );

              Log("   Added $added msgs") if $added/100 == int($added/100);

              if ( $msgs_per_folder ) {
                 #  opt_F allows us to limit number of messages copied per folder
                 last if $added == $msgs_per_folder;
              }

              if ( $SOURCE_ARCHIVE{"$src_mbx"} ) {
                 push( @moves, $uid );
              }

           } else {
             #  The message exists, see if the flags have changed.
             Log("   msgnum=$msgnum exists, check its flags") if $verbose;
             # $dst_flags = fetchMsgFlags( $dst_msgnum, $dst );
             ($dst_msgnum,$dst_flags) = split(/,/, $destList{"$msgid"});

             sort_flags( \$src_flags );
             sort_flags( \$dst_flags );

             unless ( $dst_flags eq $src_flags ) {
                if ( $test ) {
                   Log("   Would have updated the flags for msgnum $dst_msgnum") if $verbose;
                   $would_have_updated++;
                   next;
                }

                if ( $verbose ) {
                   Log("   Updating the flags for msgnum $dst_msgnum");
                   Log("src_flags $src_flags");
                   Log("dst_flags $dst_flags");
                }
                $rc = setFlags( $dst_msgnum, $src_flags, $dst_flags, $dst );
                return $rc if $rc == -1;
                $updated++;
             }
           }
      }
      if ( $test ) {
         Log("   Would have added $would_have_added messages to $dst_mbx");
      } else {
         Log("   Added $added messages to $dst_mbx");
      }

      ($user) = split(/:/, $destUser );

      if ( $test ) {
         push( @summary, "$user:$dst_mbx:Would have added:$would_have_added" );
         push( @summary, "$user:$dst_mbx:Would have updated:$would_have_updated" );
      } else {
         push( @summary, "$user:$dst_mbx:added:    $added" );
         push( @summary, "$user:$dst_mbx:Updated:  $updated" );
      }

      if ( $SOURCE_ARCHIVE{"$src_mbx"} ) {
         my $archive_mbx = $SOURCE_ARCHIVE{"$src_mbx"};
         createMbx( $archive_mbx, $src ) unless mbxExists( $archive_mbx, $src );
         selectMbx( $src_mbx, $src, 'SELECT' );
         foreach $uid ( @moves ) {
            move_msg( $uid, $archive_mbx, $src ) unless $test;
         }
      }

      #  Remove messages from the dst mbx that no longer exist on 
      #  the src mbx

      $deleted = check_for_deletes( $src_mbx, $dst_mbx, \%sourceList, $dst, $src );
      last if $deleted == -1;    #  Server dropped our session.

      $total_added   += $added;
      $total_updated += $updated;
      $total_deleted += $deleted;
   }

   if ( $test ) {
      return ($total_added,$total_updated,$total_deleted);
   } else {
      return ($total_added,$total_updated,$total_deleted);
   }
}

sub check_for_deletes {

my $src_mbx    = shift;
my $dst_mbx    = shift;
my $sourceList = shift;
my $dst        = shift;
my $src        = shift;
my $deleted=0;
my $deletes=0;
my $total_deletes=0;

   #  Delete any messages on the dst that are no longer on the src.

   return 0 if $no_deletes;

   if ( $sync_since ) {
      getDatedMsgList( $dst_mbx, $sync_since, \@destMsgs, \%destList, $dst );
   } else {
      getMsgList( $dst_mbx, \@destMsgs, \%destList, $dst );
   }

   ($user) = split(/:/, $destUser);
   Log("Checking $dst_mbx for deletes for $user") if $verbose;

   $n = keys %$sourceList;

   selectMbx( $dst_mbx, $dst, 'SELECT' );
   selectMbx( $src_mbx, $src, 'EXAMINE' );

   foreach $_ ( @destMsgs ) {
      ($msgid,$dst_msgnum,$dst_flags,$date,$header_date,$uid) = split(/\|\|\|\|\|\|/, $_,6);
      if ( $verbose ) {
         Log("   msgid      $msgid");
         Log("   dst msgnum $dst_msgnum");
         Log("   dst_mbx    $dst_mbx");
      }

      if ( !$$sourceList{"$msgid"}  ) {
         #  The msg doesn't exist in the mailbox on the source, need to remove it from the dest

         if ( $test ) {
            Log("Removing $msgid from the dest") if $verbose;
            $would_have_deleted++;
            next;
         }
            
         Log("Removing $msgid from the dest") if $verbose;
         $rc = deleteMsg( $dst, $dst_msgnum );
         if ( $rc == 1 ) {
            #  Need to expunge messages from this mailbox when we're done
            $deletes++;
            $deleted=1;
         } elsif ( $rc == -1 ) {
            #  The server terminated our session. 
            return $rc;
         }
      }
   }

   if ( $test ) {
      $deletes = $would_have_deleted;
      Log("   Would have deleted $deletes messages from $dst_mbx");
   } else {
      expungeMbx( $dst, $dst_mbx ) if $deleted;
      Log("   Deleted $deletes messages from $dst_mbx");
   }

   ($user) = split(/:/, $destUser );

   if ( $test ) {
      push( @summary, "$user:$dst_mbx:Would have deleted:$deletes" );
   } else {
      push( @summary, "$user:$dst_mbx:deleted:  $deletes" );
   }

   return $deletes;
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

   #  Use the new dst connection if we had to disconnect/reconnect because of Exchange
   #  10-error limit.
   $conn = $NEW{$conn} if $NEW{$conn};

   @response = ();
   sendCommand( $conn, "1 NAMESPACE");
   while ( 1 ) {
      readResponse( $conn );
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
         $_ = lc( $_ );    
         s/^\\//;
         $_ = ucfirst( $_ );
         $_ = '\\' . $_;
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

sub createDstMbxs {

my $mbxs = shift;
my $dst  = shift;
my %dst_mbxs;

   #  Create a corresponding mailbox on the dst for each one
   #  on the src.
   
   my @dst_mbxs = getMailboxList( $dst );
   foreach $_ ( @dst_mbxs ) {
      $dst_mbxs{"$_"} = 1;
   }
      
   foreach my $mbx ( @$mbxs ) {
      $dstmbx = mailboxName( $mbx,$srcPrefix,$srcDelim,$dstPrefix,$dstDelim );
      $dstmbx =~ s/\s+/ /g if $trim_mbx_spaces;

      if ( $test and !mbxExists($dstmbx, $dst) ) {
         Log("Would have created $dstmbx on the destination") unless uc( $mbx ) eq 'INBOX';
      } else {
         ###  createMbx( $dstmbx, $dst ) unless mbxExists( $dstmbx, $dst );
         createMbx( $dstmbx, $dst ) unless $dst_mbxs{"$dstmbx"};
      }
   }
}

sub mbxExists {

my $mbx  = shift;
my $conn = shift;
my $status = 1;
my $loops;

   #  Determine whether a mailbox exists

   #  Use the new dst connection if we had to disconnect/reconnect because of Exchange
   #  10-error limit.
   $conn = $NEW{$conn} if $NEW{$conn};

   sendCommand ($conn, "1 EXAMINE \"$mbx\"");
   while (1) {
        readResponse ($conn);
        last if $response =~ /^1 OK/i;
        if ( $response =~ /^1 NO|^1 BAD/ ) {
           $status = 0;
           last;
        }
        if ( $loops++ > 100 ) {
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

   #  Use the new dst connection if we had to disconnect/reconnect because of Exchange
   #  10-error limit.
   $conn = $NEW{$conn} if $NEW{$conn};

   sendCommand ( $conn, "1 STORE $msgnum -FLAGS ($old_flags)");
   while (1) {
        readResponse ($conn);
        if ( $response =~ /^1 OK/i ) {
           $rc = 1;
           last;
        }
        if ( $response =~ /^\* BYE/ ) {
           Log("Fatal error: $response");
           Log("The server has ended the session");
           return -1;
        }

        if ( $response =~ /^1 BAD|^1 NO/i ) {
           Log("Error setting flags for msg $msgnum: $response");
           $rc = 0;
           last;
        }
   }

   # Set the new flags

   #  Use the new dst connection if we had to disconnect/reconnect because of Exchange
   #  10-error limit.
   $conn = $NEW{$conn} if $NEW{$conn};

   sendCommand ( $conn, "1 STORE $msgnum +FLAGS ($new_flags)");
   while (1) {
        readResponse ($conn);
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

   #  Use the new dst connection if we had to disconnect/reconnect because of Exchange
   #  10-error limit.
   $conn = $NEW{$conn} if $NEW{$conn};

   sendCommand( $conn, "1 $type \"$mbx\"");
   while ( 1 ) {
      readResponse( $conn );
      if ( $response =~ /^1 OK/i ) {
         $status = 1;
         last;
      } elsif ( $response =~ /does not exist/i ) {
         $status = 0;
         return 0;
      } elsif ( $response =~ /^1 NO|^1 BAD/i ) {
         Log("Unexpected response to SELECT/EXAMINE $mbx command: $response");
         return 0;
      }
      
      if ( $loops++ > 100 ) {
         Log("No response to $type command, skipping this mailbox"); 
         return 0;
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
   #  one IMAP server expects this. Do the same for the day of month
   #  part of the date (Zimbra doesn't like it).

   $$date =~ s/^\s+//;
   $$date =~ /(.+) (.+):(.+):(.+) (.+)/;
   my $hrs = $2;
   my ($dom) = split(/-/, $1);
   if ( length( $dom ) == 1 ) {
      $$date = '0' . $$date;
   }

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

   #  Use the new dst connection if we had to disconnect/reconnect because of Exchange
   #  10-error limit.
   $conn = $NEW{$conn} if $NEW{$conn};

   sendCommand ($conn, "1 LIST \"\" INBOX");
   undef @response;
   while ( 1 ) {
        readResponse ($conn);
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
   
#  login_plain
#
#  login in at the source host with the user's name and password.  If provided
#  with administrator credential, use them as this eliminates the need for the 
#  user's password.
#
sub login_plain {

my $user      = shift;
my $conn      = shift;

   #  Do an AUTHENTICATE = PLAIN.  If an admin user has been provided then use it.

   my ($user,$admin,$pwd) = split(/:/, $user, 3);

   if ( !$admin ) {
      # Log in as the user
      $admin = $user
   }

   $login_str = sprintf("%s\x00%s\x00%s", $user,$admin,$pwd);
   $login_str = encode_base64("$login_str", "");
   $len = length( $login_str );

   #  Use the new dst connection if we had to disconnect/reconnect because of Exchange
   #  10-error limit.
   $conn = $NEW{$conn} if $NEW{$conn};

   # sendCommand ($conn, "1 AUTHENTICATE PLAIN {$len}" );
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
           unless ( $exchange_override ) {
              $exchange = 1;
              Log("The destination is an Exchange server");
           }
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

   #  Use the new dst connection if we had to disconnect/reconnect because of Exchange
   #  10-error limit.
   $conn = $NEW{$conn} if $NEW{$conn};

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

sub validate_flags {

my $flags = shift;
my $newflags;
my %standard_flags = (
       '\\Seen', 1, '\\Deleted', 1, '\\Draft', 1,
       '\\Answered', 1, '\\Flagged', 1, '\\Recent', 1,
       '\\SEEN', 1, '\\DELETED', 1, '\\DRAFT', 1,
       '\\ANSWERED', 1, '\\FLAGGED', 1, '\\RECENT', 1 );

    # Remove any flags not supported by the destination mailbox

    foreach my $flag ( split(/\s+/, $flags ) ) {
        $flag = uc( $flag );
        next unless $standard_flags{$flag};
        $newflags .= "$flag ";
    }
    chop $newflags;

    return $newflags;

}

sub summarize {

   my $summary;
   foreach $_ ( @summary ) {
     ($user,$results) = split(/:/, $_, 2);
     $USERS{"$user"}++ if $user;
     $summary .= "$user\n" if $user ne $previous;
     $previous = $user;
     $summary .= "      $results\n";
   }

   $users = keys %USERS;
   $header = "$users users synchronized\n----------------------------------------------------\n";
   $summary = $header . $summary;

   Log("\nSynchronization summary:\n$summary");
}

sub move_msg {

my $uid   = shift;
my $mbx   = shift;
my $conn  = shift;

   #  Move a message from the current mailbox to another one.

   #  Use the new dst connection if we had to disconnect/reconnect because of Exchange
   #  10-error limit.
   $conn = $NEW{$conn} if $NEW{$conn};

   sendCommand ($conn, "1 UID MOVE $uid $mbx" );
   my $loops;
   while (1) {
        readResponse ( $conn );
        last if $response =~ /^1 OK/i;
        if ($response =~ /^1 NO|^1 BAD|^\* BYE/i) {
           Log ("unexpected MOVE response: $response");
           exit;
        }
        $last if $loops++ > 99;
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

sub exchange_workaround {

   #  Because Exchange terminates an IMAP connection after 10 errors have occurred
   #  we have to start a new session before we can continue

   Log("The maximum number of errors ($errors) permitted by Exchange have occurred, disconnecting from Exchange server.");
   $errors = 0;

   $old_dst = $dst;
   logout( $dst );
   connectToHost( $destHost, \$dst );

   #  Log back into Exchange

   if ( $destUser =~ /(.+):(.+):(.+)/ ) {
      #  An AUTHENTICATE = PLAIN login has been requested
      Log("PLAIN login") if $debug;
      return 0 unless login_plain( $destUser, $dst );
   } else {
      #  Otherwise do an ordinary login
      unless ( login( $destUser,$destPwd, $dst ) ) {
         logout( $src );
         return 0;
      }
   }
   selectMbx( $dstmbx, $dst, 'SELECT' );
   
   #  Map the old dst connection to the new one
   $NEW{$old_dst} = $dst;

}


#!/usr/bin/perl

use Socket;
use FileHandle;
use Fcntl;
use Getopt::Std;
use MIME::Base64 qw(encode_base64 decode_base64);

    ######################################################################
    #  Program name   mbxIMAPsync.pl                                     #
    #  Written by     Rick Sanders                                       #
    #  Date           12 Feb 2004                                        #
    #                                                                    #
    #  Description                                                       #
    #                                                                    #
    #  mbxIMAPsync is used to synchronize the contents of a Unix         #
    #  mailfiles with an IMAP mailbox.  The user supplies the location   #
    #  & name of the Unix mailbox (eg /var/mail/rfs) and the hostname,   #
    #  username, & password of the IMAP account along with the name      #
    #  of the IMAP mailbox.  For example:                                #
    #                                                                    #
    #  ./mbxIMAPsync.pl -f /var/mail/rfs -i imapsrv/rfs/mypass -m INBOX  #
    #                                                                    #
    #  mbxIMAPsync compares the messages in the mailfile with those in   #
    #  the IMAP mailbox by Message-Id and adds the ones in the mailfile  #
    #  which are not in the IMAP mailbox.  Then it looks for messages    #
    #  in the IMAP mailbox which are not in the mailfile and removes     #
    #  them from the IMAP mailbox.                                       #
    #                                                                    #
    #  See the Usage() for available options.                            #
    ######################################################################

   init();

   connectToHost($imapHost, \$conn );
   login($imapUser,$imapPwd, $conn );

   #  Get list of msgs in the mailfile by Message-Id

   $added=$purged=0;
   print STDOUT "Processing $mailfile\n";
   print STDOUT "Checking for messages to add\n";
   @msgs = readMbox( $mailfile );
   foreach $msg ( @msgs ) {
       @msgid = grep( /^Message-ID:/i, @$msg );
       ($label,$msgid) = split(/:/, $msgid[0]);
       chomp $msgid;
       trim( *msgid );
       $mailfileMsgs{"$msgid"} = '1';
       push( @sourceMsgs, $msgid );

       if ( !findMsg( $msgid, $mbx, $conn ) ) {
          # print STDOUT "Need to add msgid >$msgid<\n";
          my $message;

          foreach $_ ( @$msg ) { chop $_; $message .= "$_\r\n"; }

          if ( insertMsg($mbx, \$message, $flags, $date, $conn ) ) {
             $added++;
             print STDOUT "   Added $msgid\n";
          }
       }
   }

   #  Remove any messages from the IMAP mailbox that no longer
   #  exist in the mailfile

   print STDOUT "Checking for messages to purge\n";
   getMsgList( $mbx, \@imapMsgs, $conn );
   foreach $msgid ( @imapMsgs ) {
      if ( $mailfileMsgs{"$msgid"} eq '' ) {
         if ( deleteMsg($msgid, $mbx, $conn ) ) {
            Log("   Marked $msgid for deletion");
            print STDOUT "   Marked msgid $msgid for deletion\n";
            $deleted++;
         } 
      }
   }

   if ( $deleted ) {
      #  Need to purge the deleted messages
      $purged = expungeMbx( $mbx, $conn );
   }

   Log("Done");
   Log("Added  $added messages to IMAP mailbox $mbx");
   Log("Purged $purged messages from IMAP mailbox $mbx");

   print STDOUT "\nAdded  $added messages to IMAP mailbox $mbx\n";
   print STDOUT "Purged $purged messages from IMAP mailbox $mbx\n";

   exit;


sub init {

   if ( ! getopts('f:m:i:L:dxA:F:I') ) {
      usage();
      exit;
   }

   ($imapHost,$imapUser,$imapPwd) = split(/\//, $opt_i);
   $mailfile = $opt_f;
   $mbx      = $opt_m;
   $logfile  = $opt_L;
   $admin_user = $opt_A;
   $msgs_per_folder = $opt_F;
   $debug    = 1 if $opt_d;
   $showIMAP = 1;

   if ( $logfile ) {
      if ( ! open (LOG, ">> $logfile") ) {
        print "Can't open logfile $logfile: $!\n";
        $logfile = '';
      }
   }
   Log("\nThis is mbxIMAPsync\n");

   if ( !-e $mailfile ) {
      Log("$mailfile does not exist");
      exit;
   }

   #  Determine whether we have SSL support via openSSL and IO::Socket::SSL
   $ssl_installed = 1;
   eval 'use IO::Socket::SSL';
   if ( $@ ) {
      $ssl_installed = 0;
   }
}

sub usage {

   print "Usage: mbxIMAPsync.pl\n";
   print "    -f <location of mailfiles>\n";
   print "    -i imapHost/imapUser/imapPassword\n";
   print "    -m <IMAP mailbox>\n";
   print "    [-L <logfile>]\n";
   print "    [-d debug]\n";

}

sub readMbox {

my $file  = shift;
my @mail  = ();
my $mail  = [];
my $blank = 1;
local *FH;
local $_;

    Log("Reading the mailfile") if $debug;
    open(FH,"< $file") or die "Can't open $file";

    while(<FH>) {
        if($blank && /\AFrom .*\d{4}/) {
            push(@mail, $mail) if scalar(@{$mail});
            $mail = [ $_ ];
            $blank = 0;
        }
        else {
            $blank = m#\A\Z#o ? 1 : 0;
            push(@{$mail}, $_);
        }
    }

    push(@mail, $mail) if scalar(@{$mail});
    close(FH);

    return wantarray ? @mail : \@mail;
}

sub Log {

my $line = shift;
my $msg;

   ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime (time);
   $msg = sprintf ("%.2d-%.2d-%.4d.%.2d:%.2d:%.2d %s",
                  $mon + 1, $mday, $year + 1900, $hour, $min, $sec, $line);

   if ( $logfile ) {
      print LOG "$msg\n";
   }
   print STDERR "$line\n";

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

   Log("Logging in as $user") if $debug;
   sendCommand ($conn, "1 LOGIN $user $pwd");
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
    Log ("<< $response",2) if $showIMAP;
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
sub insertMsg {

my $mbx = shift;
my $message = shift;
my $flags = shift;
my $date  = shift;
my $conn  = shift;
my ($lsn,$lenx);

   Log("   Inserting message into mailbox $mbx") if $debug;
   $lenx = length($$message);

   #  Create the mailbox unless we have already done so
   ++$lsn;
   if ($destMbxs{"$mbx"} eq '') {
        Log("creating mailbox $mbx") if $debug;
	sendCommand (IMAP, "$lsn CREATE \"$mbx\"");
	while ( 1 ) {
	   readResponse (IMAP);
	   if ( $response =~ /^1 OK/i ) {
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

   ++$lsn;
   $flags =~ s/\\Recent//i;

   # &sendCommand (IMAP, "$lsn APPEND \"$mbx\" ($flags) \"$date\" \{$lenx\}");
   sendCommand (IMAP, "$lsn APPEND \"$mbx\" \{$lenx\}");
   readResponse (IMAP);
   if ( $response !~ /^\+/ ) {
       Log ("unexpected APPEND response: $response");
       # next;
       push(@errors,"Error appending message to $mbx for $user");
       return 0;
   }

   print IMAP "$$message\r\n";

   undef @response;
   while ( 1 ) {
       readResponse (IMAP);
       if ( $response =~ /^$lsn OK/i ) {
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

   sendCommand ( $conn, "1 FETCH 1:* (uid flags internaldate body[header.fields (Message-Id)])");
   undef @response;
   while ( 1 ) {
	readResponse ( $conn );
	if ( $response =~ /^1 OK/i ) {
		# print STDERR "response $response\n";
		last;
	}
	elsif ( $XDXDXD ) {
		Log ("unexpected response: $response");
		Log ("Unable to get list of messages in this mailbox");
		push(@errors,"Error getting list of $user's msgs");
		return 0;
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


sub findMsg {

my $msgid = shift;
my $mbx   = shift;
my $conn  = shift;
my $msgnum;
my $noSuchMbx;

   Log("Searching for $msgid in $mbx") if $debug;
   sendCommand ( $conn, "1 SELECT \"$mbx\"");
   while (1) {
	readResponse ($conn);
        if ( $response =~ /^1 NO/ ) {
           $noSuchMbx = 1;
           last;
        }
	last if $response =~ /^1 OK/;
   }
   return '' if $noSuchMbx;

   Log("Search for $msgid") if $debug;
   sendCommand ( $conn, "1 SEARCH header Message-Id \"$msgid\"");
   while (1) {
	readResponse ($conn);
	if ( $response =~ /\* SEARCH /i ) {
	   ($dmy, $msgnum) = split(/\* SEARCH /i, $response);
	   ($msgnum) = split(/ /, $msgnum);
	}

	last if $response =~ /^1 OK/;
	last if $response =~ /complete/i;
   }

   if ( $msgnum ) {
      Log("Message exists") if $debug;
   } else {
      Log("Message does not exist") if $debug;
   }

   return $msgnum;
}

sub deleteMsg {

my $msgid = shift;
my $mbx   = shift;
my $conn  = shift;
my $rc;

   Log("Deleting message $msgid") if $debug;
   $msgnum = findMsg( $msgid, $mbx, $conn );

   sendCommand ( $conn, "1 STORE $msgnum +FLAGS (\\Deleted)");
   while (1) {
        readResponse ($conn);
        if ( $response =~ /^1 OK/i ) {
	   $rc = 1;
	   Log("   Marked $msgid for delete");
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
my $purged=0;

   Log("Purging $mbx") if $debug;
   sendCommand ( $conn, "1 SELECT \"$mbx\"");
   while (1) {
        readResponse ($conn);
        last if $response =~ /^1 OK/;

	if ( $response =~ /^1 NO|^1 BAD/i ) {
	   Log("Error selecting mailbox $mbx: $response");
	   last;
	}
   }

   sendCommand ( $conn, "1 EXPUNGE");
   while (1) {
        readResponse ($conn);
        last if $response =~ /^1 OK/;
        $purged++ if $response =~ /EXPUNGE/i;

	if ( $response =~ /^1 BAD|^1 NO/i ) {
	   print STDOUT "Error expunging messages: $response\n";
	   last;
	}
   }

   return $purged;

}


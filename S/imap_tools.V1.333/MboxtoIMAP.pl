#!/usr/bin/perl

# $Header: /mhub4/sources/imap-tools/MboxtoIMAP.pl,v 1.21 2014/10/15 15:46:28 rick Exp $

######################################################################
#  Program name   MboxtoIMAP.pl                                      #
#  Written by     Rick Sanders                                       #
#  Date           9 March 2008                                       #
#                                                                    #
#  Description                                                       #
#                                                                    #
#  MboxtoIMAP.pl is used to copy the contents of Unix                #
#  mailfiles to IMAP mailboxes.  It parses the mailfiles             #
#  into separate messages which are inserted into the                #
#  corresponging IMAP mailbox.                                       #
#                                                                    #
#  See the Usage() for available options.                            #
#                                                                    #
######################################################################

use Socket;
use FileHandle;
use Fcntl;
use Getopt::Std;
use IO::Socket;
use File::Find;
use MIME::Base64 qw(encode_base64 decode_base64);

    init();
    @mailfiles = getMailfiles();

    connectToHost($imapHost, \$dst);
    login($imapUser,$imapPwd, $dst);
    namespace( $dst, \$dstPrefix, \$dstDelim );

    if ( $range ) {
      ($lower,$upper) = split(/-/, $range);
      Log("Migrating Mbox message numbers between $lower and $upper");
    }

    $msgs=$errors=0;
    foreach $mailfile ( @mailfiles ) {
       $owner = getOwner( "$mfdir/$mailfile" );
       if ( $mbxname and $mfile ) {
          $mbx = $mbxname;
       } else {
          # @terms = split(/\//, $mailfile);
          # $mbx = $terms[$#terms];
          $mbx = $mailfile;
          $mbx =~ s/$mfdir\///;
       }
       $mbx =~ s/\.mbox$//;
       $mbx = mailboxName( $mbx,$dstPrefix,$dstDelim );

       $mbxs++;
       Log("Copying to mbx $mbx");

       if ( !isAscii( $mbx ) ) {
          # mbx name contains non-ASCII characters
          if ( $utf7 ) {
             $mbx = Unicode::IMAPUtf7::imap_utf7_encode( $mbx );
          } else {
             Log("The name $mbx contains non-ASCII characters.  To have it properly");
             Log("named in IMAP you must install the Unicode::IMAPUtf7 Perl module");
          }
       } 

       createMbx( $mbx, $dst ) unless mbxExists( $mbx, $dst );

       if ( $update ) {
          Log("Get msgids on the destination") if $debug;
          getMsgIdList( $mbx, \%DST_MSGS, $dst );
       }

       foreach $_ ( keys %DST_MSGS ) {
          Log(print STDERR "$_") if $debug;
       }

       if ( $removeCopiedMsgs ) {
          unless( open(NEW, ">$mfdir/$mailfile.new") ) {
             Log("Can't open $mfdir/$mailfile.new: $!");
             exit;
          }
       }

       $msgnum=0;
       @msgs = readMbox( $mailfile );
       $msgcount = $#msgs+1;
       Log("There are $msgcount messages in the $mailfile mbox");
       $copied = 0;
       foreach $msg ( @msgs ) {
          alarm $timeout;
          $msgnum++;
          @msgid = grep( /^Message-ID:/i, @$msg );
          ($label,$msgid) = split(/:/, $msgid[0]);
          chomp $msgid;
          trim( *msgid );
          @subject = grep( /^Subject:/i, @$msg );
          ($label,$subject) = split(/:/, $subject[0], 2);
          chomp $subject;
          trim( *subject );
          @orig_date = grep( /^Date:/i, @$msg );
          ($label,$orig_date) = split(/:/, $orig_date[0],2);
          chomp $orig_date;
          trim( *orig_date );

          Log("msgid $msgid") if $debug;
          if ( $update ) {
             #  Don't insert the message if it already exists
             next if $DST_MSGS{"$msgid"};
             Log("$msgid does not exist on the destination") if $debug;
          }
          Log("Copying message number $msgnum $msgid");

          # if ( $getdate ) {
          #   $date = get_date( $msg );
          # }

          $date = get_date( $msg );

          my $message;
          foreach $_ ( @$msg ) { 
             chomp;
             $message .= "$_\r\n"; 
          }
 
          if ( $range ) {
             if ( ($msgnum < $lower) or ($msgnum > $upper) ) {
                #  We aren't going to copy this msg so save it to
                #  the temp copy of the mailfile that we are building
                print NEW "$message\n" unless $removeCopiedMessages;
                next;
             }
          }

          if ( insertMsg($mbx, \$message, $flags, $date, $dst) ) {
             $added++;
             $copied++;
             print STDOUT "   Added $msgid\n" if $debug;
             print NEW "$message\n" unless $removeCopiedMsgs;
          } else {
             Log("Copy failed");
          }

          if ( $msgs_per_folder ) {
             #  opt_F allows us to limit number of messages copied per folder
             last if $copied == $msgs_per_folder;
          }

          alarm 0;
          if ( $conn_timed_out ) {
             Log("$imapHost timed out");
             print STDERR "reconnect to $imapHost on conn = $dst\n";
             reconnect( $checkpoint, $dst );
             $conn_timed_out = 0;
             next;
          }
       }
    
       if ( $removeCopiedMsgs ) {
          #  Put the temp mailfile less the copied messages in place.
          close NEW;
          $stat = rename( "$mfdir/$mailfile.new", "$mfdir/$mailfile" );
          unless ( $stat ) {
             Log("Rename $mfdir/$mailfile.new to $mfdir/$mailfile failed: $stat");
          } else {
             $stat = `chown $owner $mfdir/$mailfile`;
             Log("Installed new version of mailfile $mfdir/$mailfile");
          }
       }
    }

    logout( $dst );

    Log("\n\nSummary:\n");
    Log("   Mailboxes  $mbxs");
    Log("   Total Msgs $added");

    if ( $opt_W ) {
       Log("Wrote failed appends to MboxtoIMAP.failed_appends");
    }

    exit;


sub init {

   if ( !getopts('m:L:i:dIr:RDf:n:p:UM:t:WA:F:') ) {
      usage();
      exit;
   }

   $mfdir    = $opt_m;
   $mfile    = $opt_f;
   $mbxname  = $opt_n;
   $admin_user = $opt_A;
   $logfile  = $opt_L;
   $range    = $opt_r;
   $root_mbx = $opt_p;
   $max_size = $opt_M;
   $showIMAP = 1 if $opt_I;
   $debug    = 1 if $opt_d;
   $update   = 1 if $opt_U;
   $getdate = 1 if $opt_D;
   $removeCopiedMsgs = 1 if $opt_R;
   $timeout  = $opt_t;
   $timeout = 300 unless $timeout;
   $msgs_per_folder = $opt_F;

   ($imapHost,$imapUser,$imapPwd) = split(/\//, $opt_i);

   if ( $logfile ) {
      if ( ! open (LOG, ">> $logfile") ) {
        print "Can't open logfile $logfile: $!\n";
        $logfile = '';
      }
   }
   Log("Starting");
   Log("Running in update mode, msgs already on the destination will not be copied again") if $update;

   #  Determine whether we have SSL support via openSSL and IO::Socket::SSL
   $ssl_installed = 1;
   eval 'use IO::Socket::SSL';
   if ( $@ ) {
      $ssl_installed = 0;
   }
      
   #  Determine if the IMAP Utf7 module is installed.

   eval 'use Unicode::IMAPUtf7';
   if ( $@ ) {
      # Module not installed
      $utf7 = 0;   
   } else {
      $utf7 = 1;
   }

   #  Set up signal handling
   $SIG{'ALRM'} = 'signalHandler';
   $SIG{'HUP'}  = 'signalHandler';
   $SIG{'INT'}  = 'signalHandler';
   $SIG{'TERM'} = 'signalHandler';
   $SIG{'URG'}  = 'signalHandler';

   if ( $opt_W ) {
      #  The user wants a file of failed APPENDS
      open(W, ">MboxtoIMAP.failed_appends");
   }

}


sub getMailfiles {

   #  Get a list of the mailfiles to be processed.  The
   #  user can either supply a directory name where one or
   #  more mailfiles reside or he can give a complete filepath
   #  and name of a single mailfile.
   #
   #  The list of mailfiles is returned in @mailfiles

   if ( $mfdir ) {
      get_mboxes( $mfdir );   # Returns @mailfiles
   } elsif ( $mfile ) {
      if ( !-e $mfile ) {
         Log("$mfile does not exist.");
         print STDOUT "mfile $mfile does not exist\n";
         exit;
      }
      push( @mailfiles, $mfile );
   }

   Log("No mailfiles were found in $dir") if $#mailfiles == -1;

   @mailfiles = sort { lc($a) cmp lc($b) } @mailfiles;

   return @mailfiles;
}



sub usage {

   print "Usage: MboxtoIMAP.pl\n";
   print "    -m <location of mailfiles>\n";
   print "    -f <file spec of individual mailfile>\n";
   print "    -n <mailbox name> Used with -f <mailfile>\n";
   print "    -i <server/username/password>\n";
   print "       (if the password is an OAUTH2 token prefix it with 'oauth2:'\n";
   print "    [-A <admin_user:admin_pwd>]\n";
   print "    [-r <range of messages>]  eg 1-10 or 450-475\n";
   print "    [-R remove copied messages from the mailfile]\n";
   print "    [-p <root mbx> put all mailboxes under the root mbx\n";
   print "    [-L <logfile>]\n";
   print "    [-d debug]\n";
   print "    [-I log IMAP protocol exchanges]\n";

}

sub readMbox {

my $file  = shift;
my @mail  = ();
my $mail  = [];
my $blank = 1;
local *FH;
local $_;

    open(FH,"< $file") or die "Can't open $file";

    #       s/$//;
    while(<FH>) {
        s/\r$//;
        s/;
        $//;
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
      #  An AUTHENTICATE = PLAIN login has been requested
      ($authuser,$authpwd) = split(/:/, $admin_user );
      login_plain( $user, $authuser, $authpwd, $conn ) or exit;
      return 1;
   }

   if ( $pwd =~ /^oauth2:(.+)/i ) {
      $token = $1;
      Log("password is an OAUTH2 token") if $debug;
      login_xoauth2( $user, $token, $conn );
      return 1;
   }

   Log("Logging in as $user") if $debug;
   $rsn = 1;
   sendCommand ($conn, "$rsn LOGIN \"$user\" \"$pwd\"");
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

sub readResponse
{
    local($fd) = shift @_;

    $response = <$fd>;
    chop $response;
    $response =~ s/\r//g;
    push (@response,$response);
    Log ("<< $response") if $showIMAP;
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

    Log (">> $cmd") if $showIMAP;
}

sub insertMsg {

my $mbx = shift;
my $message = shift;
my $flags = shift;
my $date  = shift;
my $conn  = shift;
my ($lsn,$lenx);

   Log("   Inserting message") if $debug;
   $lenx = length($$message);

   if ( $debug ) {
      Log("$$message");
   }

   ++$lsn;
   $flags =~ s/\\Recent//i;

   fixup_date( \$date );

   sendCommand ($conn, "$lsn APPEND \"$mbx\" () \"$date\" \{$lenx\}");
   readResponse ($conn);
   if ( $response =~ /^1 BAD/ ) {
      print W "$response: $subject   $orig_date\n" if $opt_W;
      return 0;
   }
   if ( $response !~ /^\+/ ) {
       # next;
       push(@errors,"Error appending message to $mbx for $user");
       return 0;
   }

   print $conn "$$message\r\n";

   undef @response;
   while ( 1 ) {
       readResponse ($conn);
       if ( $response =~ /^$lsn OK/i ) {
	   last;
       } elsif ( $response !~ /^\*/ ) {
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
   sendCommand ($conn, "$rsn EXAMINE \"$mailbox\"");
   undef @response;
   $empty=0;
   while ( 1 ) {
	readResponse ( $conn );
	if ( $response =~ / 0 EXISTS/i ) { $empty=1; }
	if ( $response =~ /^$rsn OK/i ) {
		# print STDERR "response $response\n";
		last;
	}
	elsif ( $response !~ /^\*/ ) {
		Log ("unexpected response: $response");
		# print STDERR "Error: $response\n";
		return 0;
	}
   }

   sendCommand ( $conn, "$rsn FETCH 1:* (uid flags internaldate body[header.fields (Message-Id)])");
   undef @response;
   while ( 1 ) {
	readResponse ( $conn );
	if ( $response =~ /^$rsn OK/i ) {
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
      } elsif ( $response =~ /NO|BAD/i ) {
         Log("Unexpected response to NAMESPACE command: $response");
         last;
      }
   }

   foreach $_ ( @response ) {
      if ( /NAMESPACE/i ) {
         my $i = index( $_, '((' );
         my $j = index( $_, '))' );
         my $val = substr($_,$i+2,$j-$i-3);
         ($$prefix,$$delimiter) = split( / /, $val );
         $$prefix    =~ s/"//g;
         $$delimiter =~ s/"//g;
         last;
      }
      last if /^NO|^BAD/;
   }
 
   if ( $debug ) {
      Log("prefix  $$prefix");
      Log("delim   $$delimiter");
   }

}

sub mailboxName {

my $mbx       = shift;
my $dstPrefix = shift;
my $dstDelim  = shift;
my $dstmbx;

   #  Insert the IMAP server's prefix (if defined) and replace the Unix
   #  file delimiter with the server's delimiter (again if defined).

   $dstmbx = "$dstPrefix$mbx";
   $dstmbx =~ s#/#$dstDelim#g;

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

sub getOwner {

my $fn = shift;
my $owner;

   #  Get the numeric UID of the file's owner
   @info = stat( $fn );
   $owner = $info[4];

   return $owner;
}

sub get_date {

my $msg = shift;

   #  Extract the date from the message and format it
          
   my @date = grep( /^Date:/i, @$msg );
   my ($label,$date) = split(/:/, $date[0],2);

   $date =~ s/^\s+|\s+$//g;
   $date =~ s/\s+/ /g;

   if ( $date =~ /^(.+) (.+),/ ) {
      #  Format is DOW MDAY, MMM YYYY 0000.  Fix it up.
      $dow = $1;
      $date =~ s/^$dow\s+//;
      $date =~ s/,//;
      $date = "$dow, " . $date;
     
   }

   if ( $date =~ /^(.+),\s+(.+) (.+)\s+(.+)\s+(.+)/ ) {
      $yr = $3;
      if ( $yr < 2000 and length($yr) == 2 ) {
         #  Y2K problem, date has only 2 digits
         $date =~ s/$yr/19$yr/;
      }
   }

   if ( $date =~ /,/ ) {
      ($dow,$date) = split(/,\s*/, $date);
   } 
   if ( $date =~ /\((.+)\)/ ) {
      $date =~ s/\($1\)//g;
   }
   $date =~ s/ /-/;
   $date =~ s/ /-/;
   chomp $date;
   $date =~ s/^\s+|\s+$//g;

   if ( $date =~ / 0000$/ ) {
      $date =~ s/ 0000$/\ +0000/;
   }

   return $date;
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

   #  Subcribe to it.

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

   if ( $empty ) {
      return;
   }

   Log("Fetch the header info") if $debug;

   sendCommand ( $conn, "1 FETCH 1:* (body[header.fields (Message-Id)])");
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

sub reconnect {

my $checkpoint = shift;
my $conn = shift;

   $timed_out = 1;
print STDERR "logout conn =$conn\n";
   logout( $conn );
   Log("Timed out, closing the IMAP connection");
   close $conn;

   Log("Reconnect to $imapHost on $conn");
   connectToHost($imapHost,\$conn);
print STDERR "new conn $conn\n";
$showIMAP = 1;
   Log("Logging back in as $imapUser");
   login($imapUser,$imapPwd,$conn);

   createMbx( $mbx, $dst ) unless mbxExists( $mbx, $dst );

}

sub get_mboxes {

my $dir = shift;

   @$files = ();
   push( @dirs, $dir );
   find( \&find_files, @dirs );   # Creates @mboxes
}

sub find_files {

   my $fn = $File::Find::name;
   next if -d $fn;   # Skip directories

   #  Make sure this is a Mbox file
   next unless mbox( $fn );
   push( @mailfiles, $fn );
}

sub mbox {

my $fn = shift;
my $is_mbox = 0;

   #  Look at the file and return 1 if it 
   #  appears to be an mbox.

   open(T, "<$fn");
   my $line = <T>;
   $is_mbox = 1 if $line =~ /^From/;
   close T;
   
   return $is_mbox;
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


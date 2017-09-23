#!/usr/bin/perl

# $Header: /mhub4/sources/imap-tools/maildir_to_imap.pl,v 1.9 2014/10/31 21:33:39 rick Exp $

##########################################################################
#   Program name    maildir_to_imap.pl                                   #
#   Written by      Rick Sanders                                         #
#                                                                        #
#   Description                                                          #
#                                                                        #
#   maildir_to_imap is used to copy the messages in a maildir to a       #
#   user's IMAP mailbox.  maildir_to_imap is executed like this:         #
#                                                                        #
#   ./maildir_to_imap.pl -i <user list> -D <imapserver[:port]>           #
#                                                                        #
#   The user list is a file with one or more entries containing the      #
#   location of the user's maildir and his IMAP username and password.   #
#                                                                        #
#   For example:                                                         #
#         /mhub4/maildirs/rwilson@abc.net,rich.wilson,welcome            #
#         /mhub4/maildirs/jane.eyre@abc.net,jane.eyre,mypass             #
#                                                                        #
#   See usage() for a list of arguments                                  #
##########################################################################

init();
get_user_list( \@users );
migrate_user_list( \@users );

exit;


sub migrate_user_list {

my $users = shift;

  #  Migrate a set of users

  foreach $userinfo ( @$users ) {
     $userinfo =~ s/oauth2:/oauth2---/g;
Log("userinfo $userinfo");
     $usercount++;
     ($user) = split(/\s*,\s*/, $userinfo);
     Log("migrate $user");

     #  Start the migration.  Unless maxChildren has been set to 1
     #  fork off child processes to do the migration in parallel.
 
     if ($maxChildren == 1) {
	migrate ($userinfo, $imaphost);
     } else {
  	Log("There are $children running") if $debug;
  	if ( $children < $maxChildren ) {
   	   Log("   Forking to migrate $user") if $debug;
     	   if ( $pid = fork ) {	# Parent
	      Log ("   Parent $$ forked $pid") if $debug;
     	   } elsif (defined $pid) {	# Child
	      Log ("  Child process $$ processing $sourceUser") if $debug;
              migrate($userinfo, $imaphost);
              Log("   $user is done");
              exit 0;
     	   } else {
              Log("Error forking child to migrate $user");
              next;
     	   }
     	   $children++;
     	   $children{$pid} = $user;
  	} 

  	Log ("I'm PID $$") if $debug;
  	while ( $children >= $maxChildren ) {
     	   Log(" $$ - Max children running.  Waiting...") if $debug;
     	   $foundPid = wait;	# Wait for a child to terminate
	   if ($? != 0) {
	      Log ("ERROR: PID $foundPid exited with status $?");
	   }
	   delete $children{$foundPid};
     	   $children--;
  	}
  	Log("OK to launch another user migration") if $debug;
  }

}
}

sub xxxx {

   if ($maxChildren > 1) {
      Log("All children have been launched, waiting for them to finish");
      foreach $pid ( keys(%children) ) {
         $user = $children{$pid};
         Log("Waiting on process $pid ($user) to finish");
         waitpid($pid, 0);
         if ($? != 0) {
            Log ("ERROR: PID $pid exited with status $?");
         }
      }
   }
}


sub    sum {
summarize();
$elapsed = sprintf("%.2f", (time()-$start)/3600);
Log("Elapsed time  $elapsed hours");
Log("Migration completed");
exit;
}

sub migrate {
  
my $userinfo = shift;
my $imaphost = shift;

   my ($user,$pwd,$userpath) = split(/,/, $userinfo);

   return unless connectToHost($imaphost, \$dst);
   return unless login($user,$pwd, $dst);

   get_maildir_folders( $userpath, \%folders );

   my $messages;
   foreach $maildir_folder ( keys %folders ) {
      $maildir_folder =~ s/\&/&-/;   # Encode the '&' char
      $maildir_folder =~ s/\s+$//;
      $folder_path = $folders{"$maildir_folder"};

      if ( $MAP{uc("$maildir_folder")} ) {
         #  The user wants a different name for the IMAP folder
         Log("Messages from the $maildir_folder folder will be written to $MAP{uc(\"$maildir_folder\")} ");
         $maildir_folder = $MAP{uc("$maildir_folder")};
      }
      createMbx( $maildir_folder, $dst ) unless mbxExists( $maildir_folder, $dst );

      get_maildir_msgs( $folder_path, \@msgs );
      my $msgcount = $#msgs + 1;
      Log("     $maildir_folder ($msgcount msgs) $folder_path");
 
      next if !@msgs;

      $inserted=0;
      foreach $msgfn ( @msgs ) {
         $inserted++ if insert_msg( $msgfn, $maildir_folder, $dst );

         if ( $msgs_per_folder ) {
            #  opt_F allows us to limit number of messages copied per folder
            last if $inserted == $msgs_per_folder;
         }
      }
      Log("     Inserted $inserted messages into $maildir_folder\n");
   }

   $conn_timed_out=0;

}

sub init {

use Getopt::Std;
use Fcntl;
use Socket;
use IO::Socket;
use sigtrap;
use FileHandle;
# require "ctime.pl";
use MIME::Base64 qw( encode_base64 decode_base64 );
   
   $start = time();

   #  Set up signal handling
   $SIG{'ALRM'} = 'signalHandler';
   $SIG{'HUP'}  = 'signalHandler';
   $SIG{'INT'}  = 'signalHandler';
   $SIG{'TERM'} = 'signalHandler';
   $SIG{'URG'}  = 'signalHandler';

   getopts('H:i:L:n:ht:M:SLdD:Um:IA:F:M:');

   # usage() if $opt_h;
   #  usage();

   $userlist     = $opt_i;
   $logfile      = $opt_L;
   $maxChildren  = $opt_n;
   $usage        = $opt_h;
   $timeout      = $opt_t;
   $imaphost     = $opt_H;
   $imaphost     = $opt_D;
   $mbxList      = $opt_m;
   $debug=1      if $opt_d;
   $showIMAP=1   if $opt_I;
   $admin_user   = $opt_A;
   $mailbox_map  = $opt_M;
   $msgs_per_folder = $opt_F;

   $timeout = 45 unless $timeout;
   $maxChildren = 1 unless $maxChildren;
   $hostname = `hostname`;

   foreach $map ( split(/\s*,\s*/, $mailbox_map ) ) {
      ($maildir_folder,$imap_mbx) = split(/:/, $map );
      $MAP{uc("$maildir_folder")} = $imap_mbx;
   }

   $logfile = "maildir_to_imap.log" unless $logfile;
   open (LOG, ">>$logfile");
   select LOG;
   $| = 1;
   Log("$0 starting");

   #  $date = ctime(time);
   #  chomp($date);

   #  Determine whether we have SSL support via openSSL and IO::Socket::SSL
   $ssl_installed = 1;
   eval 'use IO::Socket::SSL';
   if ( $@ ) {
      $ssl_installed = 0;
   }

}

sub usage {

   print "\nUsage:  maildir_to_imap.pl -i <users> -D imapHost\n\n";
   print "Optional arguments:\n\n";
   print " -i <file of usernames>\n";
   print "-A <admin_user:admin_password>\n";
   print " -n <number of simultaneous migration processes to run>\n";
   print " -m <list of mailboxes> eg Inbox,Drafts,Sent\n";
   print " -M <maildir_folder_name:IMAP_mailbox_name,...,maildir_folder_name:IMAP_mailbox_name>\n";
   print " -L <logfile, default is maildir_to_imap.log>\n";
   print " -t <timeout in seconds>\n";
   print " -d debug mode\n";
   print " -I record IMAP protocol exchanges\n\n";
   exit;

}


sub Log {

my $line = shift;

   if ( LOG ) {
      my @f = localtime( time );
      my $timestamp = sprintf( "%02d-%02d-%04d.%02d:%02d:%02d",
			 (1 + $f[ 4 ]), $f[ 3 ], (1900 + $f[ 5 ]),
			 @f[ 2,1,0 ] );
      printf LOG "%s %s: %s\n", $timestamp, $$, $line;
   }
   #  print STDERR "$line\n";
}

#  Make a connection to an IMAP host

sub format_bytes {

my $bytes = shift;

   #  Format the number nicely

   if ( length($bytes) >= 10 ) {
      $bytes = $bytes/1000000000;
      $tag = 'GB';
   } elsif ( length($bytes) >= 7 ) {
      $bytes = $bytes/1000000;
      $tag = 'MB';
   } else {
      $bytes = $bytes/1000;
      $tag = 'KB';
   }

   # commafy
   $_ = $bytes;
   1 while s/^([-+]?\d+)(\d{3})/$1,$2/;
   $bytes = sprintf("%.2f", $_) . " $tag";

   return $bytes;
}


sub commafy {

my $number = shift;

   $_ = $number;
   1 while s/^([-+]?\d+)(\d{3})/$1,$2/;
   $number = $_;

   return $number;
}

#  Reconnect to a server after a timeout error.
#
sub reconnect {

my $checkpoint = shift;
my $conn = shift;

   Log("This is reconnect, conn is $conn") if $debug;
   logout( $conn );
   close $conn;
   sleep 5;
   ($mbx,$shost,$suser,$spwd,$dhost,$duser,$dpwd) = split(/\|/, $checkpoint);
   if ( $conn eq $src ) {
      $host = $shost;
      $user = $suser;
      $pwd  = $spwd;
   } else { 
      $host = $dhost;
      $user = $duser;
      $pwd  = $dpwd;
   }
   connectToHost($host,$conn);
   login($user,$pwd,$conn);
   selectMbx( $mbx, $conn );
   createMbx( $mbx, $dst );   # Just in case
   Log("leaving reconnect");
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
}

#  Get the total message count and bytes and write
#  it to the log.  

sub summarize {

   #  Each child appends its totals to /tmp/migrateEmail.sum so
   #  we read the lines and add up the grand totals.

   $totalUsers=$totalMsgs=$totalBytes=0;
   open(SUM, "</tmp/migrateIMAP.sum");
   while ( <SUM> ) {
      chomp;
      ($msgs,$bytes) = split(/\|/, $_);
      $totalUsers++;
      $totalMsgs  += $msgs;
      $totalBytes += $bytes;
   }

   $_ = $totalMsgs;
   1 while s/^([-+]?\d+)(\d{3})/$1,$2/;  #  Commafy the message total
   $totalMsgs = $_;
   $totalBytes = formatBytes( $totalBytes );

   Log("Summary of migration");
   Log("Migrated $totalUsers users, $totalMsgs messages, $totalBytes.");

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

sub fix_ts {

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

sub stats {

   print "\n";
   print "Users migrated   $users\n";
   print "Total messages   $total_msgs\n";
   print "Total bytes      $total_bytes\n";

   $elapsed = time() - $start;
   $minutes = $elapsed/60;
   print "Elapsed time     $minutes minutes\n";

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


sub usage {

   print STDOUT "usage:\n";
   exit;

}

sub processArgs {

   if ( !getopts( "" ) ) {
      usage();
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

sub insert_msg {

my $msgfn   = shift;
my $folder  = shift;
my $dst     = shift;

   #  Put a message in the user's folder

   my $flag = 'Unseen';
   if ( $msgfn =~ /,/ ) {
      $flag = '\\Seen' if $msgfn =~ /,S$/;
   }

   if ( !open(MESSAGE, "<$msgfn")) {
      Log( "    Can't open message fn $msgfn: $!" );
      return 0;
   }
   my ($date,$message,$msgid);
   while( <MESSAGE> ) {
       chomp;
       # print STDERR "message line $_\n";
       if ( /^Date: (.+)/ and !$date ) {
          $date = $1;
       }
       if ( /^Message-Id: (.+)/i and !$msgid ) {
          $msgid = $1;
          Log("msgid $msgid") if $debug;
       }
       $message .= "$_\r\n";
   }
   close MESSAGE;

   fix_date( \$date );

   $status = insert_imap_msg( $dst, $folder, \$message, $flag, $date );

   return $status;

}

sub entry_exists {

my $mail  = shift;
my $ldap  = shift;
my $pwd   = shift;
my $dn;
my $i;

   my $attrs = [ 'mailpassword' ];
   my $base = 'o=site';
   my $filter = "mail=$mail";

   my $result = $ldap->search(
            base   => $base,
            filter => $filter,
            scope  => "subtree",
            attrs  => $attrs
   );

   if ( $result->code ) {
      my $error = $result->code;
      my $errtxt = ldap_error_name( $result->code );
      Log("Error searching for $filter: $errtxt");
      exit;
   }

   my @entries = $result->entries;
   my $i = $#entries + 1;

   $entry = $entries[0];
   $$pwd = $entry->get_value( 'mailpassword' );

   return $i;
}

sub get_user_list {

my $users    = shift;

   #  Build a list of the users and their maildirs

   open(F, "<$userlist") or die "Can't open user list $userlist: $!";
   while( <F> ) {
      chomp;
      s/^\s+//;
      next if /^#/;
      next unless $_;
      my( $maildir,$user,$pwd) = split(/,/, $_);
      push( @$users, "$user,$pwd,$maildir" );
   }
   close F;

}

#  Make a connection to an IMAP host

sub connectToHost {

my $host = shift;
my $conn = shift;

   Log("Connecting to $host");
   
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

#  login
#
#  login in at the IMAP host with the user's name and password
#
sub login {

my $user = shift;
my $pwd  = shift;
my $conn = shift;

   if ( $admin_user ) {
      #  Do an AUTH PLAIN login
      ($admin_user,$admin_pwd) = split(/:/, $admin_user);
      login_plain( $user, $admin_user, $admin_pwd, $conn ) or return 0;
      return 1;
   }

   if ( $pwd =~ /^oauth2---(.+)/i ) {
      $token = $1;
      Log("password is an OAUTH2 token");
      $status = login_xoauth2( $user, $token, $conn );
      return $status;
   }

   sendCommand ($conn, "1 LOGIN $user $pwd");
   while (1) {
	readResponse ( $conn );
	if ($response =~ /^1 OK/i) {
		last;
	}
	elsif ($response =~ /^1 NO|^1 BAD/) {
		Log ("$user login failed: unexpected LOGIN response: $response");
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

#
#  readResponse
#
#  This subroutine reads and formats an IMAP protocol response from an
#  IMAP server on a specified connection.
#

sub readResponse {

my $fd = shift;

   exit unless defined $fd;
   $response = <$fd>;
   chop $response;
   $response =~ s/\r//g;
   push (@response,$response);
   Log ("<< *** Connection timeout ***") if $conn_timed_out;
   Log ("<< $response") if $showIMAP;
}

#  sendCommand
#
#  This subroutine formats and sends an IMAP protocol command to an
#  IMAP server on a specified connection.
#
sub sendCommand {

local($fd) = shift @_;
local($cmd) = shift @_;

    print $fd "$cmd\r\n";
    Log (">> $cmd") if $showIMAP;
}

#
#  log out from the host
#
sub logout {

my $conn = shift;

   undef @response;
   sendCommand ($conn, "1 LOGOUT");
   while ( 1 ) {
        readResponse ($conn);
        next if $response =~ /APPEND complete/i;   # Ignore strays
        if ( $response =~ /^1 OK/i ) {
           last;
        } elsif ( $response !~ /^\*/ ) {
           Log("unexpected logout response $response");
           last;
        }
   }
   close $conn;
   return;
}

sub selectMbx {

my $mbx  = shift;
my $conn = shift;

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
   sendCommand ($conn, "1 SELECT \"$mbx\"");
   undef @response;
   $empty=0;
   while ( 1 ) {
        readResponse ( $conn );
        if ( $response =~ /^1 OK/i ) {
           # print STDERR "response $response\n";
           last;
        }
        elsif ( $response !~ /^\*/ ) {
           Log ("unexpected response: $response");
          return 0;
        }
   }

}

sub createMbx {

my $mbx = shift;
my $conn = shift;

   #  Create a mailbox


   sendCommand ($conn, "1 CREATE \"$mbx\"");
   while ( 1 ) {
      readResponse ($conn);
      last if $response =~ /^1 OK|already exists /i;
      if ( $response !~ /^\*/ ) {
         if (!($response =~ /already exists|reserved mailbox name/i)) {
            # Log ("WARNING: $response");
         }
         last;
      }
   }
}

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

   undef @mbxs;

   for $i (0 .. $#response) {
        $response[$i] =~ s/\s+/ /;
        if ( $response[$i] =~ /"$/ ) {
           $response[$i] =~ /\* LIST \((.*)\) "(.+)" "(.+)"/i;
           $mbx = $3;
        } else {
           $response[$i] =~ /\* LIST \((.*)\) "(.+)" (.+)/i;
           $mbx = $3;
        }
	$mbx =~ s/^\s+//;  $mbx =~ s/\s+$//;

	if ($response[$i] =~ /NOSELECT/i) {
		if ($debug) { Log("$mbx is set NOSELECT,skip it",2); }
		next;
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
my $seen;
my $empty;
my $msgnum;
my $from;
my $flags;

   @$msgs  = ();
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

   if ( $empty ) {
      Log("$mailbox is empty");
      return;
   }

   Log("Fetch the header info") if $debug;

   sendCommand ( $conn, "1 FETCH 1:* (uid flags internaldate body[header.fields (From Date)])");
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
	$seen=0;
	$_ = $response[$i];

	last if /OK FETCH complete/;

        if ($response[$i] =~ /FLAGS/) {
           #  Get the list of flags
           $response[$i] =~ /FLAGS \(([^\)]*)/;
           $flags = $1;
           $flags =~ s/\\Recent//;
        }

        if ( $response[$i] =~ /INTERNALDATE/) {
           $response[$i] =~ /INTERNALDATE (.+) BODY/;
           # $response[$i] =~ /INTERNALDATE "(.+)" BODY/;
           $date = $1;

           $date =~ /"(.+)"/;
           $date = $1;
           $date =~ s/"//g;
        }

        if ( $response[$i] =~ /\* (.+) FETCH/ ) {
           ($msgnum) = split(/\s+/, $1);
        }

        if ( $msgnum && $date ) {
           if ( $unseen ) {
	      push (@$msgs,"$msgnum|$date|$flags") unless $flags =~ /Seen/i;
           } else {
	      push (@$msgs,"$msgnum|$date|$flags");
           }
           $msgnum = $date = '';
        }
   }

}

#  insert_imap_msg
#
#  This routine inserts an RFC822 message into a user's folder
#
sub insert_imap_msg {

my $conn    = shift;
my $mbx     = shift;
my $message = shift;
my $flags   = shift;
my $date    = shift;
my ($lsn,$lenx);

   $lenx = length($$message);
   Log("   Inserting message") if $debug;
   Log("message size $lenx bytes") if $debug;

   $date =~ s/\((.+)\)//;
   $date =~ s/\s+$//g;

   $totalBytes = $totalBytes + $lenx;
   $totalMsgs++;

   #  Create the mailbox unless we have already done so
   # if ($destMbxs{"$mbx"} eq '') {
   #    createMbx( $mbx, $conn );
   # } 
   # $destMbxs{"$mbx"} = '1';

   $flags =~ s/\\Recent//i;
   $flags =~ s/Unseen//i;

   if ( $date ) {
      sendCommand ($conn, "1 APPEND \"$mbx\" ($flags) \"$date\" \{$lenx\}");
   } else {
      sendCommand ($conn, "1 APPEND \"$mbx\" ($flags) \{$lenx\}");
   }
   
   readResponse ($conn);
   if ($conn_timed_out) {
       Log ("unexpected response timeout appending message");
       push(@errors,"Error appending message to $mbx for $user");
       return 0;
   }
	
   if ( $response !~ /^\+/ ) {
       Log ("unexpected APPEND response: >$response<");
       # next;
       push(@errors,"Error appending message to $mbx for $user");
       return 0;
   }

   print $conn "$$message\r\n";

   undef @response;
   while ( 1 ) {
       readResponse ($conn);
       if ( $response =~ /^1 OK/i ) {
	   last;
       }
       elsif ( $response !~ /^\*/ ) {
	   Log ("Unexpected APPEND response: >$response<");
	   # next;
	   return 0;
       }
   }

   return 1;
}

sub mbxExists {

my $mbx  = shift;
my $conn = shift;
my $status = 1;

   #  Determine whether a mailbox exists
   sendCommand ($conn, "1 SELECT \"$mbx\"");
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

sub get_maildir_folders {

my $userpath = shift;
my $folders  = shift;

   #  Get a list of the user's folders 
   
   %$folders = ();

   if ( $mbxList ) {
      #  The user has supplied a list of mailboxes
      foreach $mbx ( split(/,/, $mbxList ) ) {
         $$folders{"$mbx"} = $userpath . '/.' . $mbx;
      }
      return;
   }

   opendir D, $userpath;
   my @files = readdir( D );
   closedir D;

   $$folders{'INBOX'} = $userpath;
   foreach $fn ( @files ) {
      next if $fn eq '.';
      next if $fn eq '..';
      next unless $fn =~ /^\./;
      my $fname = $fn;
      $fname =~ s/\./\//;
      $fname =~ s/^\///;
      $$folders{"$fname"} = "$userpath/$fn";
   }

}

sub get_maildir_msgs {

my $path = shift;
my $msgs = shift;
my @subdirs = qw( tmp cur new );

   @$msgs = ();
   foreach $subdir ( @subdirs ) {
      opendir D, "$path/$subdir";
      my @files = readdir( D );
      closedir D;

      foreach $fn ( @files ) {
         next if $fn =~ /^\./;
         my $msgfn = "$path/$subdir/$fn";
         push( @$msgs, $msgfn );
      }
   }

}

sub imap_message_exists {

my $msgid = shift;
my $conn  = shift;
my $msgnum;
my $loops;

   # Search a mailbox on the server for a message by its msgid.

   Log("   Search for $msgid") if $debug;
   sendCommand ( $conn, "1 SEARCH header Message-Id \"$msgid\"");
   while (1) {
        readResponse ($conn);
        if ( $response =~ /\* SEARCH /i ) {
           ($dmy, $msgnum) = split(/\* SEARCH /i, $response);
           ($msgnum) = split(/ /, $msgnum);
        }

        last if $response =~ /^1 OK|^1 NO|^1 BAD/;
        last if $response =~ /complete/i;

        last if $loops++ > 10;
   }

   if ( $debug ) {
      Log("$msgid was not found") unless $msgnum;
   }

   return $msgnum;
}

sub fix_date {

my $date = shift;

   #  Try to make the date acceptable to IMAP

   return if $$date eq '';
   fix_ts( $date );

   $$date =~ s/\((.+)\)$//;
   $$date =~ s/\s+$//g;

   if ( $$date =~ /\s*,\s*/ ) {
      ($dow,$$date) = split(/\s*,\s*/, $$date);
   }
   $$date =~ s/ /-/;
   $$date =~ s/ /-/;

   return;

   my @terms = split(/\s+/, $$date);

   if ( $terms[0] =~ /(.+),/ ) {
      my $dow = $1;
      if ( length( $dow ) > 3 ) {
         #  Day of week can't be more than 3 chars
         my $DOW = substr($dow,0,3);
         $$date =~ s/$dow/$DOW/;
      }
   } 

   if ( $terms[1] =~ /jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec/i ) {
      #  The month and day are swapped.
      my $temp = $terms[1];
      $terms[1] = $terms[2];
      $terms[2] = $temp;
   }

   if ( $terms[5] =~ /\((.+)\)/ ) {
      #  The date is missing the TZ offset
      $terms[5] = "+0000 ($1)";
   }

   if ( $terms[5] =~ /"(.+)"/ ) {
      #  The TZ code has quotes instead of parens
      $terms[5] =~ s/"/\(/;
      $terms[5] =~ s/"/\)/;
      $terms[5] = "+0000 $terms[5]";
   }

   if ( $terms[5] =~ /-[0-9]-[0-9][0-9]/ ) {
      #  Lots of dates are like '-0-500'
      $terms[5] =~ s/-//g;
      $terms[5] = '-' . $terms[5];
   }

   if ( $terms[5] eq '-0-100' ) {
      #  Don't know what this is supposed to mean
      $terms[5] = "+0000";
   }

   if ( $terms[5] eq '00800' ) {
      $terms[5] = "+0800";
   }

   if ( $terms[5] eq '-' ) {
      $terms[5] .= $terms[6];
      $terms[5] =~ s/\s+//g;
      $terms[6] = '';
   }
   if ( $terms[4] =~ /\./ ) {
      $terms[4] =~ s/\./:/g;
   }

   if ( $terms[5] =~ /[a-zA-Z]/ ) {
      $terms[5] = "-0000 ($terms[5])" unless $terms[5] eq 'UT';
   }

   $$date = join( " ", @terms );

}


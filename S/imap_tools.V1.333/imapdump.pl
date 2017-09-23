#!/usr/bin/perl

# $Header: /mhub4/sources/imap-tools/imapdump.pl,v 1.36 2015/03/05 20:09:28 rick Exp $

#######################################################################
#   Program name    imapdump.pl                                       #
#   Written by      Rick Sanders                                      #
#   Date            1/03/2008                                         #
#                                                                     #
#   Description                                                       #
#                                                                     #
#   imapdump.pl is a utility for extracting all of the mailboxes      #
#   and messages in an IMAP user's account.  When supplied with       # 
#   host/user/password information and the location of a directory    #
#   on the local system imapdump.pl will connect to the IMAP server,  #
#   extract each message from the user's account, and write it to     #
#   a file.  The result looks something like this:                    #
#                                                                     #
#     /var/backups/INBOX                                              #
#          1 2 3 4 5                                                  #
#     /var/backups/Drafts                                             #
#          1 2                                                        #
#     /var/backups/Notes/2002                                         #
#          1 2 3 4 5 6 7                                              #
#     /var/backups/Notes/2003                                         #
#          1 2 3                                                      #
#     etc etc                                                         #
#                                                                     #
#   imapdump.pl is called like this:                                  #
#      ./imapdump.pl -S host/user/password -f /var/backup             #
#                                                                     #
#   Optional arguments:                                               #
#	-d debug                                                      #
#       -I show IMAP protocol exchanges                               #
#       -L logfile                                                    #
#       -m mailbox list (dumps only the specified mailboxes, see      #
#                        the usage notes for syntax)                  #
#######################################################################

use Socket;
use IO::Socket;
use FileHandle;
use Fcntl;
use Getopt::Std;
use File::Path;
use MIME::Base64 qw(decode_base64 encode_base64);

#################################################################
#            Main program.                                      #
#################################################################

   init();

   if ( $users_file ) {
      @users = get_users( $users_file );
   } else {
      push( @users, $sourceUser );
   }

   my $pm = Parallel::ForkManager->new( $num_children ) if $num_children != -1;

   foreach $sourceUser ( @users ) {
      if ( $num_children == -1 ) {
         #  We're on Windows or the number of children has not been set
         dump_user( $sourceUser, $dir );
         next;
      }

      $pm->run_on_finish( sub {
      my($pid,$exit_code,$ident,$exit_signal,$core_dump,$var,$v)=@_;
         ($copied,$mbx) = split(/,/, ${$var});
         $total += $copied;
         push( @summary, "Copied $copied messages from $mbx");
      });

      $pm->start and next;

      #  This is the child process, backing up $sourceUser");

      dump_user( $sourceUser, $dir );
      exit;
   }

   $pm->wait_all_children if $num_children != -1;

   Log("Done");

   exit;

sub dump_user {

my $sourceUser = shift;
my $dir        = shift;
my %DUMPED;

   ($user) = split(/:/, $sourceUser);
   Log("Dumping messages for $user");
   mkdir( "$dir/$user", 0777 ) unless -d "$dir/$user";
   if ( $no_dups ) {
      #  The user wants to make sure we only dump messages which
      #  have not been dumped before.  Use a dbm file to keep
      #  track of previously dumped messages.
      Log("Running in no-duplicates mode");

      if ( !$dbm_dir ) {
         $dbm_dir = $dir;
      }
      $dbm = $dbm_dir . '/' . $user . '/dumped';
      unless( dbmopen(%DUMPED, $dbm, 0600) ) {
        Log("Can't open $dbm: $!\n");
        exit unless $debug;
      } else {
        Log("Opened dbm file $dbm");
      }

      if ( $debug ) {
         Log("Messages previously dumped");
         while(($x,$y) = each( %DUMPED ) ) {
             Log("   $x");
         }
      }
   }

   #  Get list of all messages on the source host by Message-Id
   #
   connectToHost($sourceHost, \$conn);

   if ( $extract_attachments ) {
      $workdir = $dir . "/work";
      mkdir( $workdir, 0777 ) unless -d $workdir;
   }

   login( $sourceUser, $sourcePwd, $conn );

   @mbxs = getMailboxList($sourceUser, $conn);

   #  Exclude certain mbxs if that's what the user wants
   if ( $excludeMbxs or $excludeMbxs_regex ) {
      exclude_mbxs( \@mbxs );
   }

   $added=0;
   foreach $mbx ( @mbxs ) {
        Log("Dumping messages in $mbx mailbox") if $dump_flags;
        my @msgs;

        if ( $sent_after ) {
           getDatedMsgList( $mbx, $sent_after, \@msgs, $conn, 'EXAMINE' );
        } else {
           getMsgList( $mbx, \@msgs, $conn, 'EXAMINE' );
        }

        if ( $update ) {
           #  Get a list of the messages in the dump directory by msgid           
           Log("Reading $dir/$user/$mbx");
           $count = get_msgids( "$dir/$user/$mbx", \%MSGIDS );
           Log("There are $count messages in $dir/$user/$mbx");
        }

        my $i = $#msgs + 1;
        Log("$mbx has $i messages");
        my $msgnums;
        $updated = $flags_updated = $added = 0;

        foreach $msgnum ( @msgs ) {
             $fn = '';
             ($msgnum,$date,$flags,$msgid) = split(/\|/, $msgnum);
             ($fn,$oldflags) = split(/\|/, $MSGIDS{"$msgid"} );
             if ( $no_dups ) {
                #  If the user wants no duplicates and we have already
                #  dumped this message then skip it.
                if ( $DUMPED{"$msgid"} ) {
                   Log("   $msgid has already been dumped") if $debug;
                   next;
                } else {
                   Log("   Dumping msgnum $msgnum - $msgid") if $debug;
                }
             } elsif ( $update and $sync_flags and $fn ) {
                summarize_flags( \$flags );
                # ($fn,$oldflags) = split(/\|/, $MSGIDS{"$msgid"} );
                if ( $oldflags ne $flags ) {
                   Log("$fn: The flags have changed: new=$flags   old=$oldflags");
                   ($newfn) = split(/,/, $fn);
                   $newfn .=  ',' . $flags;
                   $rc = rename( $fn, $newfn );
                   $flags_updated++;
                   next;
                }  else {
                   next;
                }
             } elsif ( $update ) {
                #  Don't dump the message if it already exists in the dump directory
                if ( $MSGIDS{"$msgid"} ) {
                   Log("   $msgid exists in the dump directory") if $debug;
                   next;
                } else {
                   Log("   Dumping msgnum $msgnum  --- $msgid");
                   $updated++;
                }
             }

             $message = fetchMsg( $msgnum, $mbx, $conn );
             mkpath( "$dir/$user/$mbx" ) if !-d "$dir/$user/$mbx";
             $msgfile = $msgnum;

             if ( $update ) {
                #  Make sure filename is unique
                $msgfile = unique( $msgfile, "$dir/$user/$mbx" );
             }
              
             $msgfile .= $extension if $extension;

             if ( $include_all_flags ) {
                summarize_flags( \$flags);
                $msgfile .= ",$flags" if $flags;
             } elsif ( $include_flag and $flags =~ /Seen/i ) {
                $msgfile .= ',S';
             }

             if ( !open (M, ">$dir/$user/$mbx/$msgfile") ) {
                Log("Error opening $dir/$user/$mbx/$msgfile: $!");
                next;
             }
             Log("   Copying message $msgnum") if $debug;
             print M $message;
             close M;
             $added++;

             if ( $no_dups ) {
                #  Flag it as dumped
                $DUMPED{"$msgid"} = 1;
             }

             if ( $extract_attachments ) {
                extract_attachments( $msgfile, "$dir/$user/$mbx", $workdir );
             }
 
             $msgnums .= "$msgnum ";
        }
        if ( $sync_flags and $update ) {
           Log("Flags updated $flags_updated messages in $mbx");
        }
        Log("Dumped $added messages in $mbx") if $added;

        if ( $remove_msgs ) {
           selectMbx( $mbx, $conn );
           deleteMsg( $conn, $msgnums, $mbx ) if $remove_msgs; 
           expungeMbx( $conn, $mbx )          if $remove_msgs;
        }
   }

   logout( $conn );
   Log("$added total messages dumped");

   #  Remove the workdir
   rmdir $workdir;
}


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

   if ( $extract_attachments ) {
      eval 'use MIME::Parser';
      if ( $@ ) {
         Log("The Perl module MIME::Parser must be installed to extract attachments.");
         exit;
      }

      Log("Attachments will be extracted");
      $workdir = $dir . '/work' if $extract_attachments;
      mkdir( $workdir, 0777 ) unless -d $workdir;
   }

   if ( $num_children and $OS =~ /Windows/i ) {
         Log("Multi-process mode is not supported on Windows");
         $num_children = -1;
   } elsif ( $num_children > 0 ) {
      eval 'use Parallel::ForkManager';
      if ( $@ ) {
         Log("In order to run multiple copy processes you must install the Parallel::ForkManager Perl module.");
         exit;
      }
      Log("Running in parallel mode, number of children = $num_children");
   } else {
      $num_children = -1;
   }

   Log("Running in Update mode") if $update;
   Log("Running in no-duplicates mode") if $no_dups;
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

sub imap_login {

   # Not used

   if ( $sourceUser =~ /(.+):(.+)/ ) {
      #  An AUTHENTICATE = PLAIN login has been requested
      my $sourceUser  = $1;
      my $authuser    = $2;
      login_plain( $sourceUser, $authuser, $sourcePwd, $conn ) or exit;
   } else {
       if ( !login($sourceUser,$sourcePwd, $conn) ) {
          Log("Check your username and password");
          print STDOUT "Login failed: Check your username and password\n";
          exit;
       }
   }

}

#  login
#
#  login in at the source host with the user's name and password
#
sub login {

my $user = shift;
my $pwd  = shift;
my $conn = shift;

   if ( $user =~ /:/ ) {
      ($user,$pwd) = split(/:/, $user);
   }

   if ( $admin_user ) {
      ($auth_user,$auth_pwd) = split(/:/, $admin_user);
      login_plain( $user, $auth_user, $auth_pwd, $conn ) or exit;
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
my $mode    = shift;
my $seen;
my $empty;
my $msgnum;
my $from;
my $flags;
my $msgid;

   $mode = 'EXAMINE' unless $mode;
   sendCommand ($conn, "1 $mode \"$mailbox\"");
   undef @response;
   $empty=0;
   $loops=0;
   while ( 1 ) {
	readResponse ( $conn );

        if ( $loops++ > 99 ) {
           Log("The IMAP server stopped responding");
           exit;
        }

	if ( $response =~ / 0 EXISTS/i ) { $empty=1; }
	if ( $response =~ /^1 OK/i ) {
		last;
	}
	elsif ( $response !~ /^\*/ ) {
		Log ("unexpected response: $response");
		return 0;
	}
   }

   if ( $opt_R ) {
      #  Fetch this many messages (for testing)
      $end = $opt_R;
   } else {
      $end = '*';
   }

   sendCommand ( $conn, "1 FETCH 1:$end (uid flags internaldate body[header.fields (From Date Message-Id Subject)])");
   
   undef @response;
   $no_response=0;
   while ( 1 ) {
	readResponse ( $conn );
        check_response();

	if ( $response =~ /^1 OK/i ) {
		last;
	} 
        last if $response =~ /^1 NO|^1 BAD|^\* BYE/;
   }

   @msgs  = ();
   $flags = '';
   for $i (0 .. $#response) {
	last if $response[$i] =~ /^1 OK FETCH complete/i;

        if ($response[$i] =~ /FLAGS/) {
           #  Get the list of flags
           $response[$i] =~ /FLAGS \(([^\)]*)/;
           $flags = $1;
           $flags =~ s/\\Recent//;
        }

        if ( $response[$i] =~ /Message-Id: (.+)/i ) {
           $msgid = $1;
        }

        if ( $response[$i] =~ /INTERNALDATE/) {
           $response[$i] =~ /INTERNALDATE (.+) BODY/i;
           # $response[$i] =~ /INTERNALDATE "(.+)" BODY/;
           $date = $1;
           
           $date =~ /"(.+)"/;
           $date = $1;
           $date =~ s/"//g;
        }
        if ( $response[$i] =~ /^From:\s*(.+)/i) {
           $from = $1 unless $from;
        }
        if ( $response[$i] =~ /^Date:\s*(.+)/i) {
           $header_date = $1 unless $header_date;
        }

        if ( $response[$i] =~ /^Subject: (.+)/i) {
           $subject = $1 unless $subject;
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
              if ( !$subject and !$from and !$subject ) {
                 Log("   message has no from/subject/date fields. Can't build dummy msgid");
              } else {
                 $msgid = "$header_date$subject$from";
                 $msgid =~ s/\s+//g;
                 $msgid =~ s/\+|\<|\>|\?|\*|"|'|\(|\)|\@|\.//g;
                 Log("   msgnum $msgnum has no msgid, built one as $msgid");
              }
           }
	   push (@$msgs,"$msgnum|$date|$flags|$msgid");
           $msgnum = $date = $flags = $msgid = '';
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
my ($seen, $empty, @list,$msgid);

    #  Get a list of messages sent after the specified date

    Log("Searching for messages after $cutoff_date");

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
    #  Get list of messages sent after the reference date
    #
    Log("Get messages sent after $date") if $debug;
    $nums = "";
    $no_response=0;
    sendCommand ($conn, "1 SEARCH SINCE \"$date\"");
    while ( 1 ) {
	readResponse ($conn);
        check_response();
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
    Log("there are $n messages after $sent_after");

@$msgs  = ();
$no_response=0;
for $num (@msgList) {

     sendCommand ( $conn, "1 FETCH $num (uid flags internaldate body[header.fields (Message-Id Date)])");
     
     undef @response;
     while ( 1 ) {
	readResponse   ( $conn );
        check_response();
	if   ( $response =~ /^1 OK/i ) {
		last;
	}   
        last if $response =~ /^1 NO|^1 BAD|^\* BYE/;
     }

     $flags = '';
     my $msgid;
     foreach $_ ( @response ) {
	last   if /^1 OK FETCH complete/i;
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

          if ( /\* (.+) FETCH/ ) {
             ($msgnum) = split(/\s+/, $1);
          }

          if ( /^\)/ or /\)\)$/ ) {
             push (@$msgs,"$msgnum|$date|$flags|$msgid");
             $msgnum=$msgid=$date=$flags='';
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

   $no_response=0;
   sendCommand( $conn, "1 FETCH $msgnum (rfc822)");
   while (1) {
	readResponse ($conn);
        check_response();
   
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
   print STDOUT " imapdump.pl -S Host/User/Password -f <dir>\n";
   print STDOUT " <dir> is the file directory to write the message structure\n";
   print STDOUT " Optional arguments:\n";
   print STDOUT "          -F <flags>  (eg dump only messages with specified flags\n";
   print STDOUT "          -l <file of users>\n";
   print STDOUT "          -d debug\n";
   print STDOUT "          -x <extension>  File extension for dumped messages\n";
   print STDOUT "          -g  Dump message attachments as separate files\n";
   print STDOUT "          -G  Dump only message attachments not complete message or header (Used with -g)\n";
   print STDOUT "          -r remove messages after dumping them\n";
   print STDOUT "          -L logfile\n";
   print STDOUT "          -m mailbox list (eg \"Inbox, Drafts, Notes\". Default is all mailboxes)\n";
   print STDOUT "          -a <DD-MMM-YYYY> copy only messages after this date\n";
   print STDOUT "          -e exclude mailbox list (using exact matches)\n";
   print STDOUT "          -E exclude mailbox list (using regular expressions)\n";
   print STDOUT "          [-s] Include Seen/Unseen status in message filename (2454,S or 2454,U\n";
   print STDOUT "          [-z] Include all status flags in message filename (2454,DSF or 2454,SA\n";
   print STDOUT "          [-C] Include custom (nonstandard) flags in message filename, eg $SPECIAL$\n";
   print STDOUT "          [-u] Don't dump messages already dumped\n";
   print STDOUT "          [-D <dbm directory] Directory to put dbm file, used with -u argument\n";
   print STDOUT "          [-U] Don't dump message if it already exists in the dump directory\n";
   exit;

}

sub processArgs {

   if ( !getopts( "dS:L:m:hf:F:Ix:ra:uD:Ue:E:A:sgR:l:n:GZwzC" ) ) {
      usage();
   }

   if ( $opt_S =~ /\\/ ) {
      @backslashes = split(/\\/, $opt_S);
      $num_backslashes = scalar @backslashes;
      if ( $num_backslashes == 2 ) {
         ($sourceHost, $sourceUser, $sourcePwd) = split(/\//, $opt_S);
      } else {
         ($sourceHost, $sourceUser, $sourcePwd) = split(/\\/, $opt_S);
      }
   } else {
      ($sourceHost, $sourceUser, $sourcePwd) = split(/\//, $opt_S);
   }

   $mbxList      = $opt_m;
   $logfile      = $opt_L;
   $dir          = $opt_f;
   $extension    = $opt_x;
   $dump_flags   = $opt_F;
   $users_file   = $opt_l;
   $num_children = $opt_n;
   $remove_msgs  = 1 if $opt_r;
   $debug    = 1 if $opt_d;
   $showIMAP = 1 if $opt_I;
   $no_dups  = 1 if $opt_u;
   $update   = 1 if $opt_U;
   $extract_attachments = 1 if $opt_g;
   $extract_only_attachments = 1 if $opt_G;
   $sent_after = $opt_a;
   $dbm_dir    = $opt_D;
   $excludeMbxs       = $opt_e;
   $excludeMbxs_regex = $opt_E;
   $admin_user        = $opt_A;
   $include_flag      = $opt_s;
   $sync_flags        = $opt_w;
   $include_custom_flags = 1 if $opt_C;

   if ( !$dir ) {
      print "You must specify the file directory where messages will\n";
      print "be written using the -f argument.\n\n";
      usage();
      exit;
   }

   validate_date( $sent_after ) if $sent_after;

   mkpath( "$dir" ) if !-d "$dir";

   if ( !-d $dir ) {
      print "Fatal Error: $dir does not exist\n";
      exit;
   }

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

sub findMsg {

my $conn  = shift;
my $msgid = shift;
my $mbx   = shift;
my $msgnum;

   Log("EXAMINE $mbx") if $debug;
   sendCommand ( $conn, "1 EXAMINE \"$mbx\"");
   while (1) {
	readResponse ($conn);
	last if $response =~ /^1 OK/;
   }

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

   return $msgnum;
}

sub deleteMsg {

my $conn    = shift;
my $msgnums = shift;
my $mbx     = shift;
my $rc;

   $msgnums =~ s/\s+$//;

   foreach my $msgnum ( split(/\s+/, $msgnums) ) {
      sendCommand ( $conn, "1 STORE $msgnum +FLAGS (\\Deleted)");
      while (1) {
        readResponse ($conn);
        if ( $response =~ /^1 OK/i ) {
	   $rc = 1;
	   Log("   Marked msgnum $msgnum for delete");
	   last;
	}

	if ( $response =~ /^1 BAD|^1 NO/i ) {
	   Log("Error setting \\Deleted flag for msg $msgnum: $response");
	   $rc = 0;
	   last;
	}
      }
   }

   return $rc;
}


sub expungeMbx {

my $conn  = shift;
my $mbx   = shift;

   Log("SELECT $mbx") if $debug;
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

	if ( $response =~ /^1 BAD|^1 NO/i ) {
	   print "Error expunging messages: $response\n";
	   last;
	}
   }

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
}

sub get_msgids {

my $dir = shift;
my $msgids = shift;
my $i;
my $progress = 100;
my $count = 0;
my $msgid;

   #  Build a list of the messageIDs for the messages in the requested directory

   %$msgids = ();

   return 0 if !-e $dir;   # No such directory

   if ( !opendir D, $dir ) {
      Log("Error opening $dir: $!");
      return 0;
   }
   my @files = readdir( D );
   closedir D;

   $count = scalar @files;
   $count = $count - 2;

   foreach $_ ( @files ) {
      next if /^\./;
      $fn = "$dir/$_";
      next if -d $fn;   #  Skip directories
      $i++;
      Log("fn $fn") if $debug;
      ($filename,$flags) = split(/,/, $fn);
      if ( !open(MSG, "<$fn" ) ) {
         Log("Error opening $fn: $!");
         next;
      }
      $msgid = '';
      while( <MSG> ) {
         chomp;
         s/\r$|\m$//g;
         if (/^Subject:\s+(.+)/i ) {
            $subject = $1 unless $subject;
         }
         if (/^From:\s+(.+)/i ) {
            $from = $1 unless $from;
         }
         if (/^Date:\s+(.+)/i ) {
            $header_date = $1 unless $header_date;
         }

         if (/^Message-ID:\s+(.+)/i ) {
            $msgid =~ s/\+|\<|\>|\?|\*|"|'|\(|\)|\@|\.//g;
            $$msgids{"$1"} = "$fn|$flags";
            $msgid = 1;
            if ( !$msgid ) {
               #  Wrapped to next line
               chomp( $msgid = <MSG> );
               $msgid =~ s/\r$|\m$//g;
            }
         }
         last if $_ eq '';     # End of header
     }
     close MSG;

     if ( !$msgid ) {
        #  The message lacks a message-id so construct one.
        $header_date =~ s/\W//g;
        $subject =~ s/\W//g;
        $msgid = "$header_date$subject$from";
        $msgid =~ s/\s+//g;
        $msgid =~ s/\+|\<|\>|\?|\*|"|'|\(|\)|\@|\.//g;
        Log("msgnum $msgnum has no msgid, built one as $msgid") if $debug;
Log("$msgid");
        $$msgids{"$msgid"} = "$fn|$flags";
     }

     if ( $i/$progress == int($i/$progress) ) { Log("   $i messages read so far"); }
   }

   return $count;
}

sub unique {

my $fn  = shift;
my $dir = shift;
my @letters = qw( a b c d e f g h i j k l m n o p q r s t u v w x y z );

   #  Generate a filename which is unique in the directory

   return $fn if !-e "$dir/$fn";

   #  A file with this name exists.

   my $new;
   foreach $letter ( @letters ) {
      $new = $fn . $letter;
      last if !-e "$dir/$new";
   }

   return $new;

}

#  exclude_mbxs
#
#  Exclude certain mailboxes from the list if the user has provided an
#  exclude list of complete mailbox names with the -e argument.  He may 
#  also supply a list of regular expressions with the -E argument
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

sub selectMbx {

my $mbx = shift;
my $conn = shift;

   #  select the mailbox
   sendCommand( $conn, "1 SELECT \"$mbx\"");
   while ( 1 ) {
      readResponse( $conn );
      if ( $response =~ /^1 OK/i ) {
         last;
      } elsif ( $response =~ /^1 NO|^1 BAD|^\* BYE/i ) {
         Log("Unexpected response to SELECT $mbx command: $response");
         last;
      }
   }

}

sub reconnect {

   #  The IMAP server has dropped our session or stopped responding for some reason.
   #  Re-establish the session and continue if we can

   $number_of_reconnects++;
   if ( $number_of_reconnects > 25 ) {
      #  That's enough.  Declare a fatal error and give up.
      Log("FATAL ERROR:  Number of reconnects exceeded 25.  Exiting.");
      exit;
   }

   Log("Reconnecting...");
   sleep 30;

   connectToHost($sourceHost, \$conn);
   login();
   selectMbx( $mbx, $conn );

   #  We now return you to the previously scheduled programming already in progress
}

sub check_response {

   #  If the server has stopped responding call the reconnect() routine

   if ( $response eq '' ) {
      $no_response++;
   } else {
      $no_response = 0;
   }

   if ( $no_response > 99 ) {
      Log("The IMAP server has stopped responding");
      reconnect();
   }

}

sub extract_attachments {

my $msgfn   = shift;
my $dir     = shift;
my $workdir = shift;

   #  Extract all attachments 

   Log("msgfn $msgfn") if $debug;

   $msgfn = $dir . '/' . $msgfn;

   #  Get the message header and write it out to a file
   open(H, "<$msgfn");
   $header = '';
   while( <H> ) {
       chomp;
       $header .= "$_\n";
       last if length( $_ ) == 1;    # end of the header
   }
   close H;

   unless( $extract_only_attachments ) {
      #  Write the header to a file unless the user only wants attachments
      my $header_fn = "$msgfn" . ".header";
      open(H, ">$header_fn");
      print H "$header\n";
      close H;
   }

   parseMsg( $msgfn, $dir, $workdir );

   if ( $extract_only_attachments ) {
      #  The user wants the attachments but not the complete file or 
      #  the header file
      unlink $msgfn;
   }

}

sub parseMsg {

my $msgfn   = shift;
my $dir     = shift;
my $workdir = shift;

   #  This routine dumps the message parts to files and returns
   #  the filenames 

   #  Remove any existing files from the workdir
   opendir D, $workdir;
   my @files = readdir( D );
   closedir D;
   foreach $_ ( @files ) {
      next if /^\./;
      $fn = "$workdir/$_";
      unlink $fn if -e $fn;
   }

   my @terms = split(/\//, $msgfn );
   my $prefix = $terms[$#terms];
   Log("prefix $prefix") if $debug;

   my $parser = new MIME::Parser;

   $parser->extract_nested_messages(0);    
   $parser->output_dir( $workdir );

   # Read the MIME message and parse it.
   $entity = $parser->parse_open( $msgfn );
   $entity = $parser->parse_data( $msgfn );

   save_attachments( $dir, $workdir, $prefix );
}

sub save_attachments {

my $dir     = shift;
my $workdir = shift;
my $prefix  = shift;

   #  Apply the prefix to attachment names and move the attachments into
   #  the dump directory

   opendir D, $workdir;
   my @files = readdir( D );
   closedir D;
   my $i = 0;
   foreach $_ ( @files ) {
      next if /^\./;
      $i++;
      $filename = $_;
      if ( $filename =~ /msg-(.+)-(.+).txt/ ) {
         #  Unnamed attachment is given a random name by the parser.
         #  Rename it so we don't get dups each time we run
         $old = "$workdir/$filename";
         $new = "$workdir/attachment" . '-' . "$i.txt";
         $rc = rename( $old, $new );
         $old = $workdir . '/' . $msg . 'attachment-' . $i . ".txt";
         $new = "$dir/$prefix." . 'attachment-' . $i . ".txt";
      } else {
         $old = "$workdir/$_";
         $new = "$dir/$prefix.$_";
         $i--;
      }

      #  Move it into the dump directory
      $rc = rename( $old, $new );

      if ( !$rc ) {
         Log("Error moving $old to $new:  $!");
      }
      unlink $old if -e $old;
   }

}

sub get_users {

my $dir = shift;

   #  Build the list of users to be backed up from the users_list file

   if ( !-e $users_file ) {
      print "$users_file does not exist\n";
      exit;
   }
   if ( !open(U, "<$users_file" ) ) {
      print "Can't open $users_file: $!\n";
      exit;
   }

   while( <U> ){
      chomp;
      s/^\s+//g;
      next if /^#/;
      push( @users, $_ );
   }
   close U;

   return @users;

}

sub create_user_dir {

my $user = shift;
my $status = 1;

   #  Create a subdirectory this user's messages

   print STDOUT "user $user\n";
   print STDOUT "dir  $dir\n";

   mkdir ( "$dir/$user", 0644 );

   unless ( -d "$dir/$user" ) {
      Log("Unable to create $dir/$user: $!");
      return 0;
   }

   return $status;
}

sub summarize_flags {

my $flags = shift;

   #  Turn a list of IMAP flags into a list of single character flags

   my $FLAGS = $$flags;
   $$flags = '';
   foreach $_ ( split(/\s+/, $FLAGS ) ) {
      s/DRAFT/draft/i;
      if ( /^\\/ ) {
         Log("standard flag $_") if $debug;
         $$flags .= substr($_,1,1);
      } elsif ( /^\$/ ) {
         Log("custom flag $_") if $debug;
         $$flags .= $_ . '$' if $include_custom_flags;
      }
   }
   Log("flags $$flags") if $debug;

}

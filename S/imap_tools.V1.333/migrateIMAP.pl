#!/usr/bin/perl

# $Header: /mhub4/sources/imap-tools/migrateIMAP.pl,v 1.65 2015/06/24 13:38:39 rick Exp $

#*************************************************************************
#                                                                        *
#   Program name    migrateIMAP                                          *
#   Written by      Rick Sanders                                         *
#   Date            6 May 2008                                           * 
#                                                                        * 
#   Description                                                          *
#                                                                        *
#   This script is used to migrate the e-mail on one IMAP Server         *
#   another.  Each users's messages are copied from the "source"         *
#   server to the "destination" server using the IMAP protocol. You      *
#   supply a file with the user's names & passwords.  For example:       *
#                                                                        *
#   ./migrateIMAP.pl -S source -D destination -i <users file>            *
#                                                                        *
#   Use the -h argument to see the complete list of arguments.           *
#*************************************************************************

init();

#  Get the list of usernames and passwords

@users = getUserList( $userlist );

$i=$totalUsers=$children=0;
for ($index = 0; $index <= $#users; $index++) {
  $userinfo = $users[$index];
  $userinfo =~ s/oauth2:/oauth2---/g;

  ($user) = split(/\s*:\s*/, $userinfo);
  Log("user $user");

  #  Start the migration.  Unless maxChildren has been set to 1
  #  fork off child processes to do the migration in parallel.
 
  if ($maxChildren == 1) {
	migrate ($userinfo);
  } else {
  	Log("There are $children running") if $debug;
  	if ( $children < $maxChildren ) {
   	   Log("   Forking to migrate $user");
     	   if ( $pid = fork ) {	# Parent
	      Log ("   Parent $$ forked $pid");
     	   } elsif (defined $pid) {	# Child
	      Log ("  Child process $$ processing $sourceUser");
              migrate($userinfo);
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
     	   Log(" $$ - Max children running.  Waiting...");
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

summarize();
$elapsed = sprintf("%.2f", (time()-$start)/3600);
Log("Elapsed time  $elapsed hours");
Log("Migration completed");
exit;

sub migrate {
  
my $user = shift;
my $mbxs_created = 0;

  ($sourceUser,$sourcePwd,$destUser,$destPwd) = split(/\s*:\s*/, $user); 
  $userinfo = $user;

   Log("Starting migration of $sourceUser");
   if ( $debug ) {
      Log( "   sourceUser      $sourceUser");
      Log( "   destUser        $destUser");
      Log( "   sourcePwd       $sourcePwd");
      Log( "   destPwd         $destPwd");
      Log( "   src_admin_user  $src_admin_user");
      Log( "   dst_admin_user  $dst_admin_user");
   }

   $conn_timed_out=0;
   return 0 unless connectToHost($sourceHost, \$src);
   return 0 unless login_source( $user, $src );

   return 0 unless connectToHost($destHost, \$dst);
   return 0 unless login_dest( $user, $dst );

   namespace( $src, \$srcPrefix, \$srcDelim, $opt_x );
   namespace( $dst, \$dstPrefix, \$dstDelim, $opt_y );

   $totalUsers++;
   @mbxs = getMailboxList($sourceUser, $src);
   getMailboxes( \%DST_MBXS, $dst );

   #  Exclude certain mbxs if that's what the user wants
   if ( $excludeMbxs ) {
      exclude_mbxs( \@mbxs );
   }

   $longest_name = mailbox_names( \@mbxs );

   map_mbx_names( \%mbx_map, $srcDelim, $dstDelim );

   $total = 0;
   foreach $mbx ( @mbxs ) {
      $dstmbx = mailboxName( $mbx,$srcPrefix,$srcDelim,$dstPrefix,$dstDelim );
      $checkpoint = "$mbx|$sourceHost|$sourceUser|$sourcePwd|";
      $checkpoint .= "$destHost|$destUser|$destPwd";
   
      createMbx( $dstmbx, $dst ) if !$DST_MBXS{"$dstmbx"};

      #  Mbxs marked NOSELECT don't hold any messages so after creating them
      #  we don't need to do anything else.
      next if $nosel_mbxs{"$mbx"};

      get_supported_flags( $dstmbx, $dst, \%SUPPORTED_FLAGS );

      if ( $sent_after or $sent_before ) {
         getDatedMsgList( $mbx, $sent_before, $sent_after, \@msgs, $src );
      } else {
         getMsgList( $mbx, \@msgs, $src );
      }

      if ( $debug ) {
         $n = $#msgs + 1;
         Log("    $mbx has $n messages");
         foreach $m ( @msgs ) { Log("$m"); }
      }

      if ( $#msgs == -1 ) {
         #  Create an empty mailbox
         $line = pack("A$longest_name A13 A18", $mbx, '', "(0 messages)");
         Log("    Copied $line");
         next;
      }

      if ( $update ) {

         #  Get a list of messages on the dest.  Use the message id
         #  as the key unless the user has specified MD5 hashes
         #  so we can avoid copying ones already on the dest

         %DST_MSGS = %SRC_MGS = ();
         if ( $md5_hash ) {
            Log("Using md5 hash of msg body as the key") if $debug;
            getMsgList( $mbx, \@dstmsgs, $dst );
            foreach $msg ( @dstmsgs ) {
               ($msgnum,$msgid,$subject,$date) = split(/\|/, $msg);
               fetch_msg_body( $msgnum, $dst, \$message );
               $key = hash( \$message );
               Log("   msgnum:$msgnum hash $key") if $debug;
               $DST_MSGS{"$key"} = 1;
            }
         } else {
            getMsgIdList( $dstmbx, \%DST_MSGS, $dst );
         }
      }

      $added=0;
      selectMbx( $dstmbx, 'SELECT', $dst );

      my $msgcount = scalar @msgs;
      my ($u) = split(/:/, $sourceUser);
      Log("$u: There are $msgcount messages in the $mbx folder to be migrated");

      foreach $_ ( @msgs ) {
         ($msgnum,$date,$flags,$msgid,$header_date) = split(/\|/, $_);
         $flags = validate_flags( $flags, \%SUPPORTED_FLAGS );
 
         if ( $update ) {
            #  If we are in 'update' mode then don't copy 
            #  a message if it already exists on the dest
            if ( $md5_hash ) {
               #  Use the md5 hash
               fetch_msg_body( $msgnum, $src, \$message );
               $key = hash( \$message );
               next if $DST_MSGS{"$key"};
            } else {
               #  Use the msgid
               if ( $DST_MSGS{"$msgid"} ) {
                  # Msg is already on the destinatoin
                  Log("    $msgid is already on the destination") if $debug;
                  next;
               } 
            }
         }

         alarm $timeout;
         fetchMsg( $msgnum, $mbx, \$message, $src );
         alarm 0;

         $size = length( $message );

         if ( $copy_this_size_only ) {
            if ( $size == $copy_this_size_only ) {
               Log("COPYING MSGNUM $msgnum TO THE DESTINATION");
           } else {
               Log("SKIPPING MSGNUM $msgnum");
               next;
           }
         }

         my $mb = $size/1000000;
         if ( $max_size and $mb > $max_size ) {
            commafy( \$size );
            Log("   Skipping message $msgnum because its size ($size) exceeds the $max_size MB limit");
            next;
         }

         if ( $throttle ) {
            #  Gmail is throttling us.  Sleep a bit to lower our access rate
            Log("Gmail is throttling our connection.  Sleeping for 30 seconds");
            sleep 30;
            $throttle = 0;
         }

         next if length( $message ) == 0;

         if ( $conn_timed_out ) {
            Log("source host $srcHost timed out");
            reconnect( $checkpoint, $src );
            $conn_timed_out = 0;
            next;
         }

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

         insertMsg( $dst, $dstmbx, *message, $flags, $date );
         if ( $conn_timed_out ) {
            Log("destination host $destHost timed out");
            reconnect( $checkpoint, $dst );
            $conn_timed_out = 0;
            next;
         }
         $added++;

         if ( $msgs_per_folder ) {
            #  opt_F allows us to limit number of messages copied per folder
            last if $added == $msgs_per_folder;
         }
      }
      $total += $added;
      $line = pack("A$longest_name A13 A18", $mbx, '', "($added messages)");
      Log("    Copied $line");

      if ( $update and $del_from_dest ) {
         %DST_MSGS = %SRC_MGS = ();
         Log("Get msgids on the destination") if $debug;
         selectMbx( $dstmbx, 'SELECT', $dst );
         getMsgIdList( $dstmbx, \%DST_MSGS, $dst );

         selectMbx( $mbx, 'EXAMINE', $src );
         Log("Get msgids on the source") if $debug;
         getMsgIdList( $mbx, \%SRC_MSGS, $src );

         my $dst_count = keys %DST_MSGS;
         my $src_count = keys %SRC_MSGS;
         $s = keys %SRC_MSGS;
         $d = keys %DST_MSGS;
         Log("There are $s msgs on the src and $d on the dest for $dstmbx") if $debug;
         Log("Remove msgs from the destination which aren't on the source") if $debug;

         $expunge = 0;
         selectMbx( $dstmbx, 'SELECT', $dst );
         foreach $msgid ( keys %DST_MSGS ) {
            next if $SRC_MSGS{"$msgid"};

            #  This message no longer exists on the source.  Delete it from the dest
            Log("$msgid is not on the source, delete it from the dest") if $debug;
            $dst_msgnum = $DST_MSGS{"$msgid"};
            deleteMsg( $dst, $dst_msgnum ) if $dst_msgnum;
            $expunge = 1;
         }
         expungeMbx( $dst, $dstmbx ) if $expunge;
      }
   }

   #  Update the summary file with the totals for this user
   open(SUM, ">>/tmp/migrateIMAP.sum");
   print SUM "$total|$totalBytes\n";
   close SUM;
   $totalBytes = formatBytes( $totalBytes );
   Log("    Copied $total messages $totalBytes");
   logout( $src );
   logout( $dst );

}

sub init {

   use Getopt::Std;
   use Fcntl;
   use Socket;
   use IO::Socket;
   use sigtrap;
   use FileHandle;
   use MIME::Base64 qw(decode_base64 encode_base64);

   $start = time();

   #  Set up signal handling
   $SIG{'ALRM'} = 'signalHandler';
   $SIG{'HUP'}  = 'signalHandler';
   $SIG{'INT'}  = 'signalHandler';
   $SIG{'TERM'} = 'signalHandler';
   $SIG{'URG'}  = 'signalHandler';

   getopts('S:D:L:i:b:t:n:M:m:hIdux:y:a:b:UHr:e:f:E:R:Xp:wF:os:GJPQA:C:WZ:');

   usage() if $opt_h;
   unless ($opt_S and $opt_D ) {
     usage();
   }
   $sourceHost = $opt_S;
   $destHost   = $opt_D;
   $userlist   = $opt_i;
   $logfile    = $opt_L;
   $maxChildren = $opt_n;
   $usage      = $opt_h;
   $timeout    = $opt_t;
   $unseen     = $opt_u;
   $seen_only  = $opt_o;
   $sent_after = $opt_a;
   $sent_before = $opt_b;
   $mbx_map_fn = $opt_M;
   $mbxList    = $opt_m;
   $root_mbx   = $opt_p;
   $excludeMbxs = $opt_E;
   $excludeMbxs_regex = $opt_R;
   $range      = $opt_r;
   $showIMAP=1 if $opt_I;
   $debug=1    if $opt_d;
   $update=1   if $opt_U;
   $del_from_dest = 1 if $opt_X;
   $md5_hash=1 if $opt_H;
   $src_admin_user = $opt_e;
   $dst_admin_user = $opt_f;
   $exchange = 1 if $opt_w;
   $msgs_per_folder = $opt_F;
   $max_size  = $opt_s;
   $src_xoauth2_tokens = 1 if $opt_G;
   $dst_xoauth2_tokens = 1 if $opt_J;
   $src_plain = 1 if $opt_P;
   $dst_plain = 1 if $opt_Q;
   $kerio_src_master_pwd = $opt_A;
   $kerio_dst_master_pwd = $opt_C;
   $wrap_long_lines = 1 if $opt_W;

   $copy_this_size_only = $opt_Z;

   $timeout = 300 unless $timeout;
   $maxChildren = 2 unless $maxChildren;
   $hostname = `hostname`;

   if ( $md5_hash ) {
      use Digest::MD5 qw(md5_hex);
   }

   $logfile = "migrateIMAP.log" unless $logfile;
   if ( -e $logfile ) {
      #  Rename the existing logfile
      $line = `head -n 1 $logfile`;
      $ts = substr($line,0,16);
      rename($logfile, "$logfile.$ts");
   }
   open (LOG, ">>$logfile");
   select LOG;
   $| = 1;
   unlink '/tmp/migrateIMAP.sum' if -e '/tmp/migrateIMAP.sum';
   Log("$0 starting");

   if ( $ENV{OS} =~ /Windows/i ) {
      Log("Running on a Windows system.");
      Log("A single migration process will be used since Windows does not support fork()");
      $maxChildren = 1;
   }
   if ( $update ) {
      if ( $md5_hash ) {
         Log("Running in update/md5_hash mode");
      } else {
         Log("Running in update mode");
         Log("Messages on the dest which are not on the source will be deleted") if $del_from_dest;
      }
   }

   Log("Renamed old logfile to $logfile.$ts") if $ts;

   #  Validate the arguments and call usage() if necessary

   #  Determine whether we have SSL support via openSSL and IO::Socket::SSL
   $ssl_installed = 1;
   eval 'use IO::Socket::SSL';
   if ( $@ ) {
      $ssl_installed = 0;
   }

   no warnings 'utf8';

}

sub usage {

   print "\nUsage:  migrateIMAP.pl -S sourceHost -D destinationHost\n\n";
   print "Optional arguments:\n\n";
   print " -i <file of usernames>\n";
   print " -n <number of simultaneous migration processes to run>\n";
   print " -L <logfile, default is migrateIMAP.log>\n";
   print " -t <timeout in seconds>\n";
   print " -u <migrate only Unseen messages>\n";
   print " -o <migrate only Seen messages>\n";
   print " -M <file> mailbox map file. Maps src mbxs to dst mbxs.\n";
   print " -p <root mailbox> put all folders under this mailbox (except inbox)\n";
   print " -m  <mbx1,mbx2,..,mbxn> List of mailboxes to migrate.\n";
   print " -E  <mbx1,mbx2,..,mbxn> List of mailboxes to exclude.\n";
   print " -R  <mbx1,mbx2,..,mbxn> List of mailboxes to exclude using regular expressions.\n";
   print " -d debug mode\n";
   print " -I record IMAP protocol exchanges\n";
   print " -x <mbx delimiter [mbx prefix]>  source (eg, -x '. INBOX.'\n";
   print " -y <mbx delimiter [mbx prefix]>  destination\n";
   print " -a <DD-MMM-YYYY> copy only messages after this date\n";
   print " -b <DD-MMM-YYYY> copy only messages before this date\n";
   print " -U update mode, don't copy messages that already exist at the destination\n";
   print " -X In update mode delete messages from the destination which don't exist on the source\n";
   print " -H use an MD5 hash of the message body to determine uniqueness\n";
   print " -T copy custom flags (eg, \$Label1,\$MDNSent,etc)\n";
   print " -e <admin_user:admin_password>  Source administrator user and password\n";
   print " -f <admin_user:admin_password>  Destination administrator user and password\n";
   print " -w destination is Exchange server\n";
   print " -G passwords are XOAUTH2 tokens\n";
   print " -s <size in MB>.  Don't copy messages larger than this size.\n";
   print " -A <source Kerio master password>\n";
   print " -C <destin Kerio master password>\n";
   print " -W wrap long lines at 1,000 characters\n";
   exit;

}


sub Log {

my $line = shift;

if ( 0 ) {
   if ( $line =~ /^\>\> 1 LOGIN (.+) "(.+)"/ ) {
      #  Obscure the password for security's sake
      # $line =~ s/$2/XXXX/;
      $line = ">> LOGIN $1 \"XXXX\"";
   }
}

   if ( LOG ) {
      my @f = localtime( time );
      my $timestamp = sprintf( "%02d-%02d-%04d.%02d:%02d:%02d",
			 (1 + $f[ 4 ]), $f[ 3 ], (1900 + $f[ 5 ]),
			 @f[ 2,1,0 ] );
      printf LOG "%s %s: %s\n", $timestamp, $$, $line;
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

#  login_source
#
sub login_source {

my $user = shift;
my $src  = shift;

   ($sourceUser,$sourcePwd,$destUser,$destPwd) = split(/\s*:\s*/, $user); 

   if ( $src_plain ) {
      Log("Do a PLAIN login on the source");
      $sourceUser = "$sourceUser:$sourceUser:$sourcePwd";
   } elsif ( $src_admin_user and !$sourcePwd ) {
      Log("Doing AUTH PLAIN to the source") if $debug;
      #  Do an admin login using AUTHENTICATION = PLAIN
      $sourceUser .= ":$src_admin_user";
      $src_admin_user =~ /(.+)\s*:\s*(.+)/;
      $src_admin_pwd  = $2;
   }

   unless ( $sourcePwd or $src_admin_user or $kerio_src_master_pwd ) {
     Log("Password not found for $sourceUser, messages will not be migrated");
     return 0;
   }

   if ( $kerio_src_master_pwd ) {
      return 0 unless kerio_master_login( $kerio_src_master_pwd, $sourceUser, $src );
   } elsif ( $src_xoauth2_tokens ) {
      #  Passwords are OAUTH2 tokens
      login_xoauth2( $sourceUser, $sourcePwd, $src);
   } elsif ( $sourcePwd =~ /^oauth2---(.+)/i ) {
      $token = $1;
      Log("password is an OAUTH2 token");
      $status = login_xoauth2( $sourceUser, $token, $src );
      return $status;
   } elsif ( $sourceUser =~ /(.+):(.+):(.+)/ ) {
      #  An AUTHENTICATE = PLAIN login has been requested
      Log("PLAIN login") if $debug;
      return 0 unless login_plain( $sourceUser, $src );
   } else {
      #  Otherwise do an ordinary login
      Log("ORDINARY login");
      return 0 unless login($sourceUser,$sourcePwd, $src);
   }

}

sub login_dest {

my $user = shift;
my $dst  = shift;

   ($sourceUser,$sourcePwd,$destUser,$destPwd) = split(/\s*:\s*/, $user); 

   if ( $dst_plain ) {
      Log("Do a PLAIN login on the dest");
      $destUser = "$destUser:$destUser:$destPwd";
   } elsif ( $dst_admin_user and !$destPwd ) {
      #  Do an admin login using AUTHENTICATION = PLAIN
      Log("Doing AUTH PLAIN to the dest");
      $destUser .= ":$dst_admin_user";
      $dst_admin_user =~ /(.+)\s*:\s*(.+)/;
      $dst_admin_pwd  = $2;
   }

   unless ( $destPwd or $dst_admin_user or $kerio_dst_master_pwd ) {
     Log("Password not found for $destUser, messages will not be migrated");
     return 0;
   }

   if ( $kerio_dst_master_pwd ) {
      return 0 unless kerio_master_login( $kerio_dst_master_pwd, $destUser, $dst );
   } elsif ( $dst_xoauth2_tokens ) {
      #  Passwords are OAUTH2 tokens
      login_xoauth2( $destUser, $destPwd, $dst);
   } elsif ( $destPwd =~ /^oauth2---(.+)/i ) {
      $token = $1;
      Log("password is an OAUTH2 token");
      $status = login_xoauth2( $destUser, $token, $dst );
      return $status;
   } elsif ( $destUser =~ /(.+):(.+):(.+)/ ) {
      #  An AUTHENTICATE = PLAIN login has been requested
      Log("PLAIN login") if $debug;
      return 0 unless login_plain( $destUser, $dst );
   } else {
      #  Otherwise do an ordinary login
      Log("ORDINARY login");
      return 0 unless login($destUser,$destPwd, $dst);
   }

}

#  login
#
#  login in at the host with the user's name and password
#
sub login {

my $user = shift;
my $pwd  = shift;
my $conn = shift;

   sendCommand ($conn, "1 LOGIN $user \"$pwd\"");
   while (1) {
	readResponse ( $conn );
        $gmail = 1 if $response =~ /OK Gimap ready for requests/;
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
my $conn      = shift;

   #  Do an AUTHENTICATE = PLAIN.  If an admin user has been provided then use it.

   my ($user,$admin,$pwd) = split(/:/, $user, 3);
   if ( $debug ) {
      Log("Doing an  AUTHENTICATE = PLAIN");
      Log( "user  $user");
      Log( "admin $admin");
      Log( "pwd   $pwd");
   }

   my $login_str = sprintf("%s\x00%s\x00%s", $user,$admin,$pwd);
   $login_str = encode_base64("$login_str", "");
   my $len = length( $login_str );

   # sendCommand ($conn, "1 AUTHENTICATE PLAIN {$len}" );
   sendCommand ($conn, "1 AUTHENTICATE PLAIN $login_str" );

   my $loops;
   while (1) {
        readResponse ( $conn );
        $gmail = 1 if $response =~ /OK Gimap ready for requests/;
        last if $response =~ /^1 OK/i;
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

sub kerio_master_login {

my $pwd   = shift;
my $user  = shift;
my $conn  = shift;

   sendCommand ($conn, "1 X-MASTERAUTH");
   while (1) {
        readResponse ( $conn );
        last if $response =~ /^\+/;
        if ($response =~ /^1 NO|^1 BAD|^\* BYE/i) {
           Log ("unexpected LOGIN response: $response");
           return 0;
        }
   }

   my ($challenge) = $response =~ /^\+ (.+)/;
   my $string = $challenge . $pwd;
   my $challenge_response = md5_hex( $string );

   if ( $debug ) {
      Log("challenge $challenge");
      Log("pwd       $pwd");
      Log("sending   $challenge_response");
   }

   sendCommand ($conn, $challenge_response);
   my $loops;
   while (1) {
        last if $loops++ > 9;
        readResponse ( $conn );
        last if $response =~ /^1 OK/i;
        if ($response =~ /^1 NO|^1 BAD|^\* BYE/i) {
           Log ("Failed to login as Kerio Master:  unexpected LOGIN response: $response");
           exit;
        }
   }

   #  Select the user

   Log("Selecting user $user") if $debug;
   sendCommand ($conn, "1 X-SETUSER \"$user\"" );
   while (1) {
        readResponse ( $conn );
        last if $response =~ /^1 OK/i;
        if ($response =~ /^1 NO|^1 BAD|^\* BYE/i) {
           Log ("unexpected LOGIN response: $response");
           return 0;
        }
   }

   Log("$user has been selected") if $debug;

   return 1;
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
        } elsif ( $response =~ /\{(.+)\}$/ ) {
                #  The next response contains a nested mbx
	        readResponse ($conn);
                next;
	} elsif ( $response !~ /^\*/ ) {
		Log ("unexpected response: $response");
		return 0;
	}
   }

   %nosel_mbxs = ();
   undef @mbxs;

   for $i (0 .. $#response) {
        $response[$i] =~ s/\s+/ /;
        if ( $response[$i] =~ /\{(.+)\}$/ ) {
           #  Domino workaround for submailbox appearing on next line
           $mbx = $response[$i+1];
        } elsif ( $response[$i] =~ /"$/ ) {
           $response[$i] =~ /\* LIST \((.*)\) "(.+)" "(.+)"/i;
           $mbx = $3;
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

        if ( $mbx eq '[Gmail]/All Mail' ) {
           # The Gmail 'All Mail' folder is where all msgs in Gmail are stored.
           # Gmail uses pointers to group the messages into folders. We don't
           # need to copy the contents of the All Mail folders because we'll
           # get them from the other 'folders'.
           Log("Skipping $mbx");
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

#  getDatedMsgList
#
#  Get a list of the user's messages in a mailbox on
#  the host in the specified range of dates
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
my $header_date;

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
	} elsif ( $response !~ /^\*/ ) {
		Log ("unexpected response: $response");
		# print STDERR "Error: $response\n";
		return 0;
	}
   }

   return if $empty;

   Log("Fetch the header info") if $debug;

   if ( $range ) {
      $fetch_range = $range;
   } else {
      $fetch_range = '1:*';
   }

   sendCommand ( $conn, "1 FETCH $fetch_range (uid flags internaldate body[header.fields (From Subject Date Message-Id)])");
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
        } elsif ( $response =~ /^\* BYE/i ) {
           Log("The server terminated our session with a BYE command: $response");
           exit;
        }
   }

   read_response( \@response, $msgs );

}


sub fetchMsg {

my $msgnum = shift;
my $mbx    = shift;
my $message = shift;
my $conn   = shift;

   Log("   Fetching msg $msgnum...") if $debug;
   $$mesage = '';

   $item = 'BODY[]';
   sendCommand( $conn, "1 FETCH $msgnum ($item)");
   @a = ();
   while (1) {
	readResponse ($conn);
	Log ("Unable to fetch message - connection timeout") if ($conn_timed_out);
 
        if ( $response =~ /THROTTLE/i and $gmail ) {
           #  Gmail is throttling our connection
           $throttle = 1;
        }
	if ( $response =~ /^1 OK/i ) {
           last;
	} 
        elsif ( $response =~ /^1 NO|^1 BAD/i ) {
                Log("Error fetching msgnum $msgnum: $response");
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
		Log("Message could not be processed, skipping it");
		push(@errors,"Message could not be processed, skipping it");
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
                   # Log ("Already read $cc bytes of $len - waiting on " . ($len - $cc)) if $debug;
                   $n = 0;
                   $n = read ($conn, $segment, $len - $cc);
                   # $n = read ($conn, $segment, ($len - $cc > 4096 ? 4096 : $len-$cc));
                   # Log ("Read $n bytes") if $debug;
                   if ( $n == 0 ) {
                      Log ("unable to read $len bytes");
                      return 0;
                   }
                   $$message .= $segment;
                   $cc += $n;
		}
	}
   }

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

#  trim
#
#  remove leading and trailing spaces from a string
sub trim {

local (*string) = @_;

   $string =~ s/^\s+//;
   $string =~ s/\s+$//;

   return;
}

#  insertMsg
#
#  This routine inserts an RFC822 messages into a user's folder
#
sub insertMsg {

local ($conn, $mbx, *message, $flags, $date) = @_;
local ($lsn,$lenx);

   Log("   Inserting message") if $debug;
   $lenx = length($message);
   $totalBytes = $totalBytes + $lenx;
   $totalMsgs++;

   $flags = flags( $flags );
   fixup_date( \$date );

   $flags =~ s/\\Recent//i;

   alarm ( $timeout );
   sendCommand ($conn, "1 APPEND \"$mbx\" ($flags) \"$date\" \{$lenx\}");
   readResponse ($conn);
   alarm( 0 );
   if ($conn_timed_out) {
       Log ("unexpected response timeout appending message");
       push(@errors,"Error appending message to $mbx for $user");
       return 0;
   }
 
   if ( $response =~ /\* BYE/ ) {
      Log("The destination server has closed our session");
      exit;
   }
	
   if ( $response !~ /^\+/ ) {
       Log ("unexpected APPEND response: >$response<");
       # next;
       push(@errors,"Error appending message to $mbx for $user");
       return 0;
   }

   alarm $timeout;
   print $conn "$message\r\n";
   alarm 0;

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

   return;
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

sub formatBytes {

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

sub getUserList {

my $fn = shift;

   @users = ();
   unless ( -e $fn ) {
     Log("Fatal error reading $fn: $!");
     exit;
   }
   open(L, "<$fn") or die $!;
   while ( <L> ) {
      chomp;
      s/\r$//;
      s/^\s+//;
      next if /^#/;
      push( @users, $_ );
   }
   close L;

   return @users;

}

sub selectMbx {

my $mbx  = shift;
my $mode = shift;
my $conn = shift;

   $mode = 'EXAMINE' unless $mode eq 'SELECT';

   Log("selecting mbx $mbx") if $debug;
   sendCommand ($conn, "1 $mode \"$mbx\"");
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

#  Reconnect to a server after a timeout error.
#
sub reconnect {

my $checkpoint = shift;
my $conn = shift;

   logout( $src );
   logout( $dst );

  ($user) = split(/\s*:\s*/, $userinfo);
   connectToHost($sourceHost, \$src);
   login_source( $userinfo, $src );

   connectToHost($destHost, \$dst);
   login_dest( $userinfo, $dst );

   selectMbx( $mbx, 'SELECT', $src );

   return;
}

#  Handle signals

sub signalHandler {

my $sig = shift;

   if ( $sig eq 'ALRM' ) {
      Log("Caught a SIG$sig signal, timeout error");
      reconnect( $checkpoint, \$dst );
      $conn_timed_out = 1;
   } else {
      Log("eaught a SIG$sig signal, shutting down");
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

sub namespace {

my $conn      = shift;
my $prefix    = shift;
my $delimiter = shift;
my $mbx_delim = shift;

   #  Query the server with NAMESPACE so we can determine its
   #  mailbox prefix (if any) and hierachy delimiter.

   if ( $mbx_delim ) {
      #  The user has supplied a mbx delimiter and optionally a prefix.
      Log("Using user-supplied mailbox hierarchy delimiter $mbx_delim") if $debug;
      ($$delimiter,$$prefix) = split(/\s+/, $mbx_delim);
      return;
   }

   @response = ();
   sendCommand( $conn, "1 NAMESPACE");
   while ( 1 ) {
      readResponse( $conn );
      if ( $response =~ /^1 OK/i ) {
         last;
      } elsif ( $response =~ /^1 NO|^1 BAD/i ) {
         Log("Unexpected response to NAMESPACE command: $response");
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
      last if /^1 NO|^1 BAD/;
   }
 
   if ( $debug ) {
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
my $dstmbx;

   #  Adjust the mailbox name if the source and destination server
   #  have different mailbox prefixes or hierarchy delimiters.

   if ( $srcmbx =~ /[$dstDelim]/ and $srcDelim ne $dstDelim ) {
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

   #  Change the mailbox name if the user has supplied mapping rules.
   if ( $mbx_map{"$srcmbx"} ) {
      $srcmbx = $mbx_map{"$srcmbx"}
   }

   if ( ($srcPrefix eq $dstPrefix) and ($srcDelim eq $dstDelim) ) {
      #  No adjustments necessary
      $dstmbx = $srcmbx;
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

         $dstmbx = 'Trash' if lc( $dstmbx) eq "inbox/trash"; 
         $dstmbx = 'Sent' if lc( $dstmbx) eq "inbox/sent"; 

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

sub map_mbx_names {

my $mbx_map = shift;
my $srcDelim = shift;
my $dstDelim = shift;

   #  The -M <file> argument causes migrateIMAP to read the
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
   $use_utf7 = 0;
   while( <MAP> ) {
      chomp;
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
      eval 'use Encode::IMAPUTF7 qw/decode/';
      if ( $@ ) {
         Log("At least one mailbox map contains non-ASCII characters.  This means you");
         Log("have to install the Perl Encode::IMAPUTF7 module in order to map mailbox ");
         Log("names between the source and destination servers.");
         print "At least one mailbox map contains non-ASCII characters.  This means you\n";
         print "have to install the Perl Encode::IMAPUTF7 module in order to map mailbox\n";
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
         $dstsrc = Encode::IMAPUTF7::encode( 'IMAP-UTF-7', $srcmbx );
         $dstmbx = Encode::IMAPUTF7::encode( 'IMAP-UTF-7', $dstmbx );
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
      Log("$mailbox is empty");
      return;
   }

   Log("Fetch the header info") if $debug;

   sendCommand ( $conn, "1 FETCH 1:* (body[header.fields (Date From Subject Message-Id)])");
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

       if ( $response[$i] =~ /Message-ID:\s*(.*)/i ) {
          $msgid = $1;
          # Line-wrap, get it from the next line
          if ( $msgid eq '' ) {
             $msgid = get_wrapped_msgid( \@response, $i );
          }
       }

       if ( $response[$i] =~ /Subject:\s*(.+)/i ) {
          $subject = $1;
       }

       if ( $response[$i] =~ /Date:\s*(.+)/i ) {
          $header_date = $1;
       }

       if ( $response[$i] =~ /From:\s*(.+)/i ) {
          $from = $1;
       }

       if ( $response[$i] =~ /\* (.+) FETCH/ ) {
           ($msgnum) = split(/\s+/, $1);
       }

       if ( $response[$i] =~ /^\)/ or ( $response[$i] =~ /\)\)$/ ) ) {
           #  End of header

           if ( $msgid eq '' ) {
              #  The message lacks a message-id so construct one.
              $header_date =~ s/\W//g;
              $subject =~ s/\W//g;
              $msgid = "$header_date$subject$from";
              $msgid =~ s/\s+//g;
              $msgid =~ s/\+|\<|\>|\?|\*|"|'|\(|\)//g;
              Log("msgnum $msgnum has no msgid, built one as $msgid") if $debug;
           }

           $$msgids{"$msgid"} = $msgnum;
           $msgid=$msgnum=$from=$subject=$header_date='';
       }
   }

}

sub read_response {

my $response = shift;
my $msgs     = shift;
my ($msgid,$date,$flags,$msgnum);

   #  Read the response to our FETCH command and grab
   #  the items we want (msgnum,date,flags, and msgid).

   @$msgs = ();
   for $i (0 .. $#$response) {
        $seen=0;
        $_ = $response[$i];

        if ( /THROTTLE/i and $gmail ) {
            #  Gmail is throttling us.  Sleep a bit to lower our access rate
            Log("Gmail is throttling our connection.  Sleeping for 30 seconds");
            sleep 30;
            $throttle = 0;
        }

        if ($response[$i] =~ /FLAGS/) {
           #  Get the list of flags
           $response[$i] =~ /FLAGS \(([^\)]*)/;
           $flags = $1;
           $flags =~ s/\\Recent//;
        }

        if ( $response[$i] =~ /INTERNALDATE/i ) {
           $response[$i] =~ /INTERNALDATE (.+) BODY/i;
           $date = $1;
           $date =~ /"(.+)"/;
           $date = $1;
           $date =~ s/"//g;
        }

        if ( $response[$i] =~ /^Message-Id:\s*(.*)/i ) {
           $msgid = $1;
           if ( $msgid eq '' ) {
              # Line-wrap, get it from the next line
              $msgid = get_wrapped_msgid( \@response, $i );
           }
        }

        if ( $response[$i] =~ /From:\s*(.+)/i) {
           $from = $1;
        }

        if ( $response[$i] =~ /Subject:\s*(.+)/i) {
           $subject = $1;
        }

        if ( $response[$i] =~ /Date:\s*(.+)/i) {
           $header_date = $1;
        }

        if ( $response[$i] =~ /\* (.+) FETCH/ ) {
           ($msgnum) = split(/\s+/, $1);
        }

        if ( $_ =~ /^\)/ or ( $_ =~ /\)\)$/ ) ) {
           #  End of header

           if ( $msgid eq '' ) {
              #  The message lacks a message-id so construct one.
              $header_date =~ s/\W//g;
              $subject =~ s/\W//g;
              $msgid = "$header_date$subject$from";
              $msgid =~ s/\s+//g;
              $msgid =~ s/\+|\<|\>|\?|\*|"|'|\(|\)//g;
              Log("msgnum $msgnum has no msgid, built one as $msgid") if $debug;
           }

           if ( $unseen ) {
              push (@$msgs,"$msgnum|$date|$flags|$msgid|$header_date") unless $flags =~ /Seen/i;
           } elsif ( $seen_only ) {
              push (@$msgs,"$msgnum|$date|$flags|$msgid|$header_date") if $flags =~ /Seen/i;
           } else {
              push (@$msgs,"$msgnum|$date|$flags|$msgid|$header_date");
           }
           $msgnum=$date=$flags=$msgid=$header_date=$from=$subject='';
        }
   }

}

sub get_supported_flags {

my $mbx   = shift;
my $conn  = shift;
my $FLAGS = shift;

   #  Determine which flags are supported by the mailbox

   sendCommand ($conn, "1 EXAMINE \"$mbx\"");
   undef @response;
   $empty=0;
   while ( 1 ) {
        readResponse ( $conn );
        if ( $response =~ /^1 OK/i ) {
                last;
        } elsif ( $response !~ /^\*/ ) {
                Log ("unexpected response: $response");
                last;
        } elsif ( $response =~ /^\* FLAGS \((.+)\)/i ) {
                %$FLAGS = ();
                foreach my $flag ( split(/\s+/, $1) ) {
                   $flag = uc( $flag );
                   $$FLAGS{$flag} = 1;
                }
        }
   }

}

sub validate_flags {

my $flags = shift;
my $valid_flags = shift;
my $newflags;

    # Remove any flags not supported by the destination mailbox

    foreach my $flag ( split(/\s+/, $flags ) ) {
        $flag = uc( $flag );
        next unless $$valid_flags{$flag};
        $newflags .= "$flag ";
    }
    chop $newflags;

    return $newflags;

}

sub hash {

my $body = shift;

   #  Generate an MD5 hash of the message body

   my $md5 = md5_hex($$body);
   Log("   md5 hash $md5") if $debug;

   return $md5;
}

sub fetch_msg_body {

my $msgnum = shift;
my $conn   = shift;
my $message = shift;

   #  Fetch the body of the message less the headers

   Log("   Fetching msg $msgnum...") if $debug;

   sendCommand( $conn, "1 FETCH $msgnum (rfc822)");
   while (1) {
	readResponse ($conn);
	if ( $response =~ /^1 OK/i ) {
		$size = length($message);
		last;
	} 
        elsif ( $response =~ /^1 NO|^1 BAD/i ) {
                Log("Error fetching msgnum $msgnum: $response");
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
	   ($response =~ /^\*\s+$msgnum\s+FETCH\s+\(.*RFC822\s+\{[0-9]+\}/i) {
		($len) = ($response =~ /^\*\s+$msgnum\s+FETCH\s+\(.*RFC822\s+\{([0-9]+)\}/i);
		$cc = 0;
		$$message = "";
		while ( $cc < $len ) {
			$n = 0;
			$n = read ($conn, $segment, $len - $cc);
			if ( $n == 0 ) {
				Log ("unable to read $len bytes");
				return 0;
			}
			$$message .= $segment;
			$cc += $n;
		}
	}
   }

}

sub mailbox_names {

my $mbxs = shift;

   #  Figure out what the longest mbx name is so we
   #  can nicely format the running totals

   my $longest;
   foreach $_ ( @$mbxs ) {
      my $length = length( $_ );
      $longest = $length if $length > $longest;
   }

   $longest += 2;
   return $longest;

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

sub findMsg {

my $msgid = shift;
my $conn  = shift;
my $msgnum;

   # Search a mailbox on the server for a message by its msgid.

   Log("   Search for $msgid") if $verbose;
   sendCommand ( $conn, "1 SEARCH header Message-Id \"$msgid\"");
   while (1) {
	readResponse ($conn);
	if ( $response =~ /\* SEARCH /i ) {
	   ($dmy, $msgnum) = split(/\* SEARCH /i, $response);
	   ($msgnum) = split(/ /, $msgnum);
	}

	last if $response =~ /^1 OK|^1 NO|^1 BAD/;
	last if $response =~ /complete/i;
   }

   if ( $verbose ) {
      Log("$msgid was not found") unless $msgnum;
   }

   return $msgnum;
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

my $conn  = shift;
my $mbx   = shift;
my $status;
my $loops;
my $expunged=0;

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

   Log("    $expunged messages purged from $mbx");

}

sub exchange_workaround {

   #  Because Exchange limits the number of mailboxes you can create
   #  during a single IMAP session we have to get a new session before
   #  we can continue.

   Log("Disconnecting and reconnecting to Exchange server");
   logout( $dst );
   connectToHost( $destHost, \$dst );

   #  Log back into Exchange

   if ( $destUser =~ /(.+):(.+):(.+)/ ) {
      #  An AUTHENTICATE = PLAIN login has been requested
      Log("PLAIN login") if $debug;
      return 0 unless login_plain( $destUser, $dst );
   } elsif ( $xoauth2_tokens ) {
      #  Passwords are XOAUTH2 tokens
      login_xoauth2( $destUser, $destPwd, $dst);
   } else {
      #  Otherwise do an ordinary login
      unless ( login_ordinary( $destUser,$destPwd, $dst ) ) {
         logout( $src );
         return 0;
      }
   }

   return;

}

#  getDestMailboxList
#
#  get a list of the user's mailboxes on the destination host
#
sub getMailboxes {

my $MBXS = shift;
my $conn = shift;

   #  Get a list of the user's mailboxes
   #

   Log("Get list of user's mailboxes on the destination") if $debug;

   sendCommand ($conn, "1 LIST \"\" *");
   undef @response;
   while ( 1 ) {
	readResponse ($conn);
	if ( $response =~ /^1 OK/i ) {
		last;
        } elsif ( $response =~ /\{(.+)\}$/ ) {
                #  The nested mailbox is on the next line
                readResponse ($conn);
                next;
	} elsif ( $response !~ /^\*/ ) {
		Log ("unexpected response: $response");
		return 0;
	}
   }

   %$MBXS = ();
   for $i (0 .. $#response) {
        $response[$i] =~ s/\s+/ /;
        if ( $response[$i] =~ /\{(.+)\}$/ ) {
           #  Domino workaround for submailbox appearing on next line
           $mbx = $response[$i+1];
        } elsif ( $response[$i] =~ /"$/ ) {
           $response[$i] =~ /\* LIST \((.*)\) "(.+)" "(.+)"/i;
           $mbx = $3;
        } else {
           $response[$i] =~ /\* LIST \((.*)\) "(.+)" (.+)/i;
           $mbx = $3;
        }
	$mbx =~ s/^\s+//;  $mbx =~ s/\s+$//;
        $$MBXS{"$mbx"} = 1;
   }

}

sub commafy {

my $number = shift;

   $_ = $$number;
   1 while s/^([-+]?\d+)(\d{3})/$1,$2/;

   $$number = $_;

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


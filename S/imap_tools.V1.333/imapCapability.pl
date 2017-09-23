#!/usr/bin/perl

#  $Header: /mhub4/sources/imap-tools/imapCapability.pl,v 1.9 2014/10/15 21:42:58 rick Exp $

###########################################################################
#  Program name  imapCapability.pl                                        #
#  Written by    Rick Sanders                                             #
#  Date          23 December 2007                                         #
#                                                                         #
#  Description                                                            #
#                                                                         #
#  imapCapability.pl is a simple program for querying an IMAP             #
#  server for a list of the IMAP features it supports.                    #
#                                                                         #
#  Description                                                            #
#                                                                         #
#  imapCapability is used to discover what services an IMAP               #
#  server supports.                                                       #
#                                                                         #
#  Usage: imapCapability.pl -h <host> -u <user> -p <password>             #
#  Optional arguments: -d (debug) -m (list folders)                       #             
#                                                                         #
#  Sample output:                                                         #
#  The server supports the following IMAP capabilities:                   #
#                                                                         #
#  IMAP4 IMAP4REV1 ACL NAMESPACE UIDPLUS IDLE LITERAL+ QUOTA              #
#  ID MULTIAPPEND LISTEXT CHILDREN BINARY LOGIN-REFERRALS                 #
#  UNSELECT STARTTLS AUTH=LOGIN AUTH=PLAIN AUTH=CRAM-MD5                  # 
#  AUTH=DIGEST-MD5 AUTH=GSSAPI AUTH=MSN AUTH=NTLM                         #
###########################################################################

############################################################################
# Copyright (c) 2012 Rick Sanders <rfs9999@earthlink.net>                  #
#                                                                          #
# Permission to use, copy, modify, and distribute this software for any    #
# purpose with or without fee is hereby granted, provided that the above   #
# copyright notice and this permission notice appear in all copies.        #
#                                                                          #
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES #
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF         #
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR  #
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES   #
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN    #
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF  #
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.           #
############################################################################

use Socket;
use FileHandle;
use Fcntl;
use Getopt::Std;
use IO::Socket;
eval 'use Encode qw/encode decode/';
eval 'use Encode::IMAPUTF7 qw/encode decode/';
use MIME::Base64 qw(encode_base64 decode_base64);

#################################################################
#            Main program.                                      #
#################################################################
  
   ($host,$user,$pwd) = getArgs();
   
   unless ( $host and $user and $pwd ) {
      print "Host:Port   > ";
      chomp($host = <>);
      print "Username    > ";
      chomp($user = <>);
      print "Password    > ";
      chomp($pwd = <>);
   }

   unless ( $host and $user and $pwd ) {
      print "Please supply host, username, and password\n";
      exit;
   }

   init();

   connectToHost($host, \$conn)    or exit;
   login($user,$pwd, $conn) or exit;
   capability( $conn );

   if ( $list_mbxs ) {
      print STDOUT "\nList of mailboxes for $user:\n\n";
      @mbxs = listMailboxes( $conn );

      foreach $mbx ( @mbxs ) {
         $mbx1 = decode( 'IMAP-UTF-7', $mbx );
         if ( $mbx eq $mbx1 ) {
            print STDOUT "   $mbx\n";
         } elsif( $utf7_installed ) {
            print STDOUT "   $mbx  ($mbx1)\n";
         } else {
            print STDOUT "   $mbx\n";
         }
      }   
   }
   logout( $conn );

sub init {

   #  Determine whether we have SSL support via openSSL and IO::Socket::SSL
   $ssl_installed = 1;
   eval 'use IO::Socket::SSL';
   if ( $@ ) {
      $ssl_installed = 0;
   }

   $utf7_installed = 1;
   eval 'use Encode::IMAPUTF7 qw/decode/';
   if ( $@ ) {
      $utf7_installed = 0;
   }
}

sub getArgs {

   getopts( "h:u:p:dmA:I" );
   $host = $opt_h;
   $user = $opt_u;
   $pwd  = $opt_p;
   $debug = $opt_d;
   $admin_user = $opt_A;
   $list_mbxs = 1 if $opt_m;
   $showIMAP = 1 if $opt_I;

   if ( $admin_user ) {
      #  Don't need user password
      $pwd = 'XXXX';
   }

   if ( $opt_H ) {
      usage();
   }

   if ( !$host or !$user or !$pwd ) {
      usage();
   }

   return ($host,$user,$pwd);

}

sub usage {

   print STDOUT "usage:  imapCapability.pl -h <host> -u <user> -p <password>\n";
   print STDOUT "     Option argument:  -m  (list mailboxes)\n";
   exit;

}


sub connectToHost {

my $host = shift;
my $conn = shift;

   ($host,$port) = split(/:/, $host);
   $port = 143 unless $port;

   # We know whether to use SSL for ports 143 and 993.  For any
   # other ones we'll have to figure it out.
   $mode = sslmode( $host, $port );

   if ( $mode eq 'SSL' ) {
      unless( $ssl_installed == 1 ) {
         warn("You must have openSSL and IO::Socket::SSL installed to use an SSL connection");
         exit;
      }
      print "Attempting an SSL connection\n" if $debug;
      $$conn = IO::Socket::SSL->new(
         Proto           => "tcp",
         SSL_verify_mode => 0x00,
         PeerAddr        => $host,
         PeerPort        => $port,
         Domain          => AF_INET,
      );

      unless ( $$conn ) {
        $error = IO::Socket::SSL::errstr();
        print "Error connecting to $host: $error\n";
        exit;
      }
   } else {
      #  Non-SSL connection
      print "Attempting a non-SSL connection\n" if $debug;
      $$conn = IO::Socket::INET->new(
         Proto           => "tcp",
         PeerAddr        => $host,
         PeerPort        => $port,
      );

      unless ( $$conn ) {
        print "Error connecting to $host:$port: $@\n";
        warn "Error connecting to $host:$port: $@";
        exit;
      }
   } 
   print "Connected to $host on port $port\n";

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

   sendCommand ($conn, "1 LOGIN $user $pwd");
   while (1) {
	readResponse ( $conn );
	last if $response =~ /^1 OK/i;
	if ($response =~ /^1 NO|^1 BAD/i) {
           print "Unexpected LOGIN response: $response\n";
           return 0;
	}
   }
   print "Logged in as $user\n" if $debug;

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

sub capability {

my $conn = shift;
my @response;
my $capability;

   sendCommand ($conn, "1 CAPABILITY");
   while (1) {
        readResponse ( $conn );
        $capability = $response if $response =~ /\* CAPABILITY/i;
        last if $response =~ /^1 OK/i;
        if ($response =~ /^1 NO|^1 BAD/i) {
           print "Unexpected response: $response\n";
           return 0;
        }
   }

   print STDOUT "\nThe server supports the following IMAP capabilities:\n\n";
   $capability =~ s/^\* CAPABILITY //;
   print "$capability\n";

}

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
                print "Unexpected LOGOUT response: $response\n";
                last;
        }
   }
   close $conn;
   return;
}

sub sendCommand {

my $fd = shift;
my $cmd = shift;

    print $fd "$cmd\r\n";
    print STDOUT "$cmd\n" if $showIMAP;
}

sub readResponse {

my $fd = shift;

    $response = <$fd>;
    chop $response;
    $response =~ s/\r//g;
    push (@response,$response);
    print STDOUT "$response\n" if $showIMAP;
}


#  listMailboxes
#
#  Get a list of the user's mailboxes
#
sub listMailboxes {

my $conn = shift;

   sendCommand ($conn, "1 LIST \"\" *");
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
        push ( @mbxs, $mbx ) if $mbx ne '';
   }

   return @mbxs;
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

sub Log {

my $str = shift;

   print STDERR "$str\n";

}

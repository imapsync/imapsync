#!/usr/bin/perl

=head1 NAME

idle.pl - example using IMAP idle

=head1 SYNOPSIS

idle.pl [options]

  Options: [*] == Required, [+] == Multiple vals OK, (val) == Default
    --o Server=<server>    *IMAP server name/IP
    --o User=<user>        *User account to login to
    --o Password=<passwd>  *Password to use for the User account
                           (see security note below)
    --o Port=<port>        port on Server to connect to
    --o Ssl=<bool>         use SSL on this connection
    --o Starttls=<bool>    call STARTTLS on this connection
    --o Debug=<int>        enable debugging in Mail::IMAPClient
    --o ImapclientKey=Val  any other Mail::IMAPClient attribute/value pair
    --folder <folder>      folder (mailbox) to IMAP SELECT (INBOX)
    --maxidle <sec>        maximum time to idle without receiving data (300)
    --help                 display a brief help message
    --man                  display the entire man page
    --debug                enable script debugging

=head1 NOTES

=head2 --o Password=<password>

A password specified as a command-line option may be visible
to other users via the system process table. It may alternately be
given in the PASSWORD environment variable.

=head2 --maxidle <sec>

RFC 2177 states, "The server MAY consider a client inactive if it has
an IDLE command running, and if such a server has an inactivity
timeout it MAY log the client off implicitly at the end of its timeout
period. Because of that, clients using IDLE are advised to terminate
the IDLE and re-issue it at least every 29 minutes to avoid being
logged off."

The default of --maxidle 300 is used to allow the client to notice
when a connection has silently been closed upstream due to network or
firewall issue or configuration without missing too many idle events.

=cut

use strict;
use warnings;
use File::Basename qw(basename);
use Getopt::Long qw(GetOptions);
use Mail::IMAPClient qw();
use Pod::Usage qw(pod2usage);
use POSIX qw();

use constant {
    FOLDER  => "INBOX",
    MAXIDLE => 300,
};

$| = 1;    # set autoflush

my $DEBUG   = 0;              # GLOBAL set by process_options()
my $QUIT    = 0;
my $VERSION = "1.00";
my $Prog    = basename($0);

###
# main program
main();

sub main {
    my %Opt = process_options();

    pout("started $Prog\n");

    my $imap = Mail::IMAPClient->new( %{ $Opt{opt} } )
      or die("$Prog: error: Mail::IMAPClient->new: $@\n");

    my ( $folder, $chkseen, $tag ) = ( $Opt{folder}, 1, undef );

    $imap->select($folder)
      or die("$Prog: error: select '$folder': $@\n");

    $SIG{'INT'} = \&sigint_handler;

    until ($QUIT) {
        unless ( $imap->IsConnected ) {
            warn("$Prog: reconnecting due to error: $@\n") if $imap->LastError;
            $imap->connect or last;
            $imap->select($folder) or last;
            $tag = undef;
        }

        my $ret;
        if ($chkseen) {
            $chkseen = 0;

            # end idle if necessary
            if ($tag) {
                $tag = undef;
                $ret = $imap->done or last;
            }

            my $unseen = $imap->unseen_count;
            last if $@;
            pout("$unseen unseen/new message(s) in '$folder'\n") if $unseen;
        }

        # idle for X seconds unless data was returned by done
        unless ($ret) {
            $tag ||= $imap->idle
              or die("$Prog: error: idle: $@\n");

            warn( "$Prog: DEBUG: ", _ts(), " do idle_data($Opt{maxidle})\n" )
              if $DEBUG;
            $ret = $imap->idle_data( $Opt{maxidle} ) or last;

            # connection can go stale so we exit/re-enter of idle state
            # - RFC 2177 mentions 29m but firewalls may be more strict
            unless (@$ret) {
                warn( "$Prog: DEBUG: ", _ts(), " force exit of idle\n" )
                  if $DEBUG;
                $tag = undef;

                # restarted lost connections on next iteration
                $ret = $imap->done or next;
            }
        }

        local ( $1, $2, $3 );
        foreach my $resp (@$ret) {
            $resp =~ s/\015?\012$//;

            warn("$Prog: DEBUG: server response: $resp\n") if $DEBUG;

            # ignore:
            # - DONE command
            # - <tag> OK IDLE...
            next if ( $resp eq "DONE" );
            next if ( $resp =~ /^\w+\s+OK\s+IDLE\b/ );

            if ( $resp =~ /^\*\s+(\d+)\s+(EXISTS)\b/ ) {
                my ( $num, $what ) = ( $1, $2 );
                pout("$what: $num message(s) in '$folder'\n");
                $chkseen++;
            }
            elsif ( $resp =~ /^\*\s+(\d+)\s+(EXPUNGE)\b/ ) {
                my ( $num, $what ) = ( $1, $2 );
                pout("$what: message $num from '$folder'\n");
            }

            # * 83 FETCH (FLAGS (\Seen))
            elsif ( $resp =~ /^\*\s+(\d+)\s+(FETCH)\s+(.*)/ ) {
                my ( $num, $what, $info ) = ( $1, $2, $3 );
                $chkseen++ if ( $info =~ /[\(|\s]\\Seen[\)|\s]/ );
                pout("$what: message $num from '$folder': $info\n");
            }
            else {
                pout("server response: $resp\n");
            }
        }
    }

    my $rc = 0;
    if ($@) {
        if ($QUIT) {
            warn("$Prog: caught signal\n");
        }
        else {
            $rc = 1;
        }
        warn("$Prog: imap error: $@\n") if ( !$QUIT || $DEBUG );
    }
    exit($rc);
}

###
# supporting routines

sub pout {
    print( _ts(), " ", @_ );
}

sub process_options {
    my ( %Opt, @err );

    GetOptions( \%Opt, "opt=s%", "debug:1", "help", "man", "folder=s",
        "maxidle:i" )
      or pod2usage( -verbose => 0 );

    pod2usage( -message => "$Prog: version $VERSION\n", -verbose => 1 )
      if ( $Opt{help} );
    pod2usage( -verbose => 2 ) if ( $Opt{man} );

    # set global DEBUG
    $DEBUG = $Opt{debug} || 0;

    # folder (mailbox) to watch
    $Opt{folder} = FOLDER unless ( exists $Opt{folder} );

    # restart idle when no idle_data seen for this long
    $Opt{maxidle} = MAXIDLE unless ( exists $Opt{maxidle} );

    $Opt{opt}->{Password} = $ENV{PASSWORD}
      if ( !exists $Opt{opt}->{Password} && defined $ENV{PASSWORD} );

    foreach my $arg (qw(Server User Password)) {
        push( @err, "-o $arg=<val> is required" ) if !exists $Opt{opt}->{$arg};
    }

    pod2usage(
        -verbose => 1,
        -message => join( "", map( "$Prog: $_\n", @err ) )
    ) if (@err);

    return %Opt;
}

# example: 2005-10-02 07:50:32
sub _ts {
    my %opt = @_;
    my $fmt = $opt{fmt} || "%Y-%m-%d %T";
    return POSIX::strftime( $fmt, localtime(time) );
}

sub sigint_handler {
    $QUIT = 1;
}

#!/usr/bin/perl

use Time::Local;
use FileHandle;
use File::Copy;
use Mail::IMAPClient;
use Sys::Hostname;

my $default_user = 'default';
my $default_pswd = 'default';

###
# ARGS: DATE     = YYYYMMDDHHMM (defaults to current system date)
#       UID      = IMAP account id (defaults to $default_user)
#       PSWD     = uid's password (defaults to $default_pswd)
#       HOST     = Target host (defaults to localhost)
#       CLEAN    = 1   (defaults to 0; used to clean out mailbox 1st)
#       CLEANONLY= 1   (defaults to 0; if 1 then only CLEAN is done)
#       DOMAIN   = x.com (no default) the mail domain for UID's address
#
# EG:   populate_mailbox.pl DATE=200001010100 UID=testuser
###

( my ($x) = join( " ", @ARGV ) );
$x =~ s~=~ ~g;
chomp($x);

my %hash = split( /\s+/, $x ) if $x;

while ( my ( $k, $v ) = each %hash ) {
    $hash{ uc $k } = $v;
}

while ( my ( $k, $v ) = each %hash ) {
    delete $hash{$k} if $k =~ tr/[a-z]//;
}

$hash{UID}  ||= "$default_user";
$hash{PSWD} ||= "$default_pswd";
$hash{HOST} ||= hostname;

while ( my ( $k, $v ) = each %hash ) {
    print "Running with $k set to $v\n";
}

my $domain = $hash{DOMAIN} or die "No mail domain provided.\n";
my $now = seconds( $hash{DATE} ) || time;

my $six       = $now - ( 6 * 24 * 60 * 60 );
my $seven     = $now - ( 7 * 24 * 60 * 60 );
my $notthirty = $now - ( 29 * 24 * 60 * 60 );
my $thirty    = $now - ( 30 * 24 * 60 * 60 );
my $notsixty  = $now - ( 59 * 24 * 60 * 60 );
my $sixty     = $now - ( 60 * 24 * 60 * 60 );
my $notd365   = $now - ( 364 * 24 * 60 * 60 );
my $d365      = $now - ( 365 * 24 * 60 * 60 );

$hash{SUBJECTS} = [
    "Sixty days old",
    "Less than sixty days old",
    "365 days old",
    "Less than 365 days old",
    "Trash/Incinerator -- 7 days old",
    "Sent -- 29 days old",
    "Sent -- 30 days old",
    "Trash -- 6 days old",
];

$hash{FOLDERS} = [
    "Sent",              "INBOX",
    "Trash",             "365_folder",
    "Trash/Incinerator", "not_365_folder",
];

&clean_mailbox if $hash{CLEANONLY} || $hash{CLEAN};
exit if $hash{CLEANONLY};

# send     to:          date:            subject:
# -------- ---          -----           ---------
sendmail( $hash{UID}, $sixty,    "Sixty days old" );
sendmail( $hash{UID}, $notsixty, "Less than sixty days old" );
sendmail( $hash{UID}, $d365,     "365 days old" );
sendmail( $hash{UID}, $notd365,  "Less than 365 days old" );

populate_trash( "Trash/Incinerator", $hash{UID}, $seven,     7 );
populate_trash( "Trash",             $hash{UID}, $six,       6 );
populate_trash( "Sent",              $hash{UID}, $thirty,    30 );
populate_trash( "Sent",              $hash{UID}, $notthirty, 29 );

movemail( "365 days old", "365_folder" );

movemail( "Less than 365 days old", "not_365_folder" );

exit;

sub seconds {
    my $d = shift or return undef;
    my ( $yy, $moy, $dom, $hr, $min ) =
      $d =~ m!  ^               # anchor at start       #
                (\d\d\d\d)      # year                  #
                (\d\d)          # month                 #
                (\d\d)          # day                   #
                (\d\d)          # hour                  #
                (\d\d)          # minute                #
                !x;

    # allow year 0999 to be year 999, and year 0099 to be year 99
    return timegm( 0, $min, $hr, $dom, $moy - 1,
        ( $yy > 999 ? $yy : $yy - 1900 ) );
}

sub sendmail {
    my ( $to, $date, $subject ) = @_;
    my $text = <<EOTEXT ;
To: $to\@$hash{DOMAIN}
Date: @{[&rfc822_date($date)]}
Subject: $subject

Dear mail tester,

This is a test message to test mail for messages \l$subject.

I hope you like it!

Love,
The E-Mail Engineering Team

EOTEXT

    for ( my $x = 0 ; $x < 10 ; $x++ ) {
        my $imap = Mail::IMAPClient->new(
            Server   => $hash{HOST},
            User     => $hash{UID},
            Password => $hash{PSWD}
        ) or die "can't connect: $!\n";

        $imap->append( "INBOX", $text );
        $imap->logout;
    }
}

sub populate_trash {
    my $where = shift;
    my $to    = shift;
    my $date  = shift;
    my $d     = shift;

    my ( $ss, $min, $hr, $day, $mon, $year ) = gmtime($date);
    $mon++;
    $year += 1900;
    my $fn = sprintf( "%4.4d%2.2d%2.2d%2.2d%2.2d%2.2d",
        $year, $mon, $day, $hr, $min, $ss );
    my $x       = 0;
    my $subject = "$where -- $d days old";
    while ( $x++ < 10 ) {
        my $fh;
        $fh .= "Date: @{[&rfc822_date($date)]}\n";
        $fh .= <<EOTRAH ;
Subject: $subject

This note was put in the $where folder $d days ago.  (My how time flies!)
I hope you enjoyed testing with it!

EOTRAH
        my $imap = Mail::IMAPClient->new(
            Server   => $hash{HOST},
            User     => $hash{UID},
            Password => $hash{PSWD}
        ) or die "can't connect: $!\n";
        $imap->append( $where, $fh );
    }
}

sub movemail {
    my ( $subj, $fold ) = @_;
    my $fh = Mail::IMAPClient->new(
        Debug    => 0,
        Server   => $hash{HOST},
        User     => $hash{UID},
        Password => $hash{PSWD},
    );

    $fh->select("inbox") or die "cannot open inbox: $!\n";

    foreach my $f ( $fh->search(qq(SUBJECT "$subj")) ) {
        $fh->move( $fold, $f );
    }
}

sub clean_mailbox {
    my $fh = Mail::IMAPClient->new(
        Debug    => 0,
        Server   => $hash{HOST},
        User     => $hash{UID},
        Password => $hash{PSWD},
    );
    for my $x ( @{ $hash{FOLDERS} } ) {
        my @msgs;
        $fh->create($x) unless $fh->exists($x);
        $fh->select($x);
        for my $s ( @{ $hash{SUBJECTS} } ) {
            push @msgs, $fh->search(qq(SUBJECT "$s"));
        }
        $fh->delete_message(@msgs) if scalar(@msgs);
        $fh->expunge;
    }
}

# Date: Fri, 09 Jul 1999 13:10:55 -0400
sub rfc822_date {
    my $date = shift;
    my @date = localtime($date);
    my @dow  = qw{ Sun Mon Tue Wed Thu Fri Sat };
    my @mnt  = qw{ Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec};

    return sprintf(
        "%s, %2.2d %s %4.4s %2.2d:%2.2d:%2.2d -0400",
        $dow[ $date[6] ],
        $date[3],
        $mnt[ $date[4] ],
        $date[5] += 1900,
        $date[2], $date[1], $date[0]
    );
}

=head1 AUTHOR

David J. Kernen

The Kernen Group, Inc.

imap@kernengroup.com

=head1 COPYRIGHT

This example and Mail::IMAPClient are Copyright (c) 2003
by The Kernen Group, Inc. All rights reserved.

This example is distributed with Mail::IMAPClient and
subject to the same licensing requirements as Mail::IMAPClient.

imtest is a utility distributed with Cyrus IMAP server,
Copyright (c) 1994-2000 Carnegie Mellon University.
All rights reserved.

=cut

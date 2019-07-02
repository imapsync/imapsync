package MyTest;

use strict;
use warnings;

my $infile = "test.txt";

sub new {
    my ($class) = @_;
    my %self;

    open( my $fh, "<", $infile )
      or die("test parameters not provided in $infile\n");

    my %argmap = ( passed => "Password", authmech => "Authmechanism" );
    while ( my $l = <$fh> ) {
        chomp $l;
        next if $l =~ /^\s*#/;
        my ( $p, $v ) = split( /=/, $l, 2 );
        s/^\s+//, s/\s+$// for $p, $v;
        $p = $argmap{$p} if $argmap{$p};
        $self{ ucfirst($p) } = $v if defined $v;
    }
    close($fh);

    my @missing;
    foreach my $p (qw/Server User Password/) {
        push( @missing, $p ) unless defined $self{$p};
    }

    die("missing value for: @missing") if (@missing);
    return \%self;
}

1;

#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

use lib "t/lib";
use MyTest;
my $params;

BEGIN {
    eval { $params = MyTest->new; };
    $@
      ? plan skip_all => $@
      : plan tests    => 7;
}

BEGIN { use_ok('Mail::IMAPClient') or exit; }

my %args = ( Debug => $ARGV[0], %$params );
my $imap = Mail::IMAPClient->new(%args);
ok( !$@, "successful login" ) or diag( '$@:' . $@ );

# RFC 2087: QUOTA
SKIP: {
    my ( $res, $root );
    skip "QUOTA not supported", 1 unless $imap->has_capability("QUOTA");

    foreach my $root ( "", "INBOX", "/blah" ) {
        $res = $imap->getquotaroot($root);
        ok( $res, "getquotaroot($root)" ) or diag( '$@:' . $@ );

        #my $tag = $imap->Count;
        #foreach my $r ( @{$res||[]} ) {
        #    next if $r =~ /^$tag\s+/;
        #    chomp($r);
        #    warn("gqr r=$r\n");
        #}
    }

    ok( $imap->getquota("User quota"), "getquota" ) or diag( '$@:' . $@ );

    my $dne = "ThisDoesNotExist";
    ok( !$imap->getquota($dne), "getquota($dne)" ) or diag( '$@:' . $@ );
}

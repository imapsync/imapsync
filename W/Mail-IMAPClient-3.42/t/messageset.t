#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 7;

BEGIN { use_ok('Mail::IMAPClient::MessageSet') or exit; }

my $one   = q/1:4,3:6,10:15,20:25,2:8/;
my $range = Mail::IMAPClient::MessageSet->new($one);
is( $range, "1:8,10:15,20:25", 'range simplify' );

is(
    join( ",", $range->unfold ),
    "1,2,3,4,5,6,7,8,10,11,12,13,14,15,20,21,22,23,24,25",
    'range unfold'
);

$range .= "30,31,32,31:34,40:44";
is( $range, "1:8,10:15,20:25,30:34,40:44", 'overload concat' );

is(
    join( ",", $range->unfold ),
    "1,2,3,4,5,6,7,8,10,11,12,13,14,15,20,21,22,23,24,25,"
      . "30,31,32,33,34,40,41,42,43,44",
    'unfold extended'
);

$range -= "1:2";
is( $range, "3:8,10:15,20:25,30:34,40:44", 'overload subtract' );

is(
    join( ",", $range->unfold ),
    "3,4,5,6,7,8,10,11,12,13,14,15,20,21,22,23,24,25,"
      . "30,31,32,33,34,40,41,42,43,44",
    'subtract unfold'
);

#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 13;

BEGIN { use_ok('Mail::IMAPClient') or exit; }

{
    my $obj = Mail::IMAPClient->new();

    my %t = ( 0 => "01-Jan-1970" );
    foreach my $k ( sort keys %t ) {
        my $v = $t{$k};
        my $s = $v . ' 00:00:00 +0000';

        is( Mail::IMAPClient::Rfc2060_date($k), $v, "Rfc2060_date($k)=$v" );
        is( Mail::IMAPClient::Rfc3501_date($k), $v, "Rfc3501_date($k)=$v" );
        is( Mail::IMAPClient::Rfc3501_datetime($k),
            $s, "Rfc3501_datetime($k)=$s" );
        is( Mail::IMAPClient::Rfc2060_datetime($k),
            $s, "Rfc3501_datetime($k)=$s" );
        is( $obj->Rfc3501_date($k),     $v, "->Rfc3501_date($k)=$v" );
        is( $obj->Rfc2060_date($k),     $v, "->Rfc2060_date($k)=$v" );
        is( $obj->Rfc3501_datetime($k), $s, "->Rfc3501_datetime($k)=$s" );
        is( $obj->Rfc2060_datetime($k), $s, "->Rfc2060_datetime($k)=$s" );

        foreach my $z (qw(+0000 -0500)) {
            my $vz = $v . ' 00:00:00 ' . $z;
            is( Mail::IMAPClient::Rfc2060_datetime( $k, $z ),
                $vz, "Rfc2060_datetime($k)=$vz" );
            is( Mail::IMAPClient::Rfc3501_datetime( $k, $z ),
                $vz, "Rfc3501_datetime($k)=$vz" );
        }
    }
}

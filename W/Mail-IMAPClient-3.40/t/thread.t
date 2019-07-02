#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 7;

BEGIN { use_ok('Mail::IMAPClient::Thread') or exit; }

my $t1 = <<'e1';
* THREAD (166)(167)(168)(169)(172)(170)(171)(173)(174 175 176 178 181 180)(179)(177 183 182 188 184 185 186 187 189)(190)(191)(192)(193)(194 195)(196 197 198)(199)(200 202)(201)(203)(204)(205)(206 207)(208) 
e1

my $t2 = <<'e2';
* THREAD (166)(167)(168)(169)(172)((170)(179))(171)(173)((174)(175)(176)(178)(181)(180))((177)(183)(182)(188 (184)(189))(185 186)(187))(190)(191)(192)(193)((194)(195 196))(197 198)(199)(200 202)(201)(203)(204)(205 206 207)(208)
e2

my $parser = Mail::IMAPClient::Thread->new;
ok( defined $parser, 'created parser' );

isa_ok( $parser, 'Parse::RecDescent' );    #  !!!

my $thr1 = $parser->start($t1);
ok( defined $thr1, 'thread1 start' );

cmp_ok( scalar(@$thr1), '==', 25 );

my $thr2 = $parser->start($t2);
ok( defined $thr2, 'thread2 start' );

cmp_ok( scalar(@$thr2), '==', 23 );

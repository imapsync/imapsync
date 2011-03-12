#! /usr/bin/perl

BEGIN { *CORE::GLOBAL::time = sub { CORE::time } };

use strict;
use warnings;
use Test::More tests => 9;
use Authen::NTLM;
use MIME::Base64;

my $user = "test";
my $domain = "test";
my $passwd = "test";
my $msg1 = "TlRMTVNTUAABAAAAB5IIAAAAAAAAAAAABAAEACAAAAB0ZXN0";
my $challenge = "TlRMTVNTUAACAAAABAAEADgAAAAFgokCQUJDREVGR0gAAAAAAAAAAAQABAA8AAAAdGVzdHRlc3R0ZXN0";
my $msg2 = "TlRMTVNTUAADAAAAGAAYAEAAAAAwADAAWAAAAAQABACIAAAACAAIAIwAAAAIAAgAlAAAAAAAAABcAAAABYIIAMAnJRnMkjvahFEZwXRLN9QAAAAAAAAAABmT0B8dzYsVm1/IAPnR5PIBAQAAAAAAAIBgMzwAAAAAAAAAAAAAAAAAAAAAAAAAAHRlc3R0AGUAcwB0AHQAZQBzAHQA";

my $a = Authen::NTLM-> new(
	user     => $user,
	domain   => $domain,
	password => $passwd,
	version  => 2,
);

my $reply1 = $a-> challenge;
ok($reply1 eq $msg1, 'reply 1');

# decode challenge - not normally user accessed
my $c = &Authen::NTLM::decode_challenge(decode_base64($challenge));
ok($c->{ident} eq "NTLMSSP", 'header');
ok($c->{type} == 2, 'type');
ok($c->{flags} == 0x02898205, 'flags');
ok($c->{data} eq "ABCDEFGH", 'data');
ok($c->{domain}{len} == 4, 'domain length');
ok($c->{domain}{offset} == 56, 'domain offset');
ok($c->{buffer} eq "testtesttest", 'contents');

# 13: v2 challenge-response uses time()
{
	no warnings qw(redefine);
	local *CORE::GLOBAL::time = sub { 1_000_000_000 };
	my $reply2 = $a-> challenge($challenge);
	ok($reply2 eq $msg2, 'reply 2');
}

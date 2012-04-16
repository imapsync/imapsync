#! /usr/bin/perl

use strict;
use warnings;
use Test::More tests => 12;

use Authen::NTLM;
use MIME::Base64;

my $user = "test";
my $domain = "test";
my $passwd = "test";
my $msg1 = "TlRMTVNTUAABAAAAB7IAAAQABAAgAAAABAAEACQAAAB0ZXN0dGVzdA==";
my $challenge = "TlRMTVNTUAACAAAABAAEADAAAAAFggEAQUJDREVGR0gAAAAAAAAAAAAAAAAAAAAAdGVzdA==";
my $msg2 = "TlRMTVNTUAADAAAAGAAYAEAAAAAYABgAWAAAAAQABABwAAAACAAIAHQAAAAIAAgAfAAAAAAAAABEAAAABYIBAJ7/TlMo4HLg0gOk6iKq4bv2vk35ozHEKKoqG8nTkQ5S82zyqpJzxPDJHUMynnKsBHRlc3R0AGUAcwB0AHQAZQBzAHQA";

# 2: username

ok(ntlm_user($user) eq $user, 'ntlm_user');

# 3: domain

ok(ntlm_domain($domain) eq $domain, 'ntlm_domain');

# 4: password

ok(ntlm_password($passwd) eq $passwd, 'ntlm_password');

# 5: initial message

my $reply1 = ntlm();
ok($reply1 eq $msg1, 'reply 1');

# 6-12: decode challenge - not normally user accessed

my $c = &Authen::NTLM::decode_challenge(decode_base64($challenge));
ok($c->{ident} eq "NTLMSSP", 'header');
ok($c->{type} == 2, 'type');
ok($c->{flags} == 0x00018205, 'flags');
ok($c->{data} eq "ABCDEFGH", 'data');
ok($c->{domain}{len} == 4, 'domain length');
ok($c->{domain}{offset} == 48, 'domain offset');
ok($c->{buffer} eq "test", 'contents');

# 13: challenge response

my $reply2 = ntlm($challenge);
ok($reply2 eq $msg2, 'reply 2');

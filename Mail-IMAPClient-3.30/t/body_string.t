#!/usr/bin/perl
#
# tests for body_string()
#
# body_string() calls fetch() internally. rather than refactor
# body_string() just for testing, we subclass M::IC and use the
# overidden fetch() to feed it test data.

use strict;
use warnings;
use IO::Socket qw(:crlf);
use Test::More tests => 3;

BEGIN { use_ok('Mail::IMAPClient') or exit; }

my @tests = (
    [
        "simple fetch",
        [
          '12 FETCH 1 BODY[TEXT]',
          '* 1 FETCH (FLAGS (\\Seen \\Recent) BODY[TEXT]',
          "This is a test message$CRLF" . "Line Z (last line)$CRLF",
          ")$CRLF",
          "12 OK Fetch completed.$CRLF",
        ],
        [ 1 ],
        "This is a test message$CRLF" . "Line Z (last line)$CRLF",
    ],

    # 2010-05-27: test for bug reported by Heiko Schlittermann
    [
        "uwimap IMAP4rev1 2007b.404 fetch unseen",
        [
          '4 FETCH 1 BODY[TEXT]',
          '* 1 FETCH (BODY[TEXT]',
          "This is a test message$CRLF" . "Line Z (last line)$CRLF",
          ")$CRLF",
          "* 1 FETCH (FLAGS (\\Recent \\Seen)$CRLF",
          "4 OK Fetch completed$CRLF",
        ],
        [ 1 ],
        "This is a test message$CRLF" . "Line Z (last line)$CRLF",
    ],
);

package Test::Mail::IMAPClient;

use base qw(Mail::IMAPClient);

sub new {
    my ( $class, %args ) = @_;
    my %me = %args;
    return bless \%me, $class;
}

sub fetch {
    my ( $self, @args ) = @_;
    return $self->{_next_fetch_response} || [];
}

package main;

sub run_tests {
    my ( $imap, $tests ) = @_;

    for my $test (@$tests) {
        my ( $comment, $fetch, $request, $response ) = @$test;
        $imap->{_next_fetch_response} = $fetch;
        my $r = $imap->body_string(@$request);
        is_deeply( $r, $response, $comment );
    }
}

my $imap = Test::Mail::IMAPClient->new( Uid => 0, Debug => 0 );

run_tests( $imap, \@tests );

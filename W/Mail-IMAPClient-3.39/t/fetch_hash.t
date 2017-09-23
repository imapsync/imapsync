#!/usr/bin/perl
#
# tests for fetch_hash()
#
# fetch_hash() calls fetch() internally. rather than refactor
# fetch_hash() just for testing, we instead subclass M::IC and use the
# overidden fetch() to feed it test data.

use strict;
use warnings;
use Test::More tests => 27;

BEGIN { use_ok('Mail::IMAPClient') or exit; }

my @tests = (
    [
        "unquoted value",
        [ q{* 1 FETCH (UNQUOTED foobar)}, ],
        [ [1], qw(UNQUOTED) ],
        { "1" => { "UNQUOTED" => q{foobar}, } },
    ],
    [
        "quoted value",
        [ q{* 1 FETCH (QUOTED "foo bar baz")}, ],
        [ [1], qw(QUOTED) ],
        { "1" => { "QUOTED" => q{foo bar baz}, }, },
    ],
     [
        "escaped-backslash before end-quote",
        [ q{* 1 FETCH (QUOTED "foo bar baz\\\\")}, ],
        [ [1], qw(QUOTED) ],
        { "1" => { "QUOTED" => q{foo bar baz\\\\}, }, },
    ],
    [
        "parenthesized value",
        [ q{* 1 FETCH (PARENS (foo bar))}, ],
        [ [1], qw(PARENS) ],
        { "1" => { "PARENS" => q{foo bar}, }, },
    ],
    [
        "parenthesized value with quotes",
        [ q{* 1 FETCH (PARENS (foo "bar" baz))}, ],
        [ [1], qw(PARENS) ],
        { "1" => { "PARENS" => q{foo "bar" baz}, }, },
    ],
    [
        "parenthesized value with parens at start",
        [ q{* 1 FETCH (PARENS ((foo) bar baz))}, ],
        [ [1], qw(PARENS) ],
        { "1" => { "PARENS" => q{(foo) bar baz}, }, },
    ],
    [
        "parenthesized value with parens in middle",
        [ q{* 1 FETCH (PARENS (foo (bar) baz))}, ],
        [ [1], qw(PARENS) ],
        { "1" => { "PARENS" => q{foo (bar) baz}, }, },
    ],
    [
        "parenthesized value with parens at end",
        [ q{* 1 FETCH (PARENS (foo bar (baz)))}, ],
        [ [1], qw(PARENS) ],
        { "1" => { "PARENS" => q{foo bar (baz)}, }, },
    ],
    [
        "parenthesized value with quoted parentheses",
        [ q{* 1 FETCH (PARENS (foo "(bar)" baz))}, ],
        [ [1], qw(PARENS) ],
        { "1" => { "PARENS" => q{foo "(bar)" baz}, }, },
    ],
    [
        "parenthesized value with quoted unclosed parentheses",
        [ q{* 1 FETCH (PARENS (foo "(bar" baz))}, ],
        [ [1], qw(PARENS) ],
        { "1" => { "PARENS" => q{foo "(bar" baz}, }, },
    ],
    [
        "parenthesized value with quoted unopened parentheses",
        [ q{* 1 FETCH (PARENS (foo "bar)" baz))}, ],
        [ [1], qw(PARENS) ],
        { "1" => { "PARENS" => q{foo "bar)" baz}, }, },
    ],
    [
        "complex parens",
        [ q{* 1 FETCH (PARENS ((((foo) "bar") baz (quux))))}, ],
        [ [1], qw(PARENS) ],
        { "1" => { "PARENS" => q{(((foo) "bar") baz (quux))}, }, },
    ],
    [
        "basic literal value",
        [ q{* 1 FETCH (LITERAL}, q{foo}, q{)}, ],
        [ [1], qw(LITERAL) ],
        { "1" => { "LITERAL" => q{foo}, }, },
    ],
    [
        "multiline literal value",
        [ q{* 1 FETCH (LITERAL}, q{foo\r\nbar\r\nbaz\r\n}, q{)}, ],
        [ [1], qw(LITERAL) ],
        { "1" => { "LITERAL" => q{foo\r\nbar\r\nbaz\r\n}, }, },
    ],
    [
        "multiple attributes",
        [ q{* 1 FETCH (FOO foo BAR bar BAZ baz)}, ],
        [ [1], qw(FOO BAR BAZ) ],
        {
            "1" => {
                "FOO" => q{foo},
                "BAR" => q{bar},
                "BAZ" => q{baz},
            },
        },
    ],
    [
        "dotted attribute",
        [ q{* 1 FETCH (FOO.BAR foobar)}, ],
        [ [1], qw(FOO.BAR) ],
        { "1" => { "FOO.BAR" => q{foobar}, }, },
    ],
    [
        "complex attribute",
        [ q{* 1 FETCH (FOO.BAR[BAZ (QUUX)] quuz)}, ],
        [ [1], q{FOO.BAR[BAZ (QUUX)]} ],
        { "1" => { q{FOO.BAR[BAZ (QUUX)]} => q{quuz}, }, },
    ],
    [
        "BODY.PEEK[] requests match BODY[] responses",
        [q{* 1 FETCH (BODY[] foo)}],
        [ [1], qw(BODY.PEEK[]) ],
        { "1" => { "BODY[]" => q{foo}, }, },
    ],
    [
        "BODY.PEEK[] requests match BODY.PEEK[] responses also",
        [q{* 1 FETCH (BODY.PEEK[] foo)}],
        [ [1], qw(BODY.PEEK[]) ],
        { "1" => { "BODY.PEEK[]" => q{foo}, }, },
    ],
    [
        "BODY[]<0.1024> requests match BODY[]<0> responses",
        [ q{* 1 FETCH (BODY[]<0>}, q{foo}, ")\r\n" ],
        [ [1], qw(BODY[]<0.1024>) ],
        { "1" => { "BODY[]<0>" => q{foo}, }, },
    ],
    [
        "BODY.PEEK[]<0.1024> requests match BODY[]<0> responses",
        [ q{* 1 FETCH (BODY[]<0>}, q{foo}, ")\r\n" ],
        [ [1], qw(BODY.PEEK[]<0.1024>) ],
        { "1" => { "BODY[]<0>" => q{foo}, }, },
    ],
    [
        "non-escaped BODY[HEADER.FIELDS (...)]",
        [
q{* 1 FETCH (FLAGS () BODY[HEADER.FIELDS (TO FROM SUBJECT DATE)]},
            'From: Phil Pearl (Lobbes) <phil+from@perkpartners.com>
To: phil+to@perkpartners.com
Subject: foo "bar\" (baz\)
Date: Sat, 22 Jan 2011 20:43:58 -0500

'
        ],
        [ [1], ( qw(FLAGS), 'BODY[HEADER.FIELDS (TO FROM SUBJECT DATE)]' ) ],
        {
            '1' => {
                'BODY[HEADER.FIELDS (TO FROM SUBJECT DATE)]' =>
                  'From: Phil Pearl (Lobbes) <phil+from@perkpartners.com>
To: phil+to@perkpartners.com
Subject: foo "bar\" (baz\)
Date: Sat, 22 Jan 2011 20:43:58 -0500

',
                'FLAGS' => '',
            },
        },
    ],
);

my @uid_tests = (
    [
        "uid enabled",
        [ q{* 1 FETCH (UID 123 UNQUOTED foobar)}, ],
        [ [123], qw(UNQUOTED) ],
        { "123" => { "UNQUOTED" => q{foobar}, } },
    ],
    [
        "ENVELOPE with escaped-backslash before end-quote",
        [ q{* 1 FETCH (UID 1 FLAGS (\Seen) ENVELOPE ("Fri, 28 Jan 2011 00:03:30 -0500" "Subject" (("Ken N" NIL "ken" "dom.loc")) (("Ken N" NIL "ken" "dom.loc")) (("Ken N" NIL "ken" "dom.loc")) (("Ken Backslash\\\\" NIL "ken.bl" "dom.loc")) NIL NIL NIL "<msgid>")) } ],
        [ [1], qw(UID FLAGS ENVELOPE) ],
        {
            "1" => {
                'UID'        => '1',
                'FLAGS'      => '\\Seen',
                'ENVELOPE' =>
q{"Fri, 28 Jan 2011 00:03:30 -0500" "Subject" (("Ken N" NIL "ken" "dom.loc")) (("Ken N" NIL "ken" "dom.loc")) (("Ken N" NIL "ken" "dom.loc")) (("Ken Backslash\\\\" NIL "ken.bl" "dom.loc")) NIL NIL NIL "<msgid>"}
            },
        },
    ],
    [
        "escaped ENVELOPE subject",
        [
q{* 1 FETCH (UID 1 X-SAVEDATE "28-Jan-2011 16:52:31 -0500" FLAGS (\Seen) ENVELOPE ("Fri, 28 Jan 2011 00:03:30 -0500"},
            q{foo "bar\\" (baz\\)},
q{ (("Phil Pearl" NIL "phil" "dom.loc")) (("Phil Pearl" NIL "phil" "dom.loc")) (("Phil Pearl" NIL "phil" "dom.loc")) ((NIL NIL "phil" "dom.loc")) NIL NIL NIL "<msgid>")) }
        ],
        [ [1], qw(UID X-SAVEDATE FLAGS ENVELOPE) ],
        {
            "1" => {
                'X-SAVEDATE' => '28-Jan-2011 16:52:31 -0500',
                'UID'        => '1',
                'FLAGS'      => '\\Seen',
                'ENVELOPE' =>
q{"Fri, 28 Jan 2011 00:03:30 -0500" "foo \\"bar\\\\\\" (baz\\\\)" (("Phil Pearl" NIL "phil" "dom.loc")) (("Phil Pearl" NIL "phil" "dom.loc")) (("Phil Pearl" NIL "phil" "dom.loc")) ((NIL NIL "phil" "dom.loc")) NIL NIL NIL "<msgid>"}
            },
        },
    ],
    [
        "real life example",
        [
'* 1 FETCH (UID 541 FLAGS (\\Seen) INTERNALDATE "15-Sep-2009 20:05:45 +1000" RFC822.SIZE 771 BODY[HEADER.FIELDS (TO FROM DATE SUBJECT)]',
            'Date: Tue, 15 Sep 2009 20:05:45 +1000
To: rob@pyro
From: rob@pyro
Subject: test Tue, 15 Sep 2009 20:05:45 +1000

',
            ' BODY[]',
            'Return-Path: <rob@pyro>
Delivered-To: rob@pyro
Received: from pyro (pyro [127.0.0.1])
        by pyro.home (Postfix) with ESMTP id A5C8115A066
        for <rob@pyro>; Tue, 15 Sep 2009 20:05:45 +1000 (EST)
Date: Tue, 15 Sep 2009 20:05:45 +1000
To: rob@pyro
From: rob@pyro
Subject: test Tue, 15 Sep 2009 20:05:45 +1000
X-Mailer: swaks v20061116.0 jetmore.org/john/code/#swaks
Message-Id: <20090915100545.A5C8115A066@pyro.home>
Lines: 1

This is a test mailing
',
            ')
',
        ],
        [
            [1],
            q{BODY.PEEK[HEADER.FIELDS (To From Date Subject)]},
            qw(FLAGS INTERNALDATE RFC822.SIZE BODY[])
        ],
        {
            "541" => {
                'BODY[]' => 'Return-Path: <rob@pyro>
Delivered-To: rob@pyro
Received: from pyro (pyro [127.0.0.1])
        by pyro.home (Postfix) with ESMTP id A5C8115A066
        for <rob@pyro>; Tue, 15 Sep 2009 20:05:45 +1000 (EST)
Date: Tue, 15 Sep 2009 20:05:45 +1000
To: rob@pyro
From: rob@pyro
Subject: test Tue, 15 Sep 2009 20:05:45 +1000
X-Mailer: swaks v20061116.0 jetmore.org/john/code/#swaks
Message-Id: <20090915100545.A5C8115A066@pyro.home>
Lines: 1

This is a test mailing
',
                'INTERNALDATE' => '15-Sep-2009 20:05:45 +1000',
                'FLAGS'        => '\\Seen',
                'BODY[HEADER.FIELDS (TO FROM DATE SUBJECT)]' =>
                  'Date: Tue, 15 Sep 2009 20:05:45 +1000
To: rob@pyro
From: rob@pyro
Subject: test Tue, 15 Sep 2009 20:05:45 +1000

',
                'RFC822.SIZE' => '771',
            },
        },
    ],
);

package Test::Mail::IMAPClient;

use vars qw(@ISA);
@ISA = qw(Mail::IMAPClient);

sub new {
    my ( $class, %args ) = @_;
    my %me = %args;
    return bless \%me, $class;
}

sub fetch {
    my ( $self, @args ) = @_;
    return $self->{_next_fetch_response} || [];
}

sub Escaped_results {
    my ( $self, @args ) = @_;
    return $self->{_next_fetch_response} || [];
}

package main;

sub run_tests {
    my ( $imap, $tests ) = @_;

    for my $test (@$tests) {
        my ( $comment, $fetch, $request, $expect ) = @$test;
        $imap->{_next_fetch_response} = $fetch;
        my $r = $imap->fetch_hash(@$request);
        is_deeply( $r, $expect, $comment );
    }
}

my $imap = Test::Mail::IMAPClient->new( Uid => 0 );
run_tests( $imap, \@tests );

$imap->Uid(1);
run_tests( $imap, \@uid_tests );

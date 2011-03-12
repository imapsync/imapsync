#!/usr/bin/perl

use warnings;
use strict;

use Test::More tests => 8;

use_ok('Mail::IMAPClient::BodyStructure');

my $bs = <<'END_OF_BS';
(BODYSTRUCTURE ("TEXT" "PLAIN" ("CHARSET" "us-ascii") NIL NIL "7BIT" 511 20 NIL NIL NIL))^M
END_OF_BS

my $bsobj = Mail::IMAPClient::BodyStructure->new($bs);
ok(defined $bsobj, 'parsed first');
is($bsobj->bodytype, 'TEXT', 'bodytype');
is($bsobj->bodysubtype, 'PLAIN', 'bodysubtype');

my $bs2 = <<'END_OF_BS2';
(BODYSTRUCTURE (("TEXT" "PLAIN" ("CHARSET" "us-ascii") NIL NIL "7BIT" 2 1 NIL NIL NIL)("MESSAGE" "RFC822" NIL NIL NIL "7BIT" 3930 ("Tue, 16 Jul 2002 15:29:17 -0400" "Re: [Fwd: Here is the the list of uids]" (("Michael Etcetera" NIL "michael.etcetera" "generic.com")) (("Michael Etcetera" NIL "michael.etcetera" "generic.com")) (("Michael Etcetera" NIL "michael.etcetera" "generic.com")) (("Michael Etcetera" NIL "michael.etcetera" "generic.com")) (("David J Kavid" NIL "david.kavid" "generic.com")) NIL NIL "<72f9a217.a21772f9@generic.com>") (("TEXT" "PLAIN" ("CHARSET" "us-ascii") NIL NIL "7BIT" 369 11 NIL NIL NIL)("MESSAGE" "RFC822" NIL NIL NIL "7BIT" 2599 ("Tue, 9 Jul 2002 13:42:04 -0400" "Here is the the list of uids" (("Nicholas Kringle" NIL "nicholas.kringle" "generic.com")) (("Nicholas Kringle" NIL "nicholas.kringle" "generic.com")) (("Nicholas Kringle" NIL "nicholas.kringle" "generic.com")) (("Michael Etcetera" NIL "michael.etcetera" "generic.com")) (("Richard W Continued" NIL "richard.continued" "generic.com")) NIL NIL "<015401c2276f$f09b7c10$59cab08c@one.two.generic.com>") ((("TEXT" "PLAIN" ("CHARSET" "iso-8859-1") NIL NIL "QUOTED-PRINTABLE" 256 10 NIL NIL NIL)("TEXT" "HTML" ("CHARSET" "iso-8859-1") NIL NIL "QUOTED-PRINTABLE" 791 22 NIL NIL NIL) "ALTERNATIVE" ("BOUNDARY" "----=_NextPart_001_0151_01C2274E.6969D0F0") NIL NIL) "MIXED" ("BOUNDARY" "----=_NextPart_000_0150_01C2274E.6969D0F0") NIL NIL) 75 NIL NIL NIL) "MIXED" ("BOUNDARY" "--1f34eac2082b02") NIL ("EN")) 118 NIL NIL NIL) "MIXED" ("BOUNDARY" "------------F600BD8FDDD648ABA72A09E0") NIL NIL))
END_OF_BS2

$bsobj = Mail::IMAPClient::BodyStructure->new($bs2) ;
ok(defined $bsobj, 'parsed second');
is($bsobj->bodytype, 'MULTIPART', 'bodytype');
is($bsobj->bodysubtype, 'MIXED', 'bodysubtype');

is(join("#",$bsobj->parts),
    "1#2#2.HEAD#2.1#2.2#2.2.HEAD#2.2.1#2.2.1.1#2.2.1.2", 'parts');

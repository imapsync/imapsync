#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 49;

BEGIN { use_ok('Mail::IMAPClient::BodyStructure') or exit; }

my $bs = <<'END_OF_BS';
(BODYSTRUCTURE ("TEXT" "PLAIN" ("CHARSET" "us-ascii") NIL NIL "7BIT" 511 20 NIL NIL NIL))
END_OF_BS

my $bsobj = Mail::IMAPClient::BodyStructure->new($bs);
ok( defined $bsobj, 'parsed first' );
is( $bsobj->bodytype,    'TEXT',  'bodytype' );
is( $bsobj->bodysubtype, 'PLAIN', 'bodysubtype' );

my $bs2 = <<'END_OF_BS2';
(BODYSTRUCTURE (("TEXT" "PLAIN" ("CHARSET" 'us-ascii') NIL NIL "7BIT" 2 1 NIL NIL NIL)("MESSAGE" "RFC822" NIL NIL NIL "7BIT" 3930 ("Tue, 16 Jul 2002 15:29:17 -0400" "Re: [Fwd: Here is the the list of uids]" (("Michael Etcetera" NIL "michael.etcetera" "generic.com")) (("Michael Etcetera" NIL "michael.etcetera" "generic.com")) (("Michael Etcetera" NIL "michael.etcetera" "generic.com")) (("Michael Etcetera" NIL "michael.etcetera" "generic.com")) (("David J Kavid" NIL "david.kavid" "generic.com")) NIL NIL "<72f9a217.a21772f9@generic.com>") (("TEXT" "PLAIN" ("CHARSET" "us-ascii") NIL NIL "7BIT" 369 11 NIL NIL NIL)("MESSAGE" "RFC822" NIL NIL NIL "7BIT" 2599 ("Tue, 9 Jul 2002 13:42:04 -0400" "Here is the the list of uids" (("Nicholas Kringle" NIL "nicholas.kringle" "generic.com")) (("Nicholas Kringle" NIL "nicholas.kringle" "generic.com")) (("Nicholas Kringle" NIL "nicholas.kringle" "generic.com")) (("Michael Etcetera" NIL "michael.etcetera" "generic.com")) (("Richard W Continued" NIL "richard.continued" "generic.com")) NIL NIL "<015401c2276f$f09b7c10$59cab08c@one.two.generic.com>") ((("TEXT" "PLAIN" ("CHARSET" "iso-8859-1") NIL NIL "QUOTED-PRINTABLE" 256 10 NIL NIL NIL)("TEXT" "HTML" ("CHARSET" "iso-8859-1") NIL NIL "QUOTED-PRINTABLE" 791 22 NIL NIL NIL) "ALTERNATIVE" ("BOUNDARY" "----=_NextPart_001_0151_01C2274E.6969D0F0") NIL NIL) "MIXED" ("BOUNDARY" "----=_NextPart_000_0150_01C2274E.6969D0F0") NIL NIL) 75 NIL NIL NIL) "MIXED" ("BOUNDARY" "--1f34eac2082b02") NIL ("EN")) 118 NIL NIL NIL) "MIXED" ("BOUNDARY" "------------F600BD8FDDD648ABA72A09E0") NIL NIL))
END_OF_BS2

$bsobj = Mail::IMAPClient::BodyStructure->new($bs2);
ok( defined $bsobj, 'parsed second' );
is( $bsobj->bodytype,    'MULTIPART', 'bodytype' );
is( $bsobj->bodysubtype, 'MIXED',     'bodysubtype' );

is(
    join( "#", $bsobj->parts ),

    # Parsing in version 3.03-3.23, changed (broke) outcome from
    #  this: "1#2#2.HEAD#2.1#2.2#2.2.HEAD#2.2.1#2.2.1.1#2.2.1.2"
    #  to:   "1#2#2.HEAD#2.1#2.1.1#2.1.2#2.1.2.HEAD#2.1.2.1#2.1.2.1.1#2.1.2.1.1.1#2.1.2.1.1.2"
    # Patches to BodyStructure.pm in 3.25 changed it to this:
    "1#2#2.HEAD#2.TEXT#2.1#2.2#2.2.HEAD#2.2.TEXT#2.2.1#2.2.1.1#2.2.1.2",
    'parts'
);

my $bs3 = <<'END_OF_BS3';
FETCH (UID 1 BODYSTRUCTURE (("TEXT" "PLAIN" ("charset" "ISO-8859-1")
NIL NIL "quoted-printable" 1744 0)("TEXT" "HTML" ("charset"
"ISO-8859-1") NIL NIL "quoted-printable" 1967 0) "ALTERNATIVE"))
END_OF_BS3

$bsobj = Mail::IMAPClient::BodyStructure->new($bs3);
ok( defined $bsobj, 'parsed third' );

my $bs4 = <<'END_OF_BS4';
* 9 FETCH (UID 9 BODYSTRUCTURE (("TEXT" "PLAIN" ("charset" "us-ascii") NIL "Notification" "7BIT" 588 0)("MESSAGE" "DELIVERY-STATUS" NIL NIL "Delivery report" "7BIT" 459)("MESSAGE" "RFC822" NIL NIL "Undelivered Message" "8bit" 10286 ("Thu, 31 May 2007 11:25:56 +0200 (CEST)" "*****SPAM***** RE: Daily News" (("admin@activtrades.com" NIL "polettld" "ensma.fr")) (("admin@activtrades.com" NIL "polettld" "ensma.fr")) (("admin@activtrades.com" NIL "polettld" "ensma.fr")) ((NIL NIL "polettld" "ensma.fr")) NIL NIL "NIL" "<20070531133257.92825.qmail@cc299962-a.haaks1.ov.home.nl>") (("TEXT" "PLAIN" ("charset" "iso-8859-1") NIL NIL "7bit" 1510 0)("MESSAGE" "RFC822" ("name" "message" "x-spam-type" "original") NIL "Original message" "8bit" 5718) "MIXED")) "REPORT"))
END_OF_BS4

$bsobj = Mail::IMAPClient::BodyStructure->new($bs4);
ok( defined $bsobj, 'parsed fourth' );

# test bodyMD5, contributed by Micheal Stok
my $bs5 = <<'END_OF_BS5';
* 6 FETCH (UID 17280 BODYSTRUCTURE ((("text" "plain" ("charset" "utf-8") NIL NIL "quoted-printable" 1143 37 NIL NIL NIL)("text" "html" ("charset" "utf-8") NIL NIL "quoted-printable" 4618 106 NIL NIL NIL) "alternative" ("boundary" "Boundary-00=_Z7P340MWKGMMYJ0CCJD0") NIL NIL)("image" "tiff" ("name" "8dd0e430.tif") NIL NIL "base64" 204134 "pmZp5QOBa9BIqFNmvxUiyQ==" ("attachment" ("filename" "8dd0e430.tif")) NIL) "mixed" ("boundary" "Boundary-00=_T7P340MWKGMMYJ0CCJD0") NIL NIL))
END_OF_BS5

my @exp;
$bsobj = Mail::IMAPClient::BodyStructure->new($bs5);
@exp = qw(1 1.1 1.2 2);
ok( defined $bsobj, 'parsed fifth' );
is_deeply( [ $bsobj->parts ], \@exp, 'bs5 parts' )
  or diag( join(" ", $bsobj->parts ) );

#
my $bs6 = q{(BODYSTRUCTURE (("text" "plain" ("charset" "UTF-8" "format" "flowed") NIL NIL "8bit" 82 6 NIL NIL NIL NIL)("message" "rfc822" ("name" "this is internal letter.eml") NIL NIL "7bit" 243436 ("Mon, 24 Aug 2009 10:51:22 +0400" "this is internal letter" ((NIL NIL "icestar" "inbox.ru")) ((NIL NIL "icestar" "inbox.ru")) ((NIL NIL "icestar" "inbox.ru")) ((NIL NIL "dima" "adriver.ru")) NIL NIL NIL "<4A92386A.9080307@inbox.ru>") (("text" "plain" ("charset" "UTF-8" "format" "flowed") NIL NIL "7bit" 116 7 NIL NIL NIL NIL)("text" "xml" ("name" "mediaplan.xml" "charset" "us-ascii") NIL NIL "base64" 31412 424 NIL ("inline" ("filename" "mediaplan.xml")) NIL NIL)("application" "zip" ("name" "banners2.zip") NIL NIL "base64" 209942 NIL ("inline" ("filename" "banners2.zip")) NIL NIL) "mixed" ("boundary" "------------070804080502030807020509") NIL NIL NIL) 3326 NIL ("inline" ("filename" "this is internal letter.eml")) NIL NIL) "mixed" ("boundary" "------------070704030806000803040203") NIL NIL NIL))};

$bsobj = Mail::IMAPClient::BodyStructure->new($bs6);
@exp   = qw(1 2 2.HEAD 2.TEXT 2.1 2.2 2.3);
ok( defined $bsobj, 'parsed sixth' );
is_deeply( [ $bsobj->parts ], \@exp, 'bs6 parts' )
  or diag( join(" ", $bsobj->parts ) );

#
my $bs7 = q{(BODYSTRUCTURE (("text" "plain" ("charset" "us-ascii") NIL NIL "7bit" 20 1 NIL NIL NIL NIL)("message" "rfc822" NIL NIL NIL "7bit" 1810 ("Fri,07 May 2010 01:55:07 -0400" "wrap inner a" (("Phil Pearl" NIL "phil" "perkpartners.com")) (("Phil Pearl" NIL "phil" "perkpartners.com")) (("Phil Pearl" NIL "phil" "perkpartners.com")) ((NIL NIL "phil" "perkpartners.com")) NIL NIL NIL "<25015.1273211707@local>") (("text" "plain" ("charset" "us-ascii") NIL NIL "7bit" 27 3 NIL NIL NIL NIL)("message" "rfc822" NIL NIL NIL "7bit" 783 ("Fri, 07 May 2010 01:54:14 -0400" "inner msg #1" (("Phil Pearl" NIL "phil" "perkpartners.com")) (("Phil Pearl" NIL "phil" "perkpartners.com")) (("Phil Pearl" NIL "phil" "perkpartners.com")) ((NIL NIL "phil" "perkpartners.com")) NIL NIL NIL "<24986.1273211654@local>") ("text" "plain" ("charset" "us-ascii") NIL NIL "7bit" 25 3 NIL NIL NIL NIL) 23 NIL ("inline" ("filename" "52")) NIL NIL) "mixed" ("boundary" "=-=-=") NIL NIL NIL) 58 NIL ("inline" ("filename" "53")) NIL NIL) "mixed" ("boundary""==-=-=") NIL NIL NIL))};

$bsobj = Mail::IMAPClient::BodyStructure->new($bs7);
@exp   = qw(1 2 2.HEAD 2.TEXT 2.1 2.2 2.2.HEAD 2.2.1);
ok( defined $bsobj, 'parsed seventh' );
is_deeply( [ $bsobj->parts ], \@exp, 'bs7 parts' )
  or diag( join(" ", $bsobj->parts ) );

#
my $bs8 = q{(BODYSTRUCTURE (("text" "plain" ("charset" "us-ascii") NIL NIL "7bit" 31 2 NIL NIL NIL NIL)("message" "rfc822" NIL NIL "My forwarded message" "7bit" 2833 ("Fri, 07 May 2010 01:55:40 -0400" "outer msg" (("Phil Pearl" NIL "phil" "perkpartners.com")) (("Phil Pearl" NIL "phil" "perkpartners.com")) (("Phil Pearl" NIL "phil" "perkpartners.com")) ((NIL NIL "phil" "perkpartners.com")) NIL NIL NIL "<25030.1273211740@local>") (("text" "plain" ("charset" "us-ascii") NIL NIL "7bit" 20 1 NIL NIL NIL NIL)("message" "rfc822" NIL NIL NIL "7bit" 1810 ("Fri, 07 May 2010 01:55:07 -0400" "wrap inner a" (("Phil Pearl" NIL "phil" "perkpartners.com")) (("Phil Pearl" NIL "phil" "perkpartners.com")) (("Phil Pearl" NIL "phil" "perkpartners.com")) ((NIL NIL "phil" "perkpartners.com")) NIL NIL NIL "<25015.1273211707@local>") (("text" "plain" ("charset" "us-ascii") NIL NIL "7bit" 27 3 NIL NIL NIL NIL)("message" "rfc822" NIL NIL NIL "7bit" 783 ("Fri, 07 May 2010 01:54:14 -0400" "inner msg #1" (("Phil Pearl" NIL "phil" "perkpartners.com")) (("Phil Pearl" NIL "phil" "perkpartners.com")) (("Phil Pearl" NIL "phil" "perkpartners.com")) ((NIL NIL "phil" "perkpartners.com")) NIL NIL NIL "<24986.1273211654@local>") ("text" "plain" ("charset" "us-ascii") NIL NIL "7bit" 25 3 NIL NIL NIL NIL) 23 NIL ("inline" ("filename" "52")) NIL NIL) "mixed" ("boundary" "=-=-=") NIL NIL NIL) 58 NIL ("inline" ("filename" "53")) NIL NIL) "mixed" ("boundary" "==-=-=") NIL NIL NIL) 91 NIL ("inline" ("filename" "52")) NIL NIL)("text" "plain" ("charset" "us-ascii") NIL NIL "7bit" 30 2 NIL NIL NIL NIL)("application" "octet-stream" NIL NIL "My attachment" "7bit" 76 NIL ("attachment" ("filename" ".signature.cell")) NIL NIL)("text" "plain" ("charset" "us-ascii") NIL NIL "7bit" 31 2 NIL NIL NIL NIL) "mixed" ("boundary" "===-=-=") NIL NIL NIL))};

$bsobj = Mail::IMAPClient::BodyStructure->new($bs8);
@exp   = qw(1 2 2.HEAD 2.TEXT 2.1 2.2 2.2.HEAD 2.2.TEXT 2.2.1 2.2.2 2.2.2.HEAD 2.2.2.1 3 4 5);
ok( defined $bsobj, 'parsed eighth' );
is_deeply( [ $bsobj->parts ], \@exp, 'bs8 parts' )
  or diag( join(" ", $bsobj->parts ) );

# Ryan Finnie MIME torture test
my $bs9 = q{(BODYSTRUCTURE (("text" "plain" ("CHARSET" "US-ASCII") NIL NIL "8bit" 617 16 NIL NIL NIL NIL)("message" "rfc822" NIL NIL "I'll be whatever I wanna do. --Fry" "7bit" 582 ("23 Oct 2003 22:25:56 -0700" "plain jane message" (("Ryan Finnie" NIL "rfinnie" "domain.dom")) (("Ryan Finnie" NIL "rfinnie" "domain.dom")) (("Ryan Finnie" NIL "rfinnie" "domain.dom")) ((NIL NIL "bob" "domain.dom")) NIL NIL NIL "<1066973156.4264.42.camel@localhost>") ("text" "plain" ("CHARSET" "US-ASCII") NIL NIL "8bit" 311 9 NIL NIL NIL NIL) 18 NIL ("inline" NIL) NIL NIL)("message" "rfc822" NIL NIL "Would you kindly shut your noise-hole? --Bender" "7bit" 1460 ("23 Oct 2003 23:15:11 -0700" "messages inside messages inside..." (("Ryan Finnie" NIL "rfinnie" "domain.dom")) (("Ryan Finnie" NIL "rfinnie" "domain.dom")) (("Ryan Finnie" NIL "rfinnie" "domain.dom")) ((NIL NIL "bob" "domain.dom")) NIL NIL NIL "<1066976111.4263.74.camel@localhost>") (("text" "plain" ("CHARSET" "US-ASCII") NIL NIL "8bit" 193 3 NIL NIL NIL NIL)("message" "rfc822" NIL NIL "At the risk of sounding negative, no. --Leela" "7bit" 697 ("23 Oct 2003 23:09:05 -0700" "the original message" (("Ryan Finnie" NIL "rfinnie" "domain.dom")) (("Ryan Finnie" NIL "rfinnie" "domain.dom")) (("Ryan Finnie" NIL "rfinnie" "domain.dom")) ((NIL NIL "bob" "domain.dom")) NIL NIL NIL "<1066975745.4263.70.camel@localhost>") (("text" "plain" ("CHARSET" "US-ASCII") NIL NIL "8bit" 78 3 NIL NIL NIL NIL)("application" "x-gzip" ("NAME" "foo.gz") NIL NIL "base64" 58 NIL ("attachment" ("filename" "foo.gz")) NIL NIL) "mixed" ("boundary" "=-XFYecI7w+0shpolXq8bb") NIL NIL NIL) 25 NIL ("inline" NIL) NIL NIL) "mixed" ("boundary" "=-9Brg7LoMERBrIDtMRose") NIL NIL NIL) 49 NIL ("inline" NIL) NIL NIL)("message" "rfc822" NIL NIL "Dirt doesn't need luck! --Professor" "7bit" 817 ("23 Oct 2003 22:40:49 -0700" "this message JUST contains an attachment" (("Ryan Finnie" NIL "rfinnie" "domain.dom")) (("Ryan Finnie" NIL "rfinnie" "domain.dom")) (("Ryan Finnie" NIL "rfinnie" "domain.dom")) ((NIL NIL "bob" "domain.dom")) NIL NIL NIL "<1066974048.4264.62.camel@localhost>") ("application" "x-gzip" ("NAME" "blah.gz") NIL "Attachment has identical content to above foo.gz" "base64" 396 NIL ("attachment" ("filename" "blah.gz")) NIL NIL) 17 NIL ("inline" NIL) NIL NIL)("message" "rfc822" NIL NIL "Hold still, I don't have good depth perception! --Leela" "7bit" 1045 ("23 Oct 2003 23:09:16 -0700" "Attachment filename vs. name" (("Ryan Finnie" NIL "rfinnie" "domain.dom")) (("Ryan Finnie" NIL "rfinnie" "domain.dom")) (("Ryan Finnie" NIL "rfinnie" "domain.dom")) ((NIL NIL "bob" "domain.dom")) NIL NIL NIL "<1066975756.4263.70.camel@localhost>") (("text" "plain" ("CHARSET" "US-ASCII") NIL NIL "8bit" 377 6 NIL NIL NIL NIL)("application" "x-gzip" ("NAME" "blah2.gz") NIL "filename is blah1.gz, name is blah2.gz" "base64" 58 NIL ("attachment" ("filename" "blah1.gz")) NIL NIL) "mixed" ("boundary" "=-1066975756jd02") NIL NIL NIL) 29 NIL ("inline" NIL) NIL NIL)("message" "rfc822" NIL NIL "Hello little man. I WILL DESTROY YOU! --Moro" "7bit" 1149 ("23 Oct 2003 23:09:21 -0700" "No filename? No problem!" (("Ryan Finnie" NIL "rfinnie" "domain.dom")) (("Ryan Finnie" NIL "rfinnie" "domain.dom")) (("Ryan Finnie" NIL "rfinnie" "domain.dom")) ((NIL NIL "bob" "domain.dom")) NIL NIL NIL "<1066975761.4263.70.camel@localhost>") (("text" "plain" ("CHARSET" "US-ASCII") NIL NIL "8bit" 517 10 NIL NIL NIL NIL)("application" "x-gzip" NIL NIL "I'm getting sick of witty things to say" "base64" 58 NIL ("attachment" NIL) NIL NIL) "mixed" ("boundary" "=-1066975756jd03") NIL NIL NIL) 33 NIL ("inline" NIL) NIL NIL)("message" "rfc822" NIL NIL "Friends! Help! A guinea pig tricked me! --Zoidberg" "7bit" 896 ("23 Oct 2003 22:40:45 -0700" "html and text, both inline" (("Ryan Finnie" NIL "rfinnie" "domain.dom")) (("Ryan Finnie" NIL "rfinnie" "domain.dom")) (("Ryan Finnie" NIL "rfinnie" "domain.dom")) ((NIL NIL "bob" "domain.dom")) NIL NIL NIL "<1066974044.4264.62.camel@localhost>") (("text" "html" ("CHARSET" "utf-8") NIL NIL "8bit" 327 11 NIL NIL NIL NIL)("text" "plain" ("CHARSET" "US-ASCII") NIL NIL "8bit" 61 2 NIL NIL NIL NIL) "mixed" ("boundary" "=-ZCKMfHzvHMyK1iBu4kff") NIL NIL NIL) 33 NIL ("inline" NIL) NIL NIL)("message" "rfc822" NIL NIL "Smeesh! --Amy" "7bit" 642 ("23 Oct 2003 22:41:29 -0700" "text and text, both inline" (("Ryan Finnie" NIL "rfinnie" "domain.dom")) (("Ryan Finnie" NIL "rfinnie" "domain.dom")) (("Ryan Finnie" NIL "rfinnie" "domain.dom")) ((NIL NIL "bob" "domain.dom")) NIL NIL NIL "<1066974089.4265.64.camel@localhost>") (("text" "plain" ("CHARSET" "US-ASCII") NIL NIL "8bit" 62 2 NIL NIL NIL NIL)("text" "plain" ("CHARSET" "US-ASCII") NIL NIL "8bit" 68 2 NIL NIL NIL NIL) "mixed" ("boundary" "=-pNc4wtlOIxs8RcX7H/AK") NIL NIL NIL) 24 NIL ("inline" NIL) NIL NIL)("message" "rfc822" NIL NIL "That's not a cigar. Uh... and it's not mine. --Hermes" "7bit" 1515 ("23 Oct 2003 22:39:17 -0700" "HTML and... HTML?" (("Ryan Finnie" NIL "rfinnie" "domain.dom")) (("Ryan Finnie" NIL "rfinnie" "domain.dom")) (("Ryan Finnie" NIL "rfinnie" "domain.dom")) ((NIL NIL "bob" "domain.dom")) NIL NIL NIL "<1066973957.4263.59.camel@localhost>") (("text" "html" ("CHARSET" "utf-8") NIL NIL "8bit" 824 22 NIL NIL NIL NIL)("text" "html" ("NAME" "htmlfile.html" "CHARSET" "UTF-8") NIL NIL "8bit" 118 6 NIL ("attachment" ("filename" "htmlfile.html")) NIL NIL) "mixed" ("boundary" "=-zxh/IezwzZITiphpcbJZ") NIL NIL NIL) 49 NIL ("inline" NIL) NIL NIL)("message" "rfc822" NIL NIL "The spirit is willing, but the flesh is spongy, and bruised. --Zapp" "7bit" 6683 ("23 Oct 2003 22:23:16 -0700" "smiley!" (("Ryan Finnie" NIL "rfinnie" "domain.dom")) (("Ryan Finnie" NIL "rfinnie" "domain.dom")) (("Ryan Finnie" NIL "rfinnie" "domain.dom")) ((NIL NIL "bob" "domain.dom")) NIL NIL NIL "<1066972996.4264.39.camel@localhost>") ((((("text" "plain" ("charset" "us-ascii") NIL NIL "quoted-printable" 1606 42 NIL NIL NIL NIL)("text" "html" ("charset" "utf-8") NIL NIL "quoted-printable" 2173 54 NIL NIL NIL NIL) "alternative" ("boundary" "=-dHujWM/Xizz57x/JOmDF") NIL NIL NIL)("image" "png" ("name" "smiley-3.png") "<1066971953.4232.15.camel@localhost>" NIL "base64" 1122 NIL ("attachment" ("filename" "smiley-3.png")) NIL NIL) "related" ("type" "multipart/alternative" "boundary" "=-GpwozF9CQ7NdF+fd+vMG") NIL NIL NIL)("image" "gif" ("name" "dot.gif") NIL NIL "base64" 96 NIL ("attachment" ("filename" "dot.gif")) NIL NIL) "mixed" ("boundary" "=-CgV5jm9HAY9VbUlAuneA") NIL NIL NIL)("application" "pgp-signature" ("name" "signature.asc") NIL "This is a digitally signed message part" "7bit" 196 NIL NIL NIL NIL) "signed" ("micalg" "pgp-sha1" "protocol" "application/pgp-signature" "boundary" "=-vH3FQO9a8icUn1ROCoAi") NIL NIL NIL) 176 NIL ("inline" NIL) NIL NIL)("message" "rfc822" NIL NIL "Kittens give Morbo gas. --Morbo" "7bit" 3113 ("23 Oct 2003 22:32:37 -0700" "the PROPER way to do alternative/related" (("Ryan Finnie" NIL "rfinnie" "domain.dom")) (("Ryan Finnie" NIL "rfinnie" "domain.dom")) (("Ryan Finnie" NIL "rfinnie" "domain.dom")) ((NIL NIL "bob" "domain.dom")) NIL NIL NIL "<1066973557.4265.51.camel@localhost>") (("text" "plain" ("CHARSET" "US-ASCII") NIL NIL "8bit" 863 22 NIL NIL NIL NIL)(("text" "html" ("CHARSET" "utf-8") NIL NIL "8bit" 1283 22 NIL NIL NIL NIL)("image" "gif" NIL "<1066973340.4232.46.camel@localhost>" NIL "base64" 116 NIL NIL NIL NIL) "related" ("boundary" "=-bFkxH1S3HVGcxi+o/5jG") NIL NIL NIL) "alternative" ("type" "multipart/alternative" "boundary" "=-tyGlQ9JvB5uvPWzozI+y") NIL NIL NIL) 79 NIL ("inline" NIL) NIL NIL) "mixed" ("boundary" "=-qYxqvD9rbH0PNeExagh1") NIL NIL NIL))};

$bsobj = Mail::IMAPClient::BodyStructure->new($bs9);
@exp   = qw(1 2 2.HEAD 2.1 3 3.HEAD 3.TEXT 3.1 3.2 3.2.HEAD 3.2.TEXT 3.2.1 3.2.2 4 4.HEAD 4.1 5 5.HEAD 5.TEXT 5.1 5.2 6 6.HEAD 6.TEXT 6.1 6.2 7 7.HEAD 7.TEXT 7.1 7.2 8 8.HEAD 8.TEXT 8.1 8.2 9 9.HEAD 9.TEXT 9.1 9.2 10 10.HEAD 10.TEXT 10.1 10.1.1 10.1.1.1 10.1.1.1.1 10.1.1.1.2 10.1.1.2 10.1.2 10.2 11 11.HEAD 11.TEXT 11.1 11.2 11.2.1 11.2.2);
ok( defined $bsobj, 'parsed ninth' );
is_deeply( [ $bsobj->parts ], \@exp, 'bs9 parts' )
  or diag( join(" ", $bsobj->parts ) );

# envelope
# date, subject, from, sender, reply-to, to, cc, bcc, in-reply-to, message-id
{
    my $resp = q{* 2 FETCH (UID 42895 ENVELOPE ("Mon, 29 Nov 2010 18:28:23 +0200" "subj" (("Phil Pearl" NIL "phil+from" "dom.loc")) (("Phil Pearl" NIL "phil+sender" "dom.loc")) () ((NIL NIL "phil+to" "dom.loc")) NIL NIL NIL "<msgid>"))};
    my $env = Mail::IMAPClient::BodyStructure::Envelope->new($resp);
    is( $env->subject, "subj", "subject" );
    is( $env->inreplyto, "NIL", "inreplyto" );
    is( $env->messageid, "<msgid>", "messageid" );
    is( $env->bcc, "NIL", "bcc" );
    is( $env->cc, "NIL", "cc" );
    is( $env->replyto, "NIL", "replyto" );

    # personalname mailboxname hostname sourcename
    my $to = $env->to_addresses;
    is_deeply( $to, [ '<phil+to@dom.loc>' ], "to_addresses" );
}

# envelope: parse_string
# date, subject, from, sender, reply-to, to, cc, bcc, in-reply-to, message-id
{
    my $str = q{"Mon, 29 Nov 2010 18:28:23 +0200" "subj" (("Phil Pearl" NIL "phil+from" "dom.loc")) (("Phil Pearl" NIL "phil+sender" "dom.loc")) () ((NIL NIL "phil+to" "dom.loc")) NIL NIL NIL "<msgid>"};
    my $env = Mail::IMAPClient::BodyStructure::Envelope->parse_string($str);
    is( $env->subject, "subj", "subject" );
    is( $env->inreplyto, "NIL", "inreplyto" );
    is( $env->messageid, "<msgid>", "messageid" );
    is( $env->bcc, "NIL", "bcc" );
    is( $env->cc, "NIL", "cc" );
    is( $env->replyto, "NIL", "replyto" );

    # personalname mailboxname hostname sourcename
    my $to = $env->to_addresses;
    is_deeply( $to, [ '<phil+to@dom.loc>' ], "to_addresses" );
}

# envelope: parse_string
# date, subject, from, sender, reply-to, to, cc, bcc, in-reply-to, message-id
{
    my $str = q{("Mon, 29 Nov 2010 18:28:23 +0200" "subj" (("Phil Pearl" NIL "phil+from" "dom.loc")) (("Phil Pearl" NIL "phil+sender" "dom.loc")) () ((NIL NIL "phil+to" "dom.loc")) NIL NIL NIL "<msgid>")};
    my $env = Mail::IMAPClient::BodyStructure::Envelope->parse_string($str);
    is( $env->subject, "subj", "subject" );
    is( $env->inreplyto, "NIL", "inreplyto" );
    is( $env->messageid, "<msgid>", "messageid" );
    is( $env->bcc, "NIL", "bcc" );
    is( $env->cc, "NIL", "cc" );
    is( $env->replyto, "NIL", "replyto" );

    # personalname mailboxname hostname sourcename
    my $to = $env->to_addresses;
    is_deeply( $to, [ '<phil+to@dom.loc>' ], "to_addresses" );
}

# envelope: parse_string with backslashes
# date, subject, from, sender, reply-to, to, cc, bcc, in-reply-to, message-id
{
    my $str = q{("Thu, 19 Jun 2014 17:12:34 -0700" "subj" (("Ken N" NIL "ken+from" "dom.loc")) (("Ken N" NIL "ken+sender" "dom.loc")) () (("backslash\\\\" NIL "ken+to" "dom.loc")) NIL NIL NIL "<msgid>")};
    my $env = Mail::IMAPClient::BodyStructure::Envelope->parse_string($str);
    ok( defined $env, 'parsed envelope string with backslashes' );
  SKIP: {
      skip "ENVELOPE could not be parsed", 7 unless defined $env;
      is( $env->subject, "subj", "subject" );
      is( $env->inreplyto, "NIL", "inreplyto" );
      is( $env->messageid, "<msgid>", "messageid" );
      is( $env->bcc, "NIL", "bcc" );
      is( $env->cc, "NIL", "cc" );
      is( $env->replyto, "NIL", "replyto" );

      # personalname mailboxname hostname sourcename
      my $to = $env->to_addresses;
      is_deeply( $to, [ 'backslash\\\\ <ken+to@dom.loc>' ], "to_addresses" );
    }
}

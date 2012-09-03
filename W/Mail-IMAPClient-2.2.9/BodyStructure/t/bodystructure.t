# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'
# $Id: bodystructure.t,v 1.1 2002/08/23 14:34:40 dkernen Exp $
######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .

use Mail::IMAPClient::BodyStructure;
use warnings;

BEGIN {
	print "1..8\n";
        $main::loaded = 1;
        $| = 1;
        print "ok 1\n";
}
my $bs=<<"END_OF_BS";
(BODYSTRUCTURE ("TEXT" "PLAIN" ("CHARSET" "us-ascii") NIL NIL "7BIT" 511 20 NIL NIL NIL))^M
END_OF_BS
my $bsobj = Mail::IMAPClient::BodyStructure->new($bs) ;
if ($bsobj) { print "ok 2\n" } else {
	print "not ok 2\n"; 
	exit;
}
if ($bsobj->bodytype eq 'TEXT') { print "ok 3\n" } 
else {print "not ok 3 (expected 'TEXT' ; got '" . $bsobj->bodytype . "')\n"}
if ($bsobj->bodysubtype eq 'PLAIN') { print "ok 4\n" } 
else {print "not ok 4 (expected 'PLAIN' ; got '" . $bsobj->bodytype . "')\n"}

my $bs2 = <<'END_OF_BS2';
(BODYSTRUCTURE (("TEXT" "PLAIN" ("CHARSET" "us-ascii") NIL NIL "7BIT" 2 1 NIL NIL NIL)("MESSAGE" "RFC822" NIL NIL NIL "7BIT" 3930 ("Tue, 16 Jul 2002 15:29:17 -0400" "Re: [Fwd: Here is the the list of uids]" (("Michael Etcetera" NIL "michael.etcetera" "generic.com")) (("Michael Etcetera" NIL "michael.etcetera" "generic.com")) (("Michael Etcetera" NIL "michael.etcetera" "generic.com")) (("Michael Etcetera" NIL "michael.etcetera" "generic.com")) (("David J Kavid" NIL "david.kavid" "generic.com")) NIL NIL "<72f9a217.a21772f9@generic.com>") (("TEXT" "PLAIN" ("CHARSET" "us-ascii") NIL NIL "7BIT" 369 11 NIL NIL NIL)("MESSAGE" "RFC822" NIL NIL NIL "7BIT" 2599 ("Tue, 9 Jul 2002 13:42:04 -0400" "Here is the the list of uids" (("Nicholas Kringle" NIL "nicholas.kringle" "generic.com")) (("Nicholas Kringle" NIL "nicholas.kringle" "generic.com")) (("Nicholas Kringle" NIL "nicholas.kringle" "generic.com")) (("Michael Etcetera" NIL "michael.etcetera" "generic.com")) (("Richard W Continued" NIL "richard.continued" "generic.com")) NIL NIL "<015401c2276f$f09b7c10$59cab08c@one.two.generic.com>") ((("TEXT" "PLAIN" ("CHARSET" "iso-8859-1") NIL NIL "QUOTED-PRINTABLE" 256 10 NIL NIL NIL)("TEXT" "HTML" ("CHARSET" "iso-8859-1") NIL NIL "QUOTED-PRINTABLE" 791 22 NIL NIL NIL) "ALTERNATIVE" ("BOUNDARY" "----=_NextPart_001_0151_01C2274E.6969D0F0") NIL NIL) "MIXED" ("BOUNDARY" "----=_NextPart_000_0150_01C2274E.6969D0F0") NIL NIL) 75 NIL NIL NIL) "MIXED" ("BOUNDARY" "--1f34eac2082b02") NIL ("EN")) 118 NIL NIL NIL) "MIXED" ("BOUNDARY" "------------F600BD8FDDD648ABA72A09E0") NIL NIL))
END_OF_BS2

$bsobj = Mail::IMAPClient::BodyStructure->new($bs2) ;
if ($bsobj) { print "ok 5\n" } else {print "not ok 5\n"}
if ($bsobj->bodytype eq 'MULTIPART') { print "ok 6\n" } 
else {print "not ok 6 (expected 'MULTIPART' ; got '" . $bsobj->bodytype . "')\n"}
if ($bsobj->bodysubtype eq 'MIXED') { print "ok 7\n" } 
else {print "not ok 7 (expected 'MIXED' ; got '" . $bsobj->bodytype . "')\n"}
if (join("#",$bsobj->parts) eq "1#2#2.HEAD#2.1#2.2#2.2.HEAD#2.2.1#2.2.1.1#2.2.1.2") {
print "ok 8\n";
} else {print "not ok 8\n"}

END {print "not ok 1\n" unless $main::loaded;}


# History:
# $Log: bodystructure.t,v $
# Revision 1.1  2002/08/23 14:34:40  dkernen
#
# Modified Files:	Changes IMAPClient.pm Makefile Makefile.PL test.txt for version 2.2.0
# Added Files: Makefile Makefile.PL Parse.grammar Parse.pm Parse.pod  version 2.2.0
# Added Files: parse.t  for version 2.2.0
# Added Files: bodystructure.t  for 2.2.0
#

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'
# $Id: parse.t,v 1.2 2002/08/30 20:48:34 dkernen Exp $
######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .

use Mail::IMAPClient::BodyStructure::Parse;

BEGIN {
	print "1..1\n";
        $main::loaded = 1;
        $| = 1;
        print "ok 1\n";
}
END {print "not ok 1\n" unless $main::loaded;}


# History:
# $Log: parse.t,v $
# Revision 1.2  2002/08/30 20:48:34  dkernen
#
# #
# Modified Files:
# 	Changes IMAPClient.pm MANIFEST Makefile Makefile.PL README
# 	Todo test.txt
# 	BodyStructure/Parse/Makefile
# 	BodyStructure/Parse/Parse.pm
# 	BodyStructure/Parse/Parse.pod
# 	BodyStructure/Parse/t/parse.t
# for version 2.2.1
# #
#
# Revision 1.1  2002/08/23 14:34:29  dkernen
#
# Modified Files:	Changes IMAPClient.pm Makefile Makefile.PL test.txt for version 2.2.0
# Added Files: Makefile Makefile.PL Parse.grammar Parse.pm Parse.pod  version 2.2.0
# Added Files: parse.t  for version 2.2.0
#

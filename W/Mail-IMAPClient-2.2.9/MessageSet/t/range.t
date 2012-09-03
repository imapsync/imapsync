#!/usr/local/bin/perl 
#$Id: range.t,v 1.2 2003/06/12 21:42:17 dkernen Exp $

END {print "not ok 1\n" unless $main::loaded;}
use Mail::IMAPClient::MessageSet;

BEGIN {
        $| = 1;
	print "1..7\n";
       $main::loaded = 1;
        print "ok 1\n";
}
my $one = q/1:4,3:6,10:15,20:25,2:8/;
my $range = Mail::IMAPClient::MessageSet->new($one);
if ( "$range" eq "1:8,10:15,20:25" ) {
	print "ok 2\n";
} else {
	print "not ok 2 ($range)\n";
}
if ( join(",",$range->unfold) eq 
	"1,2,3,4,5,6,7,8,10,11,12,13,14,15,20,21,22,23,24,25"
) {
	print "ok 3\n";
} else {
	print "not ok 3 (",join("",$range->unfold),")\n";
}

$range .= "30,31,32,31:34,40:44";
if ( "$range" eq "1:8,10:15,20:25,30:34,40:44" ) {

	print "ok 4\n";
} else {
	print "not ok 4 ($range)\n";
}
if ( join(",",$range->unfold) eq 
	"1,2,3,4,5,6,7,8,10,11,12,13,14,15,20,21,22,23,24,25," .
	"30,31,32,33,34,40,41,42,43,44"	
) {
	print "ok 5\n";
} else {
	print "not ok 5 (",join("",$range->unfold),")\n";
}

$range -= "1:2";
if ( "$range" eq "3:8,10:15,20:25,30:34,40:44" ) {
	print "ok 6\n";
} else {
	print "not ok 6 ($range)\n";
}
if ( join(",",$range->unfold) eq 
	"3,4,5,6,7,8,10,11,12,13,14,15,20,21,22,23,24,25," .
	"30,31,32,33,34,40,41,42,43,44"	
) {
	print "ok 7\n";
} else {
	print "not ok 7 (",join("",$range->unfold),")\n";
}

exit;


# History:
# $Log: range.t,v $
# Revision 1.2  2003/06/12 21:42:17  dkernen
# Cleaning up cvs repository
#
# Revision 1.1  2003/06/12 21:37:24  dkernen
#
# Preparing 2.2.8
# Added Files: COPYRIGHT
# Modified Files: Parse.grammar
# Added Files: Makefile.old
# 	Makefile.PL Todo sample.perldb
# 	BodyStructure.pm
# 	Parse.grammar Parse.pod
#  	range.t
#
# Revision 1.1  2002/10/23 20:46:00  dkernen
#
# Modified Files: Changes IMAPClient.pm MANIFEST Makefile.PL
# Added Files: Makefile.PL MessageSet.pm
# Added Files: range.t
#
#

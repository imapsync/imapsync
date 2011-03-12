# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'
# $Id: thread.t,v 1.1 2002/08/30 20:50:43 dkernen Exp $
######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .

use Mail::IMAPClient::Thread;

BEGIN {
	print "1..6\n";
        $main::loaded = 1;
        $| = 1;
        print "ok 1\n";
}

$t1 = <<'e1';
* THREAD (166)(167)(168)(169)(172)(170)(171)(173)(174 175 176 178 181 180)(179)(177 183 182 188 184 185 186 187 189)(190)(191)(192)(193)(194 195)(196 197 198)(199)(200 202)(201)(203)(204)(205)(206 207)(208) 
e1
$t2 = <<'e2';
* THREAD (166)(167)(168)(169)(172)((170)(179))(171)(173)((174)(175)(176)(178)(181)(180))((177)(183)(182)(188 (184)(189))(185 186)(187))(190)(191)(192)(193)((194)(195 196))(197 198)(199)(200 202)(201)(203)(204)(205 206 207)(208)
e2

my $parser = Mail::IMAPClient::Thread->new;

if ( $parser ) {
	print "ok 2\n";
} else {
	print "not ok 2\n";
}

my $thr1 = $parser->start($t1) ;

if ( $thr1 ) {
	print "ok 3\n";
} else {
	print "not ok 3\n";
}

if ( scalar(@$thr1) == 25 ) {
	print "ok 4\n";
} else {
	print "not ok 4\n";
}

my $thr2 = $parser->start($t2) ;

if ( $thr2 ) {
	print "ok 5\n";
} else {
	print "not ok 5\n";
}
if ( scalar(@$thr2) == 23 ) {
	print "ok 6\n";
} else {
	print "not ok 6\n";
}


END {print "not ok 1\n" unless $main::loaded;}


# History:
# $Log: thread.t,v $
# Revision 1.1  2002/08/30 20:50:43  dkernen
#
# Added Files: Thread/Makefile.PL Thread/Thread.grammar Thread/Thread.pod
# Added Files: Thread/t/thread.t
#
#

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'
# $Id: cram-md5.t,v 19991216.1 2003/06/12 21:38:36 dkernen Exp $
######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .

use Mail::IMAPClient;

######################### End of black magic.


my $test = 0;
my %parms;
my $imap;
my @tests;
my $uid;

=begin debugging

$db = IO::File->new(">/tmp/de.bug");
local *TMP = $db ;
open(STDERR,">&TMP");
select(((select($db),$|=1))[0]);

=end debugging

=cut

if (open TST,"./test.txt" ) {
        while (defined(my $l = <TST>)) {
                chomp $l;
                my($p,$v)=split(/=/,$l);
                for($p,$v) { s/(?:^\s+)|(?:\s+$)//g; }
                $parms{$p}=$v if $v;
        }
        close TST;
} else {

	print "1..1\n";
	print "ok 1 (skipped)\n";
	exit;
}
exit unless		%parms 
	and 	length 	$parms{server}
	and 	length 	$parms{user}
	and 	length 	$parms{passed} ;

eval { $imap = Mail::IMAPClient->new( 
		Server 	=> "$parms{server}"||"localhost",
		Port 	=> "$parms{port}"  || '143',
		Clear   => 0,
		Timeout => 30,
		Debug   => $ARGV[0],
		Debug_fh   => 	$ARGV[0]?IO::File->new(">imap1.debug"):undef,
		Fast_IO => 1,
		Uid 	=> 1,
                Authmechanism  => $parms{authmechanism}||undef,
) 	or 
	print STDERR 	"\nCannot connect to $parms{server} to get capabilities. ",
			"Are server/user/password correct?\n" 
	and exit
} ;

$imap->Debug_fh and $imap->Debug_fh->autoflush();
if ( $imap->has_capability("AUTH=CRAM-MD5") ) {
	$authmech = "CRAM-MD5";
	$authmech = "CRAM-MD5";
	do "./t/basic.t";
} else {
	print "1..1\n";
	print "ok 1 (skipped)\n";
	exit;
}

# History:
# $Log: cram-md5.t,v $
# Revision 19991216.1  2003/06/12 21:38:36  dkernen
#
# Preparing 2.2.8
# Added Files: COPYRIGHT
# Modified Files: Parse.grammar
# Added Files: Makefile.old
# 	Makefile.PL Todo sample.perldb
# 	BodyStructure.pm
# 	Parse.grammar Parse.pod
#  	range.t
#  	Thread.grammar
#  	draft-crispin-imapv-17.txt rfc1731.txt rfc2060.txt rfc2062.txt
#  	rfc2221.txt rfc2359.txt rfc2683.txt
#
# Revision 1.1  2003/06/12 21:38:17  dkernen
#
# Preparing 2.2.8
# Added Files: COPYRIGHT
# Modified Files: Parse.grammar
# Added Files: Makefile.old
# 	Makefile.PL Todo sample.perldb
# 	BodyStructure.pm
# 	Parse.grammar Parse.pod
#  	range.t
#  	Thread.grammar
#  	draft-crispin-imapv-17.txt rfc1731.txt rfc2060.txt rfc2062.txt
#  	rfc2221.txt rfc2359.txt rfc2683.txt
#
#

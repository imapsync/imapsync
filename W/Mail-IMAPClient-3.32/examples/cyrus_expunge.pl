#!/usr/local/bin/perl
#$Id$

use Mail::IMAPClient;
use IO::File;

# Change the following line (or replace it with something better):
my($h,$u,$p) = ('cyrus_host','cyrus_admin_id','cyrus_admin_pswd');

my $imap = Mail::IMAPClient->new(	Server  => "$h",			# imap host
					User    => "$u",			# $u,	
					Password=> "$p",			# $p,
					Uid	=> 1,				# True value
					Port    => 143,				# Cyrus
					Debug	=> 0,				# True value
					Buffer	=> 4096*10,			# True value
					Fast_io	=> 1,				# True value
					Timeout	=> 30,				# True value
					# Debug_fh=> IO::File->new(">out.db"),	# fhandle
				) 
or die "$@";

for my $f ( $imap->folders ) {
	print "Expunging $f\n";
	unless ($imap->select($f) ) {
		$imap->setacl($f,$u,"lrswipcda") or warn "Cannot setacl for $f: $@\n" and next;
		$imap->select($f) or warn "Cannot select $f: $@" and next;
	}
	$imap->expunge;
}


=head1 AUTHOR 
	
David J. Kernen

The Kernen Group, Inc.

imap@kernengroup.com

=head1 COPYRIGHT

This example and Mail::IMAPClient are Copyright (c) 2003 
by The Kernen Group, Inc. All rights reserved.

This example is distributed with Mail::IMAPClient and 
subject to the same licensing requirements as Mail::IMAPClient.

imtest is a utility distributed with Cyrus IMAP server, 
Copyright (c) 1994-2000 Carnegie Mellon University.  
All rights reserved. 

=cut

#
#$Log: cyrus_expunge.pl,v $
#Revision 19991216.3  2003/06/12 21:38:31  dkernen
#
#Preparing 2.2.8
#Added Files: COPYRIGHT
#Modified Files: Parse.grammar
#Added Files: Makefile.old
#	Makefile.PL Todo sample.perldb
#	BodyStructure.pm
#	Parse.grammar Parse.pod
# 	range.t
# 	Thread.grammar
# 	draft-crispin-imapv-17.txt rfc1731.txt rfc2060.txt rfc2062.txt
# 	rfc2221.txt rfc2359.txt rfc2683.txt
#
#Revision 1.1  2003/06/12 21:38:14  dkernen
#
#Preparing 2.2.8
#Added Files: COPYRIGHT
#Modified Files: Parse.grammar
#Added Files: Makefile.old
#	Makefile.PL Todo sample.perldb
#	BodyStructure.pm
#	Parse.grammar Parse.pod
# 	range.t
# 	Thread.grammar
# 	draft-crispin-imapv-17.txt rfc1731.txt rfc2060.txt rfc2062.txt
# 	rfc2221.txt rfc2359.txt rfc2683.txt
#
#

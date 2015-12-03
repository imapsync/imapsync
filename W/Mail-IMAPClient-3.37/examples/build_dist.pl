#!/usr/local/bin/perl
#$Id$

use Mail::IMAPClient;

=head1 DESCRIPTION

B<build_dist.pl> accepts the name of a target folder as an argument. It
then opens that folder and rummages through all the mail files in it, looking
for "Reply-to:" headers (or "From:" headers, where there is no "Reply-to:").
It then appends a message into the folder containing all of the addresses in 
thus found as a list of recipients. This message can be used to conveniently 
drag and drop names into an address book, distribution list, or e-mail message,
using the GUI client of choice. 

The email appended to the folder specified in the I<-f> option will have the
subject "buid_dist.pl I<folder> Output".

=head1 SYNTAX

b<build_dist.pl> I<-h>

b<build_dist.pl> I<-s servername -u username -p password -f folder [ -d ]>

=over 4

=item -f The folder name to process.

=item -s The servername of the IMAP server 

=item -u The user to log in as

=item -p The password for the user specified in the I<-u> option

=item -d Tells the IMAP client to turn on debugging info

=item -h Prints out this document

=back

B<NOTE:> You can supply defaults for the above options by updating the script.

=cut

use Getopt::Std;

getopts('s:u:p:f:d');

# Update the following to supply defaults:

$opt_f ||= "default folder";
$opt_s ||= "default server";
$opt_u ||= "default user";
$opt_p ||= "default password";	# security risk: use with caution!

# Let the compiler know we're serious about these two variables:
$opt_h = $opt_h or $opt_d = $opt_d ; 

exec "perldoc $0" if $opt_h;

my $imap = Mail::IMAPClient->new( 
		Server 	=> $opt_s ,
		User 	=> $opt_u ,
		Password=> $opt_p ,
		Debug	=> $opt_d||0 ,
) or die "can't connect to server\n";

$imap->select($opt_f);

my @msgs = $imap->search("NOT SUBJECT",qq("buid_dist.pl $opt_f Output"));
my %list;
foreach my $m (@msgs) {

	my $ref = $imap->parse_headers($m,"Reply-to","From");
	
	warn "Couldn't get recipient address from msg#$m\n" 
		unless 	scalar(@{$ref->{'Reply-to'}})   ||
			scalar(@{$ref->{'From'}})	;	

	my $from = scalar(@{$ref->{'Reply-to'}}) 	? 
			  $ref->{'Reply-to'}[0]		: 
			  $ref->{'From'}[0] 		;

	my $addr = $from; 
	$addr =~ s/.*<//;
	$addr =~ s/[\<\>]//g;
	$list{$addr} = $from unless exists $list{$addr};
}

$append = <<"EOMSG";
To: ${\(join(",",values %list))}
From: $opt_u\@$opt_s
Date: ${\($imap->Rfc822_date(time))}
Subject: build_dist.pl $opt_f Output

The above note was never actually sent to the following people:

${\(join("\n",keys %list))}

Interesting, eh?

Love,
$opt_u

EOMSG

$imap->append($opt_f,$append) or warn "Couldn't append the message.";

$imap->logout;


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


# $Id$
# $Log: build_dist.pl,v $
# Revision 19991216.7  2003/06/12 21:38:29  dkernen
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
# Revision 19991216.6  2000/12/11 21:58:50  dkernen
#
# Modified Files:
# 	build_dist.pl build_ldif.pl copy_folder.pl find_dup_msgs.pl
# 	imap_to_mbox.pl populate_mailbox.pl
# to add CVS data
#
# Revision 19991216.5  1999/12/16 17:19:09  dkernen
# Bring up to same level
#
# Revision 19991124.3  1999/12/16 17:14:22  dkernen
# Incorporate changes for exists method performance enhancement
#
# Revision 19991124.02  1999/11/24 17:46:16  dkernen
# More fixes to t/basic.t
#
# Revision 19991124.01  1999/11/24 16:51:46  dkernen
# Changed t/basic.t to test for UIDPLUS before trying UID cmds
#
# Revision 1.8  1999/11/23 17:51:05  dkernen
# Committing version 1.06 distribution copy
#

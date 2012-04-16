#!/usr/local/bin/perl
#$Id$
use Mail::IMAPClient;
use MIME::Lite;
use Data::Dumper;

=head1 DESCRIPTION

B<build_ldif.pl> accepts the name of a target folder as an argument. It
then opens that folder and rummages through all the mail files in it, looking
for "Reply-to:" headers (or "From:" headers, where there is no "Reply-to:").
It then prints to STDOUT a file in ldif format containing entries for all of 
the addresses that it finds. It also appends a message into the specified folder containing
all of the addresses in both the B<To:> field of the message header and in an 
LDIF-format attachment.

B<build_ldif.pl> requires B<MIME::Lite>.

=head1 SYNTAX

B<build_ldif.pl> I<-h>

B<build_ldif.pl> I<-s servername -u username -p password -f folder [ -d ]>

=over 4

=item -f The folder name to process.

=item -s The servername of the IMAP server 

=item -t Include "To" and "Cc" fields as well as "From"

=item -u The user to log in as

=item -p The password for the user specified in the I<-u> option

=item -d Tells the IMAP client to turn on debugging info

=item -n Suppress delivering message to folder

=item -h Prints out this document

=back

B<NOTE:> You can supply defaults for the above options by updating the script.

=cut

use Getopt::Std;

getopts('hs:u:p:f:dtn');

# Update the following to supply defaults:

$opt_f ||= "default folder";
$opt_s ||= "default server";
$opt_u ||= "default user";
$opt_p ||= "default password";	# security risk: use with caution!

# Let the compiler know we're serious about these variables:
$opt_0 = ( $opt_h or $opt_d or $opt_t or $opt_n or $opt_0); 

exec "perldoc $0" if $opt_h;

my $imap = Mail::IMAPClient->new( 
		Server 	=> $opt_s ,
		User 	=> $opt_u ,
		Password=> $opt_p ,
		Debug	=> $opt_d||0 ,
) or die "can't connect to server\n";

$imap->select($opt_f); $imap->expunge;

my @msgs = $imap->search("NOT SUBJECT",qq("buid_ldif.pl $opt_f Output"));
my %list;
foreach my $m (@msgs) {

	my $ref = $imap->parse_headers($m,"Reply-to","From");
	
	warn "Couldn't get recipient address from msg#$m\n" 
		unless 	scalar(@{$ref->{'Reply-to'}})   ||
			scalar(@{$ref->{'From'}})	;	

	my $from = scalar(@{$ref->{'Reply-to'}}) 	? 
			  $ref->{'Reply-to'}[0]		: 
			  $ref->{'From'}[0] 		;
	my $name = $from				;

	$name =~ s/<.*//				;
	if ($name =~ /\@/) {
		$name = $from				;
		$name =~ s/\@.*//;			;
	}
	$name =~ s/\"//g				;
	$name =~ s/^\s+|\s+$//g				;
	my $addr = $from				; 
	$addr =~ s/.*<//				;
	$addr =~ s/[\<\>]//g				;
	$list{lc($addr)} = [ $addr, $name ]
		unless exists $list{lc($addr)} 		;
	if ($opt_t) {					# Do "To" and "Cc", too
		my $ref = $imap->parse_headers($m,"To","Cc")		;
		my @array = ( 	@{$ref->{To}}	, @{$ref->{Cc}}	)	;
		my @members = ()					;
		foreach my $text (@array) 				{
		  while ( $text =~ /	"([^"\\]*(\\.[^"\\]*)*"[^,]*),?	|
					([^",]+),?			|
					,
			/gx 
		  ) {
			push @members, defined($1)?$1:$3 		;
		  }
		}
		foreach my $to (@members) 				{ 

			my $name = $to					;

			$name =~ s/<.*//				;
			if ($name =~ /\@/) {
				$name = $to				;
				$name =~ s/\@.*//;			;
			}
			$name =~ s/\"//g				;
			$name =~ s/^\s+|\s+$//g				;
			my $addr = $to					; 
			$addr =~ s/.*<//				;
			$addr =~ s/[\<\>]//g				;
			$list{lc($addr)} = [ $addr, $name ]
				unless exists $list{lc($addr)} 		;
		}
	
	}
}

my $text = join "",map {
	qq{dn: cn="} . $list{$_}[1] . 
	qq{", mail=$list{$_}[0]\n} .
	qq{cn: } . $list{$_}[1] . qq{\n} .
	qq{mail: $list{$_}[0]\n} .
	qq{objectclass: top\nobjectclass: person\n\n};
} keys %list ;

# Create a new multipart message:
my $msg = MIME::Lite->new(
        From    => $opt_u,
        map({ ("To" => $list{$_}[0]) } keys %list),
        Subject => "LDIF file from $opt_f",
        Type    =>'TEXT',
        Data    =>"Attached is the LDIF file of addresses from folder $opt_f."
);
$msg->attach(	Type     =>'text/ldif',
		Filename => "$opt_f.ldif",
                Data 	 => $text ,
);
print $text;
$imap->append($opt_f, $msg->as_string) unless $opt_n;
print Dumper($imap) if $opt_d;
$imap->logout;


=head1 AUTHOR 
	
David J. Kernen

The Kernen Group, Inc.

imap@kernengroup.com

=head1 COPYRIGHT

This example and Mail::IMAPClient are Copyright (c) 1999,2003 
by The Kernen Group, Inc. All rights reserved.

This example is distributed with Mail::IMAPClient and 
subject to the same licensing requirements as Mail::IMAPClient.

imtest is a utility distributed with Cyrus IMAP server, 
Copyright (c) 1994-2000 Carnegie Mellon University.  
All rights reserved. 

=cut

# $Id$
# $Log: build_ldif.pl,v $
# Revision 19991216.11  2003/06/12 21:38:30  dkernen
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
# Revision 19991216.10  2002/05/24 15:47:18  dkernen
# Misc fixes
#
# Revision 19991216.9  2000/12/11 21:58:51  dkernen
#
# Modified Files:
# 	build_dist.pl build_ldif.pl copy_folder.pl find_dup_msgs.pl
# 	imap_to_mbox.pl populate_mailbox.pl
# to add CVS data
#
# Revision 19991216.8  2000/03/02 19:57:13  dkernen
#
# Modified Files: build_ldif.pl -- to support new option to all "To:" and "Cc:" to be included in ldif file
#
# Revision 19991216.7  2000/02/21 16:16:10  dkernen
#
# Modified Files: build_ldif.pl  -- to allow for "To:" and "Cc:" header handling and
# to handle quoted names in headers
#
# Revision 19991216.6  1999/12/28 13:56:59  dkernen
# Fixed -h option (help).
#
# Revision 19991216.5  1999/12/16 17:19:10  dkernen
# Bring up to same level
#
# Revision 19991124.3  1999/12/16 17:14:24  dkernen
# Incorporate changes for exists method performance enhancement
#
# Revision 19991124.02  1999/11/24 17:46:18  dkernen
# More fixes to t/basic.t
#
# Revision 19991124.01  1999/11/24 16:51:48  dkernen
# Changed t/basic.t to test for UIDPLUS before trying UID cmds
#
# Revision 1.8  1999/11/23 17:51:05  dkernen
# Committing version 1.06 distribution copy
#

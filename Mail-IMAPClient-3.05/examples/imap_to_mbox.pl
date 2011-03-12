#!/usr/bin/perl
# (c) 1999 Thomas Stromberg, Research Triangle Commerce, Inc.
# This software is protected by the BSD License. No rights reserved anyhow. 
# <tstromberg@rtci.com>

# DESC: Reads a users IMAP folders, and converts them to mbox
#       Good for an interim switch-over from say, Exchange to Cyrus IMAP.

# $Header: /usr/CvsRepository/Mail/IMAPClient/examples/imap_to_mbox.pl,v 19991216.7 2002/08/23 13:29:48 dkernen Exp $

# TODO:
# ----- 
# lsub instead of list option
# correct header printing From


use Mail::IMAPClient;		# a nice set of perl libs for imap 
use Getopt::Std; 			# for the command-line overrides. good for user
use File::Path;				# create full file paths. (yummy!)
use File::Basename;			# find a nice basename for a folder.
$| = 1;

# Config for the imap migration kit. 

getopts('u:p:P:s:i:f::b:dh');

if ($opt_h) { 
	# print help here
}

$SERVER		= $opt_s || 'mailhost';
$USER		= $opt_u || 'userid';
$PASSWORD	= $opt_p || 'password';
$PORT		= $opt_P || '143';
$INBOX_PATH	= $opt_i || "./mail/$USER"; 
$FOLDERS_PATH	= $opt_f || "./folders/$USER"; 
$DONT_MOVE	= $opt_m || '.mailboxlist|Trash|INBOXIIMAP|mlbxl'; 
$READ_DELIMITER	= $opt_r || '/';
$WRITE_DELIMITER= $opt_w || '/'; 
$BANNED_CHARS	= $opt_b || '.|^|%'; 
$DEBUG		= $opt_d || "0";


## do our magic tricks ######################################
&connect_imap;
&find_folders;


sub connect_imap { 
	$imap = Mail::IMAPClient->new(
		Server		=> "$SERVER", 
		User		=> "$USER",
		Password	=> "$PASSWORD",
		Port		=> "$PORT",
		Debug		=> "$DEBUG",
		Uid		=>	'0', 
		Clear		=>	'1', 
	)
	|| die ("Could not connect to $SERVER:$PORT with $USER: $! $?\n");
};

sub find_folders {
	my (@folders, $folder, $message_count, $new_folder, $path);

	@folders = $imap->folders;
	push(@folders, "INBOX");
	foreach $folder (@folders) {
		$message_count = $imap->message_count($folder);
		if (! $message_count) { 
			print("* $folder is empty, skipping.\n");
			next;
		}
		if ($folder =~ /$DONT_MOVE/) { 
			print("! $folder matches DONT_MOVE ruleset, skipping\n");
			next;
		}

		$new_folder = $folder;
		$new_folder =~ s/\./_/g;
		$new_folder =~ s/$READ_DELIMITER/$WRITE_DELIMITER/g;
		if ($new_folder eq "INBOX") { 
			$path = "$INBOX_PATH";
		} else {
			$path = "$FOLDERS_PATH/$new_folder";
		}

		printf("x %4i %-45.45s => %s", $message_count, $folder, $path);
		&write_folder($folder, $path, 1, $message_count); 
	}
}


sub write_folder {
	my($folder, $newpath, $first_message, $last_message) = @_; 
	my($msg_header, $msg_body); 

	$imap->select($folder) || print("Could not examine $folder: $!"); 
	$new_dir	= dirname($newpath);
	$new_file	= basename($newpath);
	mkpath("$new_dir", 0700) unless -d "$new_dir";
	open(mbox, ">$newpath"); 

	for ($i=$first_message; $i<$last_message+1; ++$i) { 
		if ( ($i / 25) == int($i / 25) ) { print("."); }
		$msg_header = $imap->fetch($i, "FAST") || print("Could not fetch header $i from $folder\n");
		$msg_rfc822 = $imap->fetch($i, "RFC822") || print("Could not fetch RFC822 $i from $folder\n");
		undef $start;
		foreach (@$msg_rfc822) {  
			if (($_ =~ /: /) && (! $message))	{ ++$message; print(mbox "From imap\@to.mbox Wed Oct 27 17:02:53 1999\n");}
			if (/^\)\r/)						{ undef $message; print(mbox "\n\n");} 
			next unless $message;
			$_ =~ s/\r$//;
			print(mbox "$_"); 

		}
	}		
	close(mbox);
	print("\n");
}

# $Id: imap_to_mbox.pl,v 19991216.7 2002/08/23 13:29:48 dkernen Exp $ 
# $Log: imap_to_mbox.pl,v $
# Revision 19991216.7  2002/08/23 13:29:48  dkernen
#
# Modified Files: Changes IMAPClient.pm INSTALL MANIFEST Makefile Makefile.PL README Todo test.txt
# Made changes to create version 2.1.6.
# Modified Files:
# imap_to_mbox.pl populate_mailbox.pl
# Added Files:
# cleanTest.pl migrate_mbox.pl
#
# Revision 19991216.6  2000/12/11 21:58:52  dkernen
#
# Modified Files:
# 	build_dist.pl build_ldif.pl copy_folder.pl find_dup_msgs.pl
# 	imap_to_mbox.pl populate_mailbox.pl
# to add CVS data
#
# Revision 19991216.5  1999/12/16 17:19:12  dkernen
# Bring up to same level
#
# Revision 19991124.3  1999/12/16 17:14:25  dkernen
# Incorporate changes for exists method performance enhancement
#
# Revision 19991124.02  1999/11/24 17:46:19  dkernen
# More fixes to t/basic.t
#
# Revision 19991124.01  1999/11/24 16:51:49  dkernen
# Changed t/basic.t to test for UIDPLUS before trying UID cmds
#
# Revision 1.3  1999/11/23 17:51:06  dkernen
# Committing version 1.06 distribution copy
#


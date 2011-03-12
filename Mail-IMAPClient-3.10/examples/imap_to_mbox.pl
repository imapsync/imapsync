#!/usr/local/bin/perl
# (c) 1999 Thomas Stromberg, Research Triangle Commerce, Inc.
# This software is protected by the BSD License. No rights reserved anyhow.
# <tstromberg@rtci.com>

# DESC: Reads a users IMAP folders, and converts them to mbox
#       Good for an interim switch-over from say, Exchange to Cyrus IMAP.

# TODO:
# correct header printing From

use Mail::IMAPClient;	# a nice set of perl libs for imap
use IO::Socket::SSL;
use Getopt::Std; 	# for the command-line overrides. good for user
use File::Path;		# create full file paths. (yummy!)
use File::Basename;	# find a nice basename for a folder.
use Date::Manip;	# to create From header date
$| = 1;

sub connect_imap();
sub find_folders();
sub write_folder($$$$);

# Config for the imap migration kit.

getopts('u:p:P:s:i:f::b:c:W:Sdh');

$SSL		= $opt_S || 0;
$SERVER		= $opt_s || 'dell2';
$USER		= $opt_u || 'userid';
$PASSWORD	= $opt_p || 'password';
$PORT		= $opt_P || '143';
$INBOX_PATH	= $opt_i || "/var/mail/$USER";
$FOLDERS_PATH	= $opt_f || "./folders/$USER";
$DONT_MOVE	= $opt_m || '.mailboxlist|Trash|INBOXIIMAP|mlbxl';
$READ_DELIMITER	= $opt_r || '/';
$WRITE_DELIMITER= $opt_w || '/';
$WRITE_MODE	= $opt_W || '>';
$BANNED_CHARS	= $opt_b || '.|^|%';
$CR		= $opt_c || "\r";
$DELETE		= $opt_D || 0;
$DEBUG		= $opt_d || "0";
$FAIL = 0;

if ($opt_h) {
    # print help here
    print "imap_to_mbox.pl - with the following optional arguments:
	-S	Use an SSL connection (default $SSL)
	-s <s>	Server specification (default $SERVER)
	-u <u>	User login (default $USER)
	-p <p>	User password
	-P <p>	Server Port (default $PORT)
	-i <i>	INBOX save path (default $INBOX_PATH)
	-f <f>	Save path for other folders (default $FOLDERS_PATH)
	-m <r>	Regexp for IMAP folders not to be saved:
		$DONT_MOVE
	-r <r>	Read delimiter (default \"$READ_DELIMITER\")
	-w <w>	Write Delimiter (default \"$WRITE_DELIMITER\")
	-b <b>	Banned chars (default \"$BANNED_CHARS\")
	-c <c>	Strip CRs from saved files [for Unix] (default \"$CR\")
	-D	Delete files downloaded on server
	-d	Debug mode (default $DEBUG)\n";
    exit 1;
}

## do our magic tricks ######################################
connect_imap;
find_folders;


sub connect_imap()
{
# Open an SSL session to the IMAP server
# Handles the SSL setup, and gives us back a socket
    my $ssl;
    if ($opt_S) {
	$ssl=IO::Socket::SSL->new(
		PeerHost	=> "$SERVER:imaps"
#	,	SSL_version	=> 'SSLv2'
	);

        defined $ssl
            or die "Error connecting to $SERVER:imaps - $@";

	$ssl->autoflush(1);
    }

    $imap = Mail::IMAPClient->new(
        Socket		=> ($opt_S ? $ssl : 0),
        Server		=> $SERVER,
        User		=> $USER,
        Password	=> $PASSWORD,
        Port		=> $PORT,
        Debug		=> $DEBUG,
        Uid		=> 0,
        Clear		=> 1,
    )
    or die ("Could not connect to $SERVER:$PORT with $USER: $! $?\n");
}

sub find_folders()
{
    my @folders = $imap->folders;
#	push(@folders, "INBOX");

    foreach my $folder (@folders)
    {   my $message_count = $imap->message_count($folder);
	if(! $message_count) {
	    print("* $folder is empty, skipping.\n");
	    next;
	}
	if($folder =~ /$DONT_MOVE/) {
	    print("! $folder matches DONT_MOVE ruleset, skipping\n");
	    next;
	}

	my $new_folder = $folder;
	$new_folder =~ s/\./_/g;
	$new_folder =~ s/\Q$READ_DELIMITER/$WRITE_DELIMITER/g;
	my $path
          = $new_folder eq "INBOX" ? "$INBOX_PATH"
          : "$FOLDERS_PATH/$new_folder";

	printf "x %4i %-45.45s => %s", $message_count, $folder, $path;
	write_folder $folder, $path, 1, $message_count;
    }
}

sub write_folder($$$$)
{   my($folder, $newpath, $first_message, $last_message) = @_;

    $imap->select($folder)
        or warn "Could not examine $folder: $!";

    my $new_dir  = dirname  $newpath;
    my $new_file = basename $newpath;

       -d $new_dir
    or mkpath($new_dir, 0700)
    or die "Cannot create $new_dir:$!\n";

    open mbox, $WRITE_MODE, $newpath
        or die "Cannot create file $newpath: $!\n";

    for (my $i=$first_message; $i<$last_message+1; ++$i)
    {   my $date = UnixDate(ParseDate($imap->internaldate($i)),
			 "%a %b %e %T %Y");
	my $user = $imap->get_envelope($i)->from_addresses;
	$user =~ s/^.*\<([^>]*)\>/$1/;
	$user = '-' unless $user;
	print '.' if $i%25 == 0;

	my $msg_header = $imap->fetch($i, "FAST")
            or warn "Could not fetch header $i from $folder\n";

	my $msg_rfc822 = $imap->fetch($i, "RFC822");
        unless($msg_rfc822)
        {   warn "Could not fetch RFC822 $i from $folder\n";
            $FAIL=1
        }

	undef $start;
	foreach (@$msg_rfc822)
	{   if($_ =~ /\: / && !$message)
            {   ++$message;
                print mbox "From $user $date\n";
            }

	    if(/^\)\r/)
            {   undef $message;
                print mbox "\n\n";
            }
	    next unless $message;
	    $_ =~ s/\r$//;
	    $_ = $imap->Strip_cr($_) if $CR;
	    print mbox "$_";

	}
	if($DELETE && ! $FAIL)
	{   $imap->delete_message($i)
                or warn "Could not delete_message: $@\n";
	    $FAIL = 0;
	}
    }

    close mbox
        or die "Write errors to $newpath: $!\n";

    if($DELETE)
    {   $imap->expunge($folder)
            or warn "Could not expunge: $@\n";
    }

    print "\n";
}

# 2008/08/07 - Added SSL support, fixed From header printing, and CR
#		elimination (sobek)
#
# Revision 19991216.7  2002/08/23 13:29:48  dkernen
#
# Revision 19991216.6  2000/12/11 21:58:52  dkernen
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

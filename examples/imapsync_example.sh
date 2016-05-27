#!/bin/sh
# $Id: imapsync_example.sh,v 1.6 2016/01/21 03:35:15 gilles Exp gilles $

# imapsync example shell for Unix users
# lines beginning with # are just comments 

# See http://imapsync.lamiral.info/#doc
# for more details on how to use imapsync.

# Replace below the 6 parameters  
# "test1.lamiral.info"  "test1"  "secret1"  "test2.lamiral.info"  "test2"  "secret2"
# with your own values
# Double quotes are necessary if a value contain one or more blanks.

# value for --host1 is the IMAP source server hostname or IP address
# value for --user1 is the IMAP source user login
# value for --password1 is the IMAP source user password

# value for --host2 is the IMAP destination server hostname or IP address
# value for --user2 is the IMAP destination user login
# value for --password2 is the IMAP destination user password

# Character \ at the end of the first line is essential and means
# "this command continues on the next line". You can add other lines
# but don't forget \ character lasting each line, except the last one.

# Three other options are in this example because they are good to start with
#
# --dry makes imapsync doing nothing, just print what would be done without --dry.
# 
# --justfolders does only things about folders (ignore messages). It is good
# to verify the folder mapping is good for you.
#
# --automap guesses folders mapping, for folders like 
#           "Sent", "Junk", "Drafts", "All", "Archive", "Flagged".
#
# I suggest to start with --automap --justfolders --dry.
# If the folder mapping is not good then add some --f1f2 fold1=fold2
# to fix it.
# Then remove --dry and have a run to create folders on host2.
# If everything goes well so far then remove --justfolders to
# start syncing messages.

./imapsync --host1 test1.lamiral.info   --user1 test1   --password1 'secret1' \
           --host2 test2.lamiral.info   --user2 test2   --password2 'secret2' \
           --automap --justfolders --dry "$@"



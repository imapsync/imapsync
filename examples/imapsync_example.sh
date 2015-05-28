#!/bin/sh
# $Id: imapsync_example.sh,v 1.3 2015/03/26 04:35:02 gilles Exp gilles $

# imapsync example shell for Unix users
# lines beginning with # are just comments 

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


./imapsync --host1 test1.lamiral.info   --user1 test1   --password1 'secret1' \
           --host2 test2.lamiral.info   --user2 test2   --password2 'secret2' 


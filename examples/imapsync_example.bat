@REM $Id: imapsync_example.bat,v 1.10 2016/04/07 23:14:09 gilles Exp gilles $

@REM imapsync example batch for Windows users
@REM lines beginning with @REM are just comments 

@REM See http://imapsync.lamiral.info/#doc
@REM for more details on how to use imapsync.

@REM Replace below the 6 parameters  
@REM "test1.lamiral.info"  "test1"  "secret1"  "test2.lamiral.info"  "test2"  "secret2"
@REM with your own values
@REM Double quotes are necessary if a value contain one or more blanks.

@REM value "test1.lamiral.info" for --host1 is the IMAP source server hostname or IP address
@REM value "test1" for --user1 is the IMAP source user login
@REM value "secret1" for --password1 is the IMAP source user password

@REM value "test2.lamiral.info" for --host2 is the IMAP destination server hostname or IP address
@REM value "test2" for --user2 is the IMAP destination user login
@REM value "secret2" for --password2 is the IMAP destination user password

@REM Character ^ at the end of the first line is essential and means
@REM "this command continues on the next line". You can add other lines
@REM but don't forget ^ character lasting each line, except the last one.


@REM Three other options are in this example because they are good to start with
@REM
@REM --dry makes imapsync doing nothing, just print what would be done without --dry.
@REM 
@REM --justfolders does only things about folders (ignore messages). It is good
@REM               to verify the folder mapping is good for you.
@REM
@REM --automap guesses folders mapping, for folders like 
@REM           "Sent", "Junk", "Drafts", "All", "Archive", "Flagged".
@REM
@REM I suggest to start with --automap --justfolders --dry.
@REM If the folder mapping is not good then add some --f1f2 folder1=folder2
@REM to fix it. 
@REM Then remove --dry and have a run to create folders on host2.
@REM If everything goes well so far then remove --justfolders to
@REM start syncing messages.

.\imapsync.exe --host1 test1.lamiral.info  --user1 test1 --password1  "secret1"  ^
               --host2 test2.lamiral.info  --user2 test2 --password2  "secret2"  ^
               --automap --justfolders --dry 


@PAUSE


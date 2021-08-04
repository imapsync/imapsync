@REM $Id: imapsync_example.bat,v 1.11 2020/01/07 00:45:36 gilles Exp gilles $

@REM imapsync example batch for Windows users
@REM lines beginning with @REM are just comments 
@REM Please read them, they are written for you, human folk.

@REM Read also https://imapsync.lamiral.info/README_Windows.txt
@REM for more details on how to use imapsync on Windows.

@REM Now let us enter the real work to fit your needs
@REM Replace below the 6 parameters  
@REM "test1.lamiral.info"  "test1"  "secret1"  "test2.lamiral.info"  "test2"  "secret2"
@REM with your own values
@REM Double quotes are necessary if a value contain one or more blanks.

@REM value "test1.lamiral.info" for --host1     is the IMAP source server hostname or IP address
@REM value "test1"              for --user1     is the IMAP source user login
@REM value "secret1"            for --password1 is the IMAP source user password

@REM value "test2.lamiral.info" for --host2 is the IMAP destination server hostname or IP address
@REM value "test2"              for --user2 is the IMAP destination user login
@REM value "secret2"            for --password2 is the IMAP destination user password

@REM Character ^ at the end of the first line is essential and means
@REM "this command continues on the next line". You can add other lines
@REM but don't forget ^ character lasting each line, except the last one.

@REM That is not all, keep on reading!

@REM Three other options are in this example because they are good to start with
@REM
@REM --dry makes imapsync doing nothing, just print what would be done without --dry.
@REM so if you leave --dry then imapsync will not sync your data.

@REM --justfolders does only folders creations, it ignores messages.
@REM This option is good to verify the folder mapping is good for you
@REM without starting to copy/pollute folders with messages.
@REM
@REM --automap guesses folders mapping, it wors for folders like 
@REM           "Sent", "Junk", "Drafts", "All", "Archive", "Flagged".
@REM
@REM I suggest/impose to start with --automap --justfolders --dry.
@REM If the folder mapping you see in the output is not good then add 
@REM some options --f1f2 "folder1=folder2"
@REM in oder to fix it. 

@REM Once you are happy with the folder names on the destination,
@REM remove --dry and have a run to create folders on host2.

@REM If everything goes well so far then remove --justfolders to
@REM start syncing messages.

@REM In case you are impatient, just remove  --justfolders --dry 
@REM in the firt place and go. Imapsync is not that bad by default anyway!


.\imapsync.exe --host1 "test1.lamiral.info"  --user1 "test1" --password1  "secret1"  ^
               --host2 "test2.lamiral.info"  --user2 "test2" --password2  "secret2"  ^
               --automap --justfolders --dry 

@ECHO The sync is over.
@ECHO Hit any key to close this window
@ECHO the following word "to continue" means in fact "to close this window" 
@PAUSE


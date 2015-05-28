@REM $Id: imapsync_example.bat,v 1.7 2015/03/26 04:35:24 gilles Exp gilles $

@REM imapsync example batch for Windows users
@REM lines beginning with @REM are just comments 

@REM Replace below the 6 parameters  
@REM "test1.lamiral.info"  "test1"  "secret1"  "test2.lamiral.info"  "test2"  "secret2"
@REM with your own values
@REM Double quotes are necessary if a value contain one or more blanks.

@REM value for --host1 is the IMAP source server hostname or IP address
@REM value for --user1 is the IMAP source user login
@REM value for --password1 is the IMAP source user password

@REM value for --host2 is the IMAP destination server hostname or IP address
@REM value for --user2 is the IMAP destination user login
@REM value for --password2 is the IMAP destination user password

@REM Character ^ at the end of the first line is essential and means
@REM "this command continues on the next line". You can add other lines
@REM but don't forget ^ character lasting each line, except the last one.

.\imapsync.exe --host1 test1.lamiral.info  --user1 test1 --password1  "secret1"  ^
               --host2 test2.lamiral.info  --user2 test2 --password2  "secret2" 

@PAUSE


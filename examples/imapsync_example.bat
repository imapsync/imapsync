@REM $Id: imapsync_example.bat,v 1.6 2014/05/29 23:43:09 gilles Exp gilles $

@REM imapsync example batch for Windows users
@REM lines beginning with @REM are just comments 

@REM Replace below the 6 parameters  "imap.side1.org"  "toto"  "secretoto"  "192.168.42.4"  "titi"  "titi secret"
@REM with your own values
@REM Double quotes are necessary if a value contain one or more blanks.

.\imapsync.exe --host1 imap.side1.org  --user1 toto --password1  "secretoto"   ^
               --host2 192.168.42.4    --user2 titi --password2  "titi secret" 

@PAUSE


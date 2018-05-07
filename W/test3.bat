
@REM $Id: test3.bat,v 1.29 2018/02/06 13:12:26 gilles Exp gilles $
cd /D %~dp0

@REM \$1 must be $1 on Windows

.\imapsync.exe --host1 p --user1 tata --passfile1 secret.tata  --host2 p --user2 titi --passfile2 secret.titi ^
               --folder "INBOX.blanc middle" --automap --f1f2 "INBOX.blanc middle=INBOX.blanc middle" --dry

               
@EXIT





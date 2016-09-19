
@REM $Id: test3.bat,v 1.24 2016/08/05 14:22:42 gilles Exp gilles $
cd /D %~dp0

@REM \$1 must be $1 on Windows

@REM ==== password within double-quotes
perl ./imapsync --host1 p  --user1 tata --passfile1 secret.tata  --host2 p --user2 titi --passfile2 secret.titi ^
                --debugimap2 --debugcontent --folder INBOX --maxage 1
@EXIT





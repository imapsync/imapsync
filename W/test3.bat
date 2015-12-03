
@REM $Id: test3.bat,v 1.22 2015/09/21 22:49:50 gilles Exp gilles $
cd /D %~dp0

@REM \$1 must be $1 on Windows

@REM ==== split lon lines 
perl ./imapsync ^
                --host1 p  --user1 tata ^
                --passfile1 secret.tata ^
                --host2 p  --user2 titi ^
                --passfile2 secret.titi ^
                --nofoldersizes  --folder "INBOX.longline" --regexmess "s,(.{9900}),$1\r\n,g" --dry --debugcontent
@EXIT





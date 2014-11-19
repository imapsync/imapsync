
@REM $Id: test4.bat,v 1.3 2014/11/14 17:09:34 gilles Exp gilles $
cd /D %~dp0

REM \$1 must be $1 on Windows
perl ./imapsync ^
                --host1 p  --user1 tata ^
                --passfile1 secret.tata ^
                --host2 p  --user2 titi ^
                --passfile2 secret.titi ^
                --justfolders --nofoldersizes --folder "INBOX. blanc_begin" --regextrans2 "s,(\.|^) +,$1,g"

EXIT





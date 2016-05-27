
REM $Id: test_reg.bat,v 1.3 2015/05/11 01:08:05 gilles Exp gilles $

cd /D %~dp0

perl ./imapsync --host1 p --user1 tata --passfile1 secret.tata  --host2 p --user2 titi --passfile2 secret.titi ^
                --justfolders --dry --nofoldersizes ^
		--regextrans2 "s/\./_/g"

@REM 		--regextrans2 "s,${h2_prefix}(.*),${h2_prefix}old_mail${h2_sep}$1," ^
@REM 		--regextrans2 "s,^INBOX$,${h2_prefix}old_mail${h2_sep}INBOX,"
   
   
@REM 		--regextrans2 "s,(.*),old_mail/$1,"

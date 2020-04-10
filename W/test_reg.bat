
REM $Id: test_reg.bat,v 1.4 2016/09/28 03:41:38 gilles Exp gilles $

cd /D %~dp0

 perl ./imapsync --host1 p --user1 tata --passfile1 secret.tata  --host2 p --user2 titi --passfile2 secret.titi ^
                --justfolders --folder INBOX --dry ^
        --regextrans2 "s,(/|^) +,$1,g" ^
	--regextrans2 "s, +(/|$),$1,g" ^
	--regextrans2 "s/[\^]/_/g" ^
	--regextrans2 "s/['\\]/_/g" ^
	--regextrans2 "s,^&AC8-,-,g"  ^
	--regextrans2 "s,^&APg-,oe,g"

		
		
@REM		--regextrans2 "s/\./_/g"

@REM 		--regextrans2 "s,${h2_prefix}(.*),${h2_prefix}old_mail${h2_sep}$1," ^
@REM 		--regextrans2 "s,^INBOX$,${h2_prefix}old_mail${h2_sep}INBOX,"
   
@REM 		--regextrans2 "s,(.*),old_mail/$1,"

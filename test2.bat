
REM $Id: test2.bat,v 1.3 2011/05/30 21:58:08 gilles Exp gilles $

cd C:\msys\1.0\home\Admin\imapsync
REM perl ./imapsync --host1 p  --user1 tata --passfile1 secret.tata  --host2 p --user2 titi --passfile2 secret.titi --delete2 --expunge2 --folder INBOX 
REM perl ./imapsync --host1 p  --user1 tata --passfile1 secret.tata  --host2 p --user2 titi --passfile2 secret.titi --delete2 --expunge1 --expunge2 --folder INBOX --usecache  




REM imapsync --host1 p --user1 tata --passfile1 secret.tata --host2 p --user2 titi --passfile2 secret.titi --justfolders --nofoldersize --folder INBOX.yop.yap --sep1 / --regextrans2 "s,/,_," 
REM imapsync --host1 p --user1 tata --passfile1 secret.tata --host2 p --user2 titi --passfile2 secret.titi --nofoldersize --folder INBOX.yop.yap --regexflag 's/\\Answered//g' --debug > out.txt  

REM perl imapsync --version
REM perl imapsync --tests_debug

REM imapsync.exe ^
REM   --host1 p --user1 big1 --passfile1 secret.big1 ^
REM   --host2 p --user2 big2 --passfile2 secret.big2 ^
REM   --folder INBOX.bigmail

perl imapsync 

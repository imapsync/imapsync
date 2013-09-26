

cd /D %~dp0

REM .\imapsync.exe --host1 winmail1.webcows.se --user1 monica@fractus.net --password1 yaa  --host2 winmail1.webcows.se --user2 monica@fractus.net --password2 yaa 
REM perl imapsync --host1 winmail1.webcows.se --user1 monica@fractus.net --password1 yaa  --host2 winmail1.webcows.se --user2 monica@fractus.net --password2 yaa 

REM perl imapsync --host1 p  --user1 toto --passfile1 secret.toto  --host2 p --user2 titi --passfile2 secret.titi --ssl1 --ssl2  --folder INBOX 
REM .\imapsync.exe --host1 p  --user1 toto --passfile1 secret.toto  --host2 p --user2 titi --passfile2 secret.titi --ssl1 --ssl2 --justconnect 
REM PAUSE
REM cmail.cmich.edu has address 207.75.116.61

REM imapsync.exe --host1 cmail.cmich.edu --ssl1 --ssl1_SSL_version SSLv3  ^
REM             --host2 cmail.cmich.edu --ssl2 --ssl2_SSL_version SSLv3 ^
REM             --justconnect


REM .\imapsync.exe --host1 p  --user1 tata --passfile1 secret.tata  --host2 p --user2 titi --passfile2 secret.titi --ssl1 --ssl2 --delete2 --folder INBOX 
REM .\imapsync.exe --host1 p  --user1 tata --passfile1 secret.tata  --host2 p --user2 titi --passfile2 secret.titi --ssl1 --ssl2 --delete2 --folder INBOX --usecache


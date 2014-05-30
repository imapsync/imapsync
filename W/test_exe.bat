REM $Id: test_exe.bat,v 1.11 2014/05/22 10:13:34 gilles Exp gilles $

cd /D %~dp0

@REM EXIT

.\imapsync.exe

@ECHO ==== All 8 combinaisons between ssl1/tls1 ssl2/tls2 justconnect/justlogin
@ECHO 
@ECHO ==== 1 --SSL1 --SSL2 --JUSTCONNECT
.\imapsync.exe --host1 p --ssl1 --user1 tata --passfile1 secret.tata  --host2 p --ssl2 --user2 titi --passfile2 secret.titi --justconnect

@ECHO ==== 2 --SSL1 --SSL2 --JUSTLOGIN
.\imapsync.exe --host1 p --ssl1 --user1 tata --passfile1 secret.tata  --host2 p --ssl2 --user2 titi --passfile2 secret.titi --justlogin

@ECHO ==== 3 --TLS1 --TLS2 --JUSTCONNECT
.\imapsync.exe --host1 p --tls1 --user1 tata --passfile1 secret.tata  --host2 p --tls2 --user2 titi --passfile2 secret.titi --justconnect

@ECHO ==== 4 --TLS1 --TLS2 --JUSTLOGIN
.\imapsync.exe --host1 p --tls1 --user1 tata --passfile1 secret.tata  --host2 p --tls2 --user2 titi --passfile2 secret.titi --justlogin  

@ECHO ==== 5 --SSL1 --TLS2 --JUSTCONNECT
.\imapsync.exe --host1 p --ssl1 --user1 tata --passfile1 secret.tata  --host2 p --tls2 --user2 titi --passfile2 secret.titi --justconnect

@ECHO ==== 6 --SSL1 --TLS2 --JUSTLOGIN
.\imapsync.exe --host1 p --ssl1 --user1 tata --passfile1 secret.tata  --host2 p --tls2 --user2 titi --passfile2 secret.titi --justlogin

@ECHO ==== 7 --TLS1 --SSL2 --JUSTCONNECT
.\imapsync.exe --host1 p --tls1 --user1 tata --passfile1 secret.tata  --host2 p --ssl2 --user2 titi --passfile2 secret.titi --justconnect

@ECHO ==== 8 --TLS1 --SSL2 --JUSTLOGIN
.\imapsync.exe --host1 p --tls1 --user1 tata --passfile1 secret.tata  --host2 p --ssl2 --user2 titi --passfile2 secret.titi --justlogin



.\imapsync.exe --host1 p  --user1 toto --passfile1 secret.toto  --host2 p --user2 titi --passfile2 secret.titi --ssl1 --ssl1_SSL_version SSLv3 --ssl2 --justconnect 
.\imapsync.exe --host1 p  --user1 toto --passfile1 secret.toto  --host2 p --user2 titi --passfile2 secret.titi --ssl1 --ssl1_SSL_version SSLv3 --ssl2 --justlogin 
.\imapsync.exe --host1 p  --user1 toto --passfile1 secret.toto  --host2 p --user2 titi --passfile2 secret.titi --ssl1 --ssl2 --delete2  
.\imapsync.exe --host1 p  --user1 tata --passfile1 secret.tata  --host2 p --user2 titi --passfile2 secret.titi --ssl1 --ssl2 --delete2 --folder INBOX 
.\imapsync.exe --host1 p  --user1 tata --passfile1 secret.tata  --host2 p --user2 titi --passfile2 secret.titi --ssl1 --ssl2 --delete2 --folder INBOX --usecache


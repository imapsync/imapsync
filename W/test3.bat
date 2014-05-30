
REM $Id: test3.bat,v 1.12 2014/05/22 10:15:14 gilles Exp gilles $
cd /D %~dp0

perl ./imapsync --host1 lamiral.info --tls1 --user1 tata --passfile1 secret.tata  --host2 lamiral.info --tls2 --user2 titi --passfile2 secret.titi --justconnect --debugimap
EXIT




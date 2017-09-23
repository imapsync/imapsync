
@REM $Id: test3.bat,v 1.26 2017/07/08 00:11:24 gilles Exp gilles $
cd /D %~dp0

@REM \$1 must be $1 on Windows


@ECHO ====  --justloadavg --justbanner

@REM perl .\imapsync --host1 p --user1 tata --passfile1 secret.tata --host2 p --user2 titi --passfile2 secret.titi --justbanner

@REM perl -V
@REM perl -e "print 'zzz'"
@REM perl -c .\imapsync
@REM perl    .\imapsync --version
@REM --testsdebug --debugdev

@REM perl .\imapsync  --host1 imap.gmail.com   --host2 ks2ipv6.lamiral.info  --ssl1 --ssl2 --justconnect --debugimap
@REM perl .\imapsync  --host1 test.lamiral.info   --host2 ks2ipv6.lamiral.info  --nossl1 --justconnect --debugimap
perl .\imapsync  --host1 test.lamiral.info --user1 test1 --password1 secret1  --host2 p --user2 titi --passfile2 secret.titi  --nossl1 --justlogin --debugimap



@EXIT







SET
CD /D %~dp0
REM perl imapsync --testsunit tests_kill_zero
REM perl imapsync --testsunit tests_killpid

START perl imapsync --host1 p --user1 tata --passfile1 secret.tata --host2 p --user2 titi --passfile2 secret.titi --simulong 9
ping -n 5 127.0.0.1 >nul
perl imapsync --host1 p --user1 tata --passfile1 secret.tata --host2 p --user2 titi --passfile2 secret.titi --abort









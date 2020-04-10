

SET
CD /D %~dp0
REM perl imapsync --testsunit tests_kill_zero
REM perl imapsync --testsunit tests_killpid

perl imapsync --tests


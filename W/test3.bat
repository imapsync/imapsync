

cd /D %~dp0

REM E:
REM cd .\temp
REM cd \
imapsync.exe --host1 p  --user1 tata --passfile1 secret.tata  --host2 p --user2 titi --passfile2 secret.titi --usecache --tmpdir  "E:\TEMP" --include "blanc"


REM perl imapsync --tests_debug
perl imapsync --tests

PAUSE
perl imapsync --host1 p --user1 tata --passfile1 secret.tata  --host2 p --user2 titi --passfile2 secret.titi --usecache --tmpdir "E:\TEMP"
REM perl imapsync --host1 p --user1 tata --passfile1 secret.tata  --host2 p --user2 titi --passfile2 secret.titi --usecache

REM rmdir "E:\TEMP\imapsync_cache" /s /q

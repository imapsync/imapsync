

cd /D %~dp0

REM E:
REM cd .\temp
REM cd \
REM imapsync.exe --host1 p  --user1 tata --passfile1 secret.tata  --host2 p --user2 titi --passfile2 secret.titi --usecache --tmpdir  "E:\TEMP" --include "blanc"
REM PAUSE
REM perl imapsync --host1 p --user1 tata --passfile1 secret.tata  --host2 p --user2 titi --passfile2 secret.titi --usecache --tmpdir "E:\TEMP"
REM perl imapsync --host1 p --user1 tata --passfile1 secret.tata  --host2 p --user2 titi --passfile2 secret.titi --usecache

mkdir "\\?\E:\TEMP\lala"
REM mkdir "\\?\E:\TEMP\01_______\01_______\02_______\03_______\04_______\05_______\06_______\07_______\08_______\09_______\10_______\11_______\12_______\13_______\14_______\15_______\16_______\17_______\18_______\19_______\20_______\21_______\22_______\22_______\24_______\25_______\26_______\27_______\28_______\29_______\30_______\"


perl imapsync --tests_debug --tmpdir "\\?\E:\TEMP\long"
perl imapsync --tests --tmpdir "\\?\E:\TEMP\long"



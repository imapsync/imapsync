@REM
@REM $Id: sync_loop_windows.bat,v 1.9 2015/03/26 04:34:44 gilles Exp gilles $
@REM
@REM imapsync massive sync example batch for Windows users
@REM lines beginning with @REM are just comments 
@REM
@REM Replace "test1.lamiral.info" and "test2.lamiral.info" with your own values
@REM
@REM You should get familiar with a simple and single imapsync transfer before
@REM playing with this loop batch file. See and play with imapsync_example.bat
@REM
@REM ==== Credentials file ====

@REM Credentials data are supposed to be in the file named "file.txt" in the following format
@REM user001_1;password001_1;user001_2;password001_2
@REM ...
@REM Separator is character semi-colon ; it can be replaced with any character by changing 
@REM the part "delims=;" in the FOR loop below.
@REM Each data line contains 4 columns, columns are parameters for --user1 --password1 --user2 --password2
@REM 
@REM The credentials filename "file.txt" used for the loop can be renamed 
@REM by changing "SET csvfile=file.txt" below.

@REM ==== Log files ====

@REM Log files are in the LOG_imapsync sub-folder

@REM ==== Parallel executions ====

@REM If you want to do parallel runs of imapsync then this current script is a good start.
@REM Just copy it several times and replace, on each copy, the csvfile variable value.
@REM Instead of SET csvfile=file.txt write for example
@REM SET csvfile=file01.txt in the first copy
@REM then also 
@REM SET csvfile=file02.txt in the second copy etc.
@REM Of course you also have to split data contained in file.txt
@REM into file01.txt file02.txt etc.
@REM After that, just double-clic on each batch file to launch each process
@REM 
@REM Be aware that imapsync can be  also a cpu/memory cruncher on the remote imap servers,
@REM especially in parallel runs. The best practice rule to answer the question
@REM "how many processes in parallel can we run?" is:
@REM 1) Measure the total transfer rate by adding each one printed in each run.
@REM 2) Launch new parallel runs as long as the total transfer rate increase.
@REM 3) When the total transfer rate starts to diminish, stop new launches. 
@REM    Note N as the number of parallel runs you got until then.
@REM 4) Only keep N-2 parallel runs for the future.

@REM For Parallel executions there is also a PowerShell script written by 
@REM CARTER Alex explained and located on the imapsync archive list:
@REM http://www.linux-france.org/prj/imapsync_list/msg02137.html

@REM ==== The real stuff ====

@REM @echo off

SET csvfile=file.txt

FOR /F "tokens=1,2,3,4 delims=; eol=#" %%G IN (%csvfile%) DO (
@ECHO ==== Syncing from account %%G to account %%I ====
@ECHO.

imapsync ^
  --host1 test1.lamiral.info --user1 %%G --password1 %%H ^
  --host2 test2.lamiral.info --user2 %%I --password2 %%J 

@ECHO.==== End syncing from account %%G to account %%I ====
@ECHO.
)

@ECHO Loop finished!
@ECHO Log files are in LOG_imapsync directory
@PAUSE

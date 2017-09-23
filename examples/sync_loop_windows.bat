@REM
@REM $Id: sync_loop_windows.bat,v 1.15 2017/05/13 04:43:01 gilles Exp gilles $
@REM
@REM imapsync massive sync example batch for Windows users
@REM lines beginning with @REM are just comments 
@REM
@REM See also http://imapsync.lamiral.info/FAQ.d/FAQ.Massive.txt
@REM
@REM You should get familiar with a simple and single imapsync transfer before
@REM playing with this loop batch file. See and play with imapsync_example.bat

@REM ==== How it works ====
@REM 
@REM The files 
@REM * sync_loop_windows.bat 
@REM * imapsync or imapsync.exe and 
@REM * file.txt 
@REM are supposed to be in the same directory.


@REM ==== Credentials file ====
@REM
@REM Credentials data are supposed to be in the file named "file.txt" in the following format:
@REM host001_1;user001_1;password001_1;host001_2;user001_2;password001_2;
@REM ...
@REM Separator is character semi-colon ; it can be replaced with any character by changing 
@REM the part "delims=;" in the FOR loop below.
@REM 
@REM Each data line contains 6 columns, columns are parameter values for 
@REM --host1 --user1 --password1 --host2 --user2 --password2
@REM and a fake parameter to avoid CRLF part going into the 6th parameter password2.
@REM The credentials filename "file.txt" used for the loop can be renamed 
@REM by changing "SET csvfile=file.txt" below.

@REM ==== Log files ====
@REM
@REM Log files are in the LOG_imapsync sub-folder

@REM ==== Parallel executions ====
@REM
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
@REM Be aware that imapsync can be a cpu/memory cruncher on the remote imap servers,
@REM especially in parallel runs. The best practice rule to answer the question
@REM "how many processes in parallel can we run?" is:
@REM 1) Measure the total transfer rate by adding each one printed in each run.
@REM 2) Launch new parallel runs as long as the total transfer rate increase.
@REM 3) When the total transfer rate starts to diminish, stop new launches. 
@REM    Note N as the number of parallel runs you got until then.
@REM 4) Only keep N-2 parallel runs for the future.

@REM For Parallel executions, there is also a PowerShell script written by 
@REM CARTER Alex explained and located on the imapsync archive list:
@REM http://www.linux-france.org/prj/imapsync_list/msg02137.html

@REM ==== The real stuff is below ====

@REM @echo off

@REM First let's go in the directory this batch is
CD /D %~dp0

@REM Let's get arguments of this batch, they will be added to imapsync arguments, if any. 
@SET arguments= & @SET command=%~0
@IF %1. EQU . GOTO args_end
:args_loop
@SET arguments=%arguments% %1 & @SHIFT
@IF %1. NEQ . GOTO args_loop
@ECHO Command and arguments: %command% %arguments%
:args_end

@REM Now the loop on the csv file.
SET csvfile=file.txt

FOR /F "tokens=1,2,3,4,5,6,7 delims=; eol=#" %%G IN (%csvfile%) DO (
@ECHO ==== Starting imapsync from --host1 %%G --user1 %%H to --host2 %%J --user2 %%K ====
@imapsync ^
  --host1 %%G --user1 %%H --password1 %%I ^
  --host2 %%J --user2 %%K --password2 %%L %%M %arguments%
@ECHO ==== Ended imapsync from --host1 %%G --user1 %%H to --host2 %%J --user2 %%K ====
@ECHO.
)

@ECHO Loop finished!
@ECHO Log files are in LOG_imapsync directory
@PAUSE

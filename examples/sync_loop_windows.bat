@REM
@REM $Id: sync_loop_windows.bat,v 1.6 2014/05/22 14:20:51 gilles Exp gilles $
@REM
@REM imapsync massive sync example batch for Windows users
@REM lines beginning with REM are just comments 
@REM
@REM Replace "imap.side1.org" and "imap.side2.org" with your own values
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
@REM Log files are in the LOG_imapsync subfolder

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


@REM @echo off

SET csvfile=file.txt

FOR /F "tokens=1,2,3,4 delims=; eol=#" %%G IN (%csvfile%) DO (
@ECHO ==== Syncing from account %%G to account %%I ====
@ECHO.

imapsync ^
  --host1 imap.side1.org --user1 %%G --password1 %%H ^
  --host2 imap.side2.org --user2 %%I --password2 %%J 

@ECHO.==== End syncing from account %%G to account %%I ====
@ECHO.
)

@ECHO Loop finished!
@ECHO Log files are in LOG_imapsync directory
@PAUSE

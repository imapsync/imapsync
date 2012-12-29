REM
REM $Id: sync_loop_windows.bat,v 1.4 2012/12/23 08:02:34 gilles Exp gilles $
REM
REM imapsync massive sync example batch for Windows users
REM lines beginning with REM are just comments 
REM
REM You have to rename this file from sync_loop_windows.bat.txt to sync_loop_windows.bat
REM in order to make it a batch command file that your system will recognize and execute.
REM
REM Replace "imap.side1.org" and "imap.side2.org" with your own values
REM
REM This loop will also create a log file called log_%%I.txt for each account transfer
REM where %%I is just a variable containing the user2 account name.
REM and %mydate%_%mytime% is date and time formatted for a filename.
REM Since "date /t" is localy dependent you may have to adapt mydate=%%c_%%a_%%b_%%d


REM @echo off

DATE /t
TIME /t

FOR /f "tokens=1-4 delims=-/: " %%a IN ('DATE /t') DO (SET mydate=%%c_%%a_%%b_%%d)
FOR /f "tokens=1-2 delims=-/: " %%a IN ('TIME /t') DO (SET mytime=%%a_%%b)
ECHO %mydate%_%mytime%

if not exist LOG mkdir LOG
FOR /F "tokens=1,2,3,4 delims=; eol=#" %%G IN (file.txt) DO ECHO syncing to user %%I & imapsync ^
  --host1 imap.side1.org --user1 %%G --password1 %%H ^
  --host2 imap.side2.org --user2 %%I --password2 %%J ^
  > LOG\log_%%I_%mydate%_%mytime%.txt 2>&1


ECHO Loop finished
ECHO log files are in LOG directory
PAUSE

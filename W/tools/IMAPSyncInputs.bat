@echo off

@REM Written by Liam Patrick <liam.patrick@flonix.co.uk>
@REM imapsync example batch for Windows users
@REM lines beginning with @REM are just comments 

@REM Double quotes are necessary if a value contain one or more blanks.

@REM value for --host1 is the IMAP source server hostname or IP address
@REM value for --user1 is the IMAP source user login
@REM value for --password1 is the IMAP source user password

@REM value for --host2 is the IMAP destination server hostname or IP address
@REM value for --user2 is the IMAP destination user login
@REM value for --password2 is the IMAP destination user password

@REM Character ^ at the end of the first line is essential and means
@REM "this command continues on the next line". You can add other lines
@REM but don't forget ^ character lasting each line, except the last one.


@REM ------------------------------------------------------------------------------------

:start
echo.
echo  This will run IMAPSync letting you Migrate mail to another account on
echo  another server.
echo.
echo  The information to be entered is as follows.
echo.
echo  -Host1 -User1 -Password1 -require ssl for 1?
echo  -Host2 -User2 -Password2 -require ssl for 2?
echo.
pause

:vari1
cls
echo ---------------------------------------------
echo.
SET /P ANSWER=  enter host1? 
echo.

SET HOST1=%ANSWER%

SET /P ANSWER=  enter user1? 
echo.

SET USER1=%ANSWER%

SET /P ANSWER=  enter password1? 
echo.

SET PASS1=%ANSWER%


:ssl1
SET /P ANSWER=  enable ssl1? (y/n)
echo.
if /i {%ANSWER%}=={y} (goto :ssl11)
if /i {%ANSWER%}=={n} (goto :ssl12)
(goto :ssl1)


:ssl11
SET SSL1=-ssl1
echo ssl Enabled
echo.
(goto :ask1)


:ssl12
SET SSL1=
echo ssl Disabled
echo.
(goto :ask1)


:ask1
cls
SET /P ANSWER= Check " %HOST1% %USER1% %PASS1% %SSL1% " Correct details? (y/n)

if /i {%ANSWER%}=={y} (goto :vari2)
if /i {%ANSWER%}=={n} (goto :vari1)
(goto :ask1)

@REM --------------------------------------------------------------------------------------

:vari2
cls
echo ---------------------------------------------
echo.
SET /P ANSWER=  enter host2? 
echo.

SET HOST2=%ANSWER%

SET /P ANSWER=  enter user2? 
echo.

SET USER2=%ANSWER%

SET /P ANSWER=  enter password2? 
echo.

SET PASS2=%ANSWER%


:ssl2
SET /P ANSWER=  enable ssl2? (y/n)
echo.
if /i {%ANSWER%}=={y} (goto :ssl21)
if /i {%ANSWER%}=={n} (goto :ssl22)
(goto :ssl2)


:ssl21
SET SSL2=-ssl2
echo ssl Enabled
echo.
(goto :ask2)


:ssl22
SET SSL2=
echo ssl Disabled
echo.
(goto :ask2)


:ask2
cls
SET /P ANSWER= Check " -%HOST2% -%USER2% -%PASS2% %SSL2% " Correct details? (y/n)

if /i {%ANSWER%}=={y} (goto :run)
if /i {%ANSWER%}=={n} (goto :vari2)
(goto :ask2)

@REM ------------------------------------------------------------------------------------

:run
cls
echo ---------------------------------------------------------------------------
echo.
echo  Now that all the data has been entered we will run IMAPSync
echo.
echo  This is the final step. Please read the information carefully
echo  to avoid issues with migration.
echo.
echo  If any of the details are incorrect please exit and re-enter your
echo  details to run correctly
echo.
echo  the following is what will be saved to a file which can later be run or edited
echo.
echo  .\imapsync.exe --host1 %HOST1% --user1 %USER1% --password1 "%PASS1%" 
echo                 --host2 %HOST2% --user2 %USER2% --password2 "%PASS2%" %SSL1% %SSL2%
echo.
echo  To exit without running, please enter n. to Save settings to a file, please enter s
echo.
SET /P ANSWER= (n/s)

if /i {%ANSWER%}=={n} (goto :end)
if /i {%ANSWER%}=={s} (goto :savefinal)
(goto :run)

:runfinal
.\imapsync.exe --host1 %HOST1% --user1 %USER1% --password1 "%PASS1%" ^
               --host2 %HOST2% --user2 %USER2% --password2 "%PASS2%" %SSL1% %SSL2% --regextrans2 "s/\\/./g" --maxsize 250000000 --maxlinelength 9900 
(goto :end)

:savefinal

@echo .\imapsync.exe --host1 %HOST1% --user1 %USER1% --password1 "%PASS1%" ^
--host2 %HOST2% --user2 %USER2% --password2 "%PASS2%" %SSL1% %SSL2% --regextrans2 "s/\\/./g" --maxsize 250000000 --maxlinelength 9900 > ".\%USER1%.bat"
echo.
echo  File Saved in .\%USER1%.bat
echo.
(goto :end)

:end

echo.
@PAUSE


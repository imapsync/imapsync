
@REM $Id: test2.bat,v 1.20 2015/11/23 16:47:01 gilles Exp gilles $
@REM

cd /D %~dp0

@REM @ECHO off
.\imapsync.exe --modules_version
@PAUSE
.\imapsync.exe --testslive
@PAUSE




REM $Id: web.bat,v 1.1 2023/07/01 20:46:13 gilles Exp gilles $


@REM This batch script is for me, as a developer. Ignore it.

@SETLOCAL

@PUSHD %~dp0

@ECHO 
@ECHO 

@REM Developer way
CALL perl ../../W/learn/http_one_request

@POPD

@PAUSE



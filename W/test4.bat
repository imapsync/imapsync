
@REM $Id: test4.bat,v 1.4 2019/05/28 13:20:08 gilles Exp gilles $

SET
ECHO ~dp0 = %~dp0
ECHO 0 = %0
ECHO ~0 = %~0
ECHO ~dpnx0 = %~dpnx0
ECHO cmdcmdline = %cmdcmdline%
CD /D %~dp0


@IF [%PROCESSOR_ARCHITECTURE%] == [x86] (
        @REM 32 bits
        @REM Do not add command after this one since it will anihilate the %ERRORLEVEL% of pp
        ECHO ECHO Building 32 bits binary PROCESSOR_ARCHITECTURE = %PROCESSOR_ARCHITECTURE%
) ELSE (
        @REM 64 bits
        @REM Do not add command after this one since it will anihilate the %ERRORLEVEL% of pp
        ECHO ECHO Building 64 bits binary PROCESSOR_ARCHITECTURE = %PROCESSOR_ARCHITECTURE%
)


@REM Do a PAUSE if run by double-click, aka, explorer (then ). No PAUSE in a DOS window or via ssh.
IF %0 EQU "%~dpnx0" IF "%SSH_CLIENT%"=="" PAUSE

EXIT /B





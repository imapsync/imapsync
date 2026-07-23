


REM $Id: build_exe.bat,v 1.2 2023/07/08 08:54:36 gilles Exp gilles $

@SETLOCAL
@ECHO Currently running through %0 %*

@ECHO Building oauth2_office365_with_imap.exe


@REM the following command change current directory to the dirname of the current batch pathname
@REM CD /D %~dp0

PUSHD %~dp0

CALL pp -x -o oauth2_office365_with_imap.exe ^
 --link  libcrypto-1_1-x64__.dll ^
 --link  zlib1__.dll ^
 --link  libssl-1_1-x64__.dll ^
 .\oauth2_office365_with_imap 

POPD

PAUSE


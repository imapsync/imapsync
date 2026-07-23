


REM $Id: build_oauth2_imap_exe.bat,v 1.5 2024/05/22 14:01:18 gilles Exp gilles $

@SETLOCAL
@ECHO Currently running through %0 %*

@ECHO Building oauth2_imap.exe


@REM the following command change current directory to the dirname of the current batch pathname
@REM CD /D %~dp0

PUSHD %~dp0

CALL pp -x -o oauth2_imap.exe ^
 --link  libcrypto-1_1-x64__.dll ^
 --link  zlib1__.dll ^
 --link  libssl-1_1-x64__.dll ^
 .\oauth2_imap 

POPD

PAUSE


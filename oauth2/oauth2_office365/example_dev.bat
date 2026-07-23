


REM $Id: example_dev.bat,v 1.4 2023/09/21 18:05:36 gilles Exp gilles $

@REM A line beginning with REM is a comment
@REM This batch script is for Windows users, not for Linux nor MacOS users.

@SETLOCAL

@REM This stuff is there to be able to run this batch with a double-clic
@ECHO Currently running through %0 %*
@REM the following command change current directory to the dirname of the current batch pathname
@REM CD /D %~dp0
@PUSHD %~dp0

@ECHO 
@ECHO Getting OAUTH2 tokens 

@IF NOT EXIST tokens MKDIR tokens


@REM Replace the email by the one you want an access token to be used with imapsync

REM CALL .\oauth2_office365_with_imap.exe  gilles.lamiral@outlook.com


@REM You can specify the token file with the optional second argument, 
@REM example:

REM CALL .\oauth2_office365_with_imap.exe  gilles.lamiral@outlook.com   my_token_file_the_name_I_want.txt

@REM Developer way

REM CALL perl .\oauth2_office365_with_imap  gilles.lamiral@outlook.com "" localhost

CALL .\oauth2_office365_with_imap.exe  gilles.lamiral@outlook.com  "tokens.txt" localhost


@POPD



@PAUSE



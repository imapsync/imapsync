


REM $Id: example.bat,v 1.6 2023/07/18 11:07:19 gilles Exp gilles $

@REM I hope you can read
@REM A line beginning with REM is a comment
@REM This batch script is for Windows users, not for Linux users, nor MacOS users.

@SETLOCAL

@REM This stuff is there to be able to run this batch with a double-clic
@ECHO Currently running through %0 %*
@REM the following command change current directory to the dirname of the current batch pathname
@REM CD /D %~dp0
@PUSHD %~dp0

@ECHO 
@ECHO Getting OAUTH2 tokens 

@IF NOT EXIST tokens MKDIR tokens

@REM !!! The following CALL line is the only part to edit !!!
@REM Replace the email by the email you want an access token to be used with imapsync

CALL .\oauth2_office365_with_imap.exe  gilles.lamiral@outlook.com

@REM END OF PART TO EDIT


@REM Some extra features:
@REM You can specify the token file with the optional second argument, 
@REM example:

@REM CALL .\oauth2_office365_with_imap.exe  gilles.lamiral@outlook.com   my_token_file_the_name_I_want.txt


@REM You can use localhost as the authentication redirect_uri using "localhost" as the third argument:

@REM CALL .\oauth2_office365_with_imap.exe  gilles.lamiral@outlook.com  "" localhost

@POPD



@PAUSE



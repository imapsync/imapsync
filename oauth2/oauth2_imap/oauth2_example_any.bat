
REM $Id: oauth2_example_any.bat,v 1.1 2024/06/18 11:56:07 gilles Exp gilles $

@REM I hope you can read
@REM A line beginning with @REM is a comment
@REM This batch script is for Windows users, but not for Linux users, nor MacOS users.

@SETLOCAL

@REM This stuff is there to be able to run this batch with a double-clic
@ECHO Currently running through %0 %*
@REM the following command change current directory to the dirname of the current batch pathname
@REM CD /D %~dp0
@PUSHD %~dp0

@ECHO 
@ECHO Getting OAUTH2 tokens 

@IF NOT EXIST tokens MKDIR tokens

@REM !!! The following CALL lines are the only part to edit !!!
@REM R

@REM This is an example to get a token from any OAUTH2 provider for any application.
@REM Replace all the values by yours.
@REM This example concerns the imapsync application for an imap access to an office365 account.

CALL .\oauth2_imap.exe  ^
  --client_id     "c46947ca-867f-48b7-9231-64213fdd765e" ^
  --client_secret "LH58Q~vMFFoVTbBmUnOeIDtfcacYNolMJ2cP2cLC" ^
  --redirect_uri  "https://localhost" ^
  --authorize_uri "https://login.microsoftonline.com/common/oauth2/v2.0/authorize" ^
  --token_uri     "https://login.microsoftonline.com/common/oauth2/v2.0/token" ^
  --scope_string  "offline_access https://outlook.office.com/IMAP.AccessAsUser.All" ^
  --token_file    "tokens\oauth2_tokens_gilles.lamiral@outlook.com.txt" ^
  --imap_server   "outlook.office365.com" ^
    gilles.lamiral@outlook.com


@REM END OF PART TO EDIT




@POPD

@PAUSE



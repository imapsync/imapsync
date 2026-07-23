


REM $Id: oauth2_example_dev.bat,v 1.11 2025/07/14 14:32:22 gilles Exp gilles $

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


@REM What works

@REM My imapsync application on Azure
@REM CALL .\oauth2_imap.exe  gilles.lamiral@outlook.com
@REM CALL .\oauth2_imap.exe  --redirect_uri http://localhost  gilles.lamiral@outlook.com


@REM Thunderbird client_id for Outlook.  Works well now.
@ECHO @CALL perl .\oauth2_imap --startover --localssl  --client_id "9e5f94bc-e8a4-4e73-b8be-63364c29d753" --client_secret "" --redirect_uri "https://localhost"  gilles.lamiral@outlook.com 


@REM  Thunderbird client_id for Gmail. This works well with either Chrome or Firefox 
@ECHO CALL perl .\oauth2_imap --startover --client_id "406964657835-aq8lmia8j95dhl1a2bvharmfk3t1hgqj.apps.googleusercontent.com" --client_secret "kSmqreRr0qwBWJgbf5Y-PjSU" --redirect_uri "https://localhost"  charline.lamiral@gmail.com 




@ECHO CALL perl .\oauth2_imap  gilles.lamiral@gmail.com
@ECHO CALL perl .\oauth2_imap  gilles.lamiral@outlook.com

@ECHO CALL perl .\oauth2_imap --app imapsync gilles.lamiral@gmail.com
@ECHO CALL perl .\oauth2_imap --app imapsync gilles.lamiral@outlook.com
@ECHO CALL perl .\oauth2_imap --app imapsync gilles.lamiral@outlook.com
@ECHO CALL perl .\oauth2_imap --provider gmail gilles.lamiral@outlook.com

CALL .\oauth2_imap.exe --app imapsync gilles.lamiral@outlook.com


@ECHO CALL perl .\oauth2_imap --provider gmail gilles.lamiral@outlook.com
@ECHO CALL perl .\oauth2_imap --provider office365 gilles.lamiral@gmail.com



@REM offline Desktop Application
@ECHO CALL perl .\oauth2_imap --local --startover ^
  --token_file "tokens/oauth2_tokens_gilles.lamiral@gmail.com.txt" ^
  --client_id     "108687549524-s5ijqmadnmi4qfgfgicuquftv8f8a3da.apps.googleusercontent.com" ^
  --client_secret "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" ^
  --authorize_uri "https://accounts.google.com/o/oauth2/auth" ^
  --token_uri     "https://accounts.google.com/o/oauth2/token" ^
  --scope_string  "https://mail.google.com/" ^
  --imap_server   "imap.gmail.com" ^
 gilles.lamiral@gmail.com

@REM @CALL perl .\oauth2_imap --testsone

@POPD

@PAUSE



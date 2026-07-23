@REM $Id: imapsync_example_oauth2.bat,v 1.4 2023/09/26 20:18:02 gilles Exp gilles $

@REM Here is an imapsync example batch for Windows users.
@REM Lines beginning with @REM are just comments.
@REM Please read the comments, they are written for you, human folk.


@ECHO Getting/Updating the OAUTH2 tokens

@ECHO 
@IF NOT EXIST tokens MKDIR tokens

CALL .\oauth2_office365\oauth2_office365_with_imap.exe  foo@outlook.com  tokens\tokens_foo.txt localhost

@ECHO Now calling imapsync with this fresh access token


@REM In this example,
@REM the source account uses an OAUTH2 access token ( --host1 --user1 --oauthaccesstoken1 )
@REM the destination account uses a password ( --host2 --user2 --password2 )
@REM change the values with yours.

CALL .\imapsync.exe  ^
  --host1 outlook.office365.com --user1 foo@outlook.com --oauthaccesstoken1 tokens\tokens_foo.txt ^
  --host2 test2.lamiral.info  --user2 test2  --password2  secret2  ^
  --dry --automap --justfolders


@ECHO The sync is over.
@ECHO Hit any key to close this window
@ECHO the following word "to continue" means in fact "to close this window" 
@PAUSE



@REM Developer side

@REM CALL .\oauth2_office365\oauth2_office365_with_imap.exe  gilles.lamiral@outlook.com  oauth2_office365\tokens\oauth2_tokens_gilles.lamiral@outlook.com.txt localhost


@REM CALL .\imapsync.exe  ^
@REM   --host1 outlook.office365.com  --user1 gilles.lamiral@outlook.com --oauthaccesstoken1 oauth2_office365\tokens\oauth2_tokens_gilles.lamiral@outlook.com.txt ^
@REM   --host2 outlook.office365.com  --user2 gilles.lamiral@outlook.com --oauthaccesstoken2 oauth2_office365\tokens\oauth2_tokens_gilles.lamiral@outlook.com.txt ^
@REM   --dry


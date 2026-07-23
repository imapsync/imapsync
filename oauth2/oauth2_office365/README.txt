

 $Id: README.txt,v 1.15 2023/09/26 20:13:51 gilles Exp gilles $
 
How to generate an OAUTH2 access token to access an Office365 
account with imapsync?

======================================================================
A) Installation

Download the zip archive called "oauth2_office365.zip" at
https://imapsync.lamiral.info/oauth2/
and extract it anywhere.

The zip archive "oauth2_office365.zip" is an exact archive of 
https://imapsync.lamiral.info/oauth2/oauth2_office365/


In Azure, I created an Application called imapsync.
Its client_id is c46947ca-867f-48b7-9231-64213fdd765e
This client_id is used in the command oauth2_office365_with_imap.exe

======================================================================
A) For Windows users

0) There is two files with similar names:
   - oauth2_office365_with_imap.exe 
   - oauth2_office365_with_imap
   
The file oauth2_office365_with_imap is a Perl script, it's the 
source code of the second one, oauth2_office365_with_imap.exe,
which is a standalone binary. If you change the source code,
the binary won't change unless you rebuild it.

1) Edit the file example.bat and replace the email
foo@example.com 
by yours in the line:
 
    CALL .\oauth2_office365_with_imap.exe  foo@example.com
 
2) Run example.bat by double-clic or run it in a DOS window, a black
one is a good one usually.
 
You can also directly run the following command in a DOS window, if
you know how to go to the directory where the command belongs:
    
    .\oauth2_office365_with_imap.exe  foo@example.com
 
3) The tokens are generated in the sub-directory "tokens" which has to
exist before but the batch script example.bat creates it anyway.

4) With imapsync, use the token file path as a value for the parameters
--oauthaccesstoken1 or --oauthaccesstoken2

Go to read section C) below for more detailed explanations.
 
======================================================================
B) For Linux or MacOS users
 
1) Replace the email foo@example.com by yours in the
command line:

      ./oauth2_office365_with_imap foo@example.com

and run it.

2) The tokens are generated in the sub-directory "tokens" which has to
exist before.

======================================================================
C) For all users

Here are some explanations about oauth2_office365_with_imap.exe
behavior:
 
1) The first time you run it, the file containing the tokens does not exist. 
It is ok, we are here to create them. One token is the access token 
to access the office365 account with imapsync, usually usable
for one hour only. The other token is the refresh token, a token to get 
a new access token. The refresh token stays usable for a longer time.

2) Once generated, the tokens file is ready to be used by imapsync.

Example for a source account:
    
  imapsync ... --user1 foo@example.com --oauthaccesstoken1 path/tokens/oauth2_tokens_foo@example.com.txt


Example for a destination account:
   
  imapsync ... --user2 foo@example.com --oauthaccesstoken2 path/tokens/oauth2_tokens_foo@example.com.txt

3) The token file contains two important lines.
The first line is the access token.
The second line is the refresh token.
The next lines are sugar.
 
4) The usage is simple: run the command at anytime without
changing anything, it will check the authentication and regenerate
the access token and the refresh tokens if needed.
    
5) What the oauth2_office365_with_imap command does:
    
If the tokens file already exists, the access token is checked
with a real IMAP access to the mailbox.

If the IMAP access succeeds, the access token is proven good but it
is going to be regenerated anyway.
    
If the refresh token exists, then the refresh token is used to
generate a new access token.
  
If the refresh fails, then we are as if the tokens file does
not exit.

If the new access token succeed then both tokens are placed back
in the tokens file.
 
The previous behavior sounds complicated, because it is, but the
goal is to simplify the usage. You just need to run the same
command before running imapsync with the options
--oauthaccesstoken1 or --oauthaccesstoken2
   
With big mailboxes, you have to refresh the access token during the 
imapsync process. You can automatize this refresh by running 
the batch script called infinite_loop_example.bat
This script refreshes the access token every half an hour.
 
I will integrate this tool inside imapsync later.
 
6) Good luck!

7) Feedback is welcome


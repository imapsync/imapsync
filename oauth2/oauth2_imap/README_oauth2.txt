
$Id: README_oauth2.txt,v 1.36 2025/09/08 12:18:39 gilles Exp gilles $
 
How to generate an OAUTH2 access token to access an Office365 
account or a Gmail account with imapsync? See below.



======================================================================
A) Installation

Download the zip archive called "oauth2_imap.zip" at
https://imapsync.lamiral.info/oauth2/
and extract it anywhere.

The zip archive "oauth2_imap.zip" is an exact archive of 
https://imapsync.lamiral.info/oauth2/oauth2_imap/

If you're on Linux/Unix, you have to install the Perl module 
  HTTP::Daemon::SSL

On Debian, it's done with the command 
  apt install libhttp-daemon-ssl-perl

On any system, you can install it with the command cpanm,
also called cpanminus:

  cpanm HTTP::Daemon::SSL


======================================================================
B) Background


B0) The "oauth2_imap" command presented here uses by default the
Thunderbird client_id so don't be surprised when the authentication
process warns you that Thunderbird wants to access the mailbox you
mentioned. It's normal and on purpose. I choose this because
Thunderbird is well known and accepted as an OAUTH2 client. So you
shouldn't struggle too much in the Azure or Google portals to find and
allow it.  oauth2_imap default behavior is like:

  oauth2_imap  --app  thunderbird ...

Second point, the authentication process in your browser will alert
you about an insecure https CA authority. It's also normal since I
created it myself using the script localhost_CA_cert, which is also
available in the directory.

Third point, if you don't have a browser available where you run the
oauth2_imap command then you will have some manual copy/paste to do
from the remote browser you use. See the section below named
"F) For all users, remote browser situation."
To avoid to wait the timeouts of the remote browser situation, use
the option --remotebrowser, it will skip the waits.


B1) In Azure,
https://portal.azure.com/
I created an Application called imapsync.
Its client_id is
c46947ca-867f-48b7-9231-64213fdd765e
This client_id is used in the command oauth2_imap when the script
detects that the email address is managed by Office365 and when the
option "--app imapsync" is used.  This application is public, not
approved by Microsoft, you won't find it in the Azure portal, but
you can use it if you accept the warnings about it during the 
approval sequence.

B2) Useless read, for now.

In Google,
https://console.cloud.google.com/

I created a project called imapsync. It is managed by
gilles.lamiral@gmail.com. I added an "OAuth 2.0 Client IDs" for a
"Desktop" type application in it via the link
https://console.cloud.google.com/apis/credentials 

This Desktop app has a client_id and a client_secret used in
oauth2_imap when the script detects the email address is managed by
Gmail and when the option "--app imapsync" is used.  This application
is not fully approved by Google so forget it for now.


======================================================================
C) For Windows users

0) Warning. There are two files with similar names:
   - oauth2_imap.exe 
   - oauth2_imap
 
The file oauth2_imap is a Perl script, it is the source code of the
second one, oauth2_imap.exe, which is a standalone binary. If you
change the source code, the binary won't change unless you rebuild it,
which is not very difficult with the file build_oauth2_imap_exe.bat
but it is not that easy to have the prerequisites installed.

Anyway, all specific oauth2 values among providers are now changeable
as parameters, so rebuilding the binary is less likely to be needed
than before.

Now, let's go generate tokens!

1a) For Office365, edit the file oauth2_example_office365.bat with
notepad or any ascii editor and replace the email address
gilles.lamiral@outlook.com by yours in the line:
 
   CALL .\oauth2_imap.exe  gilles.lamiral@outlook.com

Then, double-clic on this oauth2_example_office365.bat file and follow
the process.

1b) For Gmail, edit the file oauth2_example_gmail.bat with Notepad or
any ASCII editor and replace the email address
gilles.lamiral@gmail.com by yours in the line:
 
   CALL .\oauth2_imap.exe gilles.lamiral@gmail.com


2a) For Office365, run oauth2_example_office365.bat by double-click or
run it in a DOS window, a black window usually.

2b) For Gmail, run oauth2_example_gmail.bat by double-click or run it
in a DOS window, a black window usually.


You can also directly run the following command in a DOS window if you
know how to go to the directory where the command oauth2_imap.exe
belongs:
    
    .\oauth2_imap.exe  foo@example.com

2c) oauth2_imap guesses the provider of the tokens by using a DNS
resolution on the domain of the email address.

In case you keep the same email address on both sides, one side
is Gmail, the other side Office365, you can force the tokens provider 
with:

  ./oauth2_imap --provider office365 foo@example.com

  ./oauth2_imap --provider gmail     foo@example.com 

and so, it generates tokens for each side for the same email address.


3) The tokens are generated in the sub-directory "tokens" which has to
exist before. Do not worry, the batch scripts
oauth2_example_office365.bat and oauth2_example_gmail.bat create it
anyway.

If you want to store the tokens in another file than the default one
chosen by the script, use the parameter --token_file

4) With imapsync, use the token file path as a value for the
parameters --oauthaccesstoken1 or --oauthaccesstoken2

Go to read section E) below for more detailed explanations.

5) Token refreshing.

The Office365 access token lasts only one hour and Office365 cuts the
connection when this time is over. Imapsync usually reconnects
automatically but the access token has to be valid. So, you need to
regenerate it by running again the oauth2_imap command every half
hour, let's say.

There is a script for doing this:
https://imapsync.lamiral.info/oauth2/oauth2_imap/oauth2_example_loop.bat
Download and edit this script like the others. Replace the email
address gilles.lamiral@outlook.com with yours. Run it by a double-click
and keep it running until the imapsync process of this mailbox is finished.

Same thing to refresh a Gmail access token.

======================================================================
D) For Linux or MacOS users
 
1) Replace the email foo@example.com with yours in the
command line:

      ./oauth2_imap foo@example.com

and run it. 

You have to be in the same directory as the script oauth2_imap. It's
because this script sometimes needs to open two files that are also in
this directory. Those files are "localhost.key" and "localhost.crt",
they are needed when the redirect_uri is "https://localhost", for
Thunderbird for example.

2) The tokens are generated in the sub-directory "tokens" which has to
exist before.

3) To refresh the access token, edit and run the script:

https://imapsync.lamiral.info/oauth2/oauth2_imap/oauth2_example_loop.sh


======================================================================
E) For all users

Here are some explanations about oauth2_imap (or oauth2_imap.exe)
behavior:
 
1) The first time you run it, the file containing the tokens does not
exist.  It is ok since we are here to get the tokens and store them in
the token file. One token is the access token. It is used to access
the imap account with imapsync, but it is usually usable for one hour
only. The other token is the refresh token, a token to get a new
access token without getting again the user agreement session via a
web browser.  The refresh token stays usable for a longer time,
several days, weeks, or even months.

2) Once generated, the tokens file is ready to be used by imapsync.

Example for a source account:
    
  imapsync ... --user1 foo@example.com --oauthaccesstoken1 path/tokens/oauth2_tokens_foo@example.com.txt


Example for a destination account:

  imapsync ... --user2 foo@example.com --oauthaccesstoken2 path/tokens/oauth2_tokens_foo@example.com.txt

3) The token file contains two important lines:
The first line is the access token.
The second line is the refresh token.
The next lines are just sugar, useful only for humans, not for computers.
 
4) The usage is simple: run the command at any time without changing
anything, it will check the authentication and regenerate the access
token and the refresh tokens if needed.

5) Here is what the oauth2_imap command does:
    
If the tokens file already exists, the access token is checked with a
real IMAP access to the mailbox.

If the IMAP access succeeds, the access token is proven good but it is
going to be regenerated anyway, because we want a fresh one with the
maximum lifetime possible.
    
If the refresh token exists, then the refresh token is used to
generate a new access token and also a new refresh token (Office365)
if a refresh token is proposed back from the request.
  
If the refresh fails, then we are as if the tokens file does not exist.

If the new access token succeeds then both tokens are placed back in
the tokens file.
 
The previous behavior sounds complicated because it is, but the goal
is to simplify the usage. To refresh the access, you just need to run
the same command again before running imapsync with the options
--oauthaccesstoken1 or --oauthaccesstoken2.
 
With big mailboxes, you have to refresh the access token during the
imapsync process. You can automatize this refresh by running the batch
script called infinite_loop_example.bat

This script refreshes the access token (and maybe the refresh token)
every half an hour.

I will integrate this tool inside imapsync later.

6) Good luck!

7) Feedback on this script is welcome 
   privately at gilles@lamiral.info
   or publicly at https://github.com/imapsync/imapsync/issues/250

======================================================================
F) For all users, remote browser situation.

When you don't have a browser available on the host you run 
the oauth2_imap command, you have two solutions to make it 
succeed.

1) You make a local browser available and use it. Local means "where
you run the oauth2_imap command". Install a browser. Since a browser is 
a graphical tool, you may have some work and knowledge to make it usable.
Ssh users would appreciate the "ssh -Y ..." or "ssh -X ..." options.

2) Do some manual copy/paste to and from a foreign browser located 
anywhere on the internet. The first copy/paste is the url given by 
oauth2_imap. Copy it and paste it to your remote browser. Then follow
the authentication process. When finally your browser complains about 
an url, usually a localhost one, that can't find its server, you're 
good. Your final job  is to manually copy/paste the "code" embedded
inside this final url. See below for an example.


  At one point, you may encounter the following when using the 
  oauth2_imap script:

...
Now I try to collect the code. Will give up in 120 seconds (maybe 4x).
Entering oauth2_collect_code_localhost
Leaving  oauth2_collect_code_localhost
...
Leaving  oauth2_collect_code_localhost

Failed to collect the code
Paste the code here and press ENTER:


The code to enter is given in the final redirect url at the end of the
authentication process in your browser.  For example, you end up with
the url:

  https://localhost:60454/?code=M.C552_BL2.2.U.e63dbda3-980d-2c99-11c5-52b6193c5b0a&state=isgfvkgazimngpwxgqrskjivxjubksyw

Here, the code to give to oauth2_imap is
M.C552_BL2.2.U.e63dbda3-980d-2c99-11c5-52b6193c5b0a
It is the .... part in the string ?code=....&state=xxxx
It is what is between ?code= and the next &

It's like this because you don't use a browser where you run the
./oauth2_imap command so the redirect fails. But giving the code in
the terminal should work and provide both an access token and a
refresh token.


# $Id: README_OAUTH2.txt,v 1.2 2022/07/25 16:44:43 gilles Exp gilles $

1) Do you have a refresh_token?
Yes: Good!

No:  Get one. How? Run the commands:

    cd oauth2/
    ./generate_gmail_token  youremail@gmail.com 

You will be asked to go to a long url with a browser, like this:

To authorize token, visit this url and follow the directions:
https://accounts.google.com/o/oauth2/auth?client_id=108687549524-86sjq07f3ch8otl9fnr56mjnniltdrvn.apps.googleusercontent.com&redirect_uri=urn%3Aietf%3Awg%3Aoauth%3A2.0%3Aoob&response_type=code&scope=https%3A%2F%2Fmail.google.com%2F


Go to this url, the url above should be the same as presented by the script.
Select your gmail address on the page, maybe do some 2-steps confirmation
with your phone. Then you'll see this warning:

"Google hasn’t verified this app"
"The app is requesting access to sensitive info in your Google Account. 
Until the developer (gilles.lamiral@gmail.com) verifies this app 
with Google, you shouldn't use it."

Well, gilles.lamiral@gmail.com is me and I haven't verify this app 
with google yet. But it's me Gilles LAMIRAL, the imapsync author.

Click on the link "Advanced". 
It writes:
"Continue only if you understand the risks and trust the developer (gilles.lamiral@gmail.com)."

Then click on the link "Go to imapsync (unsafe)"

It then shows:
"imapsync wants to access your Google Account"
"Make sure you trust imapsync"
"You may be sharing sensitive info with this site or app. 
You can always see or remove access in your Google Account."

Click on the blue button "Allow"

Copy/paste the code after the prompt "Enter verification code: "

It will generate a refresh token, an access token, and an oauthdirect 
token shown on the output, saved in three files, 
one file named ./D_oauth2_refresh_token_youremail@gmail.com.txt
another named  ./D_oauth2_access_token_youremail@gmail.com.txt
another named  ./D_oauth2_oauthdirect_youremail@gmail.com.txt

The refresh_token is just there to refresh the access_token and the
oauthdirect token.

With imapsync you can use either the oauthdirect or the access_token
token, like this:

    imapsync ... --user1 useless             --oauthdirect1      oauth2/D_oauth2_oauthdirect_youremail@gmail.com.txt

    imapsync ... --user1 youremail@gmail.com --oauthaccesstoken1 oauth2/D_oauth2_access_token_youremail@gmail.com.txt

With --oauthdirect1 the --user1 parameter is useless because it is already 
coded inside the oauthdirect token.

With --oauthaccesstoken1 the --user1 parameter is important because it will be 
used by imapsync to generate the oauthdirect token.

2) How to get a fresh enough access_token (less than one hour)?

Run the same command:

    cd oauth2/
    ./generate_gmail_token  youremail@gmail.com 

It will generate a new access_token (and the oauthdirect one) 
without any prompt this time, because the refresh token is used for that.




REM $Id: $

cd /D %~dp0

perl bug_ssl_win32_2 imap.gmail.com imapsync.gl@gmail.com sss INBOX
REM perl bug_ssl_win32_3_http
PAUSE
bug_ssl_win32_2.exe imap.gmail.com imapsync.gl@gmail.com sss INBOX
REM bug_ssl_win32_3_http.exe
PAUSE



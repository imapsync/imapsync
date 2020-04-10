



@REM the following command change current directory to the dirname of the current batch pathname
CD /D %~dp0

perl .\imapsync  --host1 imap.gmail.com      --host2 ks2ipv6.lamiral.info  --justconnect 

PAUSE

.\imapsync.exe   --host1 imap.gmail.com   --host2 ks2ipv6.lamiral.info  --justconnect 

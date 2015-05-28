
REM $Id: test.bat,v 1.12 2015/03/15 04:04:11 gilles Exp gilles $

cd /D %~dp0

@ECHO ==== Just load modules
perl -mMail::IMAPClient -mDigest::MD5 -mTerm::ReadKey -mIO::Socket::SSL ^
       -mDigest::HMAC_MD5 -mAuthen::NTLM -e -mTime::HiRes ^
       -mData::Uniqid -mURI::Escape  -mIO::Tee ""

perl ./imapsync 
@REM perl ./imapsync --tests 

@ECHO ==== All 8 combinaisons between ssl1/tls1 ssl2/tls2 justconnect/justlogin

@ECHO ==== 1 --SSL1 --SSL2 --JUSTCONNECT
perl ./imapsync --host1 p --ssl1 --user1 tata --passfile1 secret.tata  --host2 p --ssl2 --user2 titi --passfile2 secret.titi --justconnect

@ECHO ==== 2 --SSL1 --SSL2 --JUSTLOGIN
perl ./imapsync --host1 p --ssl1 --user1 tata --passfile1 secret.tata  --host2 p --ssl2 --user2 titi --passfile2 secret.titi --justlogin

@ECHO ==== 3 --TLS1 --TLS2 --JUSTCONNECT
perl ./imapsync --host1 p --tls1 --user1 tata --passfile1 secret.tata  --host2 p --tls2 --user2 titi --passfile2 secret.titi --justconnect

@ECHO ==== 4 --TLS1 --TLS2 --JUSTLOGIN
perl ./imapsync --host1 p --tls1 --user1 tata --passfile1 secret.tata  --host2 p --tls2 --user2 titi --passfile2 secret.titi --justlogin  

@ECHO ==== 5 --SSL1 --TLS2 --JUSTCONNECT
perl ./imapsync --host1 p --ssl1 --user1 tata --passfile1 secret.tata  --host2 p --tls2 --user2 titi --passfile2 secret.titi --justconnect

@ECHO ==== 6 --SSL1 --TLS2 --JUSTLOGIN
perl ./imapsync --host1 p --ssl1 --user1 tata --passfile1 secret.tata  --host2 p --tls2 --user2 titi --passfile2 secret.titi --justlogin

@ECHO ==== 7 --TLS1 --SSL2 --JUSTCONNECT
perl ./imapsync --host1 p --tls1 --user1 tata --passfile1 secret.tata  --host2 p --ssl2 --user2 titi --passfile2 secret.titi --justconnect

@ECHO ==== 8 --TLS1 --SSL2 --JUSTLOGIN
perl ./imapsync --host1 p --tls1 --user1 tata --passfile1 secret.tata  --host2 p --ssl2 --user2 titi --passfile2 secret.titi --justlogin


@ECHO ==== All folders in ssl
perl ./imapsync --host1 p --ssl1 --user1 tata --passfile1 secret.tata  --host2 p --ssl2 --user2 titi --passfile2 secret.titi --delete2 --expunge2 
@ECHO ==== INBOX only
perl ./imapsync --host1 p --tls1 --user1 tata --passfile1 secret.tata  --host2 p --tls2 --user2 titi --passfile2 secret.titi --delete2 --expunge2 --folder INBOX --nofoldersizes
@ECHO ==== INBOX only and --usecache
perl ./imapsync --host1 p --tls1 --user1 tata --passfile1 secret.tata  --host2 p --ssl2 --user2 titi --passfile2 secret.titi --delete2 --expunge2 --folder INBOX --nofoldersizes --usecache


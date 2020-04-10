
@REM $Id: test3_gmail.bat,v 1.6 2017/10/22 14:21:30 gilles Exp gilles $

cd /D %~dp0

@REM ./imapsync.exe --justbanner

@REM perl .\imapsync --host1 imap.gmail.com --ssl1 --user1 gilles.lamiral@gmail.com --passfile1 secret.gilles_gmail ^
@REM                 --host2 imap.gmail.com --ssl2 --user2 gilles.lamiral@gmail.com --passfile2 secret.gilles_gmail ^
@REM                 --folder INBOX --dry

@REM PAUSE

.\imapsync.exe --host1 imap.gmail.com --ssl1 --user1 "gilles.lamiral@gmail.com" --passfile1 secret.gilles_gmail ^
                --host2 p --user2 tata --passfile2 secret.tata ^
                --dry --folder INBOX --search """X-GM-RAW to:gilles.lamiral@gmail.com""" --debugimap1

@REM GOOD imapsync.exe  ... 
@REM GOOD imapsync.exe  ... --search """X-GM-RAW to:gilles.lamiral@gmail.com"""                
@REM GOOD imapsync.exe  ... --search """X-GM-RAW "to:gilles.lamiral@gmail.com""""

@REM GOOD perl imapsync ... --search   "X-GM-RAW ""to:gilles.lamiral@gmail.com"""

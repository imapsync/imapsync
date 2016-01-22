
@REM $Id: test3.bat,v 1.23 2015/12/14 15:15:12 gilles Exp gilles $
cd /D %~dp0

@REM \$1 must be $1 on Windows

@REM ==== password within double-quotes
perl ./imapsync ^
                --host1 p  --user1 tata ^
                --password1 """(secret)""" ^
                --host2 p  --user2 titi ^
                --passfile2 secret.titi ^
                --justlogin --debugimap1 --showpassword
@EXIT





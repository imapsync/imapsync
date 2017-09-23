
REM $Id: build_exe.bat,v 1.46 2017/08/23 13:04:40 gilles Exp gilles $

@SETLOCAL
@ECHO Currently running through %0 %*

@ECHO Building imapsync.exe

@REM the following command change current directory to the dirname of the current batch pathname
CD /D %~dp0

REM Remove the error file because its existence means an error occured during this script execution
IF EXIST LOG_bat\%~nx0.txt DEL LOG_bat\%~nx0.txt


CALL :handle_error CALL :detect_perl
CALL :handle_error CALL :check_modules
CALL :handle_error CALL :pp_exe


@ENDLOCAL
EXIT /B


:pp_exe
@SETLOCAL
@REM CALL pp -o imapsync.exe  --link libeay32_.dll  --link zlib1_.dll --link ssleay32_.dll .\imapsync
IF %PROCESSOR_ARCHITECTURE% == x86 (
	CALL pp -o imapsync.exe -M Test2::Formatter -M Test2::Formatter::TAP -M Test2::Event -M Test2::Event::Info  --link zlib1_.dll --link libcrypto-1_1_.dll --link libssl-1_1_.dll .\imapsync
	REM CALL pp -o imapsync.exe -M Test2::Formatter -M Test2::Formatter::TAP -M Test2::Event -M Test2::Event::Info                            --link zlib1_.dll  .\imapsync
) ELSE (
	CALL pp -o imapsync.exe -M Test2::Formatter -M Test2::Formatter::TAP -M Test2::Event -M Test2::Event::Info  .\imapsync
)
@ENDLOCAL
EXIT /B




::------------------------------------------------------
::--------------- Detect Perl --------------------------
:detect_perl
@SETLOCAL
perl -v
@ENDLOCAL
EXIT /B
::------------------------------------------------------


::------------------------------------------------------
::--------------- Check  modules are here --------------
:check_modules
@SETLOCAL
perl ^
     -mTest::MockObject ^
     -mPAR::Packer ^
     -mReadonly ^
     -mAuthen::NTLM ^
     -mData::Dumper ^
     -mData::Uniqid ^
     -mDigest::HMAC_MD5 ^
     -mDigest::HMAC_SHA1 ^
     -mDigest::MD5 ^
     -mFile::Copy::Recursive  ^
     -mFile::Spec ^
     -mIO::Socket ^
     -mIO::Socket::INET ^
     -mIO::Socket::IP ^
     -mIO::Socket::SSL ^
     -mIO::Tee ^
     -mMail::IMAPClient ^
     -mNet::Ping ^
     -mTerm::ReadKey ^
     -mTime::Local ^
     -mUnicode::String ^
     -mURI::Escape ^
     -mJSON::WebToken ^
     -mLWP::UserAgent ^
     -mHTML::Entities ^
     -mJSON ^
     -mCrypt::OpenSSL::RSA ^
     -mEncode::Byte ^
     -e ''
IF ERRORLEVEL 1 CALL .\install_modules.bat
@ENDLOCAL
EXIT /B
::------------------------------------------------------




::------------------------------------------------------
::--------------- Handle error -------------------------
:handle_error
SETLOCAL
ECHO IN %0 with parameters %*
%*
SET CMD_RETURN=%ERRORLEVEL%

IF %CMD_RETURN% EQU 0 (
        ECHO GOOD END
) ELSE (
        ECHO BAD END
        IF NOT EXIST LOG_bat MKDIR LOG_bat
        ECHO Failure calling: %* >> LOG_bat\%~nx0.txt
)
ENDLOCAL
EXIT /B
::------------------------------------------------------

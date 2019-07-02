
REM $Id: build_exe.bat,v 1.54 2019/05/28 13:20:08 gilles Exp gilles $

@SETLOCAL
@ECHO Currently running through %0 %*

@ECHO Building imapsync.exe

@REM the following command change current directory to the dirname of the current batch pathname
CD /D %~dp0

REM Remove the error file because its existence means an error occurred during this script execution
IF EXIST LOG_bat\%~nx0.txt DEL LOG_bat\%~nx0.txt


CALL :handle_error CALL :detect_perl
CALL :handle_error CALL :check_modules
CALL :handle_error CALL :rename_to_old
CALL :handle_error CALL :pp_exe
CALL :handle_error CALL :copy_with_architecture_name

@ENDLOCAL
@REM Do a PAUSE if run by double-click, aka, explorer (then ). No PAUSE in a DOS window or via ssh.
IF %0 EQU "%~dpnx0" IF "%SSH_CLIENT%"=="" PAUSE
EXIT /B


:pp_exe
@SETLOCAL
@REM In order to verify that all Strawberry dlls are statically included in the exe
@REM get https://docs.microsoft.com/en-us/sysinternals/downloads/listdlls
@REM You'll need a first run with Listdlls.exe -accepteula
@REM Run test_exe_tests.bat
@REM In parallel, run Listdlls.exe imapsync|findstr Strawberry
@REM No line should be in the output

@REM Now imapsync can check this itself if Listdlls.exe is in its dir 
@REM .\imapsync.exe  --testsunit tests_check_binary_embed_all_dyn_libs

@REM CALL pp -o imapsync.exe  --link libeay32_.dll  --link zlib1_.dll --link ssleay32_.dll .\imapsync
@IF [%PROCESSOR_ARCHITECTURE%] == [x86] (
        @REM 32 bits
        @REM Do not add command after this one since it will anihilate the %ERRORLEVEL% of pp
        ECHO Building 32 bits binary PROCESSOR_ARCHITECTURE = %PROCESSOR_ARCHITECTURE%
        CALL     pp -o imapsync.exe -M Test2::Formatter -M Test2::Formatter::TAP -M Test2::Event ^
                                -M Test2::Event::Info  ^
                                --link zlib1_.dll ^
                                --link libcrypto-1_1_.dll ^
                                --link libssl-1_1_.dll ^
                                .\imapsync
) ELSE (
        @REM 64 bits
        @REM Do not add command after this one since it will anihilate the %ERRORLEVEL% of pp
        ECHO Building 64 bits binary PROCESSOR_ARCHITECTURE = %PROCESSOR_ARCHITECTURE%
        CALL pp -o imapsync.exe -M Test2::Formatter   -M Test2::Formatter::TAP -M Test2::Event ^
                                -M Test2::Event::Info -M Test2::EventFacet     -M Test2::Event::Pass ^
                                -M Test2::Event::Fail -M Test2::Event::V2 ^
                                --link  libcrypto-1_1-x64__.dll ^
                                --link  zlib1__.dll ^
                                --link  libssl-1_1-x64__.dll ^
                                .\imapsync
)
@ENDLOCAL
EXIT /B


::------------------------------------------------------
::--------------- Copy with architecture name ----------
:copy_with_architecture_name
@SETLOCAL
IF [%PROCESSOR_ARCHITECTURE%] == [x86] (
        @REM 32 bits
        COPY /B .\imapsync.exe .\imapsync_32bit.exe
) ELSE (
        @REM 64 bits
        COPY /B .\imapsync.exe .\imapsync_64bit.exe
)
@ENDLOCAL
EXIT /B
::------------------------------------------------------

::------------------------------------------------------
::--------------- Copy with architecture name ----------
:rename_to_old
@SETLOCAL
IF EXIST imapsync_old.exe DEL imapsync_old.exe
RENAME imapsync.exe imapsync_old.exe
@ENDLOCAL
EXIT /B
::------------------------------------------------------



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
     -mRegexp::Common ^
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
     -mFile::Tail ^
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

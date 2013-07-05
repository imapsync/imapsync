
REM $Id: $

cd /D %~dp0

REM pp -o bug_ssl_win32_1.exe bug_ssl_win32_1

pp -M IO::Socket::IP -o bug_ssl_win32_2.exe bug_ssl_win32_2

REM pp -o bug_ssl_win32_3_http.exe bug_ssl_win32_3_http



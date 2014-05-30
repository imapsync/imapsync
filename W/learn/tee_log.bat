REM 
REM scp tee_log tee_log.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'

perl -MCPAN -e "install IO::Tee"
perl ./tee_log

PAUSE

pp -o tee_log.exe -M IO::Tee ./tee_log

PAUSE

./tee_log.exe



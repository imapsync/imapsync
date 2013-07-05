

all:
	@echo "make buid_ssl_exe"
	@echo "make test_ssl_exe"


check:
	perl -I../Mail-IMAPClient-3.33/lib/ -c bug_ssl_win32_1 
	perl -I../Mail-IMAPClient-3.33/lib/ -c bug_ssl_win32_2

buid_ssl_exe: check
	unix2dos *.bat
	scp build_test_ssl.bat bug_ssl_win32_?* Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/build_test_ssl.bat'

test_ssl_exe: check
	unix2dos *.bat
	scp test_ssl.bat  Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/test_ssl.bat'

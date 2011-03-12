
# $Id: Makefile,v 1.60 2011/02/21 02:20:38 gilles Exp gilles $	

.PHONY: help usage all

help: usage

usage:
	@echo "      imapsync $(VERSION), You can do :"
	@echo "make install # as root"
	@echo "make testf   # run tests"
	@echo "make testv   # run tests verbosely"
	@echo "make test3xx # run tests with (last) Mail-IMAPClient-3.xy"
	@echo "make test229 # run tests with Mail-IMAPClient-2.2.9"
	@echo "make tests_win32 # run tests on win32"
	@echo "make tests_win32_dev # run test2.bat on win32"
	@echo "make all     "
	@echo "make upload_index"
	@echo "make imapsync.exe"
	@echo "make imapsync_elf_x86.bin"


DIST_NAME=imapsync-$(VERSION)
DIST_FILE=$(DIST_NAME).tgz
DEB_FILE=$(DIST_NAME).deb
VERSION=$(shell perl -I./Mail-IMAPClient-2.2.9 ./imapsync --version)


all: ChangeLog README VERSION 


testp :
	perl -c imapsync

ChangeLog: imapsync
	rlog imapsync > ChangeLog

README: imapsync
	perldoc -t imapsync > README

VERSION: imapsync
	perl -I./Mail-IMAPClient-2.2.9 ./imapsync --version > VERSION


.PHONY: clean clean_tilde clean_test   

clean: clean_tilde clean_man

clean_test:
	rm -f .test .test_3xx .test_229

clean_tilde:
	rm -f *~

.PHONY: install dist man

man: imapsync.1

clean_man:
	rm -f imapsync.1

imapsync.1: imapsync
	pod2man imapsync > imapsync.1

install: testp imapsync.1
	mkdir -p $(DESTDIR)/usr/bin
	install imapsync $(DESTDIR)/usr/bin/imapsync
	chmod 755 $(DESTDIR)/usr/bin/imapsync
	mkdir -p $(DESTDIR)/usr/share/man/man1
	install imapsync.1 $(DESTDIR)/usr/share/man/man1/imapsync.1
	chmod 644 $(DESTDIR)/usr/share/man/man1/imapsync.1

.PHONY: cidone ci

ci: cidone

cidone:
	rcsdiff RCS/*

###############
# Local goals
###############


.PHONY: test tests testp testf test3xx

test_quick : test_quick_229 test_quick_3xx

test_quick_229: imapsync tests.sh
	CMD_PERL='perl -I./Mail-IMAPClient-2.2.9' /usr/bin/time sh tests.sh locallocal 1>/dev/null

test_quick_3xx: imapsync tests.sh
	CMD_PERL='perl -I./Mail-IMAPClient-3.27/lib' /usr/bin/time sh tests.sh locallocal 1>/dev/null

testv:
	nice -40 sh -x tests.sh

test: .test_229 .test_3xx

tests: test

test3xx: .test_3xx

test229: .test_229

.test_229: imapsync tests.sh
	CMD_PERL='perl -I./Mail-IMAPClient-2.2.9' /usr/bin/time sh tests.sh 1>/dev/null
	touch .test_229

.test_3xx: imapsync tests.sh
	CMD_PERL='perl -I./Mail-IMAPClient-3.27/lib' /usr/bin/time sh tests.sh 1>/dev/null
	touch .test_3xx

testf: clean_test test

.PHONY: lfo upload_lfo niouze_lfo niouze_fm public  imapsync_cidone

upload_index: index.shtml 
	rcsdiff index.shtml
	rsync -avH index.shtml \
	../../public_html/www.linux-france.org/html/prj/imapsync/
	sh $(HOME)/memo/lfo-rsync

.dosify_bat: build_exe.bat test_exe.bat test.bat test2.bat
	unix2dos build_exe.bat test.bat test_exe.bat test2.bat
	touch .dosify_bat

dosify_bat: .dosify_bat

copy_win32:
	scp imapsync Admin@c:'C:/msys/1.0/home/Admin/imapsync/'

tests_win32: dosify_bat
	scp imapsync test.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
#	ssh Admin@c 'perl C:/msys/1.0/home/Admin/imapsync/imapsync --tests_debug'
	ssh Admin@c 'perl C:/msys/1.0/home/Admin/imapsync/imapsync --tests'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/test.bat'
#	ssh Admin@c 'tasklist /FI "PID eq 0"' 
#	ssh Admin@c 'tasklist /NH /FO CSV' 

tests_win32_dev: dosify_bat
	scp imapsync test2.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/test2.bat'

test_imapsync_exe: dosify_bat
	scp test_exe.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	time ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/test_exe.bat'


imapsync.exe: imapsync build_exe.bat test_exe.bat .dosify_bat
	rcsdiff imapsync
	ssh Admin@c 'perl -V'
	(date "+%s"| tr "\n" " "; echo -n "BEGIN " $(VERSION) ": "; date) >> .BUILD_EXE_TIME
	scp imapsync build_exe.bat test_exe.bat \
	Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/build_exe.bat'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/test_exe.bat'
	scp Admin@c:'C:/msys/1.0/home/Admin/imapsync/imapsync.exe' .
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/imapsync.exe --version' > VERSION_EXE
	(date "+%s"| tr "\n" " "; echo -n "END   " $(VERSION) ": "; date) >> .BUILD_EXE_TIME


# vadrouille or petite
imapsync_elf_x86.bin: imapsync
	rcsdiff imapsync
	{ test 'vadrouille' = "`hostname`" && \
	pp -o imapsync_elf_x86.bin -I Mail-IMAPClient-3.27/lib \
	-M Mail::IMAPClient -M IO::Socket -M IO::Socket::SSL \
	-M Digest::MD5 -M Digest::HMAC_MD5 -M Term::ReadKey \
	-M Authen::NTLM \
	imapsync ; \
	} || :
	{ test 'petite'     = "`hostname`" && \
	pp -o imapsync_elf_x86.bin -I Mail-IMAPClient-3.27/lib \
	-M Mail::IMAPClient -M IO::Socket -M IO::Socket::SSL \
	-M Digest::MD5 -M Digest::HMAC_MD5 -M Term::ReadKey \
	-M Authen::NTLM \
	-M Tie::Hash::NamedCapture \
	-a '/usr/lib/perl/5.10.0/auto/POSIX/SigAction;auto/POSIX/SigAction' \
	imapsync ; \
	} || :
	{ test 'ks200821.kimsufi.com'     = "`hostname`" && \
	pp -o imapsync_elf_x86.bin -I Mail-IMAPClient-3.27/lib \
	-M Mail::IMAPClient -M IO::Socket -M IO::Socket::SSL \
	-M Digest::MD5 -M Digest::HMAC_MD5 -M Term::ReadKey \
	-M Authen::NTLM \
	-M Tie::Hash::NamedCapture \
	-a '/usr/lib/perl/5.10.1/auto/POSIX/SigAction;auto/POSIX/SigAction' \
	imapsync ; \
	} || :
	./imapsync_elf_x86.bin


lfo: cidone  niouze_lfo upload_lfo 

dist: cidone test clean all INSTALL tarball

tarball: cidone all imapsync_elf_x86.bin imapsync.exe
	echo making tarball $(DIST_FILE)
	mkdir -p dist
	mkdir -p ../prepa_dist/$(DIST_NAME)
	rsync -aCv --delete --omit-dir-times --exclude dist/ ./ ../prepa_dist/$(DIST_NAME)/
	rsync -av ./imapsync.exe ../prepa_dist/$(DIST_NAME)/
	cd ../prepa_dist &&  (tar czfv $(DIST_FILE) $(DIST_NAME) || tar czfv  $(DIST_FILE) $(DIST_NAME))
	#ln -f ../prepa_dist/$(DIST_FILE) dist/
	cd ../prepa_dist && md5sum $(DIST_FILE) > $(DIST_FILE).md5.txt
	cd ../prepa_dist && md5sum -c $(DIST_FILE).md5.txt
	ls -l ../prepa_dist/$(DIST_FILE)

ks:
	rsync -av . imapsync@ks.lamiral.info:public_html/imapsync
	{ cd /g/var/paypal_reply/ &&\
	rsync -av url_exe url_release url_source imapsync@ks.lamiral.info:/g/var/paypal_reply/ \
	; }

upload_lfo:
	#rm -rf /home/gilles/public_html/www.linux-france.org/html/prj/imapsync/
	#rm -rf /home/gilles/public_html/www.linux-france.org/ftp/prj/imapsync/
	rsync -avH ./ChangeLog ./COPYING ./CREDITS ./FAQ \
	./index.shtml ./INSTALL ./TIME \
	./logo_imapsync.png ./logo_imapsync_s.png \
	./paypal.shtml ./README ./style.css ./TODO ./VERSION ./VERSION_EXE \
	/home/gilles/public_html/www.linux-france.org/html/prj/imapsync/
	rsync -avH ./dist/index.shtml \
	/home/gilles/public_html/www.linux-france.org/html/prj/imapsync/dist/
	sh ~/memo/lfo-rsync

niouze_lfo : VERSION
	echo "CORRECT ME: . ./memo && lfo_announce"

niouze_fm: VERSION
	. ./memo && fm_announce


public: niouze_fm

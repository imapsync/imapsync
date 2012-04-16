
# $Id: Makefile,v 1.93 2012/02/07 10:55:04 gilles Exp gilles $	

.PHONY: help usage all

help: usage

usage:
	@echo "      imapsync $(VERSION), You can do :"
	@echo "make install # as root"
	@echo "make testf   # run tests"
	@echo "make testv   # run tests verbosely"
	@echo "make test_quick # few tests verbosely"
	@echo "make test3xx # run tests with (last) Mail-IMAPClient-3.xy"
	@echo "make test229 # run tests with Mail-IMAPClient-2.2.9"
	@echo "make tests_win32 # run tests on win32"
	@echo "make tests_win32_dev # run test2.bat on win32"
	@echo "make all     "
	@echo "make upload_index"
	@echo "make upload_ks"
	@echo "make imapsync.exe"
	@echo "make imapsync_elf_x86.bin"
	@echo "make publish"


DIST_NAME=imapsync-$(VERSION)
DIST_FILE=$(DIST_NAME).tgz
DEB_FILE=$(DIST_NAME).deb

VERSION=$(shell perl -I$(IMAPClient) ./imapsync --version)
VERSION_EXE=$(shell cat ./VERSION_EXE)

HELLO=$(shell date;uname -a)
IMAPClient_2xx=./Mail-IMAPClient-2.2.9
IMAPClient_3xx=./Mail-IMAPClient-3.30/lib
IMAPClient=$(IMAPClient_3xx)

hello:
	echo "$(VERSION)"
	echo "$(IMAPClient)"


all: ChangeLog README VERSION imapsync_elf_x86.bin imapsync.exe


testp :
	perl -c imapsync

ChangeLog: imapsync
	rlog imapsync > ChangeLog

README: imapsync
	perldoc -t imapsync > README

VERSION: imapsync
	perl -I./$(IMAPClient) ./imapsync --version > VERSION


.PHONY: clean clean_tilde clean_test   

clean: clean_tilde clean_man

clean_test:
	rm -f .test_3xx .test_229

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


.PHONY: test tests testp testf test3xx testv2 testv3

test_quick : test_quick_3xx test_quick_229 

test_quick_229: imapsync tests.sh
	CMD_PERL='perl -I./$(IMAPClient_2xx)' /usr/bin/time sh -x tests.sh locallocal

test_quick_3xx: imapsync tests.sh
	CMD_PERL='perl -I./$(IMAPClient_3xx)' /usr/bin/time sh -x tests.sh locallocal

testv2: .test_229
	CMD_PERL='perl -I./$(IMAPClient_2xx) /usr/bin/time sh tests.sh
	touch .test_229

testv3:.test_3xx
	CMD_PERL='perl -I./$(IMAPClient_3xx)' sh -x tests.sh
	touch .test_3xx

test: .test_229 .test_3xx

tests: test

test3xx: .test_3xx

test229: .test_229

.test_229: imapsync tests.sh
	CMD_PERL='perl -I./$(IMAPClient_2xx)' /usr/bin/time sh tests.sh 1>/dev/null
	touch .test_229

.test_3xx: imapsync tests.sh
	CMD_PERL='perl -I./$(IMAPClient_3xx)' /usr/bin/time sh tests.sh 1>/dev/null
	touch .test_3xx

testf: clean_test test

.PHONY: lfo upload_lfo niouze_lfo niouze_fm public  imapsync_cidone

.dosify_bat: build_exe.bat test_exe.bat test.bat test2.bat imapsync_example.bat.txt
	unix2dos build_exe.bat test.bat test_exe.bat test2.bat imapsync_example.bat.txt
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
	scp imapsync file.txt test2.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/test2.bat'

test_imapsync_exe: dosify_bat
	scp test_exe.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	time ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/test_exe.bat'


imapsync.exe: imapsync build_exe.bat .dosify_bat
	rcsdiff imapsync
	ssh Admin@c 'perl -V'
	(date "+%s"| tr "\n" " "; echo -n "BEGIN " $(VERSION) ": "; date) >> .BUILD_EXE_TIME
	scp imapsync build_exe.bat test_exe.bat \
	Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/build_exe.bat'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/test_exe.bat'
	scp Admin@c:'C:/msys/1.0/home/Admin/imapsync/imapsync.exe' .
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/imapsync.exe --version' > VERSION_EXE
	dos2unix VERSION_EXE
	(date "+%s"| tr "\n" " "; echo -n "END   " $(VERSION) ": "; date) >> .BUILD_EXE_TIME


# vadrouille or petite
imapsync_elf_x86.bin: imapsync
	rcsdiff imapsync
	{ test 'vadrouille' = "`hostname`" && \
	pp -o imapsync_elf_x86.bin -I $(IMAPClient_3xx) \
	-M Mail::IMAPClient -M IO::Socket -M IO::Socket::SSL \
	-M Digest::MD5 -M Digest::HMAC_MD5 -M Term::ReadKey \
	-M Authen::NTLM \
	imapsync ; \
	} || :
	{ test 'petite'     = "`hostname`" && \
	pp -o imapsync_elf_x86.bin -I $(IMAPClient_3xx) \
	-I NTLM-1.09/blib/lib \
	-M Mail::IMAPClient -M IO::Socket -M IO::Socket::SSL \
	-M Digest::MD5 -M Digest::HMAC_MD5 -M Term::ReadKey \
	-M Authen::NTLM \
	-M Tie::Hash::NamedCapture \
	-a '/usr/lib/perl/5.10.1/auto/POSIX/SigAction;auto/POSIX/SigAction' \
	imapsync ; \
	} || :
	{ test 'ks200821.kimsufi.com'     = "`hostname`" && \
	pp -o imapsync_elf_x86.bin -I $(IMAPClient_3xx) \
	-M Mail::IMAPClient -M IO::Socket -M IO::Socket::SSL \
	-M Digest::MD5 -M Digest::HMAC_MD5 -M Term::ReadKey \
	-M Authen::NTLM \
	-M Tie::Hash::NamedCapture \
	-a '/usr/lib/perl/5.10.1/auto/POSIX/SigAction;auto/POSIX/SigAction' \
	imapsync ; \
	} || :
	./imapsync_elf_x86.bin


lfo: cidone  niouze_lfo upload_lfo 

dist: cidone test clean all INSTALL dist_prepa dist_prepa_exe

tarball: cidone all
	echo making tarball $(DIST_FILE)
	mkdir -p dist
	mkdir -p ../prepa_dist/$(DIST_NAME)
	rsync -aCv --delete --omit-dir-times --exclude dist/ --exclude imapsync.exe ./ ../prepa_dist/$(DIST_NAME)/
	#rsync -av ./imapsync.exe ../prepa_dist/$(DIST_NAME)/
	cd ../prepa_dist &&  (tar czfv $(DIST_FILE) $(DIST_NAME) || tar czfv  $(DIST_FILE) $(DIST_NAME))
	#ln -f ../prepa_dist/$(DIST_FILE) dist/
	cd ../prepa_dist && md5sum $(DIST_FILE) > $(DIST_FILE).md5.txt
	cd ../prepa_dist && md5sum -c $(DIST_FILE).md5.txt
	ls -l ../prepa_dist/$(DIST_FILE)


DO_IT       := $(shell test -f ./dist/path_$(VERSION).txt || makepasswd --chars 4 > ./dist/path_$(VERSION).txt)
DIST_SECRET := $(shell cat ./dist/path_$(VERSION).txt)
DIST_PATH   := ./dist/$(DIST_SECRET)

lalala:
	echo $(DIST_SECRET)

dist_prepa: tarball dist_dir
	ln -f ../prepa_dist/$(DIST_FILE) $(DIST_PATH)/
	rcsdiff imapsync
	cp -a imapsync $(DIST_PATH)/
	#cd $(DIST_PATH)/ && md5sum $(DIST_FILE) > $(DIST_FILE).md5.txt
	#cd $(DIST_PATH)/ && md5sum -c $(DIST_FILE).md5.txt
	ls -l $(DIST_PATH)/

dist_dir:
	@echo $(DIST_SECRET)
	@echo $(DIST_PATH)
	mkdir -p $(DIST_PATH)
	ln -f ./dist/path_$(VERSION).txt ./dist/path_last.txt 


dist_prepa_exe: imapsync.exe
	mkdir -p $(DIST_PATH)
	cp -a ./imapsync.exe $(DIST_PATH)/
	#cd $(DIST_PATH)/ && md5sum ./imapsync.exe > ./imapsync.exe.md5.txt
	#cd $(DIST_PATH)/ && md5sum -c ./imapsync.exe.md5.txt


.PHONY: publish upload_ks ks

ks:
	rsync -avz --delete --exclude imapsync.exe \
	  . imapsync@ks.lamiral.info:public_html/imapsync/

publish: upload_ks ks

PUBLIC_FILES = ./ChangeLog ./COPYING ./CREDITS ./FAQ \
./index.shtml ./INSTALL ./TIME \
./logo_imapsync.png ./logo_imapsync_s.png \
./paypal.shtml ./paypal_return.shtml ./paypal_return_support.shtml \
./README ./style.css ./TODO ./VERSION ./VERSION_EXE ./memo ./file.txt \
./imapsync_example.bat.txt

upload_ks:
	rsync -lptvHzP  $(PUBLIC_FILES) \
	root@ks.lamiral.info:/var/www/imapsync/
	rsync -lptvHzrP ./dist/ \
	root@ks.lamiral.info:/var/www/imapsync/dist/

upload_lfo:
	#rm -rf /home/gilles/public_html/www.linux-france.org/html/prj/imapsync/
	#rm -rf /home/gilles/public_html/www.linux-france.org/ftp/prj/imapsync/
	rsync -avHz $(PUBLIC_FILES) \
	/home/gilles/public_html/www.linux-france.org/html/prj/imapsync/
	rsync -lptvHzP ./lfo.htaccess \
	/home/gilles/public_html/www.linux-france.org/html/prj/imapsync/.htaccess
	sh ~/memo/lfo-rsync

upload_index: index.shtml FAQ
	validate --verbose index.shtml
	rcsdiff index.shtml
	rsync -avH index.shtml FAQ root@ks.lamiral.info:/var/www/imapsync/
	rsync -avH index.shtml FAQ \
	../../public_html/www.linux-france.org/html/prj/imapsync/
	sh $(HOME)/memo/lfo-rsync

niouze_lfo : 
	echo "CORRECT ME: . ./memo && lfo_announce"

niouze_fm: VERSION
	. ./memo && fm_announce


public: niouze_fm

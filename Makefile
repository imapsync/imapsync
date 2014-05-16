
# $Id: Makefile,v 1.141 2014/02/13 03:18:50 gilles Exp gilles $	

.PHONY: help usage all

help: usage

usage:
	@echo "      imapsync $(VERSION), You can do :"
	@echo "make install # as root"
	@echo "make install_dependencies # it installs needed Perl modules from CPAN"
	@echo ""
	@echo "All other goals are for the upstream developper"

	@echo "make testf   # run tests"
	@echo "make testv   # run tests verbosely"
	@echo "make test_quick # few tests verbosely"
	@echo "make tests_win32 # run --test and W/test.bat on win32"
	@echo "make tests_win32_dev # run W/test2.bat on win32"
	@echo "make tests_win32_dev3 # run W/test3.bat on win32"
	@echo "make .prereq_win32 # run examples/install_modules.bat on win32"
	@echo "make all     "
	@echo "make upload_index"
	@echo "make upload_ks"
	@echo "make imapsync.exe"
	@echo "make imapsync_elf_x86.bin"
	@echo "make publish"
	@echo "make perlcritic"
	@echo "make install_dependencies"


PREFIX ?= /usr
DIST_NAME=imapsync-$(VERSION)
DIST_FILE=$(DIST_NAME).tgz
DEB_FILE=$(DIST_NAME).deb

VERSION=$(shell perl -I$(IMAPClient) ./imapsync --version)
VERSION_EXE=$(shell cat ./VERSION_EXE)

HELLO=$(shell date;uname -a)
IMAPClient_3xx=./W/Mail-IMAPClient-3.35/lib
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
	perl -I./$(IMAPClient) ./imapsync --version > ./VERSION
	touch -r ./imapsync ./VERSION

GOOD_PRACTICES.html: GOOD_PRACTICES.t2t
	txt2tags -i GOOD_PRACTICES.t2t  -t html --toc  -o GOOD_PRACTICES.html

TUTORIAL.html: TUTORIAL.t2t
	txt2tags -i TUTORIAL.t2t -t html --toc  -o TUTORIAL.html

doc:  README ChangeLog TUTORIAL.html GOOD_PRACTICES.html 

.PHONY: clean clean_tilde clean_test doc

clean: clean_tilde clean_man

clean_test:
	rm -f .test_3xx

clean_tilde:
	rm -f *~

.PHONY: install dist man

man: imapsync.1

clean_man:
	rm -f imapsync.1

imapsync.1: imapsync
	pod2man imapsync > imapsync.1

install: testp imapsync.1
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	install imapsync $(DESTDIR)$(PREFIX)/bin/imapsync
	chmod 755 $(DESTDIR)$(PREFIX)/bin/imapsync
	mkdir -p $(DESTDIR)$(PREFIX)/share/man/man1
	install imapsync.1 $(DESTDIR)$(PREFIX)/share/man/man1/imapsync.1
	chmod 644 $(DESTDIR)$(PREFIX)/share/man/man1/imapsync.1

install_dependencies:
	sh examples/install_modules_linux.sh

.PHONY: cidone ci

ci: cidone

cidone:
	rcsdiff RCS/* 
	cd W && rcsdiff RCS/*
	cd examples && rcsdiff RCS/*

###############
# Local goals
###############


.PHONY: test tests testp testf test3xx testv3 perlcritic

perlcritic: perlcritic_3.out perlcritic_2.out

perlcritic_1.out: imapsync
	perlcritic -1 imapsync > perlcritic_1.out || :

perlcritic_2.out: imapsync
	perlcritic -2 imapsync > perlcritic_2.out || :

perlcritic_3.out: imapsync
	perlcritic -3 imapsync > perlcritic_3.out || :

test_quick : test_quick_3xx 

test_quick_3xx: imapsync tests.sh
	CMD_PERL='perl -I./$(IMAPClient_3xx)' /usr/bin/time sh -x tests.sh locallocal

testv3: imapsync tests.sh
	CMD_PERL='perl -I./$(IMAPClient_3xx)' /usr/bin/time sh tests.sh
	./i3 --version >> .test_3xx

testv: testv3

test: .test_3xx

tests: test

.test_3xx: imapsync tests.sh
	CMD_PERL='perl -I./$(IMAPClient_3xx)' /usr/bin/time sh tests.sh 1>/dev/null
	./i3 --version >> .test_3xx

testf: clean_test test

.PHONY: lfo upload_lfo   public  imapsync_cidone

.dosify_bat: W/*.bat examples/*.bat
	unix2dos W/*.bat examples/*.bat
	touch .dosify_bat

dosify_bat: .dosify_bat

copy_win32:
	scp imapsync Admin@c:'C:/msys/1.0/home/Admin/imapsync/'

tests_win32: dosify_bat
	scp imapsync W/test.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
#	ssh Admin@c 'perl C:/msys/1.0/home/Admin/imapsync/imapsync --tests_debug'
	ssh Admin@c 'perl C:/msys/1.0/home/Admin/imapsync/imapsync --tests'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/test.bat'
#	ssh Admin@c 'tasklist /FI "PID eq 0"' 
#	ssh Admin@c 'tasklist /NH /FO CSV' 

tests_win32_dev: dosify_bat
	scp imapsync examples/file.txt W/test2.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/test2.bat'

tests_win32_dev3: dosify_bat
	scp imapsync W/test3.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/test3.bat'

test_imapsync_exe: dosify_bat
	scp W/test_exe.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	time ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/test_exe.bat'

.prereq_win32: examples/install_modules.bat .dosify_bat
	scp examples/install_modules.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/examples/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/examples/install_modules.bat'
	touch .prereq_win32

imapsync.exe: imapsync .prereq_win32
	rcsdiff imapsync
	ssh Admin@c 'perl -V'
	(date "+%s"| tr "\n" " "; echo -n "BEGIN " $(VERSION) ": "; date) >> W/.BUILD_EXE_TIME
	scp imapsync build_exe.bat W/test_exe.bat \
	Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/build_exe.bat'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/test_exe.bat'
	scp Admin@c:'C:/msys/1.0/home/Admin/imapsync/imapsync.exe' .
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/imapsync.exe --version' > ./VERSION_EXE
	dos2unix ./VERSION_EXE
	(date "+%s"| tr "\n" " "; echo -n "END   " $(VERSION) ": "; date) >> W/.BUILD_EXE_TIME

exe: imapsync build_exe.bat .dosify_bat
	(date "+%s"| tr "\n" " "; echo -n "BEGIN " $(VERSION) ": "; date) >> W/.BUILD_EXE_TIME
	scp imapsync build_exe.bat  Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/build_exe.bat'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/imapsync.exe --modules_version'
	scp Admin@c:'C:/msys/1.0/home/Admin/imapsync/imapsync.exe' .
	(date "+%s"| tr "\n" " "; echo -n "END   " $(VERSION) ": "; date) >> W/.BUILD_EXE_TIME




# C:\Users\mansour\Desktop\imapsync

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
	-I W/NTLM-1.09/blib/lib \
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


lfo: cidone   upload_lfo 


tarball: .tarball


.tarball: imapsync
	echo making tarball $(DIST_FILE)
	rcsdiff RCS/* 
	cd W && rcsdiff RCS/*
	cd examples && rcsdiff RCS/*
	mkdir -p dist
	mkdir -p ../prepa_dist/$(DIST_NAME)
	rsync -aCvH --delete --omit-dir-times --exclude dist/ --exclude imapsync.exe ./ ../prepa_dist/$(DIST_NAME)/
	#rsync -av ./imapsync.exe ../prepa_dist/$(DIST_NAME)/
	cd ../prepa_dist &&  (tar czfv $(DIST_FILE) $(DIST_NAME) || tar czfv  $(DIST_FILE) $(DIST_NAME))
	#ln -f ../prepa_dist/$(DIST_FILE) dist/
	cd ../prepa_dist && md5sum $(DIST_FILE) > $(DIST_FILE).md5.txt
	cd ../prepa_dist && md5sum -c $(DIST_FILE).md5.txt
	ls -l ../prepa_dist/$(DIST_FILE)
	touch .tarball


DO_IT       := $(shell test -d dist && { test -f ./dist/path_$(VERSION).txt || makepasswd --chars 4 > ./dist/path_$(VERSION).txt ; } )
DIST_SECRET := $(shell test -d dist && cat ./dist/path_$(VERSION).txt)
DIST_PATH   := ./dist/$(DIST_SECRET)

lalala:
	echo $(DIST_SECRET)

dist: cidone test clean all perlcritic dist_prepa dist_prepa_exe


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
	rsync -avHz --delete --exclude imapsync.exe \
	  . gilles@ks.lamiral.info:public_html/imapsync/

ksa:
	rsync -avHz --delete -P \
	  . gilles@ks.lamiral.info:public_html/imapsync/

upload_ks: ci tarball
	rsync -lptvHzP  $(PUBLIC_FILES) \
	root@ks.lamiral.info:/var/www/imapsync/
	rsync -lptvHzP  $(PUBLIC_FILES_W) \
	root@ks.lamiral.info:/var/www/imapsync/W/
	rsync -lptvHzPr  $(PUBLIC_FILES_IMAGES) \
	root@ks.lamiral.info:/var/www/imapsync/W/images/
	rsync -lptvHzP ./W/ks.htaccess \
	root@ks.lamiral.info:/var/www/imapsync/.htaccess
	rsync -lptvHzPr ./dist/ \
	root@ks.lamiral.info:/var/www/imapsync/dist/
	rsync -lptvHzPr ./examples/ \
	root@ks.lamiral.info:/var/www/imapsync/examples/

publish: dist upload_ks ksa
	echo Now ou can do make ml

PUBLIC_FILES = ./ChangeLog ./NOLIMIT ./LICENSE ./CREDITS ./FAQ \
./index.shtml ./INSTALL \
./VERSION ./VERSION_EXE \
./README ./TODO ./TUTORIAL.html ./GOOD_PRACTICES.html

PUBLIC_FILES_W = ./W/style.css \
./W/TIME \
./W/paypal.shtml ./W/paypal_return.shtml ./W/paypal_return_support.shtml


PUBLIC_FILES_IMAGES = ./W/images/

ml: dist_dir
	m4 -P W/ml_announce.in | mutt -H-
	mailq


upload_lfo:
	#rm -rf /home/gilles/public_html/www.linux-france.org/html/prj/imapsync/
	#rm -rf /home/gilles/public_html/www.linux-france.org/ftp/prj/imapsync/
	#rsync -avHz $(PUBLIC_FILES) \
	#/home/gilles/public_html/www.linux-france.org/html/prj/imapsync/
	rsync -lptvHzP ./W/memo glamiral@linux-france.org:imapsync_stats/memo
	rsync -lptvHzP ./W/lfo.htaccess \
	/home/gilles/public_html/www.linux-france.org/html/prj/imapsync/.htaccess
	sh ~/memo/lfo-rsync


.valid.index.shtml: index.shtml
	tidy -q  index.shtml> /dev/null
	validate --verbose index.shtml
	touch .valid.index.shtml

upload_index: .valid.index.shtml FAQ LICENSE CREDITS TUTORIAL.html GOOD_PRACTICES.html W/*.bat examples/*.bat examples/*.sh
	rcsdiff index.shtml FAQ LICENSE CREDITS W/*.bat examples/*.bat index.shtml 
	rsync -avH index.shtml FAQ NOLIMIT LICENSE CREDITS TUTORIAL.html GOOD_PRACTICES.html root@ks.lamiral.info:/var/www/imapsync/
	rsync -avH W/*.bat root@ks.lamiral.info:/var/www/imapsync/W/
	rsync -avH examples/*.bat examples/*.sh root@ks.lamiral.info:/var/www/imapsync/examples/

install_dependencies:
	cpan install Mail::IMAPClient
	cpan install Term::ReadKey
	cpan install IO::Socket::SSL
	cpan install Digest::HMAC_MD5
	cpan install URI::Escape
	cpan install File::Copy::Recursive
	cpan install Data::Uniqid
	cpan install Authen::NTLM

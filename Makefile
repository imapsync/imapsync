
# $Id: Makefile,v 1.257 2017/09/11 11:11:18 gilles Exp gilles $	

.PHONY: help usage all doc

help: usage

usage:
	@echo "      imapsync $(VERSION), You can do :"
	@echo "make testp   # it shows needed Perl modules from your distro or CPAN"
	@echo "make install # as root"
	@echo ""
	@echo "All other goals are for the upstream developper"

	@echo "make testf   # run tests"
	@echo "make testv   # run tests verbosely"
	@echo "make test_quick # few tests verbosely"
	@echo "make W/test.bat # run --tests and W/test.bat on win32"
	@echo "make W/test_tests.bat # run --tests on win32"
	@echo "make W/test_testsdebug.bat # run --testsdebug on win32"
	@echo "make W/test2.bat # run W/test2.bat on win32"
	@echo "make W/test3.bat # run W/test3.bat on win32"
	@echo "make W/test_reg.bat # run W/test_reg.bat on win32"
	@echo "make W/test_exe.bat   # run W/test_exe.bat on win32"
	@echo "make W/test_exe_tests.bat  # run W/test_exe_tests.bat on win32"
	@echo "make W/test_exe_2.bat # run W/test_exe_2.bat on win32"
	@echo "make examples/sync_loop_windows.bat # run examples/sync_loop_windows.bat on win32"
        
	@echo "make win32_prereq # run W/install_modules.bat on win32"
	@echo "make win32_update_ssl # run W/install_module_ssl.bat on win32"
	@echo "make all     "
	@echo "make upload_tests # upload tests.sh"
	@echo "make upload_index"
	@echo "make upload_FAQ    # upload FAQs and documentation"
	@echo "make upload_X      # upload online UI"
	@echo "make upload_latest # upload latest imapsync and binaries (dev)" 
	@echo "make upload_cgi    # upload latest imapsync" 
	@echo "make valid_index # check index.shtml for good syntax"
	@echo "make upload_ks"
	@echo "make imapsync.exe"
	@echo "make bin           # build mac & win & linux binaries"
	@echo "make mac           # build mac binary"
	@echo "make win           # build win binary"
	@echo "make lin           # build linux binary"
	@echo "make publish"
	@echo "make crit          # run perlcritic on imapsync"
	@echo "make prereq # Generates W/prereq.*"
	@echo "make cl # Check links of index.shtml"
	@echo "make cle # Check links of S/*.shtml" 
	@echo "make mactestsdebug # run ./imapsync --testsdebug on Mac"
	@echo "make mactests      # run ./imapsync --tests      on Mac"
	@echo "make ks2testsdebug # run ./imapsync --testsdebug on ks2"
	@echo "make ks2tests      # run ./imapsync --tests      on ks2"


PREFIX ?= /usr
DIST_NAME=imapsync-$(VERSION)
DIST_FILE=$(DIST_NAME).tgz
DEB_FILE=$(DIST_NAME).deb

VERSION=$(shell perl -I$(IMAPClient) ./imapsync --version 2>/dev/null || cat VERSION)
VERSION_PREVIOUS=$(shell perl -I$(IMAPClient) ./dist/imapsync --version 2>/dev/null || echo ERROR)
VERSION_EXE=$(shell cat ./VERSION_EXE)

HELLO=$(shell date;uname -a)
IMAPClient_3xx=./W/Mail-IMAPClient-3.39/lib
IMAPClient=$(IMAPClient_3xx)

HOSTNAME = $(shell hostname -s)
ARCH     = $(shell uname -m)
KERNEL   = $(shell uname -s)
BIN_NAME = imapsync_bin_$(KERNEL)_$(ARCH)
DISTRO_NAME = $(shell lsb_release -i -s || echo Unknown)
DISTRO_RELEASE = $(shell lsb_release -r -s || echo 0.0)
DISTRO_CODE = $(shell lsb_release -c -s || echo Unknown)
DISTRO = $(DISTRO_NAME)_$(DISTRO_RELEASE)_$(DISTRO_CODE)

hello:
	@echo "$(VERSION)"
	@echo "$(IMAPClient)"
	@echo "$(HOSTNAME)"
	@echo "$(ARCH)"
	@echo "$(KERNEL)"
	@echo "$(BIN_NAME)"
	@echo "$(DISTRO)"


all: doc VERSION biz prereq allcritic bin VERSION_EXE 

testp :
	sh INSTALL.d/prerequisites_imapsync
	@perl -c imapsync || { echo; echo "Read the INSTALL file to solve Perl module dependencies!"; exit 1; }

ChangeLog: imapsync
	rlog imapsync > ChangeLog

README: imapsync
	pod2text --loose imapsync > README

VERSION: imapsync
	rcsdiff imapsync
	perl -I./$(IMAPClient) ./imapsync --version > ./VERSION
	touch -r ./imapsync ./VERSION

VERSION_EXE: imapsync
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/imapsync.exe --version' > ./VERSION_EXE
	dos2unix ./VERSION_EXE
	touch -r ./imapsync ./VERSION_EXE


doc/GOOD_PRACTICES.html: doc/GOOD_PRACTICES.t2t
	txt2tags -i doc/GOOD_PRACTICES.t2t  -t html --toc  -o doc/GOOD_PRACTICES.html
	./W/tools/validate_html4 doc/GOOD_PRACTICES.html
	./W/tools/validate       doc/GOOD_PRACTICES.html
	

doc/TUTORIAL_Unix.html: doc/TUTORIAL_Unix.t2t
	txt2tags -i doc/TUTORIAL_Unix.t2t -t html --toc  -o doc/TUTORIAL_Unix.html
	./W/tools/validate_html4 doc/TUTORIAL_Unix.html
	./W/tools/validate       doc/TUTORIAL_Unix.html


doc:  README  ChangeLog doc/TUTORIAL_Unix.html doc/GOOD_PRACTICES.html W/imapsync.1 

.PHONY: clean clean_tilde clean_test doc clean_log clean_bak clean_permissions

clean: clean_tilde clean_man clean_log clean_bak clean_permissions

clean_permissions:
	chmod a-x Makefile FAQ.d/FAQ.*.txt README_Windows.txt
	chmod a-x INSTALL.d/INSTALL.*.txt 
	chmod a-x X/progress.html X/imapsync_form.html 
	chmod a-x S/*.shtml S/*.html  
	chmod a-x doc/*.t2t dist/*.txt

clean_test:
	rm -f .test_3xx

clean_tilde:
	rm -f *~ W/*~ FAQ.d/*~ S/*~ INSTALL.d/*~ examples/*~

clean_log:
	rm -f LOG_imapsync/*.txt
	rm -f examples/LOG_imapsync/*.txt

clean_bak:
	rm -f index.shtml.bak ./S/style.css.bak

.PHONY: install dist man

man: imapsync.1

clean_man:
	rm -f imapsync.1

W/imapsync.1: imapsync
	pod2man imapsync > W/imapsync.1

install: testp W/imapsync.1
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	install imapsync $(DESTDIR)$(PREFIX)/bin/imapsync
	chmod 755 $(DESTDIR)$(PREFIX)/bin/imapsync
	mkdir -p $(DESTDIR)$(PREFIX)/share/man/man1
	install W/imapsync.1 $(DESTDIR)$(PREFIX)/share/man/man1/imapsync.1
	chmod 644 $(DESTDIR)$(PREFIX)/share/man/man1/imapsync.1



.PHONY: cidone ci

ci: cidone

cidone:
	rcsdiff W/*.bat W/*.sh W/*.out W/*.txt W/*.htaccess
	rcsdiff doc/*.t2t
	rcsdiff INSTALL.d/*.txt INSTALL.d/prerequisites_imapsync
	rcsdiff FAQ.d/*.txt
	rcsdiff examples/*.sh examples/*.bat examples/*.txt 
	rcsdiff RCS/*
	rcsdiff W/tools/backup_old_dist W/tools/gen_README_dist W/tools/validate_html4 W/tools/validate_xml_html5 W/tools/fix_email_for_exchange.py
	rcsdiff S/*.txt S/*.shtml S/*.html 

###############
# Local goals
###############

.PHONY: prereq test tests unitests testp testf test3xx testv3 perlcritic allcritic crit compok dev

dev: test crit bin

docker:
	ssh ks3 'cd docker/imapsync && . memo'

compok: W/.compok


W/.compok: imapsync
	perl -c imapsync
	touch W/.compok

prereq: W/prereq.scandeps.$(DISTRO).txt

W/prereq.scandeps.$(DISTRO).txt: INSTALL.d/prerequisites_imapsync imapsync
	scandeps -c -x  imapsync | tee W/prereq.scandeps.$(DISTRO).txt
	rcsdiff W/prereq.scandeps.$(DISTRO).txt || { echo 'rcsdiff detected a diff' | ci -l W/prereq.scandeps.$(DISTRO).txt ; }
	./INSTALL.d/prerequisites_imapsync | tee W/prereq.$(DISTRO).txt


crit: allcritic

perlcritic: W/perlcritic_3.out W/perlcritic_2.out 

allcritic: W/perlcritic_4.out W/perlcritic_3.out W/perlcritic_2.out W/perlcritic_1.out

W/perlcritic_1.out: imapsync W/.compok 
	perlcritic --statistics -1 imapsync > W/perlcritic_1.out.tmp || :
	mv W/perlcritic_1.out.tmp W/perlcritic_1.out
	echo | ci -l W/perlcritic_1.out

W/perlcritic_2.out: imapsync W/.compok
	perlcritic --statistics -2 imapsync > W/perlcritic_2.out.tmp || :
	mv W/perlcritic_2.out.tmp W/perlcritic_2.out
	echo | ci -l W/perlcritic_2.out

W/perlcritic_3.out: imapsync W/.compok
	perlcritic --statistics -3 imapsync > W/perlcritic_3.out.tmp || :
	mv W/perlcritic_3.out.tmp W/perlcritic_3.out
	echo | ci -l W/perlcritic_3.out

W/perlcritic_4.out: imapsync W/.compok
	perlcritic --statistics -4 imapsync > W/perlcritic_4.out.tmp || :
	mv W/perlcritic_4.out.tmp W/perlcritic_4.out
	echo | ci -l W/perlcritic_4.out


test_quick : test_quick_3xx 

test_quick_3xx: imapsync tests.sh
	CMD_PERL='perl -I./$(IMAPClient_3xx)' /usr/bin/time sh -x tests.sh locallocal

testv3: imapsync tests.sh
	CMD_PERL='perl -I./$(IMAPClient_3xx)' /usr/bin/time sh tests.sh



testv: testv3

test: .test_3xx

tests: test

unitests: 
	perl -I./$(IMAPClient_3xx) ./imapsync --tests

# .test_3xx is created by tests.sh with success at all mandatory tests
.test_3xx: imapsync tests.sh
	CMD_PERL='perl -I./$(IMAPClient_3xx)' /usr/bin/time sh tests.sh 1>/dev/null

testf: clean_test test

.PHONY: lfo upload_lfo dosify_bat public  imapsync_cidone

dosify_bat:
	unix2dos W/*.bat examples/*.bat 

copy_win32:
	scp imapsync Admin@c:'C:/msys/1.0/home/Admin/imapsync/'

W/test.bat:
	unix2dos W/test.bat
	scp imapsync W/test.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
#	ssh Admin@c 'perl C:/msys/1.0/home/Admin/imapsync/imapsync --testsdebug'
	ssh Admin@c 'perl C:/msys/1.0/home/Admin/imapsync/imapsync --tests'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/test.bat'
#	ssh Admin@c 'tasklist /FI "PID eq 0"' 
#	ssh Admin@c 'tasklist /NH /FO CSV' 


W/test_tests.bat: 
	unix2dos  W/test_tests.bat
	scp imapsync W/test_tests.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/test_tests.bat'
	./W/check_winerr test_tests.bat

W/test_testsdebug.bat: 
	unix2dos  W/test_testsdebug.bat
	scp imapsync W/test_testsdebug.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/test_testsdebug.bat'
	./W/check_winerr test_testsdebug.bat



.PHONY: W/*.bat examples/*


examples/sync_loop_windows.bat: 
	unix2dos examples/sync_loop_windows.bat
	scp imapsync examples/file.txt examples/sync_loop_windows.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/sync_loop_windows.bat --nodry --dry --nodry'
#	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/sync_loop_windows.bat '

W/test2.bat: 
	unix2dos W/test2.bat
	scp imapsync W/test2.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/test2.bat'

W/test3.bat:
	unix2dos W/test3.bat
	scp imapsync W/test3.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/test3.bat'

W/test_reg.bat:
	unix2dos W/test_reg.bat
	scp imapsync W/test_reg.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/test_reg.bat'


W/test_xoauth2.bat:
	unix2dos W/test_xoauth2.bat
	scp imapsync W/test_xoauth2.bat /g/var/pass/imapsync-xoauth2-15f8456ad5b7_notasecret.p12 /fb/i/secret.xoauth2 Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/test_xoauth2.bat'


W/test_exe_2.bat: 
	unix2dos W/test_exe_2.bat
	scp imapsync W/test_exe_2.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/test_exe_2.bat'

W/test3_gmail.bat: 
	unix2dos W/test3_gmail.bat
	scp imapsync W/test3_gmail.bat /g/var/pass/secret.gilles_gmail Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/test3_gmail.bat'

test_exe: W/test_exe.bat

W/test_exe.bat:
	unix2dos W/test_exe.bat
	scp W/test_exe.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/test_exe.bat'
	./W/check_winerr test_exe.bat

W/test_exe_tests.bat:
	unix2dos W/test_exe_tests.bat
	scp W/test_exe_tests.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/test_exe_tests.bat'
	./W/check_winerr test_exe_tests.bat

W/build_exe.bat:
	unix2dos W/build_exe.bat
	scp W/build_exe.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/build_exe.bat'
	./W/check_winerr build_exe.bat


W/learn_func.bat:
	unix2dos W/learn_func.bat
	scp W/learn_func.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/learn_func.bat'
	./W/check_winerr learn_func.bat

win32_prereq: W/install_modules.bat

W/install_modules.bat:
	unix2dos W/install_modules.bat
	scp W/install_modules.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/install_modules.bat'
	./W/check_winerr install_modules.bat


win32_update_ssl:
	scp W/install_module_ssl.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/install_module_ssl.bat'

W/install_module_one.bat:
	unix2dos W/install_module_one.bat
	scp W/install_module_one.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/install_module_one.bat'

W/uninstall_module_one.bat:
	unix2dos W/uninstall_module_one.bat
	scp W/uninstall_module_one.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/uninstall_module_one.bat'

imapsync.exe: imapsync
	rcsdiff imapsync
	ssh Admin@c 'perl -V'
	(date "+%s"| tr "\n" " "; echo -n "BEGIN " $(VERSION) ": "; date) >> W/.BUILD_EXE_TIME
	unix2dos W/build_exe.bat W/test_exe.bat W/install_modules.bat
	scp imapsync W/build_exe.bat W/test_exe.bat W/install_modules.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/build_exe.bat'
	./W/check_winerr build_exe.bat
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/test_exe.bat'
	./W/check_winerr test_exe.bat
	rm -f imapsync.exe
	scp Admin@c:'C:/msys/1.0/home/Admin/imapsync/imapsync.exe' .
	(date "+%s"| tr "\n" " "; echo -n "END   " $(VERSION) ": "; date) >> W/.BUILD_EXE_TIME

exe: imapsync
	(date "+%s"| tr "\n" " "; echo -n "BEGIN " $(VERSION) ": "; date) >> W/.BUILD_EXE_TIME
	scp imapsync W/build_exe.bat W/install_modules.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/build_exe.bat'
	./W/check_winerr build_exe.bat
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/imapsync.exe --justbanner'
	rm -f imapsync.exe
	scp Admin@c:'C:/msys/1.0/home/Admin/imapsync/imapsync.exe' .
	(date "+%s"| tr "\n" " "; echo -n "END   " $(VERSION) ": "; date) >> W/.BUILD_EXE_TIME




zip: dosify_bat
	rm -rfv ../prepa_zip/imapsync_$(VERSION_EXE)/
	mkdir -p ../prepa_zip/imapsync_$(VERSION_EXE)/FAQ.d/ ../prepa_zip/imapsync_$(VERSION_EXE)/Cook/
	cp -av examples/imapsync_example.bat examples/sync_loop_windows.bat examples/file.txt  ../prepa_zip/imapsync_$(VERSION_EXE)/
	cp -av W/build_exe.bat W/install_modules.bat W/test_cook_exe.bat W/test_cook_src.bat imapsync ../prepa_zip/imapsync_$(VERSION_EXE)/Cook/
	for f in README ; do cp -av $$f ../prepa_zip/imapsync_$(VERSION_EXE)/$$f.txt ; done
	cp -av FAQ.d/*.txt ../prepa_zip/imapsync_$(VERSION_EXE)/FAQ.d/
	cp -av imapsync.exe README_Windows.txt ../prepa_zip/imapsync_$(VERSION_EXE)/
	unix2dos ../prepa_zip/imapsync_$(VERSION_EXE)/*.txt
	cd ../prepa_zip/ && rm -f ./imapsync_$(VERSION_EXE).zip && zip -r ./imapsync_$(VERSION_EXE).zip ./imapsync_$(VERSION_EXE)/
	scp ../prepa_zip/imapsync_$(VERSION_EXE).zip Admin@c:'C:/msys/1.0/home/Admin/'
	cp ../prepa_zip/imapsync_$(VERSION_EXE).zip /fe/imapsync/


# C:\Users\mansour\Desktop\imapsync

.PHONY: mac bin win lin

mac: imapsync_bin_Darwin

imapsync_bin_Darwin: imapsync W/build_mac.sh INSTALL.d/prerequisites_imapsync
	rcsdiff imapsync
	rsync -p -e 'ssh -p 995' imapsync W/build_mac.sh INSTALL.d/prerequisites_imapsync gilleslamira@gate.polarhome.com:
	ssh -p 995 gilleslamira@gate.polarhome.com 'sh build_mac.sh'
	rsync -P -e 'ssh -p 995' gilleslamira@gate.polarhome.com:imapsync_bin_Darwin .

mactests:
	rsync -p -e 'ssh -p 995' imapsync gilleslamira@gate.polarhome.com:
	ssh -p 995 gilleslamira@gate.polarhome.com '. .bash_profile; perl imapsync --tests'

mactestsdebug:
	rsync -p -e 'ssh -p 995' imapsync gilleslamira@gate.polarhome.com:
	ssh -p 995 gilleslamira@gate.polarhome.com '. .bash_profile; perl imapsync --testsdebug --debug'

bin: lin mac win 

lin: $(BIN_NAME)

win: imapsync.exe



$(BIN_NAME): imapsync
	rcsdiff imapsync
	{ pp -o $(BIN_NAME) -I $(IMAPClient_3xx) \
	-M Mail::IMAPClient \
	-M Net::SSLeay -M IO::Socket -M IO::Socket::INET6 -M IO::Socket::SSL \
	-M Digest::MD5 -M Digest::HMAC_MD5 -M Term::ReadKey \
	-M Authen::NTLM -M HTML::Entities -M JSON::WebToken \
	imapsync ; \
	} || :
	./$(BIN_NAME)
	./$(BIN_NAME) --tests
	./$(BIN_NAME) --testslive
	./$(BIN_NAME) --justbanner
	


lfo: upload_lfo 

.PHONY: tarball

tarball: 
	echo making tarball ../prepa_dist/$(DIST_FILE)
	rcsdiff RCS/* 
	cd W && rcsdiff RCS/*
	cd examples && rcsdiff RCS/*
	mkdir -p dist
	mkdir -p ../prepa_dist/$(DIST_NAME)
	rsync -aCvH --delete --omit-dir-times --exclude dist/ --exclude imapsync.exe ./ ../prepa_dist/$(DIST_NAME)/
	cd ../prepa_dist && tar czfv $(DIST_FILE) $(DIST_NAME)
	cd ../prepa_dist && md5sum $(DIST_FILE) > $(DIST_FILE).md5.txt
	cd ../prepa_dist && md5sum -c $(DIST_FILE).md5.txt
	ls -l ../prepa_dist/$(DIST_FILE)



DIST_PATH   := ./dist/

dist: cidone test clean all perlcritic dist_prepa dist_zip README_dist


md5:
	cd $(DIST_PATH)/ && md5sum *

sha:
	cd $(DIST_PATH)/ && sha512sum *

.PHONY: moveoldrelease ks2testsdebug ks2tests README_dist

moveoldrelease:
	./W/tools/backup_old_dist


dist_prepa: tarball moveoldrelease
	ln -f ../prepa_dist/$(DIST_FILE) $(DIST_PATH)/
	rcsdiff imapsync
	cp -a ../prepa_dist/$(DIST_NAME)/imapsync $(DIST_PATH)/
	cp -a ../prepa_dist/$(DIST_NAME)/imapsync_bin_Darwin $(DIST_PATH)/
	#cd $(DIST_PATH)/ && md5sum $(DIST_FILE) > $(DIST_FILE).md5.txt
	#cd $(DIST_PATH)/ && md5sum -c $(DIST_FILE).md5.txt
	ls -l $(DIST_PATH)/


dist_zip: zip 
	cp -a ../prepa_zip/imapsync_$(VERSION_EXE).zip $(DIST_PATH)/

README_dist:
	sh W/tools/gen_README_dist > $(DIST_PATH)/README.txt
	unix2dos $(DIST_PATH)/README.txt

.PHONY: publish upload_ks ks valid_index biz

biz: S/imapsync_sold_by_country.txt

S/imapsync_sold_by_country.txt: imapsync
	cd S/ && /g/bin/imapsync_by_country && echo | ci -l imapsync_sold_by_country.txt
	

ks:
	rsync -avHz --delete --exclude imapsync.exe \
	  . gilles@ks.lamiral.info:public_html/imapsync/

ksa:
	rsync -avHz --delete -P \
	  . gilles@ks.lamiral.info:public_html/imapsync/

ks3:
	rsync -avHz --delete -P \
	  . gilles@ks3.lamiral.info:public_html/imapsync/

upload_tests: tests.sh
	rsync -avHz --delete -P \
	  tests.sh \
	  gilles@ks.lamiral.info:public_html/imapsync/


ks2testsdebug:
	rsync -aP imapsync gilles@ks.lamiral.info:public_html/imapsync/imapsync
	ssh gilles@ks.lamiral.info 'public_html/imapsync/imapsync --testsdebug'

ks2tests:
	rsync -aP imapsync gilles@ks.lamiral.info:public_html/imapsync/imapsync
	ssh gilles@ks.lamiral.info 'public_html/imapsync/imapsync --tests'

publish: dist upload_ks ksa 
	echo Now ou can do make ml

PUBLIC = ./ChangeLog ./NOLIMIT ./LICENSE ./CREDITS ./FAQ \
./index.shtml ./INSTALL ./README_Windows.txt \
./VERSION ./VERSION_EXE ./imapsync \
./README  ./TODO



PUBLIC_doc = ./doc/TUTORIAL_Unix.html ./doc/GOOD_PRACTICES.html

ml:  
	rcsdiff W/ml_announce.in
	m4 -P W/ml_announce.in | mutt -H-
	mailq


upload_lfo:
	#rm -rf /home/gilles/public_html/www.linux-france.org/html/prj/imapsync/
	#rm -rf /home/gilles/public_html/www.linux-france.org/ftp/prj/imapsync/
	#rsync -avHz $(PUBLIC) \
	#/home/gilles/public_html/www.linux-france.org/html/prj/imapsync/
	rsync -lptvHzP ./W/memo glamiral@linux-france.org:imapsync_stats/memo
	rsync -lptvHzP ./W/lfo.htaccess \
	/home/gilles/public_html/www.linux-france.org/html/prj/imapsync/.htaccess
	sh ~/memo/lfo-rsync

valid_index: W/.valid.index.shtml

cl: ./W/checklink.txt

./W/checklink.txt: index.shtml
	checklink -b -q  http://lamiral.info/~gilles/imapsync/ |tee ./W/checklink.txt

cle: ./W/checklinkext.txt

./W/checklinkext.txt: S/news.shtml S/external.shtml  S/imapservers.shtml S/template_xhtml1.shtml
	checklink -b -q  \
	http://lamiral.info/~gilles/imapsync/S/template_xhtml1.shtml \
	http://lamiral.info/~gilles/imapsync/S/news.shtml     \
	http://lamiral.info/~gilles/imapsync/S/external.shtml \
	http://lamiral.info/~gilles/imapsync/S/imapservers.shtml \
	| tee ./W/checklinkext.txt

W/.valid.index.shtml: index.shtml S/*.shtml
	for f in index.shtml S/*.shtml; do echo tidy -q $$f; tidy -q  $$f > /dev/null; done
	./W/tools/validate_xml_html5 index.shtml S/*.shtml
	touch W/.valid.index.shtml

.PHONY: upload_index upload_FAQ ci_imapsync upload_bin

upload_bin:
	rsync -a imapsync.exe imapsync_bin_Darwin imapsync_bin_Linux_i686 imapsync ../imapsync_website/
	rsync -aHvz --delete ../imapsync_website/   root@ks.lamiral.info:/var/www/imapsync/

upload_index: W/.valid.index.shtml 
	rcsdiff index.shtml S/style.css S/*.shtml FAQ.d/*.txt LICENSE CREDITS TODO examples/*.bat index.shtml INSTALL.d/*.txt
	rsync -avH index.shtml FAQ INSTALL  NOLIMIT LICENSE CREDITS TODO S/robots.txt S/favicon.ico ../imapsync_website/
	rsync -aHv  --delete ./W/ks.htaccess ../imapsync_website/.htaccess
	rsync -aHv  --delete S/ ../imapsync_website/S/
	rsync -aHv  --delete ./examples/  ../imapsync_website/examples/
	rsync -aHv  --delete ./INSTALL.d/ ../imapsync_website/INSTALL.d/
	rsync -aHv  --delete ./FAQ.d/     ../imapsync_website/FAQ.d/
	rsync -avH  --delete ./doc/       ../imapsync_website/doc/
	rsync -aHvz --delete ../imapsync_website/ root@ks.lamiral.info:/var/www/imapsync/


ci_imapsync:
	rcsdiff imapsync

upload_latest: unitests ci_imapsync bin
	rsync -a imapsync imapsync_bin_Linux_i686 imapsync_bin_Darwin imapsync.exe ../imapsync_website/
	rsync -aHvz --delete ../imapsync_website/ root@ks.lamiral.info:/var/www/imapsync/

upload_cgi: unitests ks2tests ci_imapsync 
	rsync -a imapsync  ../imapsync_website/
	rsync -aHvz --delete ../imapsync_website/ root@ks.lamiral.info:/var/www/imapsync/
	

upload_X:
	./W/tools/validate_xml_html5 X/imapsync_form.html
	rcsdiff X/imapsync_form.html
	rsync -av   --delete   X/ ../imapsync_website/X/
	rsync -aHvz --delete  ../imapsync_website/ root@ks.lamiral.info:/var/www/imapsync/

upload_FAQ:
	rcsdiff FAQ.d/*.txt  LICENSE CREDITS TODO INSTALL.d/*.txt 
	rsync -avH FAQ INSTALL  CREDITS TODO ../imapsync_website/
	rsync -aHv  --delete  ./INSTALL.d/          ../imapsync_website/INSTALL.d/
	rsync -aHv  --delete  ./FAQ.d/              ../imapsync_website/FAQ.d/
	rsync -avH  --delete  ./doc/                ../imapsync_website/doc/
	rsync -aHvz --delete ../imapsync_website/   root@ks.lamiral.info:/var/www/imapsync/


upload_ks: ci tarball
	rsync -aHv           $(PUBLIC)       ../imapsync_website/
	rsync -aHv  --delete ./W/ks.htaccess ../imapsync_website/.htaccess
	rsync -avH           ./S/            ../imapsync_website/S/
	rsync -aHv  --delete ./dist/         ../imapsync_website/dist/
	rsync -aHv  --delete ./examples/     ../imapsync_website/examples/
	rsync -aHv  --delete ./INSTALL.d/     ../imapsync_website/INSTALL.d/
	rsync -aHv  --delete ./FAQ.d/     ../imapsync_website/FAQ.d/
	rsync -avH  --delete ./doc/       ../imapsync_website/doc/
	rsync -aHvz --delete ../imapsync_website/ root@ks.lamiral.info:/var/www/imapsync/

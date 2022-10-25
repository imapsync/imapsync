
# $Id: Makefile,v 1.349 2022/09/15 08:43:25 gilles Exp gilles $	

.PHONY: help usage all doc

help: usage

usage:
	@echo "     this is imapsync $(VERSION), You can do :"
	@echo "make testp   # it shows needed Perl modules from your distro or CPAN"
	@echo "make install # as root"
	@echo ""
	@echo "All other goals are for the upstream developper"

	@echo "make testf      # run tests"
	@echo "make testv      # run tests verbosely"
	@echo "make test_quick # few tests verbosely"
	@echo "make win32testsbat         # run --tests and W/test.bat on win32"
	@echo "make win32tests            # run --tests        on win32"
	@echo "make win32testsdebug       # run --testsdebug   on win32"
	@echo "make W/test2.bat           # run W/test2.bat    on win32"
	@echo "make W/test3.bat           # run W/test3.bat    on win32"
	@echo "make W/test_reg.bat        # run W/test_reg.bat on win32"
	@echo "make W/test_exe.bat        # run W/test_exe.bat on win32"
	@echo "make W/test_exe_tests.bat  # run W/test_exe_tests.bat on win32"
	@echo "make W/test_exe_2.bat      # run W/test_exe_2.bat on win32"
	@echo "make examples/sync_loop_windows.bat # run examples/sync_loop_windows.bat on win32"
        
	@echo "make W/install_modules.bat # run W/install_modules.bat on win32"
	@echo "make W/install_module_one.bat # run W/install_module_one.bat on win32"
	@echo "make W/install_module_ssl.bat # run W/install_module_ssl.bat on win32"
	@echo "make all     "
	@echo "make upload_tests # upload tests.sh"
	@echo "make upload_index"
	@echo "make upload_FAQ    # upload FAQs and documentation"
	@echo "make upload_X      # upload online UI"
	@echo "make upload_csv    # upload online CSV service"
	@echo "make upload_latest # upload latest imapsync and binaries (dev)" 
	@echo "make upload_cgi    # upload latest imapsync online, after local and remote --tests success." 
	@echo "make upload_cgi_memo  # upload cgi_memo stat_patterns.txt to /X servers." 
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
	@echo "make mactestslive  # run ./imapsync --testslive  on Mac"
	@echo "make ks5testsdebug # run ./imapsync --testsdebug on ks5"
	@echo "make ks5tests      # run ./imapsync --tests      on ks5"
	@echo "make ks5testslive  # run ./imapsync --testslive  on ks5"


PREFIX ?= /usr
DIST_PATH := dist2/
VERSION := $(shell perl ./imapsync --version 2>/dev/null || cat VERSION)
VERSION_PREVIOUS := $(shell perl ./$(DIST_PATH)/imapsync --version 2>/dev/null || echo ERROR)


DIST_NAME := imapsync-$(VERSION)
DIST_FILE := $(DIST_NAME).tgz
DEB_FILE  := $(DIST_NAME).deb

HELLO := $(shell date;uname -a)

HOSTNAME := $(shell hostname -s)
ARCH     := $(shell uname -m)
KERNEL   := $(shell uname -s)
BIN_NAME := imapsync_bin_$(KERNEL)_$(ARCH)
DISTRO_NAME := $(shell lsb_release -i -s || echo Unknown)
DISTRO_RELEASE := $(shell lsb_release -r -s || echo 0.0)
DISTRO_CODE := $(shell lsb_release -c -s || echo Unknown)
DISTRO := $(DISTRO_NAME)_$(DISTRO_RELEASE)_$(DISTRO_CODE)

hello:
	@echo "VERSION          $(VERSION)"
	@echo "DIST_NAME        $(DIST_NAME)"
	@echo "VERSION_PREVIOUS $(VERSION_PREVIOUS)"
	@echo "HOSTNAME         $(HOSTNAME)"
	@echo "ARCH             $(ARCH)"
	@echo "KERNEL           $(KERNEL)"
	@echo "BIN_NAME         $(BIN_NAME)"
	@echo "DISTRO           $(DISTRO)"


all: doc VERSION biz prereq allcritic 

testp:
	sh INSTALL.d/prerequisites_imapsync
	@perl -c imapsync || { echo; echo "Read the INSTALL file to solve Perl module dependencies!"; exit 1; }

ChangeLog: imapsync
	rlog imapsync > ChangeLog

README: imapsync
	pod2text --loose imapsync > README
	chmod -x README

VERSION: imapsync
	rcsdiff imapsync
	./imapsync --version > ./VERSION
	touch -r ./imapsync ./VERSION


doc/GOOD_PRACTICES.html: doc/GOOD_PRACTICES.t2t
	txt2tags -i doc/GOOD_PRACTICES.t2t  -t html --toc  -o doc/GOOD_PRACTICES.html
	./W/tools/validate_html4 doc/GOOD_PRACTICES.html
	./W/tools/validate       doc/GOOD_PRACTICES.html


doc/TUTORIAL_Unix.html: doc/TUTORIAL_Unix.t2t
	txt2tags -i doc/TUTORIAL_Unix.t2t -t html --toc  -o doc/TUTORIAL_Unix.html
	./W/tools/validate_html4 doc/TUTORIAL_Unix.html
	./W/tools/validate       doc/TUTORIAL_Unix.html


doc:  README  ChangeLog doc/TUTORIAL_Unix.html doc/GOOD_PRACTICES.html W/imapsync.1 

.PHONY: clean clean_tilde clean_test doc clean_log clean_bak clean_permissions clean_oauth2

clean: clean_tilde clean_man clean_log clean_bak clean_permissions clean_oauth2

clean_permissions:
	chmod a-x Makefile FAQ.d/FAQ.*.txt README_Windows.txt
	chmod a-x FAQ.d/RCS/FAQ.*.txt,v
	chmod a-x INSTALL.d/INSTALL.*.txt 
	chmod a-x X/progress.html X/imapsync_form.html 
	chmod a-x S/*.shtml S/*.html  index.shtml S/RCS/*.shtml,v S/RCS/*.html,v 
	chmod a-x doc/*.t2t $(DIST_PATH)/*.txt

clean_test:
	rm -f .test_3xx

clean_tilde:
	rm -f *~ W/*~ FAQ.d/*~ S/*~ INSTALL.d/*~ examples/*~

clean_log:
	rm -f LOG_imapsync/*.txt
	rm -f examples/LOG_imapsync/*.txt

clean_bak:
	rm -f index.shtml.bak ./S/style.css.bak

clean_oauth2:
	rm -f oauth2/typescript oauth2/D_*txt

.PHONY: install dist man

man:  W/imapsync.1

clean_man:
	rm -f  W/imapsync.1

W/imapsync.1: imapsync
	mkdir -p W
	pod2man imapsync > W/imapsync.1

install: testp W/imapsync.1
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	install imapsync $(DESTDIR)$(PREFIX)/bin/imapsync
	chmod 755 $(DESTDIR)$(PREFIX)/bin/imapsync
	mkdir -p $(DESTDIR)$(PREFIX)/share/man/man1
	install W/imapsync.1 $(DESTDIR)$(PREFIX)/share/man/man1/imapsync.1
	chmod 644 $(DESTDIR)$(PREFIX)/share/man/man1/imapsync.1

###############
# Local goals
###############

.PHONY: dailybuild dailytests prereq test tests unitests testp testf test3xx perlcritic allcritic crit compok dev cover tidy nytprof functree

dev: test functree crit cover nytprof bin


dailytests: linuxtests win32tests win64tests mactests

dailybuild: linuxbuild win32build win64build macbuild

linuxtests:
	./imapsync --tests

linuxtestsdebug:
	./imapsync --testsdebug

testsdebug: linuxtestsdebug win64testsdebug win32testsdebug mactestsdebug 

testslive:  mactestslive




docker:
	@echo "make docker_copy_to_vp3 # copy imapsync Dockerfile memo_docker to vp3"
	@echo "make docker_build       # build the imapsync docker image"
	@echo "make docker_upload_docker_hub  # upload last build to https://hub.docker.com/r/gilleslamiral/imapsync"
	@echo "ssh vp3 THEN cd docker/imapsync && . memo_docker"

docker_build: docker_copy_to_vp3
	ssh vp3 'cd docker/imapsync && . memo_docker && imapsync_docker_build'


docker_copy_to_vp3:
	ssh vp3 'mkdir -p docker/imapsync/ var/pass/'
	rsync -av /g/var/pass/secret.docker vp3:var/pass/secret.docker
	rsync -av imapsync INSTALL.d/Dockerfile INSTALL.d/memo_docker INSTALL.d/prerequisites_imapsync INSTALL.d/secret.txt vp3:docker/imapsync/
	rsync -av RCS/imapsync,v INSTALL.d/RCS/Dockerfile,v INSTALL.d/RCS/memo_docker,v vp3:docker/imapsync/RCS/

docker_upload_docker_hub: docker_build
	ssh vp3 'cd docker/imapsync && . memo_docker && imapsync_docker_upload'

functree: W/imapsync_functions_tree_ppi.txt W/imapsync_functions_tree.txt

W/imapsync_functions_tree_ppi.txt: imapsync
	perl ./W/learn/function_calls_ppi ./imapsync > W/imapsync_functions_tree_ppi.txt
	rcsdiff W/imapsync_functions_tree_ppi.txt || { echo 'rcsdiff detected a diff' | ci -l W/imapsync_functions_tree_ppi.txt ; }

W/imapsync_functions_tree.txt: imapsync
	perl ./W/learn/function_calls ./imapsync > W/imapsync_functions_tree.txt
	rcsdiff W/imapsync_functions_tree.txt || { echo 'rcsdiff detected a diff' | ci -l W/imapsync_functions_tree.txt ; }


nytprof: nytprof_clean
	sh tests.sh ll_nytprof
	nytprofhtml

nytprof_clean:
	rm -rfv nytprof/


cover:
	perl -c ./imapsync
	perl -MDevel::Cover ./imapsync --tests --testslive
	cover

tidy: W/imapsync.tdy


W/imapsync.tdy: imapsync
	perltidy -i=8 -sts -pt=0 -l=0 -o W/imapsync.tdy   imapsync 

compok: W/.compok


W/.compok: imapsync
	perl -c imapsync
	date >> W/.compok

prereq: W/prereq.scandeps.$(DISTRO).txt W/prereq.$(DISTRO).txt

W/prereq.scandeps.$(DISTRO).txt: INSTALL.d/prerequisites_imapsync imapsync
	scandeps -c -x  imapsync | tee W/prereq.scandeps.$(DISTRO).txt
	rcsdiff W/prereq.scandeps.$(DISTRO).txt || { echo 'rcsdiff detected a diff' | ci -l W/prereq.scandeps.$(DISTRO).txt ; }

W/prereq.$(DISTRO).txt: INSTALL.d/prerequisites_imapsync imapsync
	./INSTALL.d/prerequisites_imapsync | tee W/prereq.$(DISTRO).txt
	rcsdiff W/prereq.$(DISTRO).txt || { echo 'rcsdiff detected a diff' | ci -l W/prereq.$(DISTRO).txt ; }


crit: allcritic

perlcritic: W/perlcritic_3.txt W/perlcritic_2.txt 

allcritic: W/perlcritic_4.txt W/perlcritic_3.txt W/perlcritic_2.txt W/perlcritic_1.txt

W/perlcritic_1.txt: imapsync W/.compok 
	perlcritic --statistics -1 imapsync > W/perlcritic_1.txt.tmp || :
	mv W/perlcritic_1.txt.tmp W/perlcritic_1.txt
	echo | ci -l W/perlcritic_1.txt

W/perlcritic_2.txt: imapsync W/.compok
	perlcritic --statistics-only -2 imapsync > W/perlcritic_2.txt.tmp || :
	mv W/perlcritic_2.txt.tmp W/perlcritic_2.txt
	echo | ci -l W/perlcritic_2.txt

W/perlcritic_3.txt: imapsync W/.compok
	perlcritic --statistics-only -3 imapsync > W/perlcritic_3.txt.tmp || :
	mv W/perlcritic_3.txt.tmp W/perlcritic_3.txt
	echo | ci -l W/perlcritic_3.txt

W/perlcritic_4.txt: imapsync W/.compok
	perlcritic --statistics -4 imapsync > W/perlcritic_4.txt.tmp || :
	mv W/perlcritic_4.txt.tmp W/perlcritic_4.txt
	echo | ci -l W/perlcritic_4.txt


test_quick: imapsync tests.sh
	/usr/bin/time sh -x tests.sh locallocal

testv: imapsync tests.sh
	/usr/bin/time sh tests.sh

tests: test

test: .tests_passed

# .tests_passed is created by tests.sh with success at all mandatory tests
.tests_passed: imapsync
	/usr/bin/time sh tests.sh 1>/dev/null

unitests: 
	./imapsync --tests


testf: clean_test test

.PHONY: dosify_bat

dosify_bat:
	unix2dos W/*.bat examples/*.bat 

copy_win32:
	scp imapsync Admin@c:'C:/msys/1.0/home/Admin/imapsync/'

.PHONY: win32testsbat win32tests win32testsdebug

win32testsbat:
	unix2dos W/test.bat
	scp imapsync W/test.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
#	ssh Admin@c 'perl C:/msys/1.0/home/Admin/imapsync/imapsync --testsdebug'
	ssh Admin@c 'perl C:/msys/1.0/home/Admin/imapsync/imapsync --tests'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/test.bat'
#	ssh Admin@c 'tasklist /FI "PID eq 0"' 
#	ssh Admin@c 'tasklist /NH /FO CSV' 


win32tests:
	unix2dos  W/test_tests.bat
	scp imapsync W/test_tests.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/test_tests.bat'
	./W/check_winerr test_tests.bat

win32testsdebug:
	unix2dos  W/test_testsdebug.bat
	scp imapsync W/test_testsdebug.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/test_testsdebug.bat'
	./W/check_winerr test_testsdebug.bat



.PHONY: W/*.bat examples/*


examples/sync_loop_windows.bat: 
	unix2dos examples/sync_loop_windows.bat
	scp imapsync examples/file.txt examples/sync_loop_windows.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/sync_loop_windows.bat --nodry --dry --nodry'


examples/infinite_loop_windows.bat:
	unix2dos examples/infinite_loop_windows.bat
	scp examples/infinite_loop_windows.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/infinite_loop_windows.bat'

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

W/install_modules.bat:
	unix2dos W/install_modules.bat
	scp W/install_modules.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/install_modules.bat'
	./W/check_winerr install_modules.bat


W/install_module_ssl.bat:
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

imapsync_32bit.exe: imapsync
	rcsdiff imapsync
	ssh Admin@c 'perl -V'
	(date "+%s"| tr "\n" " "; echo -n "BEGIN 32bit " $(VERSION) ": "; date) >> W/.BUILD_EXE_TIME
	unix2dos W/build_exe.bat W/test_exe.bat W/install_modules.bat
	scp imapsync W/build_exe.bat W/test_exe.bat W/install_modules.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/build_exe.bat'
	./W/check_winerr build_exe.bat
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/test_exe.bat'
	./W/check_winerr test_exe.bat
	rm -f imapsync_32bit.exe
	scp Admin@c:'C:/msys/1.0/home/Admin/imapsync/imapsync_32bit.exe' .
	chmod a+r+x imapsync_32bit.exe
	(date "+%s"| tr "\n" " "; echo -n "END   32bit " $(VERSION) ": "; date) >> W/.BUILD_EXE_TIME

32exe: imapsync
	(date "+%s"| tr "\n" " "; echo -n "BEGIN 32bit " $(VERSION) ": "; date) >> W/.BUILD_EXE_TIME
	scp imapsync W/build_exe.bat W/install_modules.bat Admin@c:'C:/msys/1.0/home/Admin/imapsync/'
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/build_exe.bat'
	./W/check_winerr build_exe.bat
	ssh Admin@c 'C:/msys/1.0/home/Admin/imapsync/imapsync_32bit.exe --justbanner'
	rm -f imapsync_32bit.exe
	scp Admin@c:'C:/msys/1.0/home/Admin/imapsync/imapsync_32bit.exe' .
	chmod a+r+x imapsync_32bit.exe
	(date "+%s"| tr "\n" " "; echo -n "END   32bit " $(VERSION) ": "; date) >> W/.BUILD_EXE_TIME

win64tests: win64tests_p26

win64tests_p24:
	unix2dos  W/test_tests.bat
	scp imapsync W/test_tests.bat pc_HP_DV7_p24:'Desktop/imapsync_build'
	ssh 'pc HP DV7'@p24 'Desktop/imapsync_build/test_tests.bat'
	./W/check_win64err test_tests.bat

win64testsdebug_p24:
	unix2dos  W/test_testsdebug.bat
	scp imapsync W/test_testsdebug.bat pc_HP_DV7_p24:'Desktop/imapsync_build'
	ssh 'pc HP DV7'@p24 'Desktop/imapsync_build/test_testsdebug.bat'
	./W/check_win64err test_testsdebug.bat

win64testsdebug: win64testsdebug_p26

win64testsdebug_p26:
	unix2dos  W/test_testsdebug.bat
	scp imapsync W/test_testsdebug.bat gille@p26:'OneDrive\Bureau\imapsync_build'
	ssh gille@p26 'OneDrive\Bureau\imapsync_build\test_testsdebug.bat'
	./W/check_p26err test_testsdebug.bat


win64tests_p26:
	unix2dos  W/test_tests.bat
	scp imapsync W/test_tests.bat gille@p26:'OneDrive\Bureau\imapsync_build'
	ssh gille@p26 'OneDrive\Bureau\imapsync_build\test_tests.bat'
	./W/check_p26err test_tests.bat


win64_test_exe_always_fail_p26:
	unix2dos W/test_exe_always_fail.bat
	scp W/test_exe_always_fail.bat gille@p26:'OneDrive\Bureau\imapsync_build'
	ssh gille@p26 'OneDrive\Bureau\imapsync_build\test_exe_always_fail.bat'
	./W/check_p26err test_exe_always_fail.bat

win64_test_always_fail_p26:
	unix2dos W/test_exe_always_fail.bat
	scp imapsync W/test_always_fail.bat gille@p26:'OneDrive\Bureau\imapsync_build'
	ssh gille@p26 'OneDrive\Bureau\imapsync_build\test_always_fail.bat'
	./W/check_p26err test_always_fail.bat

zzz:
	unix2dos W/build_exe.bat W/install_module_one.bat
	scp imapsync W/build_exe.bat W/install_module_one.bat W/test_exe_testsdebug.bat pc_HP_DV7_p24:'Desktop/imapsync_build'
	ssh 'pc HP DV7'@p24 'Desktop/imapsync_build/build_exe.bat'
	./W/check_win64err build_exe.bat

zzz2:
	unix2dos W/test_exe_testsdebug.bat W/test_exe_tests.bat
	scp W/test_exe_testsdebug.bat W/test_exe_tests.bat pc_HP_DV7_p24:'Desktop/imapsync_build'
	ssh 'pc HP DV7'@p24 'Desktop/imapsync_build/test_exe_testsdebug.bat'
	./W/check_win64err test_exe_testsdebug.bat
	ssh 'pc HP DV7'@p24 'Desktop/imapsync_build/test_exe_tests.bat'
	./W/check_win64err test_exe_tests.bat

W/test_ipv6.bat:
	unix2dos W/test_ipv6.bat
	scp W/test_ipv6.bat pc_HP_DV7_p24:'Desktop/imapsync_build'
	ssh 'pc HP DV7'@p24 'Desktop/imapsync_build/test_ipv6.bat'

W/test_namespace.bat:
	unix2dos W/test_namespace.bat
	scp W/test_namespace.bat ../../var/pass/secret.outlook.com pc_HP_DV7_p24:'Desktop/imapsync_build'
	ssh 'pc HP DV7'@p24 'Desktop/imapsync_build/test_namespace.bat'

W/test4.bat:
	unix2dos W/test4.bat
	scp W/test4.bat pc_HP_DV7_p24:'Desktop/imapsync_build'
	ssh 'pc HP DV7'@p24 'Desktop/imapsync_build/test4.bat'

W/test5.bat:
	unix2dos W/test5.bat
	scp W/test5.bat pc_HP_DV7_p24:'Desktop/imapsync_build'
	ssh 'pc HP DV7'@p24 'Desktop/imapsync_build/test5.bat'

W/test6.bat:
	unix2dos W/test6.bat
	scp W/test6.bat imapsync pc_HP_DV7_p24:'Desktop/imapsync_build'
	ssh 'pc HP DV7'@p24 'Desktop/imapsync_build/test6.bat'

W/test_abort.bat:
	unix2dos W/test_abort.bat
	scp W/test_abort.bat imapsync pc_HP_DV7_p24:'Desktop/imapsync_build'
	ssh 'pc HP DV7'@p24 'Desktop/imapsync_build/test_abort.bat'

W/test_tail.bat:
	unix2dos W/test_tail.bat
	scp W/test_tail.bat imapsync pc_HP_DV7_p24:'Desktop/imapsync_build'
	ssh 'pc HP DV7'@p24 'Desktop/imapsync_build/test_tail.bat'

win64sshaccess:
	ssh 'pc HP DV7'@p24 'perl -V'

winprepalocal:
	unix2dos W/build_exe.bat W/test_exe.bat W/install_modules.bat W/install_module_one.bat

win64prepa: winprepalocal
	ssh 'pc HP DV7'@p24 'perl -V'
	scp imapsync W/build_exe.bat W/install_modules.bat W/install_module_one.bat \
	W/test_exe_tests.bat W/test_exe_testsdebug.bat W/test_exe.bat \
	pc_HP_DV7_p24:'Desktop/imapsync_build'
	ssh 'pc HP DV7'@p24 'Desktop/imapsync_build/build_exe.bat'
	./W/check_win64err build_exe.bat

win64build_p24: winprepalocal
	scp imapsync W/build_exe.bat W/install_modules.bat  pc_HP_DV7_p24:'Desktop/imapsync_build'
	ssh 'pc HP DV7'@p24 'Desktop/imapsync_build/build_exe.bat'
	./W/check_win64err build_exe.bat

imapsync.exe: imapsync_64bit.exe_p26
	cp -a imapsync_64bit.exe_p26 imapsync.exe

win64build: imapsync_64bit.exe_p26



win64build_p26: winprepalocal
	scp imapsync W/build_exe.bat W/install_modules.bat  gille@p26:'OneDrive\Bureau\imapsync_build'
	ssh gille@p26 'OneDrive\Bureau\imapsync_build\build_exe.bat'
	./W/check_win64err build_exe.bat


.PHONY: imapsync_64bit.exe_p24 imapsync_64bit.exe_p26

64exe: imapsync_64bit.exe_p26

imapsync_64bit.exe_p26: imapsync
	(date "+%s"| tr "\n" " "; echo -n "BEGIN 64bit " $(VERSION) ": "; date) >> W/.BUILD_EXE_TIME
	unix2dos W/build_exe.bat W/test_exe.bat W/install_modules.bat W/install_module_one.bat
	ssh gille@p26 'perl -V'
	ssh gille@p26 'if not exist OneDrive\Bureau\imapsync_build  mkdir OneDrive\Bureau\imapsync_build'
	scp imapsync W/build_exe.bat W/install_modules.bat W/install_module_one.bat \
	W/test_exe_tests.bat W/test_exe_testsdebug.bat W/test_exe.bat \
	gille@p26:'OneDrive\Bureau\imapsync_build'
	ssh gille@p26 'OneDrive\Bureau\imapsync_build\build_exe.bat'
	./W/check_p26err build_exe.bat
	scp ../../var/pass/secret.tata ../../var/pass/secret.titi gille@p26:'OneDrive\Bureau\imapsync_build'
	ssh gille@p26 'OneDrive\Bureau\imapsync_build\test_exe.bat'
	./W/check_p26err test_exe.bat
	rm -f imapsync_64bit.exe
	scp -T gille@p26:'OneDrive\Bureau\imapsync_build\imapsync_64bit.exe' .
	chmod a+r+x imapsync_64bit.exe
	(date "+%s"| tr "\n" " "; echo -n "END   64bit " $(VERSION) ": "; date) >> W/.BUILD_EXE_TIME


imapsync_64bit.exe_p24: imapsync
	(date "+%s"| tr "\n" " "; echo -n "BEGIN 64bit " $(VERSION) ": "; date) >> W/.BUILD_EXE_TIME
	unix2dos W/build_exe.bat W/test_exe.bat W/install_modules.bat W/install_module_one.bat
	ssh 'pc HP DV7'@p24 'perl -V'
	scp imapsync W/build_exe.bat W/install_modules.bat W/install_module_one.bat \
	W/test_exe_tests.bat W/test_exe_testsdebug.bat W/test_exe.bat \
	pc_HP_DV7_p24:'Desktop/imapsync_build'
	ssh 'pc HP DV7'@p24 'Desktop/imapsync_build/build_exe.bat'
	./W/check_win64err build_exe.bat
	ssh 'pc HP DV7'@p24 'Desktop/imapsync_build/test_exe.bat'
	./W/check_win64err test_exe.bat
	rm -f imapsync_64bit.exe
	scp pc_HP_DV7_p24:'Desktop/imapsync_build/imapsync_64bit.exe' .
	chmod a+r+x imapsync_64bit.exe
	(date "+%s"| tr "\n" " "; echo -n "END   64bit " $(VERSION) ": "; date) >> W/.BUILD_EXE_TIME


zip: dosify_bat cidone
	rm -rfv ../prepa_zip/imapsync_$(VERSION)/
	mkdir -p ../prepa_zip/imapsync_$(VERSION)/FAQ.d/ ../prepa_zip/imapsync_$(VERSION)/Cook/
	cp -av examples/imapsync_example.bat examples/sync_loop_windows.bat examples/file.txt  ../prepa_zip/imapsync_$(VERSION)/
	cp -av W/build_exe.bat W/install_modules.bat W/test_cook_exe.bat W/test_cook_src.bat imapsync ../prepa_zip/imapsync_$(VERSION)/Cook/
	cp -av README.txt ../prepa_zip/imapsync_$(VERSION)/
	cp -av FAQ.d/*.txt ../prepa_zip/imapsync_$(VERSION)/FAQ.d/
	cp -av imapsync.exe imapsync_32bit.exe README_Windows.txt ../prepa_zip/imapsync_$(VERSION)/
	unix2dos ../prepa_zip/imapsync_$(VERSION)/*.txt
	cd ../prepa_zip/ && rm -f ./imapsync_$(VERSION).zip && zip -r ./imapsync_$(VERSION).zip ./imapsync_$(VERSION)/
	scp ../prepa_zip/imapsync_$(VERSION).zip Admin@c:'C:/msys/1.0/home/Admin/'
#	scp ../prepa_zip/imapsync_$(VERSION).zip pc_HP_DV7_p24:'Desktop/'
	cp ../prepa_zip/imapsync_$(VERSION).zip /fe/imapsync/


# C:\Users\mansour\Desktop\imapsync

.PHONY: mac macstadiumcopy maccopy macforce mactests mactestsdebug mactestslive mactestslive6 bin win lin win64 

mac: imapsync_bin_Darwin

macstadiumcopy:
	rsync -pv imapsync W/build_mac.sh INSTALL.d/prerequisites_imapsync webserver administrator@macstadium.lamiral.info:
	rsync -pv examples/file.txt examples/sync_loop_darwin.sh administrator@macstadium.lamiral.info:examples/
	rsync -pv X/ administrator@macstadium.lamiral.info:X/

maccopy:
	rsync -v -p -e 'ssh -4 -p 995' imapsync W/build_mac.sh INSTALL.d/prerequisites_imapsync webserver \
	gilleslamira@gate.polarhome.com:
	rsync -v -p -e 'ssh -4 -p 995' examples/file.txt examples/sync_loop_darwin.sh gilleslamira@gate.polarhome.com:examples/
	rsync -v -p -e 'ssh -4 -p 995' X/ gilleslamira@gate.polarhome.com:X/

macforce: maccopy
	ssh -4 -p 995 gilleslamira@gate.polarhome.com 'sh -x build_mac.sh'

imapsync_bin_Darwin: maccopy imapsync W/build_mac.sh INSTALL.d/prerequisites_imapsync 
	rcsdiff imapsync
	ssh -4 -p 995 gilleslamira@gate.polarhome.com 'sh -x build_mac.sh'
	rsync -P -e 'ssh -4 -p 995' gilleslamira@gate.polarhome.com:imapsync_bin_Darwin .

mactests:
	rsync -p -e 'ssh -4 -p 995' imapsync gilleslamira@gate.polarhome.com:
	ssh -4 -p 995 gilleslamira@gate.polarhome.com '. .bash_profile; perl imapsync --tests'

mactestsdebug:
	rsync -p -e 'ssh -4 -p 995' imapsync gilleslamira@gate.polarhome.com:
	ssh -4 -p 995 gilleslamira@gate.polarhome.com '. .bash_profile; perl imapsync --testsdebug --debug'

mactestslive:
	rsync -p -e 'ssh -4 -p 995' imapsync gilleslamira@gate.polarhome.com:
	ssh -4 -p 995 gilleslamira@gate.polarhome.com '. .bash_profile; perl imapsync --testslive'

mactestslive6:
	rsync -p -e 'ssh -4 -p 995' imapsync gilleslamira@gate.polarhome.com:
	ssh -4 -p 995 gilleslamira@gate.polarhome.com '. .bash_profile; perl imapsync --testslive6'

macstests:
	rsync -pv imapsync administrator@macstadium.lamiral.info:
	ssh administrator@macstadium.lamiral.info '. .bash_profile; perl imapsync --tests'

macstestsdebug:
	rsync -pv imapsync administrator@macstadium.lamiral.info:
	ssh administrator@macstadium.lamiral.info '. .bash_profile; perl imapsync --testsdebug'



.PHONY: bin win lin win32 win64

bin: mac win

lin: $(BIN_NAME)

win: win32 win64 imapsync.exe

win32: imapsync_32bit.exe

win64: imapsync_64bit.exe

win32build: imapsync_32bit.exe

linuxbuild: lin


$(BIN_NAME): imapsync
	rcsdiff imapsync
	{ pp -x -o $(BIN_NAME) \
	imapsync ; \
	}
	# Maybe add -M Test2::Event::Info Mail::IMAPClient \
	#-M Net::SSLeay -M IO::Socket -M IO::Socket::INET6 -M IO::Socket::SSL \
	#-M Digest::MD5 -M Digest::HMAC_MD5 -M Term::ReadKey \
	#-M Authen::NTLM -M HTML::Entities -M JSON::WebToken \
	#-M Test2::Event -M Test2::Formatter -M Test2::Formatter::TAP \
	./$(BIN_NAME)
	./$(BIN_NAME) --tests
	./$(BIN_NAME) --testslive
	./$(BIN_NAME) --justbanner



.PHONY: tarball cidone ci

tarball: cidone
	echo making tarball ../prepa_dist/$(DIST_FILE)
	mkdir -p dist
	mkdir -p ../prepa_dist/$(DIST_NAME)
	rsync -aCvH --delete --delete-excluded --omit-dir-times --exclude $(DIST_PATH) --exclude-from=W/rsync_exclude_dist.txt  ./ ../prepa_dist/$(DIST_NAME)/
	cd ../prepa_dist && tar czfv $(DIST_FILE) $(DIST_NAME)
	cd ../prepa_dist && md5sum $(DIST_FILE) > $(DIST_FILE).md5.txt
	cd ../prepa_dist && md5sum -c $(DIST_FILE).md5.txt
	ls -l ../prepa_dist/$(DIST_FILE)

ci: cidone

cidone: auto_ci
	rcsdiff X/cgi_memo X/stat_patterns.txt X/server_survey_patterns.txt X/imapsync_form.* X/imapsync_form_extra.html X/noscript.css
	rcsdiff W/*.bat W/*.sh W/*.txt W/*.htaccess
	cd W && rcsdiff RCS/*
	cd oauth2 && rcsdiff RCS/*
	rcsdiff doc/*.t2t
	rcsdiff INSTALL.d/*.txt INSTALL.d/prerequisites_imapsync
	rcsdiff FAQ.d/*.txt
	rcsdiff examples/*.sh examples/*.bat examples/*.txt 
	cd examples && rcsdiff RCS/*
	rcsdiff W/tools/backup_old_dist W/tools/gen_README_dist W/tools/validate_html4 W/tools/validate_xml_html5 W/tools/fix_email_for_exchange.py
	rcsdiff S/*.txt S/*.shtml S/*.html
	rcsdiff RCS/*


dist: cidone test clean all dist_prepa dist_zip README_dist


md5:
	cd $(DIST_PATH)/ && md5sum *

sha:
	cd $(DIST_PATH)/ && sha512sum *

.PHONY: moveoldrelease ks5testsdebug ks5tests README_dist docker_pull_count

moveoldrelease:
	./W/tools/backup_old_dist $(DIST_PATH)


dist_prepa: tarball moveoldrelease
	ln -f ../prepa_dist/$(DIST_FILE) $(DIST_PATH)/
	rcsdiff imapsync
	cp -a ../prepa_dist/$(DIST_NAME)/imapsync $(DIST_PATH)/
	cp -a ../prepa_dist/$(DIST_NAME)/imapsync_bin_Darwin $(DIST_PATH)/
	#cd $(DIST_PATH)/ && md5sum $(DIST_FILE) > $(DIST_FILE).md5.txt
	#cd $(DIST_PATH)/ && md5sum -c $(DIST_FILE).md5.txt
	ls -l $(DIST_PATH)/


dist_zip: zip 
	cp -a ../prepa_zip/imapsync_$(VERSION).zip $(DIST_PATH)/

README_dist:
	sh W/tools/gen_README_dist > $(DIST_PATH)/README.txt
	unix2dos $(DIST_PATH)/README.txt

.PHONY: publish upload_ks ks valid_index biz ks5tests_gilles ks5tests_root auto_ci

biz: S/imapsync_sold_by_country.txt docker_pull_count 

auto_ci: docker_pull_count

docker_pull_count:
	rcsdiff W/docker_pull_count.txt || { echo | ci -l W/docker_pull_count.txt ; }

S/imapsync_sold_by_country.txt: /g/bin/imapsync_by_country
	cd S/ && /g/bin/imapsync_by_country && { echo | ci -l imapsync_sold_by_country.txt ; }


ks:
	rsync -avHz --delete --exclude '*.exe' \
	  . gilles@ks.lamiral.info:public_html/imapsync/
	ssh root@ks.lamiral.info 'apachectl configtest && apachectl reload'

ksa:
	rsync -avHz --delete -P \
	  . gilles@ks.lamiral.info:public_html/imapsync/
	ssh root@ks.lamiral.info 'apachectl configtest && apachectl reload'

ks3:
	rsync -avHz --delete -P \
	  . gilles@ks3.lamiral.info:public_html/imapsync/

ks6:
	rsync -avHz --delete -P --exclude 'dist2' \
	  . gilles@ks6.lamiral.info:public_html/imapsync/


upload_tests: tests.sh
	rsync -avHz --delete -P \
	  tests.sh \
	  gilles@ks.lamiral.info:public_html/imapsync/


ks5testsdebug:
	rsync -aP imapsync gilles@ks.lamiral.info:public_html/imapsync/imapsync
	ssh gilles@ks.lamiral.info 'public_html/imapsync/imapsync --testsdebug'

ks5tests: ks5tests_gilles ks5tests_root


ks5tests_gilles:
	rsync -P imapsync gilles@ks.lamiral.info:public_html/imapsync/
	ssh gilles@ks.lamiral.info 'public_html/imapsync/imapsync --tests'

ks5tests_root:
	rsync -P imapsync root@ks5.lamiral.info:
	ssh root@ks5.lamiral.info './imapsync --tests'


ks5prerequisites:
	rsync -P imapsync INSTALL.d/prerequisites_imapsync root@ks5.lamiral.info:
	ssh root@ks5.lamiral.info 'sh prerequisites_imapsync'


ks5testslive:
	rsync -aP imapsync gilles@ks.lamiral.info:public_html/imapsync/imapsync
	ssh gilles@ks.lamiral.info 'public_html/imapsync/imapsync --testslive'

publish: dist upload_ks ksa 
	echo Now ou can do make ml

centos:
	scp imapsync INSTALL.d/prerequisites_imapsync root@vp1:
	ssh root@vp1 sh prerequisites_imapsync




PUBLIC = ./ChangeLog ./NOLIMIT ./LICENSE ./CREDITS ./FAQ \
./index.shtml ./INSTALL ./README_Windows.txt \
./VERSION ./imapsync \
./README  ./TODO ./vnstat


ml:  
	rcsdiff W/ml_announce.in.txt
	m4 -P W/ml_announce.in.txt | mutt -H-
	mailq

lfo: upload_lfo 

upload_lfo:
	#rm -rf /home/gilles/public_html/www.linux-france.org/html/prj/imapsync/
	#rm -rf /home/gilles/public_html/www.linux-france.org/ftp/prj/imapsync/
	#rsync -avHz $(PUBLIC) \
	#/home/gilles/public_html/www.linux-france.org/html/prj/imapsync/
	rsync -lptvHzP ./W/memo glamiral@linux-france.org:imapsync_stats/memo
	rsync -lptvHzP ./W/lfo.htaccess \
	/home/gilles/public_html/www.linux-france.org/html/prj/imapsync/.htaccess
	sh ~/memo/lfo-rsync

.PHONY: valid_index va


valid_index: W/.valid.index.shtml

va: valid_index

cl: ./W/checklink.txt

./W/checklink.txt: index.shtml
	checklink --broken --quiet  http://lamiral.info/~gilles/imapsync/ |tee ./W/checklink.txt

cle: ./W/checklinkext.txt

./W/checklinkext.txt: S/news.shtml S/external.shtml  S/imapservers.shtml S/template_xhtml1.shtml
	checklink --broken --quiet \
	http://lamiral.info/~gilles/imapsync/S/template_xhtml1.shtml \
	http://lamiral.info/~gilles/imapsync/S/news.shtml     \
	http://lamiral.info/~gilles/imapsync/S/external.shtml \
	http://lamiral.info/~gilles/imapsync/S/imapservers.shtml \
	| tee ./W/checklinkext.txt

W/.valid.index.shtml: index.shtml S/*.shtml
	for f in index.shtml S/*.shtml; do echo tidy -e -q $$f; tidy -e -q  $$f ; done
	./W/tools/validate_xml_html5 index.shtml S/*.shtml
	./W/tools/validate index.shtml S/donate.shtml S/external.shtml S/imapservers.shtml \
        S/news.shtml S/no_download.shtml S/paypal_return.shtml S/poll.shtml \
        S/template_xhtml1.shtml 
	touch W/.valid.index.shtml

.PHONY: upload_index ci_imapsync upload_latest upload_FAQ  upload_bin 


upload_index: valid_index clean_permissions
	rcsdiff index.shtml README_Windows.txt S/style.css S/*.shtml FAQ.d/*.txt LICENSE CREDITS TODO examples/*.bat examples/*.sh index.shtml INSTALL.d/*.txt
	rcsdiff S/quiz/quiz_imapsync.html S/quiz/quiz_imapsync.js S/quiz/quiz_imapsync.css
	rm -f examples/LOG_imapsync/*
	rsync -avH index.shtml README_Windows.txt FAQ INSTALL  NOLIMIT LICENSE CREDITS TODO S/robots.txt S/favicon.ico ../imapsync_website/
	rsync -aHv  --delete ./W/ks.htaccess ../imapsync_website/.htaccess
	rsync -aHv  --delete ./S/ ../imapsync_website/S/
	rsync -aHv  --delete ./examples/  ../imapsync_website/examples/
	rsync -aHv  --delete ./INSTALL.d/ ../imapsync_website/INSTALL.d/
	rsync -aHv  --delete ./FAQ.d/     ../imapsync_website/FAQ.d/
	rsync -avH  --delete ./doc/       ../imapsync_website/doc/
	rsync -avH  --delete ./W/tools/   ../imapsync_website/W/tools/
	rsync -aHvz --delete ../imapsync_website/ root@ks5.lamiral.info:/usr/local/www/apache24/data/imapsync/



ci_imapsync:
	rcsdiff imapsync

upload_latest: unitests ci_imapsync bin
	rsync -av imapsync imapsync_bin_Darwin imapsync.exe imapsync_32bit.exe ./INSTALL.d/prerequisites_imapsync ../imapsync_website/
	rsync -aHvzP --delete ../imapsync_website/ root@ks5.lamiral.info:/usr/local/www/apache24/data/imapsync/



.PHONY: upload_cgi upload_cgi_ks5 upload_cgi_memo upload_cgi_vp3 upload_cgi_vp4 upload_cgi_ks6 upload_tmphash_all


upload_proximapsync:
	rcsdiff W/learn/proximapsync
	W/learn/proximapsync --tests
	W/learn/proximapsync --testslive | grep 'Exiting with return value 0'
	rsync -P W/learn/proximapsync root@ks5.lamiral.info:/home/www/apache24/cgi-bin/proximapsync_new
	ssh root@ks5.lamiral.info '/home/www/apache24/cgi-bin/proximapsync_new --tests'
	ssh root@ks5.lamiral.info '/home/www/apache24/cgi-bin/proximapsync_new --testslive' | grep 'Exiting with return value 0'
	curl -v --data 'testslive=1' https://imapsync.lamiral.info/cgi-bin/proximapsync_new 2>/dev/null | grep 'Exiting with return value 0'
	rsync -P W/learn/proximapsync root@ks5.lamiral.info:/home/www/apache24/cgi-bin/proximapsync
	curl -v --data 'testslive=1' https://imapsync.lamiral.info/cgi-bin/proximapsync     2>/dev/null | grep 'Exiting with return value 0'

upload_cgi_memo:
	dos2unix X/stat_patterns.txt X/server_survey_patterns.txt
	sed -i".bak" '/^[[:space:]]*$$/d' X/stat_patterns.txt X/server_survey_patterns.txt
	rsync -av X/cgi_memo X/stat_patterns.txt X/server_survey_patterns.txt root@ks5:/var/tmp/imapsync_cgi/

upload_cgi_memo_all:
	rsync -av X/cgi_memo X/stat_patterns.txt X/server_survey_patterns.txt root@ks5:/var/tmp/imapsync_cgi/
	rsync -av X/cgi_memo X/stat_patterns.txt X/server_survey_patterns.txt root@ks6:/var/tmp/imapsync_cgi/
	rsync -av X/cgi_memo X/stat_patterns.txt X/server_survey_patterns.txt root@ks7:/var/tmp/imapsync_cgi/
	rsync -av X/cgi_memo X/stat_patterns.txt X/server_survey_patterns.txt root@vp3:/var/tmp/imapsync_cgi/
	rsync -av X/cgi_memo X/stat_patterns.txt X/server_survey_patterns.txt root@vp4:/var/tmp/imapsync_cgi/
	! ping -c1 -W1 cl1 || rsync -av X/cgi_memo X/stat_patterns.txt X/server_survey_patterns.txt root@cl1:/var/tmp/imapsync_cgi/

upload_tmphash_all:
	scp /var/tmp/imapsync_hash root@ks5:/var/tmp/imapsync_hash && ssh root@ks5 chgrp www      /var/tmp/imapsync_hash
	scp /var/tmp/imapsync_hash root@ks6:/var/tmp/imapsync_hash && ssh root@ks6 chgrp www-data /var/tmp/imapsync_hash
	scp /var/tmp/imapsync_hash root@vp3:/var/tmp/imapsync_hash && ssh root@vp3 chgrp www-data /var/tmp/imapsync_hash
	scp /var/tmp/imapsync_hash root@vp4:/var/tmp/imapsync_hash && ssh root@vp4 chgrp apache   /var/tmp/imapsync_hash
	scp /var/tmp/imapsync_hash root@i050:/var/tmp/imapsync_hash && ssh root@i050 chgrp www-data /var/tmp/imapsync_hash

test_cgi_all:
	curl -v --data 'testslive=1;exitonload=0' https://imapsync.lamiral.info/cgi-bin/imapsync 2>/dev/null | grep 'Exiting with return value 0' # ks5
	curl -v --data 'testslive=1;exitonload=0' https://i006.lamiral.info/cgi-bin/imapsync 2>/dev/null | grep 'Exiting with return value 0'
	curl -v --data 'testslive=1;exitonload=0' https://i007.lamiral.info/cgi-bin/imapsync 2>/dev/null | grep 'Exiting with return value 0'
	curl -v --data 'testslive=1;exitonload=0' https://i013.lamiral.info/cgi-bin/imapsync 2>/dev/null | grep 'Exiting with return value 0'
	curl -v --data 'testslive=1;exitonload=0' https://i014.lamiral.info/cgi-bin/imapsync 2>/dev/null | grep 'Exiting with return value 0'

upload_cgi: upload_cgi_ks5 upload_cgi_vp3 upload_cgi_vp4 upload_cgi_ks6 upload_cgi_ks7 

# FreeBSD
upload_cgi_ks5: ci_imapsync unitests ks5tests
	rsync -P imapsync root@ks5.lamiral.info:/home/www/apache24/cgi-bin/imapsync_new
	curl -v --data 'testslive=1;exitonload=0' https://imapsync.lamiral.info/cgi-bin/imapsync_new 2>/dev/null | grep 'Exiting with return value 0'
	rsync -P imapsync root@ks5.lamiral.info:/home/www/apache24/cgi-bin/imapsync
	curl -v --data 'testslive=1;exitonload=0' https://imapsync.lamiral.info/cgi-bin/imapsync 2>/dev/null | grep 'Exiting with return value 0'


# Debian
upload_cgi_vp3: ci_imapsync vp3tests
	rsync -P imapsync      root@vp3.lamiral.info:/usr/lib/cgi-bin/imapsync_new
	curl -v --data 'testslive=1;exitonload=0' https://vp3.lamiral.info/cgi-bin/imapsync_new 2>/dev/null | grep 'Exiting with return value 0'
	rsync -P imapsync      root@vp3.lamiral.info:/usr/lib/cgi-bin/imapsync
	curl -v --data 'testslive=1;exitonload=0' https://vp3.lamiral.info/cgi-bin/imapsync 2>/dev/null | grep 'Exiting with return value 0'

# Centos
upload_cgi_vp4: ci_imapsync vp4tests
	rsync -P imapsync      root@vp4.lamiral.info:/var/www/cgi-bin/imapsync_new
	curl -v --data 'testslive=1;exitonload=0' https://vp4.lamiral.info/cgi-bin/imapsync_new 2>/dev/null | grep 'Exiting with return value 0'
	rsync -P imapsync      root@vp4.lamiral.info:/var/www/cgi-bin/imapsync
	curl -v --data 'testslive=1;exitonload=0' https://vp4.lamiral.info/cgi-bin/imapsync 2>/dev/null | grep 'Exiting with return value 0'

# Debian
upload_cgi_ks6: ci_imapsync ks6tests
	rsync -P imapsync      root@ks6.lamiral.info:/usr/lib/cgi-bin/imapsync_new
	curl -v --data 'testslive=1;exitonload=0' https://ks6.lamiral.info/cgi-bin/imapsync_new 2>/dev/null | grep 'Exiting with return value 0'
	rsync -P imapsync      root@ks6.lamiral.info:/usr/lib/cgi-bin/imapsync
	curl -v --data 'testslive=1;exitonload=0' https://ks6.lamiral.info/cgi-bin/imapsync 2>/dev/null | grep 'Exiting with return value 0'

# Promox/Debian
upload_cgi_ks7: ci_imapsync ks7tests
	rsync -P imapsync      root@ks7.lamiral.info:/usr/lib/cgi-bin/imapsync_new
	curl -v --data 'testslive=1;exitonload=0' https://ks7.lamiral.info/cgi-bin/imapsync_new 2>/dev/null | grep 'Exiting with return value 0'
	rsync -P imapsync      root@ks7.lamiral.info:/usr/lib/cgi-bin/imapsync
	curl -v --data 'testslive=1;exitonload=0' https://ks7.lamiral.info/cgi-bin/imapsync 2>/dev/null | grep 'Exiting with return value 0'

# Debian
upload_cgi_cl1: ci_imapsync cl1tests
	rsync -P imapsync      root@cl1.lamiral.info:/usr/lib/cgi-bin/imapsync_new
	curl -v --data 'testslive=1;exitonload=0' https://cl1.lamiral.info/cgi-bin/imapsync_new 2>/dev/null | grep 'Exiting with return value 0'
	rsync -P imapsync      root@cl1.lamiral.info:/usr/lib/cgi-bin/imapsync
	curl -v --data 'testslive=1;exitonload=0' https://cl1.lamiral.info/cgi-bin/imapsync 2>/dev/null | grep 'Exiting with return value 0'



.PHONY: vp3tests vp4tests ks6tests 

vp3tests:
	rsync -P imapsync root@vp3.lamiral.info:imapsync
	ssh root@vp3.lamiral.info ./imapsync --tests
	ssh root@vp3.lamiral.info ./imapsync --testslive6

vp4tests:
	rsync -P imapsync root@vp4.lamiral.info:imapsync
	ssh root@vp4.lamiral.info ./imapsync --tests
	ssh root@vp4.lamiral.info ./imapsync --testslive6

ks6tests:
	rsync -P imapsync root@ks6.lamiral.info:imapsync
	ssh root@ks6.lamiral.info ./imapsync --tests
	ssh root@ks6.lamiral.info ./imapsync --testslive6

ks7tests:
	rsync -P imapsync root@ks7.lamiral.info:imapsync
	ssh root@ks7.lamiral.info ./imapsync --tests
	ssh root@ks7.lamiral.info ./imapsync --testslive6

cl1tests:
	rsync -P imapsync root@cl1.lamiral.info:imapsync
	ssh root@cl1.lamiral.info ./imapsync --tests
	ssh root@cl1.lamiral.info ./imapsync --testslive6


upload_imapsync_all:
	scp imapsync INSTALL.d/prerequisites_imapsync W/learn/processtable root@i005.lamiral.info:
	scp imapsync INSTALL.d/prerequisites_imapsync W/learn/processtable root@i006.lamiral.info:
	scp imapsync INSTALL.d/prerequisites_imapsync W/learn/processtable root@i013.lamiral.info:
	scp imapsync INSTALL.d/prerequisites_imapsync W/learn/processtable root@i014.lamiral.info:


upload_X:
	./W/tools/validate_xml_html5 X/imapsync_form.html X/imapsync_form_extra.html X/imapsync_form_extra_free.html X/imapsync_form_wrapper.html X/proximapsync_form_extra_free.html
	rcsdiff                      X/imapsync_form.html X/imapsync_form_extra.html X/imapsync_form_extra_free.html X/imapsync_form_wrapper.html X/proximapsync_form_extra_free.html
	rcsdiff X/imapsync_form.css X/noscript.css 
	rcsdiff X/imapsync_form.js X/imapsync_form_wrapper.js X/proximapsync_form.js
	rcsdiff INSTALL.d/INSTALL.OnlineUI.txt
	rsync -a ./INSTALL.d/INSTALL.OnlineUI.txt ../imapsync_website/INSTALL.d/INSTALL.OnlineUI.txt
	rsync -av   --delete   X/ ../imapsync_website/X/
	rsync -aHvz --delete  ../imapsync_website/ root@ks5.lamiral.info:/usr/local/www/apache24/data/imapsync/

upload_csv:
	./W/tools/validate_xml_html5    X/sandbox_csv.html
	rcsdiff      X/sandbox_csv.html X/sandbox_csv.js X/imapsync_csv_wrapper
	rsync -a     X/sandbox_csv.html X/sandbox_csv.js X/imapsync_csv_wrapper ../imapsync_website/X/
	rsync -aHvz  X/sandbox_csv.html X/sandbox_csv.js X/imapsync_csv_wrapper root@ks5.lamiral.info:/usr/local/www/apache24/data/imapsync/X/
	rsync X/imapsync_csv_wrapper root@ks5.lamiral.info:/home/www/apache24/cgi-bin/


upload_FAQ:
	rcsdiff FAQ.d/*.txt  LICENSE CREDITS TODO INSTALL.d/*.txt 
	rsync -avH FAQ INSTALL  CREDITS TODO ../imapsync_website/
	rsync -aHv  --delete  ./INSTALL.d/          ../imapsync_website/INSTALL.d/
	rsync -aHv  --delete  ./FAQ.d/              ../imapsync_website/FAQ.d/
	rsync -avH  --delete  ./doc/                ../imapsync_website/doc/
	rsync -aHvz --delete ../imapsync_website/   root@ks5.lamiral.info:/usr/local/www/apache24/data/imapsync/

upload_oauth2:
	rm -f oauth2/D_oauth2_*
	rsync -aHv  --delete  ./oauth2/          ../imapsync_website/oauth2/
	rsync -aHvz --delete ../imapsync_website/   root@ks5.lamiral.info:/usr/local/www/apache24/data/imapsync/

upload_ks_W_memo:
	rsync -av W/memo gilles@ks.lamiral.info:public_html/imapsync/W/memo

upload_ks: ci tarball
	rsync -aHv           $(PUBLIC)       ../imapsync_website/
	rsync -aHv  --delete ./W/ks.htaccess ../imapsync_website/.htaccess
	rsync -avH           ./S/            ../imapsync_website/S/
	rsync -aHv  --delete ./$(DIST_PATH)/ ../imapsync_website/$(DIST_PATH)/
	rsync -aHv  --delete ./examples/     ../imapsync_website/examples/
	rsync -aHv  --delete ./INSTALL.d/    ../imapsync_website/INSTALL.d/
	rsync -aHv  --delete ./FAQ.d/        ../imapsync_website/FAQ.d/
	rsync -avH  --delete ./doc/          ../imapsync_website/doc/
	rsync -avH  --delete ./W/tools/   ../imapsync_website/W/tools/
	rsync -aHvz --delete ../imapsync_website/ root@ks5.lamiral.info:/usr/local/www/apache24/data/imapsync/
	ssh root@ks.lamiral.info 'apachectl configtest && apachectl reload'


upload_ks5:
	rsync -aHvz --delete ../imapsync_website/ root@ks5.lamiral.info:/usr/local/www/apache24/data/imapsync/





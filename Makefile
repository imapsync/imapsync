
# $Id: Makefile,v 1.35 2010/08/15 11:18:38 gilles Exp gilles $	

.PHONY: help usage all

help: usage

usage:
	@echo "      imapsync $(VERSION), You can do :"
	@echo "make install # as root"
	@echo "make testf   # run tests"
	@echo "make testv   # run tests verbosely"
	@echo "make test3xx # run tests with (last) Mail-IMAPClient-3.xy"
	@echo "make test229 # run tests with Mail-IMAPClient-2.2.9"
	@echo "make all     "
	@echo "make upload_index"

DIST_NAME=imapsync-$(VERSION)
DIST_FILE=$(DIST_NAME).tgz
DEB_FILE=$(DIST_NAME).deb
VERSION=$(shell perl -I./Mail-IMAPClient-2.2.9 ./imapsync --version)



all: ChangeLog README VERSION

.PHONY: test tests testp testf test3xx

.test: imapsync tests.sh
	/usr/bin/time sh tests.sh 1>/dev/null
	touch .test

.test_3xx: imapsync tests.sh
	CMD_PERL='perl -I./Mail-IMAPClient-3.25/lib' /usr/bin/time sh tests.sh 1>/dev/null
	touch .test_3xx

test_quick : test_quick_229 test_quick_3xx

test_quick_229: imapsync tests.sh
	CMD_PERL='perl -I./Mail-IMAPClient-2.2.9' /usr/bin/time sh tests.sh locallocal 1>/dev/null

test_quick_3xx: imapsync tests.sh
	CMD_PERL='perl -I./Mail-IMAPClient-3.25/lib' /usr/bin/time sh tests.sh locallocal 1>/dev/null

testv:
	nice -40 sh -x tests.sh

test: .test_229 .test_3xx

tests: test

test3xx: .test_3xx

test229: .test_229

.test_229: imapsync tests.sh
	CMD_PERL='perl -I./Mail-IMAPClient-2.2.9' /usr/bin/time sh tests.sh 1>/dev/null
	touch .test_229

testf: clean_test test

testp :
	perl -c imapsync

ChangeLog: imapsync
	rlog imapsync > ChangeLog

README: imapsync
	perldoc -t imapsync > README

VERSION: imapsync Makefile
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
	install -D imapsync $(DESTDIR)/usr/bin/imapsync
	install -D imapsync.1 $(DESTDIR)/usr/share/man/man1/imapsync.1
	chmod 755 $(DESTDIR)/usr/bin/imapsync


dist: cidone test clean clean_dist all INSTALL tarball


tarball:
	echo making tarball $(DIST_FILE)
	mkdir -p dist
	mkdir -p ../prepa_dist/$(DIST_NAME)
	rsync -aCv --delete --omit-dir-times --exclude dist/ ./ ../prepa_dist/$(DIST_NAME)
	cd ../prepa_dist &&  (tar czfv $(DIST_FILE) $(DIST_NAME) || tar czfv  $(DIST_FILE) $(DIST_NAME))
	ln -f ../prepa_dist/$(DIST_FILE) dist/
	cd dist && md5sum $(DIST_FILE) > $(DIST_FILE).md5.txt
	cd dist && md5sum -c $(DIST_FILE).md5.txt


deb: 
	echo making debball $(DEB_FILE)
	mkdir -p ../prepa_deb
	cd  ../prepa_deb && tar  xzvf ../prepa_dist/$(DIST_FILE) &&\
	cd ../prepa_dist/$(DIST_NAME) 

.PHONY: cidone clean_dist

cidone:
	rcsdiff RCS/*

clean_dist:
	echo Used to be 'rm -f dist/*'

# Local goals

.PHONY: lfo upload_lfo niouze_lfo niouze_fm public

upload_index: index.shtml
	rsync -avH index.shtml \
	/home/gilles/public_html/www.linux-france.org/html/prj/imapsync/
	sh ~/memo/lfo-rsync


lfo: dist niouze_lfo upload_lfo 

upload_lfo: 
	rsync -avH --delete . \
	/home/gilles/public_html/www.linux-france.org/html/prj/imapsync/
	rsync -avH --delete ../prepa_dist/imapsync-*tgz  \
	/home/gilles/public_html/www.linux-france.org/ftp/prj/imapsync/
	sh ~/memo/lfo-rsync

niouze_lfo : VERSION
	. memo && lfo_announce

niouze_fm: VERSION
	. memo && fm_announce


public: niouze_fm

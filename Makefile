
# $Id: Makefile,v 1.23 2009/07/03 01:01:13 gilles Exp gilles $	

TARGET=imapsync

.PHONY: help usage all

help: usage

usage:
	@echo "      $(TARGET) $(VERSION), You can do :"
	@echo "make install # as root"
	@echo "make testf   # run tests"
	@echo "make testv   # run tests verbosely"
	@echo "make test3xx # run tests with Mail-IMAPClient-3.xy"
	@echo "make test229 # run tests with Mail-IMAPClient-2.2.9"
	@echo "make all     "

all: ChangeLog README VERSION

.PHONY: test testp testf test3xx

.test: $(TARGET) tests.sh
	/usr/bin/time sh tests.sh 1>/dev/null
	touch .test

.test_3xx: $(TARGET) tests.sh
	CMD_PERL='perl -I./Mail-IMAPClient-3.19/lib' /usr/bin/time sh tests.sh 1>/dev/null
	touch .test_3xx

test_quick : test_quick_229 test_quick_3xx

test_quick_229: $(TARGET) tests.sh
	CMD_PERL='perl -I./Mail-IMAPClient-2.2.9' /usr/bin/time sh tests.sh locallocal 1>/dev/null

test_quick_3xx: $(TARGET) tests.sh
	CMD_PERL='perl -I./Mail-IMAPClient-3.19/lib' /usr/bin/time sh tests.sh locallocal 1>/dev/null

testv:
	nice -40 sh -x tests.sh

test: .test_229 .test_3xx


test3xx: .test_3xx

test229: .test_229

.test_229: $(TARGET) tests.sh
	CMD_PERL='perl -I./Mail-IMAPClient-2.2.9' /usr/bin/time sh tests.sh 1>/dev/null
	touch .test_229

testf: clean_test test

testp :
	perl -c $(TARGET)

ChangeLog: $(TARGET)
	rlog $(TARGET) > ChangeLog

README: $(TARGET)
	perldoc -t $(TARGET) > README

VERSION: $(TARGET) Makefile
	perl -I./Mail-IMAPClient-2.2.9 ./$(TARGET) --version > VERSION

.PHONY: clean clean_tilde clean_test   

clean: clean_tilde clean_man

clean_test:
	rm -f .test .test_3xx .test_229

clean_tilde:
	rm -f *~

.PHONY: install dist man

man: $(TARGET).1

clean_man:
	rm -f $(TARGET).1

$(TARGET).1: $(TARGET)
	pod2man $(TARGET) > $(TARGET).1

install: testp $(TARGET).1
	install -D $(TARGET) $(DESTDIR)/usr/bin/$(TARGET)
	install -D $(TARGET).1 $(DESTDIR)/usr/share/man/man1/$(TARGET).1
	chmod 755 $(DESTDIR)/usr/bin/$(TARGET)


DIST_NAME=$(TARGET)-$(VERSION)
DIST_FILE=$(DIST_NAME).tgz
DEB_FILE=$(DIST_NAME).deb
VERSION=$(shell perl -I./Mail-IMAPClient-2.2.9 ./$(TARGET) --version)

dist: cidone test clean clean_dist all INSTALL tarball


tarball:
	echo making tarball $(DIST_FILE)
	mkdir -p dist
	mkdir -p ../prepa_dist/$(DIST_NAME)
	rsync -aCv --delete  --exclude dist/ ./  ../prepa_dist/$(DIST_NAME)
	cd ../prepa_dist && tar czfv $(DIST_FILE) $(DIST_NAME)
	ln -f ../prepa_dist/$(DIST_FILE) dist/
	cd dist && md5sum $(DIST_FILE) > $(DIST_FILE).md5.txt
	cd dist && md5sum -c $(DIST_FILE).md5.txt


deb: 
	echo making debball $(DEB_FILE)
	mkdir -p ../prepa_deb
	cd  ../prepa_deb && tar xzvf ../prepa_dist/$(DIST_FILE) &&\
	cd ../prepa_dist/$(DIST_NAME) 

.PHONY: cidone clean_dist

cidone:
	rcsdiff RCS/*

clean_dist:
	echo Used to be 'rm -f dist/*'

# Local goals

.PHONY: lfo niouze

lfo: dist lfo_upload niouze_lfo  niouze

lfo_upload: 
	rsync -avH --delete . \
	/home/gilles/public_html/www.linux-france.org/html/prj/$(TARGET)/
	rsync -avH --delete ../prepa_dist/imapsync-*tgz  \
	/home/gilles/public_html/www.linux-france.org/ftp/prj/$(TARGET)/
	sh ~/memo/lfo-rsync

niouze_lfo : VERSION
	. memo && lfo_announce

niouze: VERSION
	. memo && fm_announce


public: niouze

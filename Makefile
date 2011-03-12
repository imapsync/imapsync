
# $Id: Makefile,v 1.16 2007/06/15 04:08:28 gilles Exp $	

TARGET=imapsync

.PHONY: help usage all

help: usage

usage:
	@echo "      $(TARGET) $(VERSION), You can do :"
	@echo make install # as root
	@echo make testf   # run tests
	@echo make testv   # run tests verbosely
	@echo make all     

all: ChangeLog README VERSION

.PHONY: test testp testf

.test: $(TARGET) tests.sh
	nice -40 sh tests.sh 1>/dev/null
	touch .test

testv:
	nice -40 sh -x tests.sh

test: .test

testf: clean_test test

testp :
	perl -c $(TARGET)

ChangeLog: $(TARGET)
	rlog $(TARGET) > ChangeLog

README: $(TARGET)
	perldoc -t $(TARGET) > README

VERSION: $(TARGET) Makefile
	./$(TARGET) --version > VERSION

.PHONY: clean clean_tilde clean_test   

clean: clean_tilde clean_test clean_man

clean_test:
	rm -f .test

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
VERSION=$(shell ./$(TARGET) --version)

dist: cidone test clean clean_dist all INSTALL  
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

lfo: dist niouze_lfo lfo_upload niouze

lfo_upload: 
	rsync -av --delete . \
	/home/gilles/public_html/www.linux-france.org/html/prj/$(TARGET)/
	rsync -av --delete ../prepa_dist/imapsync-*tgz  \
	/home/gilles/public_html/www.linux-france.org/ftp/prj/$(TARGET)/
	sh ~/memo/lfo-rsync

niouze_lfo : VERSION
	. memo && lfo_announce

niouze: VERSION
	. memo && fm_announce


public: niouze

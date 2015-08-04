#!/bin/sh

eval `perl -I $HOME/perl5/lib/perl5 -Mlocal::lib`
export MANPATH=$HOME/perl5/man:$MANPATH

HOSTNAME=`hostname -s`
ARCH=`uname -m`
KERNEL=`uname -s`
echo "$HOSTNAME $ARCH $KERNEL"

VERSION=`./imapsync --version`
BIN_NAME=imapsync_bin_Darwin

pp -o $BIN_NAME  \
	-M Mail::IMAPClient -M IO::Socket -M IO::Socket::SSL \
	-M Digest::MD5 -M Digest::HMAC_MD5 -M Term::ReadKey \
	-M Authen::NTLM \
	imapsync

./imapsync_bin_Darwin
./imapsync_bin_Darwin --tests
./imapsync_bin_Darwin --testslive

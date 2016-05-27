#!/bin/sh

# $Id: build_mac.sh,v 1.2 2015/11/04 18:19:48 gilles Exp gilles $

eval `perl -I $HOME/perl5/lib/perl5 -Mlocal::lib`
export MANPATH=$HOME/perl5/man:$MANPATH

HOSTNAME=`hostname -s`
ARCH=`uname -m`
KERNEL=`uname -s`
echo "$HOSTNAME $ARCH $KERNEL"

VERSION=`./imapsync --version`
BIN_NAME=imapsync_bin_Darwin

cpanm Mail::IMAPClient

pp -o $BIN_NAME  \
	-M Mail::IMAPClient -M IO::Socket -M IO::Socket::SSL \
	-M Digest::MD5 -M Digest::HMAC_MD5 -M Term::ReadKey \
	-M Authen::NTLM \
	-M Crypt::OpenSSL::RSA -M JSON -M JSON::WebToken -M LWP -M HTML::Entities \
	imapsync

./imapsync_bin_Darwin
./imapsync_bin_Darwin --tests
./imapsync_bin_Darwin --testslive

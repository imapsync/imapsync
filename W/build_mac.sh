#!/bin/sh

# $Id: build_mac.sh,v 1.8 2017/03/01 03:06:46 gilles Exp gilles $

# exit on any failure
set -e

eval `perl -I $HOME/perl5/lib/perl5 -Mlocal::lib`
export MANPATH=$HOME/perl5/man:$MANPATH

HOSTNAME=`hostname -s`
ARCH=`uname -m`
KERNEL=`uname -s`
echo "$HOSTNAME $ARCH $KERNEL"

BIN_NAME=imapsync_bin_Darwin

# exit if known needed modules are missing
sh prerequisites_imapsync

VERSION=`./imapsync --version`

# Update important Perl modules
cpanm Mail::IMAPClient IO::Socket::SSL PAR::Packer

pp -o $BIN_NAME  \
	-M Mail::IMAPClient -M IO::Socket -M IO::Socket::SSL \
	-M Digest::MD5 -M Digest::HMAC_MD5 -M Term::ReadKey \
	-M Authen::NTLM -M Net::Ping \
	-M Crypt::OpenSSL::RSA -M JSON -M JSON::WebToken -M LWP -M HTML::Entities \
	-M Sys::MemInfo \
	imapsync

./imapsync_bin_Darwin 
./imapsync_bin_Darwin --tests
./imapsync_bin_Darwin --testslive

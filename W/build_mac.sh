#!/bin/sh

# $Id: build_mac.sh,v 1.15 2019/11/25 12:46:48 gilles Exp gilles $

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
OPENSSL_PREFIX=/sw cpanm Mail::IMAPClient IO::Socket::SSL Net::SSLeay PAR::Packer

pp -u -x -o $BIN_NAME  \
        -M Mail::IMAPClient -M IO::Socket -M IO::Socket::SSL \
        -M Digest::MD5 -M Digest::HMAC_MD5 -M Term::ReadKey \
        -M Authen::NTLM \
        -M Crypt::OpenSSL::RSA -M JSON -M JSON::WebToken -M LWP -M HTML::Entities \
        -M Sys::MemInfo -M Net::SSLeay \
        -M Encode -M MIME::Base64 -M Encode::IMAPUTF7 \
        --link /sw/lib/libssl.1.0.0.dylib \
        --link /sw/lib/libcrypto.1.0.0.dylib \
        imapsync

./imapsync_bin_Darwin 
./imapsync_bin_Darwin --tests
./imapsync_bin_Darwin --testslive
# Do not work anymore on polarhome at 2019_11_24
#./imapsync_bin_Darwin --testslive6


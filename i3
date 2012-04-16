#!/bin/sh

# $Id: i3,v 1.8 2011/11/12 21:49:00 gilles Exp gilles $

BASE=`dirname $0`
perl -I${BASE}/Mail-IMAPClient-3.30/lib ${BASE}/imapsync "$@"


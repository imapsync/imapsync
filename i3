#!/bin/sh

# $Id: i3,v 1.7 2011/03/15 01:15:48 gilles Exp gilles $

BASE=`dirname $0`
perl -I${BASE}/Mail-IMAPClient-3.28/lib ${BASE}/imapsync "$@"


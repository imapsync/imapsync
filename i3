#!/bin/sh

# $Id: i3,v 1.9 2012/04/15 19:18:02 gilles Exp gilles $

BASE=`dirname $0`
perl -I${BASE}/Mail-IMAPClient-3.31/lib ${BASE}/imapsync "$@"


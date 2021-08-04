#!/bin/sh

# $Id: i3,v 1.20 2021/07/02 11:34:25 gilles Exp gilles $

BASE=`dirname $0`
perl -I${BASE}/W/Mail-IMAPClient-3.43/lib ${BASE}/imapsync "$@"


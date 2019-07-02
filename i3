#!/bin/sh

# $Id: i3,v 1.18 2019/01/03 15:17:20 gilles Exp gilles $

BASE=`dirname $0`
perl -I${BASE}/W/Mail-IMAPClient-3.40/lib ${BASE}/imapsync "$@"


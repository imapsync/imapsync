#!/bin/sh

# $Id: i3,v 1.19 2019/05/27 22:05:18 gilles Exp gilles $

BASE=`dirname $0`
perl -I${BASE}/W/Mail-IMAPClient-3.42/lib ${BASE}/imapsync "$@"


#!/bin/sh

# $Id: i3,v 1.17 2017/02/17 02:09:42 gilles Exp gilles $

BASE=`dirname $0`
perl -I${BASE}/W/Mail-IMAPClient-3.39/lib ${BASE}/imapsync "$@"


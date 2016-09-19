#!/bin/sh

# $Id: i3,v 1.16 2016/03/07 02:54:23 gilles Exp gilles $

BASE=`dirname $0`
perl -I${BASE}/W/Mail-IMAPClient-3.38/lib ${BASE}/imapsync "$@"


#!/bin/sh

# $Id: i3,v 1.14 2013/12/25 03:25:18 gilles Exp gilles $

BASE=`dirname $0`
perl -I${BASE}/W/Mail-IMAPClient-3.35/lib ${BASE}/imapsync "$@"


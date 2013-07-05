#!/bin/sh

# $Id: i3,v 1.12 2013/07/03 04:11:35 gilles Exp gilles $

BASE=`dirname $0`
perl -I${BASE}/W/Mail-IMAPClient-3.33/lib ${BASE}/imapsync "$@"


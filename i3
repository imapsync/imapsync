#!/bin/sh

# $Id: i3,v 1.10 2012/08/12 23:15:15 gilles Exp gilles $

BASE=`dirname $0`
perl -I${BASE}/W/Mail-IMAPClient-3.31/lib ${BASE}/imapsync "$@"


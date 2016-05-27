#!/bin/sh

# $Id: i3,v 1.15 2015/08/18 22:40:38 gilles Exp gilles $

BASE=`dirname $0`
perl -I${BASE}/W/Mail-IMAPClient-3.37/lib ${BASE}/imapsync "$@"


#!/bin/sh

# $Id: i3,v 1.11 2012/09/11 21:00:06 gilles Exp gilles $

BASE=`dirname $0`
perl -I${BASE}/W/Mail-IMAPClient-3.32/lib ${BASE}/imapsync "$@"


#!/bin/sh

# $Id: i3,v 1.13 2013/09/28 11:50:16 gilles Exp gilles $

BASE=`dirname $0`
perl -I${BASE}/W/Mail-IMAPClient-3.34/lib ${BASE}/imapsync "$@"


#!/bin/sh

# $Id: archive_per_month.sh,v 1.7 2015/11/05 17:31:33 gilles Exp gilles $

# Translate Jan to 01, Feb to 02 etc.
month_number() {
  test X"$1" = X"Jan" && echo 01 && return
  test X"$1" = X"Feb" && echo 02 && return
  test X"$1" = X"Mar" && echo 03 && return
  test X"$1" = X"Apr" && echo 04 && return
  test X"$1" = X"May" && echo 05 && return
  test X"$1" = X"Jun" && echo 06 && return
  test X"$1" = X"Jul" && echo 07 && return
  test X"$1" = X"Aug" && echo 08 && return
  test X"$1" = X"Sep" && echo 09 && return
  test X"$1" = X"Oct" && echo 10 && return
  test X"$1" = X"Nov" && echo 11 && return
  test X"$1" = X"Dec" && echo 12 && return
  echo 00
}

# Calculates the last day of month
# Expect GNU date command

last_day_of_year_month() {
  year_ld=$1
  month_ld=$2

  next_month_day_01=`date -d "$year_ld-$month_ld-15 next month" +%Y-%m-01`
  #echo $next_month_day_1
  # last day is 1st day of next month minus 1 day
  date -d "$next_month_day_01 -1 day" +%d
}


# Replace ... with standard options like --host1 --user1 --password1 --host2 --user2 --password2
# Remove the echo at the beginning

archive_year_month() {
  year=$1
  month=$2

  month_n=`month_number $month`
  last_day=`last_day_of_year_month $year $month_n`
  echo imapsync ... \
                 --search "SENTSINCE 1-$month-$year SENTBEFORE $last_day-$month-$year" \
                 --regextrans2 "s{.*}{Archive/$year/$month_n}"

}


# 
for year_archive in 1993 1994 1995 1996 1997 1998 1999 2000 2001 2002 2003 2004 2005 2006 2007 2008 2009 2010 2011 2012 2013; do
    for month_archive in "Jan" "Feb" "Mar" "Apr" "May" "Jun"  "Jul" "Aug" "Sep" "Oct" "Nov" "Dec"; do
           archive_year_month $year_archive $month_archive
    done
done


# End of $Id: archive_per_month.sh,v 1.7 2015/11/05 17:31:33 gilles Exp gilles $


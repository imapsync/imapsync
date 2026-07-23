#!/bin/sh

# $Id: archive_per_year.sh,v 1.4 2024/01/29 22:22:49 gilles Exp gilles $



count_from_to() {
        #set -x
        nb_from=${1:-"01"}
        nb_from_ln=`echo -n $nb_from | wc -c | tr -d ' '`

        nb_to=${2:-`expr $nb_from + 9`}
        nb_incr=${3:-"1"}
        nb_counter=$nb_from
        while test $nb_counter -le $nb_to;do
                nb_list="$nb_list $nb_counter"
                nb_counter=`expr $nb_counter + $nb_incr`
                nb_counter=`printf %0${nb_from_ln}d $nb_counter`
        done
        echo $nb_list
        #set +x
}

archive_year()
{
# 1) If the host2 separator is / instead of . then change 
# --subfolder2 "Archive.$1"
# to
# --subfolder2 "Archive/$1"
# 
# 2) Remove the "echo" command if you want a real execution
# 
# 3) To delete the source emails which are archived, add --delete1
# 

        echo imapsync  \
        --host1 test1.lamiral.info --user1 test1 --password1 secret1 \
        --host2 test2.lamiral.info --user2 test2 --password2 secret2 \
        --skipemptyfolders --search "SENTSINCE 1-Jan-$1 SENTBEFORE 31-Dec-$1" \
        --subfolder2 "Archive.$1" 
}

archive_year_from_to()
{
        for year in `count_from_to $1 $2`; do
                
                archive_year $year

        done
}


year_current=`date +%Y`

# Archive from 2010, 2011, 2012, ..., until the current year

archive_year_from_to 2010 $year_current

# Other example, from 1980 to 1986
#archive_year_from_to 1980 1986

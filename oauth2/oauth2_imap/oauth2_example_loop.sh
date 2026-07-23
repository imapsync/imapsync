
# $Id: oauth2_example_loop.sh,v 1.1 2024/08/25 15:56:37 gilles Exp gilles $

# An infinite loop with a sleep of 3600 seconds between each run

# How many seconds to sleep at each run inside the loop is set in the variable %sleep%

sleep=1800

while :
do
    ./oauth2_imap gilles.lamiral@outlook.com
#   ./oauth2_imap gilles.lamiral@gmail.com
    date
    echo Now sleeping for $sleep seconds
    sleep $sleep
done


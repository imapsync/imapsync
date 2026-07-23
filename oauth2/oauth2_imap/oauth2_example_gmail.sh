
# $Id: oauth2_example_gmail.sh,v 1.3 2024/07/24 13:11:42 gilles Exp gilles $

# I hope you can read
# A line beginning with # is a comment
# This shell script is for Linux users and MacOS users.

echo Currently running through $0 "$@"

echo Getting OAUTH2 tokens 

! test -d && mkdir tokens

# !!! The following CALL lines are the only part to edit !!!
# Replace the email by the email you want an access-token to be used with imapsync

# For a Gmail account it will be:

./oauth2_imap gilles.lamiral@gmail.com

# END OF PART TO EDIT

# Some extra features:
# You can specify the token file with the option --token_file
# example:

# ./oauth2_imap --token_file   my_token_file.txt   gilles.lamiral@gmail.com



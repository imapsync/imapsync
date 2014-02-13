#!/bin/sh

# imapsync example shell for Unix users
# lines beginning with # are just comments 

# Replace imap.foo.org toto secretoto 192.168.42.4 titi secretiti with your own values

./imapsync --host1 imap.foo.org   --user1 toto   --password1 "secretoto" \
           --host2 192.168.42.4   --user2 titi   --password2 "secretiti" 


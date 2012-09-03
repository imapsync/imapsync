#! /usr/bin/perl -w
#
# Author : Jean-Yves Boisiaud
#
# Outlook (IMAP) manages mail dates from the creation date of the mail
# instead of the content of the field 'Date:', included into the mail.
# This script modifies the mtime of the mails, according to the 'Date:' field
# value.
# Before running the script, you have to build a list of the mail files.
# For example, with the MailDir format, the file has been built whith :
#   find /var/lib/vmail -type f -a -name '[0-9]*' > /tmp/toto
# Depending on the quality of the 'Date:' field, some mtime modification fails.
# You have to correct it manually.
# I ran it on 18733 mails, and 45 failed.

use strict;

my @a;
my $f;
my @b;
my @date;
my $d;
my @r;
my $s;

open(F, "</tmp/toto") or die "can't open toto";
@a = <F>;
chomp @a;

foreach $f (@a)
{
	open(F1, "<$f") or die "can't open $f";
        @b = <F1>;
        chomp @b;
        close F1;
        @date = grep /^Date: /, @b;
        next if scalar @date <= 0;
        $d = $date[0];
        $d =~ s/Date: (.*)$/$1/i;
        print "$d\n";
        @r = `/usr/bin/touch -md '$d' '$f' 2>&1`;
        print "$f\n";
        foreach $d (@r)
        {
        	print "$d\n"
        }
}


#!/usr/bin/perl
#
# $Cambridge: hermes/src/2exchange/scripts/watchdog.pl,v 1.5 2017/02/10 09:57:11 dpc22 Exp $
#
# Watchdog wrapper which runs shell script as subprocess collecting output
# in file. Kills child process if it doesn't generate output after $TIMEOUT

my $TIMEOUT = (30*60); # 30 minutes

use strict;
use warnings;

(@ARGV == 2) or die "watchdog.pl args: cmdfile outfile\n";

my $cmdfile=$ARGV[0];
my $outfile=$ARGV[1];

# Touch outfile to make sure timestamp up to date. Don't blat existing content.
open(my $fh, ">>", $outfile) or die "Failed to open $outfile: $!\n";
close($fh);

open($fh, "<", $cmdfile) or die "Failed to open $cmdfile: $!\n";
my $cmd = <$fh>;
close($fh);
chomp($cmd);

my $cmd_pid = fork();
die "watchdog.pl Could not fork(): $_\n" if not defined $cmd_pid;

if (not $cmd_pid) {
    open (STDOUT, '>>',  $outfile);
    open (STDERR, '>&', STDOUT);
    exec($cmd);
    exit 1;
}

my $watchdog_pid = fork();
die "Could not fork(): $_\n" if not defined $watchdog_pid;
if (not $watchdog_pid) {
    while (1) {
        my $now   = time;
        my @stat  = stat $outfile;
        my $mtime = (@stat) ? $stat[9] : $now;

        last if (($now - $mtime) > ${TIMEOUT});
        sleep(1);
    }
    exit 1;
}

######################################################################
# Wait for either subprocess to finish. Then kill the other one and wait
# for that to finish as well. Return the exit code from the first process.
my $pid    = wait;
my $status = $?;
my $rc     = $status >> 8;  # Normally 128+N when grandchild catches signal N
my $signal = $status & 127; # Only nonzero if $cmd_pid shell itself killed
if ($rc == 0 and $signal != 0) {
    $rc = 128 + $signal;    # Paranoia in case $pid shell is killed directly
}

die("watchdog.pl: No child process\n") if ($pid < 0);

if ($pid == $cmd_pid) {
    kill 'TERM', $watchdog_pid;
} elsif ($pid == $watchdog_pid) {
    kill 'TERM', $cmd_pid;
} else {
    die "watchdog.pl: Unexpected child process pid: ${pid}\n";
}

$pid=wait;
exit($rc);


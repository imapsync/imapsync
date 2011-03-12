#!/usr/local/bin/perl
#
# This is a partial implentation of the MD4 checksum code.
#
# NOTE
#
# The function &add() in this module is required as we need to be
# able to add 32bit integers ignoring overflow.  The C code this is
# based on does this because it uses the underlying hardware to
# perform the required addition however we need to be more careful
# as Perl will overflow an int and produce a result of 0xffffffff
# which is not very useful.  The &add() function splits its arguments
# into two shorts and adds these carrying overflow from the low short
# to the high short and ignoring carry from the high short.  Not
# exactly efficient, but it works and is fast enough for the purposes
# of this implementation
#

package Authen::NTLM::MD4;

use vars qw($VERSION @ISA @EXPORT);
require Exporter;

$VERSION = "1.02";
@ISA = qw(Exporter);
@EXPORT = qw(mdfour);

my ($A, $B, $C, $D);
my (@X, $M);

sub mdfour
{
  my ($in) = @_;

  my ($i, $pos);
  my $len = length($in);
  my $b = $len * 8;
  $in .= "\0"x128;
  $A = 0x67452301;
  $B = 0xefcdab89;
  $C = 0x98badcfe;
  $D = 0x10325476;
  $pos = 0;
  while ($len > 64)
  {
    &copy64(substr($in, $pos, 64));
    &mdfour64;
    $pos += 64;
    $len -= 64;
  }
  my $buf = substr($in, $pos, $len);
  $buf .= sprintf "%c", 0x80;
  if ($len <= 55)
  {
    $buf .= "\0"x(55-$len);
    $buf .= pack("V", $b);
    $buf .= "\0"x4;
    &copy64($buf);
    &mdfour64;
  }
  else
  {
    $buf .= "\0"x(120-$len);
    $buf .= pack("V", $b);
    $buf .= "\0"x4;
    &copy64(substr($buf, 0, 64));
    &mdfour64;
    &copy64(substr($buf, 64, 64));
    &mdfour64;
  }
  my $out = pack("VVVV", $A, $B, $C, $D);
  return $out;
}

sub F
{
  my ($X, $Y, $Z) = @_;
  my $res = ($X&$Y) | ((~$X)&$Z);
  return $res;
}

sub G
{
  my ($X, $Y, $Z) = @_;

  return ($X&$Y) | ($X&$Z) | ($Y&$Z);
}

sub H
{
  my ($X, $Y, $Z) = @_;

  return $X^$Y^$Z;
}

sub lshift
{
  my ($x, $s) = @_;

  $x &= 0xffffffff;
  return (($x<<$s)&0xffffffff) | ($x>>(32-$s));
}

sub ROUND1
{
  my ($a, $b, $c, $d, $k, $s) = @_;
  my $e = &add($a, &F($b, $c, $d), $X[$k]);
  return &lshift($e, $s);
}

sub ROUND2
{
  my ($a, $b, $c, $d, $k, $s) = @_;

  my $e = &add($a, &G($b, $c, $d), $X[$k], 0x5a827999);
  return &lshift($e, $s);
}

sub ROUND3
{
  my ($a, $b, $c, $d, $k, $s) = @_;

  my $e = &add($a, &H($b, $c, $d), $X[$k], 0x6ed9eba1);
  return &lshift($e, $s);
}

sub mdfour64
{
  my ($i, $AA, $BB, $CC, $DD);
  @X = unpack("N16", $M);
  $AA = $A;
  $BB = $B;
  $CC = $C;
  $DD = $D;

  $A = &ROUND1($A,$B,$C,$D, 0, 3); $D = &ROUND1($D,$A,$B,$C, 1, 7);
  $C = &ROUND1($C,$D,$A,$B, 2,11); $B = &ROUND1($B,$C,$D,$A, 3,19);
  $A = &ROUND1($A,$B,$C,$D, 4, 3); $D = &ROUND1($D,$A,$B,$C, 5, 7);
  $C = &ROUND1($C,$D,$A,$B, 6,11); $B = &ROUND1($B,$C,$D,$A, 7,19);
  $A = &ROUND1($A,$B,$C,$D, 8, 3); $D = &ROUND1($D,$A,$B,$C, 9, 7);
  $C = &ROUND1($C,$D,$A,$B,10,11); $B = &ROUND1($B,$C,$D,$A,11,19);
  $A = &ROUND1($A,$B,$C,$D,12, 3); $D = &ROUND1($D,$A,$B,$C,13, 7);
  $C = &ROUND1($C,$D,$A,$B,14,11); $B = &ROUND1($B,$C,$D,$A,15,19);

  $A = &ROUND2($A,$B,$C,$D, 0, 3); $D = &ROUND2($D,$A,$B,$C, 4, 5);
  $C = &ROUND2($C,$D,$A,$B, 8, 9); $B = &ROUND2($B,$C,$D,$A,12,13);
  $A = &ROUND2($A,$B,$C,$D, 1, 3); $D = &ROUND2($D,$A,$B,$C, 5, 5);
  $C = &ROUND2($C,$D,$A,$B, 9, 9); $B = &ROUND2($B,$C,$D,$A,13,13);
  $A = &ROUND2($A,$B,$C,$D, 2, 3); $D = &ROUND2($D,$A,$B,$C, 6, 5);
  $C = &ROUND2($C,$D,$A,$B,10, 9); $B = &ROUND2($B,$C,$D,$A,14,13);
  $A = &ROUND2($A,$B,$C,$D, 3, 3); $D = &ROUND2($D,$A,$B,$C, 7, 5);
  $C = &ROUND2($C,$D,$A,$B,11, 9); $B = &ROUND2($B,$C,$D,$A,15,13);

  $A = &ROUND3($A,$B,$C,$D, 0, 3); $D = &ROUND3($D,$A,$B,$C, 8, 9);
  $C = &ROUND3($C,$D,$A,$B, 4,11); $B = &ROUND3($B,$C,$D,$A,12,15);
  $A = &ROUND3($A,$B,$C,$D, 2, 3); $D = &ROUND3($D,$A,$B,$C,10, 9);
  $C = &ROUND3($C,$D,$A,$B, 6,11); $B = &ROUND3($B,$C,$D,$A,14,15);
  $A = &ROUND3($A,$B,$C,$D, 1, 3); $D = &ROUND3($D,$A,$B,$C, 9, 9);
  $C = &ROUND3($C,$D,$A,$B, 5,11); $B = &ROUND3($B,$C,$D,$A,13,15);
  $A = &ROUND3($A,$B,$C,$D, 3, 3); $D = &ROUND3($D,$A,$B,$C,11, 9);
  $C = &ROUND3($C,$D,$A,$B, 7,11); $B = &ROUND3($B,$C,$D,$A,15,15);

  $A = &add($A, $AA); $B = &add($B, $BB);
  $C = &add($C, $CC); $D = &add($D, $DD);
  $A &= 0xffffffff; $B &= 0xffffffff;
  $C &= 0xffffffff; $D &= 0xffffffff;
  map {$_ = 0} @X;
}

sub copy64
{
  my ($in) = @_;

  $M = pack("V16", unpack("N16", $in));
}

# see note at top of this file about this function
sub add
{
  my (@nums) = @_;
  my ($r_low, $r_high, $n_low, $l_high);
  my $num;
  $r_low = $r_high = 0;
  foreach $num (@nums)
  {
    $n_low = $num & 0xffff;
    $n_high = ($num&0xffff0000)>>16;
    $r_low += $n_low;
    ($r_low&0xf0000) && $r_high++;
    $r_low &= 0xffff;
    $r_high += $n_high;
    $r_high &= 0xffff;
  }
  return ($r_high<<16)|$r_low;
}

1;

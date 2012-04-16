#!/usr/local/bin/perl

package Authen::NTLM;
use strict;
use Authen::NTLM::DES;
use Authen::NTLM::MD4;
use MIME::Base64;
use Digest::HMAC_MD5;

use vars qw($VERSION @ISA @EXPORT);
require Exporter;

=head1 NAME

Authen::NTLM - An NTLM authentication module

=head1 SYNOPSIS

    use Mail::IMAPClient;
    use Authen::NTLM;
    my $imap = Mail::IMAPClient->new(Server=>'imaphost');
    ntlm_user($username);
    ntlm_password($password);
    $imap->authenticate("NTLM", Authen::NTLM::ntlm);
    :
    $imap->logout;
    ntlm_reset;
    :

or

    ntlmv2(1);
    ntlm_user($username);
    ntlm_host($host);
    ntlm_password($password);
    :

or

    my $ntlm = Authen::NTLM-> new(
        host     => $host,
        user     => $username,
        domain   => $domain,
        password => $password,
        version  => 1,
    );
    $ntlm-> challenge;
    :
    $ntlm-> challenge($challenge);



=head1 DESCRIPTION

    This module provides methods to use NTLM authentication.  It can
    be used as an authenticate method with the Mail::IMAPClient module
    to perform the challenge/response mechanism for NTLM connections
    or it can be used on its own for NTLM authentication with other
    protocols (eg. HTTP).

    The implementation is a direct port of the code from F<fetchmail>
    which, itself, has based its NTLM implementation on F<samba>.  As
    such, this code is not especially efficient, however it will still
    take a fraction of a second to negotiate a login on a PII which is
    likely to be good enough for most situations.

=head2 FUNCTIONS

=over 4

=item ntlm_domain()

    Set the domain to use in the NTLM authentication messages.
    Returns the new domain.  Without an argument, this function
    returns the current domain entry.

=item ntlm_user()

    Set the username to use in the NTLM authentication messages.
    Returns the new username.  Without an argument, this function
    returns the current username entry.

=item ntlm_password()

    Set the password to use in the NTLM authentication messages.
    Returns the new password.  Without an argument, this function
    returns the current password entry.

=item ntlm_reset()

    Resets the NTLM challenge/response state machine so that the next
    call to C<ntlm()> will produce an initial connect message.

=item ntlm()

    Generate a reply to a challenge.  The NTLM protocol involves an
    initial empty challenge from the server requiring a message
    response containing the username and domain (which may be empty).
    The first call to C<ntlm()> generates this first message ignoring
    any arguments.

    The second time it is called, it is assumed that the argument is
    the challenge string sent from the server.  This will contain 8
    bytes of data which are used in the DES functions to generate the
    response authentication strings.  The result of the call is the
    final authentication string.

    If C<ntlm_reset()> is called, then the next call to C<ntlm()> will
    start the process again allowing multiple authentications within
    an application.

=item ntlmv2()

    Use NTLM v2 authentication.

=back

=head2 OBJECT API

=over

=item new %options

Creates an object that accepts the following options: C<user>, C<host>,
C<domain>, C<password>, C<version>.

=item challenge [$challenge]

If C<$challenge> is not supplied, first-stage challenge string is generated.
Otherwise, the third-stage challenge is generated, where C<$challenge> is
assumed to be extracted from the second stage of NTLM exchange. The result of
the call is the final authentication string.

=back

=head1 AUTHOR

    David (Buzz) Bussenschutt <davidbuzz@gmail.com> - current maintainer
    Dmitry Karasik <dmitry@karasik.eu.org> - nice ntlmv2 patch, OO extensions.
    Andrew Hobson <ahobson@infloop.com> - initial ntlmv2 code
    Mark Bush <Mark.Bush@bushnet.demon.co.uk> - perl port
    Eric S. Raymond - author of fetchmail
    Andrew Tridgell and Jeremy Allison for SMB/Netbios code

=head1 SEE ALSO

L<perl>, L<Mail::IMAPClient>, L<LWP::Authen::Ntlm> 

=head1 HISTORY

    1.09 - fix CPAN ticket # 70703
    1.08 - fix CPAN ticket # 39925
    1.07 - not publicly released
    1.06 - relicense as GPL+ or Artistic
    1.05 - add OO interface by Dmitry Karasik
    1.04 - implementation of NTLMv2 by Andrew Hobson/Dmitry Karasik 
    1.03 - fixes long-standing 1 line bug L<http://rt.cpan.org/Public/Bug/Display.html?id=9521> - released by David Bussenschutt 9th Aug 2007 
    1.02 - released by Mark Bush 29th Oct 2001

=cut

$VERSION = "1.09";
@ISA = qw(Exporter);
@EXPORT = qw(ntlm ntlm_domain ntlm_user ntlm_password ntlm_reset ntlm_host ntlmv2);

my $domain = "";
my $user = "";
my $password = "";

my $str_hdr = "vvV";
my $hdr_len = 8;
my $ident = "NTLMSSP";

my $msg1_f = 0x0000b207;
my $msg1 = "Z8VV";
my $msg1_hlen = 16 + ($hdr_len*2);

my $msg2 = "Z8Va${hdr_len}Va8a8a${hdr_len}";
my $msg2_hlen = 12 + $hdr_len + 20 + $hdr_len;

my $msg3 = "Z8V";
my $msg3_tl = "V";
my $msg3_hlen = 12 + ($hdr_len*6) + 4;

my $state = 0;

my $host = "";
my $ntlm_v2 = 0;
my $ntlm_v2_msg3_flags = 0x88205;


# Domain Name supplied on negotiate
use constant NTLMSSP_NEGOTIATE_OEM_DOMAIN_SUPPLIED      => 0x00001000;
# Workstation Name supplied on negotiate
use constant NTLMSSP_NEGOTIATE_OEM_WORKSTATION_SUPPLIED => 0x00002000;
# Try to use NTLMv2
use constant NTLMSSP_NEGOTIATE_NTLM2                    => 0x00080000;


# Object API

sub new
{
   my ( $class, %opt) = @_;
   for (qw(domain user password host)) {
      $opt{$_} = "" unless defined $opt{$_};
   }
   $opt{version} ||= 1;
   return bless { %opt }, $class;
}

sub challenge
{
   my ( $self, $challenge) = @_;
   $state = defined $challenge;
   ($user,$domain,$password,$host) = @{$self}{qw(user domain password host)};
   $ntlm_v2 = ($self-> {version} eq '2') ? 1 : 0;
   return ntlm($challenge);
}

eval "sub $_ { \$#_ ? \$_[0]->{$_} = \$_[1] : \$_[0]->{$_} }"
   for qw(user domain password host version);

# Function API

sub ntlm_domain
{
  if (@_)
  {
    $domain = shift;
  }
  return $domain;
}

sub ntlm_user
{
  if (@_)
  {
    $user = shift;
  }
  return $user;
}

sub ntlm_password
{
  if (@_)
  {
    $password = shift;
  }
  return $password;
}

sub ntlm_reset
{
  $state = 0;
}

sub ntlmv2
{
  if (@_) {
    $ntlm_v2 = shift;
  }
  return $ntlm_v2;
}

sub ntlm_host {
  if (@_) {
    $host = shift;
  }
  return $host;
}

sub ntlm
{
  my ($challenge) = @_;

  my ($flags, $user_hdr, $domain_hdr,
      $u_off, $d_off, $c_info, $lmResp, $ntResp, $lm_hdr,
      $nt_hdr, $wks_hdr, $session_hdr, $lm_off, $nt_off,
      $wks_off, $s_off, $u_user, $msg1_host, $host_hdr, $u_host);
  my $response;
  if ($state)
  {

    $challenge =~ s/^\s*//;
    $challenge = decode_base64($challenge);
    $c_info = &decode_challenge($challenge);
    $u_user = &unicode($user);
    if (!$ntlm_v2) {
      $domain = substr($challenge, $c_info->{domain}{offset}, $c_info->{domain}{len}); 
      $lmResp = &lmEncrypt($c_info->{data});
      $ntResp = &ntEncrypt($c_info->{data});
      $flags = pack($msg3_tl, $c_info->{flags});
	 }
	 elsif ($ntlm_v2 eq '1') {
      $lmResp = &lmv2Encrypt($c_info->{data});
      $ntResp = &ntv2Encrypt($c_info->{data}, $c_info->{target_data});
      $flags = pack($msg3_tl, $ntlm_v2_msg3_flags);
	 }
    else {
      $domain = &unicode($domain);#substr($challenge, $c_info->{domain}{offset}, $c_info->{domain}{len}); 
      $lmResp = &lmEncrypt($c_info->{data});
      $ntResp = &ntEncrypt($c_info->{data});
      $flags = pack($msg3_tl, $c_info->{flags});
    }
    $u_host = &unicode(($host ? $host : $user));
    $response = pack($msg3, $ident, 3);

    $lm_off = $msg3_hlen;
    $nt_off = $lm_off + length($lmResp);
    $d_off = $nt_off + length($ntResp);
    $u_off = $d_off + length($domain);
    $wks_off = $u_off + length($u_user);
    $s_off = $wks_off + length($u_host);
    $lm_hdr = &hdr($lmResp, $msg3_hlen, $lm_off);
    $nt_hdr = &hdr($ntResp, $msg3_hlen, $nt_off);
    $domain_hdr = &hdr($domain, $msg3_hlen, $d_off);
    $user_hdr = &hdr($u_user, $msg3_hlen, $u_off);
    $wks_hdr = &hdr($u_host, $msg3_hlen, $wks_off);
    $session_hdr = &hdr("", $msg3_hlen, $s_off);
    $response .= $lm_hdr . $nt_hdr . $domain_hdr . $user_hdr .
                 $wks_hdr . $session_hdr . $flags .
		 $lmResp . $ntResp . $domain . $u_user . $u_host;
  }
  else # first response;
  {
    my $f = $msg1_f;
    if (!length $domain) {
      $f &= ~NTLMSSP_NEGOTIATE_OEM_DOMAIN_SUPPLIED;
    }
    $msg1_host = $user;
    if ($ntlm_v2 and $ntlm_v2 eq '1') {
      $f &= ~NTLMSSP_NEGOTIATE_OEM_WORKSTATION_SUPPLIED;
      $f |= NTLMSSP_NEGOTIATE_NTLM2;
      $msg1_host = "";
    }

    $response = pack($msg1, $ident, 1, $f);
    $u_off = $msg1_hlen;
    $d_off = $u_off + length($msg1_host);
    $host_hdr = &hdr($msg1_host, $msg1_hlen, $u_off);
    $domain_hdr = &hdr($domain, $msg1_hlen, $d_off);
    $response .= $host_hdr . $domain_hdr . $msg1_host . $domain;
    $state = 1;
  }
  return encode_base64($response, "");
}

sub hdr
{
  my ($string, $h_len, $offset) = @_;

  my ($res, $len);
  $len = length($string);
  if ($string)
  {
    $res = pack($str_hdr, $len, $len, $offset);
  }
  else
  {
    $res = pack($str_hdr, 0, 0, $offset - $h_len);
  }
  return $res;
}

sub decode_challenge
{
  my ($challenge) = @_;

  my $res;
  my (@res, @hdr);
  my $original = $challenge;

  $res->{buffer} = $msg2_hlen < length $challenge
  ? substr($challenge, $msg2_hlen) : '';
  $challenge = substr($challenge, 0, $msg2_hlen);
  @res = unpack($msg2, $challenge);
  $res->{ident} = $res[0];
  $res->{type} = $res[1];
  @hdr = unpack($str_hdr, $res[2]);
  $res->{domain}{len} = $hdr[0];
  $res->{domain}{maxlen} = $hdr[1];
  $res->{domain}{offset} = $hdr[2];
  $res->{flags} = $res[3];
  $res->{data} = $res[4];
  $res->{reserved} = $res[5];
  $res->{empty_hdr} = $res[6];
  @hdr = unpack($str_hdr, $res[6]);
  $res->{target}{len} = $hdr[0];
  $res->{target}{maxlen} = $hdr[1];
  $res->{target}{offset} = $hdr[2];
  $res->{target_data} = substr($original, $hdr[2], $hdr[1]);

  return $res;
}

sub unicode
{
  my ($string) = @_;
  my ($reply, $c, $z) = ('');

  $z = sprintf "%c", 0;
  foreach $c (split //, $string)
  {
    $reply .= $c . $z;
  }
  return $reply;
}

sub NTunicode
{
  my ($string) = @_;
  my ($reply, $c);

  foreach $c (map {ord($_)} split(//, $string))
  {
    $reply .= pack("v", $c);
  }
  return $reply;
}

sub lmEncrypt
{
  my ($data) = @_;

  my $p14 = substr($password, 0, 14);
  $p14 =~ tr/a-z/A-Z/;
  $p14 .= "\0"x(14-length($p14));
  my $p21 = E_P16($p14);
  $p21 .= "\0"x(21-length($p21));
  my $p24 = E_P24($p21, $data);
  return $p24;
}

sub ntEncrypt
{
  my ($data) = @_;

  my $p21 = &E_md4hash;
  $p21 .= "\0"x(21-length($p21));
  my $p24 = E_P24($p21, $data);
  return $p24;
}

sub E_md4hash
{
  my $wpwd = &NTunicode($password);
  my $p16 = mdfour($wpwd);
  return $p16;
}

sub lmv2Encrypt {
  my ($data) = @_;

  my $u_pass = &unicode($password);
  my $ntlm_hash = mdfour($u_pass);

  my $u_user = &unicode("\U$user\E");
  my $u_domain = &unicode("$domain");
  my $concat = $u_user . $u_domain;

  my $hmac = Digest::HMAC_MD5->new($ntlm_hash);
  $hmac->add($concat);
  my $ntlm_v2_hash = $hmac->digest;

  # Firefox seems to use this as its random challenge
  my $random_challenge = "\0" x 8;

  my $concat2 = $data . $random_challenge;

  $hmac = Digest::HMAC_MD5->new($ntlm_v2_hash);
  $hmac->add(substr($data, 0, 8) . $random_challenge);
  my $r = $hmac->digest . $random_challenge;

  return $r;
}

sub ntv2Encrypt {
  my ($data, $target) = @_;

  my $u_pass = &unicode($password);
  my $ntlm_hash = mdfour($u_pass);

  my $u_user = &unicode("\U$user\E");
  my $u_domain = &unicode("$domain");
  my $concat = $u_user . $u_domain;

  my $hmac = Digest::HMAC_MD5->new($ntlm_hash);
  $hmac->add($concat);
  my $ntlm_v2_hash = $hmac->digest;

  my $zero_long = "\000" x 4;
  my $sig = pack("H8", "01010000");
  my $time = pack("VV", (time + 11644473600) + 10000000);
  my $rand = "\0" x 8;
  my $blob = $sig . $zero_long . $time . $rand . $zero_long .
      $target . $zero_long;

  $concat = $data . $blob;

  $hmac = Digest::HMAC_MD5->new($ntlm_v2_hash);
  $hmac->add($concat);

  my $d = $hmac->digest;

  my $r = $d . $blob;

  return $r;
}

1;

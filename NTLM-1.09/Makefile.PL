#!/usr/bin/perl

use ExtUtils::MakeMaker;

# 

WriteMakefile(
    'NAME'		=> 'Authen::NTLM',
    'DIR'		=> ['DES', 'MD4'],
    'VERSION_FROM'	=> 'NTLM.pm',
    'PREREQ_PM' => { 'MIME::Base64' => 0, 'Digest::HMAC_MD5' => 0 },
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      ('AUTHOR'     => 'David (Buzz) Bussenschutt <davidbuzz@gmail.com>, Mark Bush <Mark.Bush@bushnet.demon.co.uk>') : ()),
);

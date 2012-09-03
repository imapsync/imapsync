#!/usr/bin/perl

use ExtUtils::MakeMaker;

# 

WriteMakefile(
    'NAME'		=> 'Authen::NTLM::MD4',
    'VERSION_FROM'	=> 'MD4.pm',
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      ('AUTHOR'     => 'David (Buzz) Bussenschutt <davidbuzz@gmail.com>, Mark Bush <Mark.Bush@bushnet.demon.co.uk>') : ()),
);

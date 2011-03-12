use ExtUtils::MakeMaker;
use warnings;
use strict;

sub set_test_data();

WriteMakefile
 ( NAME         => 'Mail::IMAPClient',
 , ABSTRACT     => 'IMAP4 client library'
 , VERSION_FROM => 'lib/Mail/IMAPClient.pm'
 , PREREQ_PM    =>
    { 'Errno'        => 0
    , 'IO::Socket'   => 0
    , 'Fcntl'        => 0
    , 'IO::Select'   => 0
    , 'IO::File'     => 0
    , 'Data::Dumper' => 0
    , 'Carp'         => 0
    , 'IO::Socket::INET'  => 1.26
    , 'Parse::RecDescent' => 1.94
    , 'Digest::HMAC_MD5'  => 0
    , 'MIME::Base64' => 0

    , 'Test::More'   => 0
    , 'File::Temp'   => 0.18
    , 'Test::Pod'    => 0
    }
 , clean        => { FILES => 'test.txt' }
 );

set_test_data();

exit 0;

###
### HELPERS
###

sub set_test_data()
{   unless(-f "lib/Mail/IMAPClient.pm")
    {   warn "ERROR: not in installation directory\n";
        return;
    }

    return if -f "./test.txt";

    print <<'__INTRO';
You have the option of running an extended suite of tests during
'make test'. This requires an IMAP server name, user account, and
password to test with.

__INTRO

    my $yes = prompt "Do you want to run the extended tests? (n/y)";
    return if $yes !~ /^[Yy](?:[Ee]:[Ss]?)?$/ ;

    unless(open TST, '>', "./test.txt")
    {   warn "ERROR: couldn't open ./test.txt: $!\n";
        return;
    }

    my $server = "";
    until($server)
    {   $server = prompt "\nPlease provide the hostname or IP address of "
                     . "a host running an\nIMAP server (or QUIT to skip "
                     . "the extended tests)";
        chomp $server;
        return if $server =~ /^\s*quit\s*$/i ;
    }

    print TST "server=$server\n";

    my $user = "";
    until($user)
    {   $user = prompt "\nProvide the username of an account on $server (or QUIT)";
        chomp $user;
        return if $user =~ /^\s*quit\s*$/i ;
    }
    print TST "user=$user\n";

    my $passed = "";
    until($passed)
    {   $passed = prompt "\nProvide the password for $user (or QUIT)";
        chomp $passed;
        return if $passed =~ /^\s+$|^quit$/i ;
    }

    print TST "passed=$passed\n";

    my $port = prompt "\nPlease provide the port to connect to on $server "
                    . "to run the test\n(default is 143)";
    chomp $port;
    $port ||= 143; 
    print TST "port=$port\n";

    my $authmech = prompt "\nProvide the authentication mechanism to use "
                        . "on $server to\nrun the test (default is LOGIN)";

    chomp $authmech;
    $authmech ||= 'LOGIN'; 
    print TST "authmechanism=$authmech\n";
    close TST;

    print <<'__THANKS';

Gracias! The information you provided (including the password!) has
been stored in test.txt and SHOULD BE REMOVED (either by hand or by
'make clean') after testing.
__THANKS

}

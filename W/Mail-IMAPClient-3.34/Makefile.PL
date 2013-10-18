use ExtUtils::MakeMaker;
use warnings;
use strict;

use 5.008_001;

my @missing;
my %optional = (
    "Authen::NTLM"     => { for => "Authmechanism 'NTLM'" },
    "Authen::SASL"     => { for => "Authmechanism 'DIGEST-MD5'" },
    "Compress::Zlib"   => { for => "COMPRESS DEFLATE support" },
    "Digest::HMAC_MD5" => { for => "Authmechanism 'CRAM-MD5'" },
    "Digest::MD5"      => { for => "Authmechanism 'DIGEST-MD5'" },
    "IO::Socket::SSL"  => { for => "SSL enabled connections (Ssl => 1)" },
    "Test::Pod"        => { for => "Pod tests", ver => "1.00" },
);

foreach my $mod ( sort keys %optional ) {
    my $for = $optional{$mod}->{"for"} || "";
    my $ver = $optional{$mod}->{"ver"} || "";
    eval "use $mod $ver ();";
    push @missing, $mod . ( $for ? " for $for" : "" ) if $@;
}

# similar message to one used in DBI:
if (@missing) {
    print( "The following optional modules were not found:",
        map( "\n\t" . $_, @missing ), "\n" );

    print <<'MSG';
Optional modules are available from any CPAN mirror, reference:
  http://search.cpan.org/
  http://www.perl.com/CPAN/modules/by-module
  http://www.perl.org/CPAN/modules/by-module

MSG
    sleep 3;
}

# HACK: die on broken Parse::RecDescent 1.966002 through 1.967009
# - rt.cpan.org#74593: Recent changes break Module::ExtractUse and ...
# - rt.cpan.org#74733: Fails with Parse::RecDescent >= 1.966_002
do {
    eval { require version; require Parse::RecDescent; };
    unless ($@) {
        my $found = version->parse( Parse::RecDescent->VERSION() );
        my $broke = version->parse("1.966002");
        my $fixed = version->parse("1.967009");
        if ( $found < $fixed and $found >= $broke ) {
            die(
                "Found broken Parse::RecDescent $found in your environment.\n",
                "Please upgrade to version $fixed or greater.\n"
            );
        }
    }
};

WriteMakefile(
    NAME         => 'Mail::IMAPClient',
    AUTHOR       => 'Phil Pearl (Lobbes) <phil@zimbra.com>',
    ABSTRACT     => 'IMAP4 client library',
    VERSION_FROM => 'lib/Mail/IMAPClient.pm',
    LICENSE      => 'perl',
    META_MERGE   => {
        resources => {
            bugtracker => {
                web =>
'http://rt.cpan.org/Public/Dist/Display.html?Name=Mail-IMAPClient',
                mailto => 'bug-Mail-IMAPClient@rt.cpan.org',
            },
            homepage   => 'http://sourceforge.net/projects/mail-imapclient/',
            repository => {
                url  => 'git://git.code.sf.net/p/mail-imapclient/git',
                web  => 'http://sourceforge.net/p/mail-imapclient/git/',
                type => 'git',
            },
        },
    },
    MIN_PERL_VERSION => '5.008',
    PREREQ_PM        => {
        'Carp'              => 0,
        'Errno'             => 0,
        'Fcntl'             => 0,
        'IO::File'          => 0,
        'IO::Select'        => 0,
        'IO::Socket'        => 0,
        'IO::Socket::INET'  => 1.26,
        'List::Util'        => 0,
        'MIME::Base64'      => 0,
        'Parse::RecDescent' => 1.94,
        'Test::More'        => 0,
        'File::Temp'        => 0,
    },
    clean => { FILES => 'test.txt' },
);

set_test_data();

exit 0;

###
### HELPERS
###

sub set_test_data {
    unless ( -f "lib/Mail/IMAPClient.pm" ) {
        warn("ERROR: not in installation directory\n");
        return;
    }

    if ( -s "./test.txt" ) {
        print("The file test.txt will be used for extended tests.\n");
        return;
    }

    print <<EOF;

(OPTIONAL) For extended tests during 'make test', create a file
'test.txt' in the top level directory of this distribution (the same
directory as the Makefile.PL, etc.).  This file must contain an IMAP
server name or IP (server=...), a user account (user=...), and a
password (passed=...).  A port (port=....) and an authentication
mechanism to be used (authmechanism=...) can also be specified.

Example:

--- BEGIN: test.txt ---
server=localhost
user=mytestuser
passed=mypassword
port=143
--- END: test.txt ---

NOTE: When testing is completed, be sure to remove test.txt (either by
hand or by 'make clean').

EOF
}

use ExtUtils::MakeMaker;
use File::Copy;
use Cwd;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
$DO_BODYSTRUCTURE	= eval "require 'Parse/RecDescent.pm'" ;
unless ($DO_BODYSTRUCTURE) {
	print 
		"*** NOTE ***\n\n",
		"Unable to find and load Parse::RecDescent.\n",
		"Mail::IMAPClient will be installed without support for\n",
		"the get_bodystructure method and without the \n",
		"Mail::IMAPClient::BodyStructure subclasses. \n\n",
		"If you need these subclasses, install Parse::RecDescent \nand ",
		"re-run Makefile.PL. \n\n";
}

&set_PRD_type if $DO_BODYSTRUCTURE;

WriteMakefile(
    'DIR'		=> [ 'MessageSet', $DO_BODYSTRUCTURE ? ( 'BodyStructure' , 'Thread' ) : ()  ],
    'NAME'		=> 'Mail::IMAPClient',
    'VERSION_FROM' 	=> 'IMAPClient.pm', # finds $VERSION
    'clean' 		=> {	FILES 	=> 'test.txt'	},
    'PREREQ_PM'		=> { 	
				'Errno'		=> 0,
				'IO::Socket' 	=> 0,
				'Fcntl'		=> 0,
				'IO::Select'	=> 0,
				'IO::File'	=> 0,
				'Data::Dumper'	=> 0,
				'Carp'		=> 0,
    },

);

=begin prereqs

The Mail::IMAPClient module uses the IO::Socket module to make a socket
connection to an IMAP server and the Socket module to get some constants.
It also uses Errno, Fcntl (for faster I/O) and IO::Select, IO::File, 
Data::Dumper, and Carp.

=end prereqs

=cut

&set_test_data;

sub set_test_data {
	unless (-f "./IMAPClient.pm") { warn "ERROR: not in installation directory\n"; return }
	return if -f "./test.txt";
	print 	"You have the option of running an extended suite of tests during\n",
		"'make test'. This requires an IMAP server name, user account, and ",
		"password to test with.","\n","\n",
		"Do you want to run the extended tests? (n/y) ==> ";
	my $yes = <STDIN>;
	return unless $yes =~ /^[Yy](?:[Ee]:[Ss]?)?$/ ;

	unless (open TST,">./test.txt") { warn "ERROR: couldn't open ./test.txt: $!\n"; return }

	my $server = "";
	until ($server ) {
		print "\nPlease provide the hostname or IP address of a host running an IMAP server \n",
			"(or QUIT to skip the extended tests) ==> ";
		$server = <STDIN>;
		chomp $server;
		return if $server =~ /^\s*quit\s*$/i ;
	}
	print TST "server=$server\n";

	my $user = "";
	until ($user) {
	print "\nPlease provide the username of an account\non $server (or QUIT) ==> ";
		$user = <STDIN>;
		chomp $user;
		return if $user =~ /^\s*quit\s*$/i ;
	}

	print TST "user=$user\n";
	my $passe = "";
	until ($passed) {
		print "\nPlease provide the password for $user\n(or QUIT) ==> ";
		$passed = <STDIN>;
		chomp $passed;
		return if $passed =~ /^\s+$|^quit$/i ;
	}

	print TST "passed=$passed\n";

	print "\nPlease provide the port to connect to on $server to run the test \n",
		"(default is 143) ==> ";
	my $port = <STDIN>;
	chomp $port;
	$port ||= 143; 
	print TST "port=$port\n";
	print "\nPlease provide the authentication mechanism to use on $server to run the test \n",
		"(default is 'LOGIN', which uses the plain text LOGIN command) ==> ";
	my $authmech = <STDIN>;
	chomp $authmech;
	$authmech ||= 'LOGIN'; 
	print TST "authmechanism=$authmech\n";
	close TST;
	print "\nGracias! The information you provided (including the \n",
		" password!) has been stored in ",cwd,"/test.txt and should be\n",
		" removed (either by hand or by 'make clean') after testing.\n";
}


sub set_PRD_type {

	my $g = <<'	EOG';

	start: thing(s)
		{ $return = \%item; }

	thing: /YES/ 
		{ $return = \%item; }

	EOG

	my $p = Parse::RecDescent->new($g);

	my $i = $p->start("YES YES");
	if ( exists($i->{'thing(s)'}) ) {
		print "Using new-style Parse::RecDescent grammars\n";
		copy("./Thread/Thread.grammar_new","./Thread/Thread.grammar");

		copy( 	"./BodyStructure/Parse/Parse.grammar_new",
			"./BodyStructure/Parse/Parse.grammar"
		);

	} elsif ($i->{'thing'}) {
		print "Using old-style Parse::RecDescent grammars\n";
		print "If you upgrade Parse::RecDescent then you will ",
		"have to re-run Makefile.PL and re-make and re-'make install'",
		"Mail::IMAPClient.\n";
		copy("./Thread/Thread.grammar_old","./Thread/Thread.grammar");
		copy( 	"./BodyStructure/Parse/Parse.grammar_old",
			"./BodyStructure/Parse/Parse.grammar"
		);
	} else {
		print "Unable to parse simple Parse::RecDescent code. ",
			"Skipping installation of advanced features.";
		$DO_BODYSTRUCTURE = 0;
	}
}
	

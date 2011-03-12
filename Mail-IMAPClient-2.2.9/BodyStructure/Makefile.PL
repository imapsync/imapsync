use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'DIR'		=> [ 'Parse' ] ,
    'NAME'		=> 'Mail::IMAPClient::BodyStructure',
    'VERSION_FROM'	=> '../IMAPClient.pm', # finds $VERSION
    'PREREQ_PM'		=> {
			"Parse::RecDescent" 	=> '1.94',
			"Exporter" 		=> 0,
    }, 				
);

use ExtUtils::MakeMaker;
use Parse::RecDescent;

unlink "./Parse.pm" if -f "./Parse.pm";
sub MY::top_targets {
	package MY;

	my $inherit = shift->SUPER::top_targets(@_);
	my @inherit = split("\n",$inherit);
	for (@inherit) {
		if ( /^\s*all\s*:{1,2}/  ) {
			s/(all\s*:{1,2}\s*)/$1Parse\.pm /;
		}
	}
	return join("\n",@inherit);
}

sub MY::clean {
	package MY;

	my $inherit = shift->SUPER::clean(@_);
	return join("\n",$inherit,"	rm Parse.pm") ;
}

sub MY::postamble {
	my $string = 
		'@$(PERL) "-MParse::RecDescent" "-" ' .
		'"Parse.grammar" '. 
		'"Mail::IMAPClient::BodyStructure::Parse"' ;
	return "Parse.pm: Parse.grammar\n\t$string\n\n";
}

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
#print "",MY->top_target;

WriteMakefile(
    'NAME'		=> 'Mail::IMAPClient::Parse',
    'VERSION_FROM'	=> '../../IMAPClient.pm', 		
    'PREREQ_PM'		=> {"Parse::RecDescent" => 0 }, 
    'PM'		=> {
		'Parse.pm' => 
		'$(INST_LIBDIR)/BodyStructure/Parse.pm' 
   	},
);


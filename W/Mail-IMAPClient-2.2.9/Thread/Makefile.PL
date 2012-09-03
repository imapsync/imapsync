use ExtUtils::MakeMaker;
use Parse::RecDescent;
unlink './Thread.pm' if -f './Thread.pm';
sub MY::top_targets {
	package MY;

	my $inherit = shift->SUPER::top_targets(@_);
	my @inherit = split("\n",$inherit);
	for (@inherit) {
		if ( /^\s*all\s*:{1,2}/  ) {
			s/(all\s*:{1,2}\s*)/$1Thread\.pm /;
		}
	}
	return join("\n",@inherit);
}

sub MY::clean {
	package MY;

	my $inherit = shift->SUPER::clean(@_);
	return join("\n",$inherit,"	rm Thread.pm") ;
}

sub MY::postamble {
	my $string = 
		'@$(PERL) "-MParse::RecDescent" "-" ' .
		'"Thread.grammar" '. 
		'"Mail::IMAPClient::Thread"' ;
	return "Thread.pm: Thread.grammar\n\t$string\n\n";
}

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
#print "",MY->top_target;

WriteMakefile(
    'NAME'		=> 'Mail::IMAPClient::Thread',
    'VERSION_FROM'	=> '../IMAPClient.pm', 		
    'PREREQ_PM'		=> {"Parse::RecDescent" => 0 }, 
    'PM'		=> {
		'Thread.pm' => 
		'$(INST_LIBDIR)/Thread.pm' 
   	},
);


# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'
# $Id: basic.t,v 19991216.27 2003/06/12 21:38:35 dkernen Exp $
######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .

END {print "not ok 1\n" unless $main::loaded;}
use Mail::IMAPClient;

######################### End of black magic.


my $test = 0;
my %parms;
my $imap;
my @tests;
my $uid;
$fast||=0;
$range||=0;
$uidplus||=0;
$authmech||=0;
use vars qw/*TMP $imap/;

BEGIN {
	$^W++;
	# $ARGV[0]||=1;
	my $target; my $sep; my $target2;

	push @tests, sub { $test++ } ; # Dummy test 1
	push @tests, sub {	# 2
		if (ref($imap)) {
			print "ok ",++$test,"\n"; # ok 2
		} else {	
			print "not ok ",++$test,"\n";
			print STDERR "\nTest $test failed:\n$@\n";
		}
	};

	push @tests, sub {	# 3
		if ($sep = $imap->separator) {
			print "ok ",++$test,"\n"; # ok 3
		} else {	
			print "not ok ",++$test,"\n";
			print STDERR "\nTest $test failed:\n$@\n";
		}
	};

	push @tests, sub {	# 4
		my $isparent;
		$isparent = $imap->is_parent(INBOX);
		if (defined($isparent)) {
			$target = "INBOX${sep}IMAPClient_$$";
			$target2 = "INBOX${sep}IMAPClient_2_$$";
			print "ok ",++$test,"\n"; # ok 4
		} else {	
			$target = "IMAPClient_$$";
			$target2 = "IMAPClient_2_$$";
			print "ok ",++$test,"\n"; # ok 4
		}
		# print "target is $target\n";
	};

	
	push @tests, sub {	# 5
		if ( eval { $imap->select('inbox') } ) {
			print "ok ",++$test,"\n"; # ok 5
		} else {	
			print "not ok ",++$test,"\n";
			print STDERR "\nTest $test failed:\n$@\n";
			# print $imap->History,"\n";
		}
	};

	push @tests, sub {	# 6
		if ( eval { $imap->create("$target") } ) {
			print "ok ",++$test,"\n"; # ok 6
		} else {
			print "not ok ",++$test,"\n";
			print STDERR "\nTest $test failed:\n$@\n";
		}
	};
	push @tests, 
		sub { return "dummy test 8" },
		sub { return "dummy test 9" };

	push @tests, sub {	# 7,8,9
		if (defined($imap->is_parent($target))) {	#7 
			if ( eval { $imap->create(qq($target${sep}has "quotes")) } ) {
				print "ok ",++$test,"\n";	# ok 7
			} else {
                          if ($imap->LastError =~ /NO Invalid.*name/) {
                                print "ok ",++$test,	
				 " $parms{server} doesn't support quotes in folder names--",
				 "skipping next 2 tests\n";	# ok 7
                                print "ok ", ++$test," (skipped)\n"; # ok 8
                                print "ok ", ++$test," (skipped)\n"; # ok 9
                                return;
                          } else {
                                print "not ok ",++$test,"\n";
				print STDERR "\nTest $test failed:\n$@\n";
                                print "ok ", ++$test," (skipped)\n"; # ok 8
                                print "ok ", ++$test," (skipped)\n"; # ok 9
				return;
                          }

			}
			if ( eval { $imap->select(qq($target${sep}has "quotes")) } ) { #8
				print "ok ",++$test,"\n"; # ok 8
			} else {
				print "not ok ",++$test,"\n";
				print STDERR "\nTest $test failed:\n$@\n";
			}
			$imap->close;
			$imap->select('inbox');
			if ( eval { $imap->delete(qq($target${sep}has "quotes")) } ) { #9
				print "ok ",++$test,"\n"; # ok 9
			} else {
				print "not ok ",++$test,"\n";
				print STDERR "\nTest $test failed:\n$@\n";
			}
		} else { 
			print "ok ",++$test,"\n"; # ok 7
			print "ok ",++$test,"\n"; # ok 8
			print "ok ",++$test,"\n"; # ok 9
		}
	};

	push @tests, sub {	# 10
		# print $db $imap->Report;
		if ( eval { $imap->exists("$target") } ) {
			print "ok ",++$test,"\n";
		} else {	
			print "not ok ",++$test,"\n";
			print STDERR "\nTest $test failed:\n$@\n";
		}
	};

	push @tests, 	sub {	# 11
		if ( eval { $imap->create($target2) } ) {
			print "ok ",++$test,"\n";
		} else {	
			print "not ok ",++$test,"\n";
			print STDERR "\nTest $test failed:\n$@\n";
		}
	}, 		sub {	# 12
		if ( eval { $imap->exists($target2) } ) {
			print "ok ",++$test,"\n";
		} else {	
			print "not ok ",++$test,"\n";
			print STDERR "\nTest $test failed:\n$@\n";
		}
	};
			
	push @tests, sub {	# 13
		if ( eval { $uid = $imap->append("$target",&testmsg)} ) {
			print "ok ",++$test,"\n";
		} else {	
			print "not ok ",++$test,"\n";
			print STDERR "\nTest $test failed:\n$@\n";
		}
	};

	push @tests, sub {	# 14
		if ( eval { $imap->select("$target") } ) {
			print "ok ",++$test,"\n";
		} else {	
			print "not ok ",++$test,"\n";
			print STDERR "\nTest $test failed:\n$@\n";
		}
	};
	{
	my $size; my $string; my $target; 
	my $file = "./test_message_to_file";
	push @tests, sub {	# 15, 16, 17, 18, 19
		$target = ref($uid) ? ($imap->search("ALL"))[0] : $uid;
		if ( eval { $size = $imap->size($target) } ) { # 15  test size
			print "ok ",++$test,"\n"; #15
		} else {	
			print "not ok ",++$test,"\n";
			print STDERR "\nTest $test failed:\n$@\n";
		} 
 	}, sub {
		if ( eval { $string = $imap->message_string($target) } ) { # 16  test message_string
			print "ok ",++$test,"\n"; #16
		} else {	
			print "not ok ",++$test,"\n";
			print STDERR "\nTest $test failed:\n$@\n";
		}
	}, sub {
		if ( $size == length($string) ) {	# 17 test size = length of string
			print "ok ",++$test,"\n"; #17
		} else {	
			print "not ok ",++$test,"\n";
			print STDERR "\nTest $test failed:\n$@\n";
		}
	};
	push @tests, sub {
		eval { $imap->message_to_file($file,$target)};
		if ( $@ ) {					# 18 test message_to_file success
			print "not ok ",++$test,"\n";	
			print STDERR "\nTest $test failed:\n$@\n";
		} else {
			print "ok ",++$test,"\n";	#18	
		}
	};
	push @tests, sub {
		my $array_ref = "";				# 19 test for proper search failure
		eval { $array_ref = $imap->search("HEADER","Message-id","NOT_A_MESSAGE_ID")};
		if ( $array_ref ) {			# should have returned undef
			print "not ok ",++$test,"(arrayref=$array_ref)\n";
			print STDERR "\nTest $test failed:\n$@\n";
		} else {
			print "ok ",++$test,"\n";	#19
		}
	};
	push @tests, sub {
		if ( -s $file == $size ) {			# 20 test message_to_file size
			print "ok ",++$test,"\n";	#20
		} else {
			print "not ok ",++$test,"\n";	#20
			print STDERR "\nTest $test failed:\n$@\n";
		}
		unlink "$file" or warn "$! unlinking $file\n";
	};
	}						# wrap up closure

	push @tests, sub {	# 21, 22, 23, 24, 25 26, 27
		my @unseen; my @seen;
		if ( eval { @seen = $imap->seen } ) { # 21	test seen's success
			print "ok ",++$test,"\n"; #21
		} else {	
			print "not ok ",++$test,"\n";
			print STDERR "\nTest $test failed:\n$@\n";
		}
		if ( @seen == 1 ) 			{ # 22	test seen's results
			print "ok ",++$test,"\n"; #22
		} else {
			print "not ok ",++$test,"\n";
			print STDERR "\nTest $test failed:\n$@\n";
		}
		
		if ( eval { $imap->deny_seeing(\@seen) } ) { # 23 test deny_seeing's success
			print "ok ",++$test,"\n"; #23
		} else {	
			print "not ok ",++$test,"\n";
			print STDERR "\nTest $test failed:\n$@\n";
		}
		if ( eval { @unseen = $imap->unseen } ) { # 24 test unseen's success
			print "ok ",++$test,"\n"; #24
		} else {	
			print "not ok ",++$test,"\n";
			print STDERR "\nTest $test failed:\n$@\n";
		}

		if ( @unseen == 1 ) 		    { # 25 test deny_seeing's and unseen's results
			print "ok ",++$test,"\n"; #25
		} else {
			print "not ok ",++$test,"\n";
			print STDERR "\nTest $test failed:\n$@\n";
		}
		if ( eval { $imap->see(\@seen) } ) { # 26 test see's success
			print "ok ",++$test,"\n"; #26
		} else {	
			print "not ok ",++$test,"\n";
			print STDERR "\nTest $test failed:\n$@\n";
		}
		if ( @seen == 1 ) 			{ # 27 test seen's and see's success
			print "ok ",++$test,"\n"; #27
		} else {
			print "not ok ",++$test,"\n";
			print STDERR "\nTest $test failed:\n$@\n";
		}
		eval { $imap->deny_seeing(@seen)  };
		my $subject;
		eval { $imap->Peek(1) };
		eval { $subject = $imap->parse_headers($seen[0],"Subject")->{Subject}[0] };
		if ( join("",$imap->flags($seen[0])) =~ /\\Seen/i ) { 	# 28 test "Peek = 1"
			print "not ok ",++$test,"\n";	
			print STDERR "\nTest $test failed:\n$@\n";
		} 	else {
			print "ok ",++$test,"\n";	#28	
		}
		eval { $imap->deny_seeing(@seen)  };
		eval { $imap->Peek(0) };
		eval { $subject = $imap->parse_headers($seen[0],"Subject")->{Subject}[0] };
		if ( join("",$imap->flags($seen[0])) =~ /\\Seen/i ) { 	# 29 test "Peek = 0"
			print "ok ",++$test,"\n";	#29	
		}	else {
			print "not ok ",++$test,"\n";	
			print STDERR "\nTest $test failed:\n$@\n";
		}
		eval { $imap->deny_seeing(@seen)  };
		eval { $imap->Peek(undef) };
		eval { $subject = $imap->parse_headers($seen[0],"Subject")->{Subject}[0] };
		if ( join("",$imap->flags($seen[0])) =~ /\\Seen/i ) { 	# 30 test "Peek = undef"
			print "not ok ",++$test,"\n";	
			print STDERR "\nTest $test failed:\n$@\n";
		}	else {
			print "ok ",++$test,"\n";	#30
		}
		
		
	};
	# Add dummy tests to come up to right number of test routines:
	push @tests, 	sub { 22 }, sub { 23 } , sub { 24 }, sub { 25 }, sub { 26 }, sub {27},
			sub {28}, sub {29}, sub {30};

	push @tests, sub {	# 31
		if ( eval { my $uid2 = $imap->copy($target2,1)} ) {
			print "ok ",++$test,"\n"; #31 
		} else {	
			print "not ok ",++$test,"\n";
			print STDERR "\nTest $test failed:\n$@\n";
		}
	};

	
	push @tests, sub {	# 32
		my @res;
		if ( eval { @res = $imap->fetch(1,"RFC822.TEXT") } ) {
			print "ok ",++$test,"\n"; #32
		} else {	
			print "not ok ",++$test,"\n";
			print STDERR "\nTest $test failed:\n$@\n";
		}
	};

	push @tests, sub {	# 33
		my $h;
		if ( eval {  $h = $imap->parse_headers(1,"Subject")  
			and $h->{Subject}[0] =~ /^Testing from pid/o } ) {
			print "ok ",++$test,"\n"; 	#33
		} else {	
			 use Data::Dumper;
			print Dumper($h);
			print "$h->{Subject}[0] \n";
			print "not ok ",++$test,"\n";
			print STDERR "\nTest $test failed:\n$@\n";
		 	print $imap->Results;
		}
	};

	my @hits = ();
	push @tests, sub {	# 34
		$imap->select("$target");
		eval { @hits = $imap->search('SUBJECT','Testing') } ;
		if ( scalar(@hits) == 1 ) {
			print "ok ",++$test,"\n"; #34
		} else {	
			print "not ok ",++$test,"\n"; #34
			print STDERR "\nTest $test failed:\n$@\n";
			print "Found ",scalar(@hits), 
			  " hits (",join(", ",@hits),")-- expected 2\n";
		}
	};

	push @tests, sub {	# 35, 36
		if ( $imap->delete_message(@hits) ) {
			print "ok ",++$test,"\n"; #35
			my $flaghash = $imap->flags(\@hits);
			my $flagflag = 0;
			foreach my $v ( values %$flaghash ) { 
				foreach my $f (@$v) { $flagflag++ if $f =~ /\\Deleted/}
			}
			if ( $flagflag == scalar(@hits) ) {
				print "ok ", ++$test,"\n"; #36
			} else {
				print "not ok ", ++$test,"\n";
				print STDERR "\nTest $test failed:\n$@\n";
			}
		} else {	
			print "not ok ",++$test,"\n"; #35
			print STDERR "\nTest $test failed:\n$@\n";
			print "not ok ",++$test,"\n"; #36
		}
	}, sub { return "Dummy test 35"} ;

	push @tests, sub {	# 37
	  eval { 
		my @nohits = $imap->search(qq(SUBJECT "Productioning")) ;
		unless ( scalar(@nohits)  ) {
			print "ok ",++$test,"\n"; #37
		} else {	
			print "not ok ",++$test," (",scalar(@nohits),")\n";
			print STDERR "\nTest $test failed:\n$@\n";
		}
	  };
	};

	push @tests, sub {	# 38, 39
		if ( $imap->restore_message(@hits) ) {
			print "ok ",++$test,"\n"; #38
			my $flaghash = $imap->flags(\@hits);
			my $flagflag = scalar(@hits);
			foreach my $v ( values %$flaghash ) { 
				foreach my $f (@$v) { $flagflag-- if $f =~ /\\Deleted/}
			}
			if ( $flagflag == scalar(@hits) ) {
				print "ok ", ++$test,"\n"; #39
			} else {
				print "not ok ", ++$test,"\n";
				print STDERR "\nTest $test failed:\n$@\n";
			}
		} else {	
			print "not ok ",++$test,"\n"; #38
			print STDERR "\nTest $test failed:\n$@\n";
			print "not ok ",++$test,"\n"; #39
		}
	}, sub { $imap->delete_message(@hits) } ;	# dummy 39
	push @tests, sub {	# 40
		$imap->select($target2);
		if ( 	$imap->delete_message(scalar($imap->search("ALL"))) 
			and $imap->close and 
			$imap->delete($target2) 
		) {
			print "ok ",++$test,"\n"; #40
			
		} else {	
			print "not ok ",++$test,"\n";
			print STDERR "\nTest $test failed:\n$@\n";
			print $imap->Report;
		}
	};
	push @tests, sub { # 41
		eval { 
			$imap->select("INBOX");
			$@ = ""; # clear $@
			@hits = $imap->search(	"BEFORE",
						Mail::IMAPClient::Rfc2060_date(time),
						"UNDELETED"
			) ;
			
		} ;
		if ($@ ) {
			$@ =~ s/\r\n$//;
			print "not ok ",++$test, " ($@)\n";
			print STDERR "\nTest $test failed:\n$@\n";
		} else {
			print "ok ",++$test,"\n"; #41
		}
	};
	# Test migrate method
	{ # start new scope for these tests
	my($im2,$migtarget);
	push @tests, sub { # 42
	 eval { 
		
		$im2 = Mail::IMAPClient->new(
                	Server  => "$parms{server}"||"localhost",
                	Port    => "$parms{port}"  || '143',
                	User    => "$parms{user}"  || scalar(getpwuid($<)),
                	( $authmech ? ( Authmechanism  => $authmech) : 
				( $parms{authmechanism} eq "LOGIN" ? () : 
				  ( Authmechanism => $parms{authmechanism}||undef ) )
			),
                	Password=> "$parms{passed}"|| scalar(getpwuid($<)),
                	Clear   => 0,
                	Timeout => 30,
                	Debug   => $ARGV[0],
                	Debug_fh   => ($ARGV[0]?IO::File->new(">./imap2.debug"):undef),
                	Fast_IO => $fast,
                	Uid     => $uidplus,
		)       or
        	print STDERR 	"\nCannot log into $parms{server} as $parms{user}. ",
				"Are server/user/password correct?\n"
        	and die ;
		my $source = $target;
		$imap->select($source) or die "cannot select source $source: $@";
		for (1...5) { $imap->append($source,&testmsg)};
		$imap->close; $imap->select($source);
		$migtarget = "${target}_mirror";
		$im2->create($migtarget) or die "can't create $migtarget: $@" ;
		$im2->select($migtarget) or die "can't select $migtarget: $@";
		$imap->migrate($im2,scalar($imap->search("ALL")),$migtarget) 
			or die "couldn't migrate: $@";
		$im2->close; $im2->select($migtarget) or die "can't select $migtarget: $@";
	 } ;
	 if ( $@ ) {
			$@=~s/\r\n$//;
			print "not ok ",++$test," ($@)\n";	
			print STDERR "\nTest $test failed:\n$@\n";
	 } else {
			print "ok ",++$test,"\n";	#42
	 }
	},	# 43
	sub {
	 my($total_bytes1,$total_bytes2) ;
	 eval {
		for ($imap->search("ALL")) { my $s = $imap->size($_); $total_bytes1 += $s; print "Size of msg $_ is $s\n" if $ARGV[0]};
		for ( $im2->search("ALL")) { my $s =  $im2->size($_); $total_bytes2 += $s; print "Size of msg $_ is $s\n" if $ARGV[0]};
	 };
	 for ($total_bytes1,$total_bytes2) { $_||=0};
	 if ($@) { 
		$@=~s/\r\n$//;
		print "not ok ",++$test," ($@)\n";
		print STDERR "\nTest $test failed:\n$@\n";
	 } elsif ( $total_bytes1 != $total_bytes2 ) {
		print "not ok ",++$test," (source has $total_bytes1 bytes and ",
			"target has $total_bytes2)\n";
		print STDERR "\nTest $test failed:\n$@\n";
	 } else {
		print "ok ",++$test,"\n"; #43
		$im2->select($migtarget);
		$im2->delete_message(@{$im2->messages}) if $im2->message_count;
		$im2->close;
	 	$im2->delete($migtarget);
	 }
	 $im2->logout;
	};	# end of the anonysub and push	
	} # end of migrate method tests' scope

	push @tests, sub { 	# 44
		if ( $imap->has_capability("IDLE") ) {
		   eval {
			my $idle = $imap->idle;
			sleep 1;
			$imap->done($idle);
		   } ;
		   if ($@) {
			print "not ok ",++$test,"\n$@\n";
		   } else {
			print "ok ",++$test,"\n";	#44
		   }
		} else {
			print "ok (skipped)",++$test,"\n";
		}
	};
	push @tests, sub {	# 45
		$imap->select('inbox');
		if ( $imap->rename($target,"${target}NEW") ) {

			print "ok ",++$test,"\n"; #45
			$imap->close;
			$imap->select("${target}NEW") ;
			$imap->delete_message(@{$imap->messages}) if $imap->message_count;
			$imap->close;
			$imap->delete("${target}NEW") ;
			
		} else {	

			print "not ok ",++$test,"\n";
			print STDERR "\nTest $test failed:\n$@\n";
			$imap->delete_message(@{$imap->messages}) 
				if $imap->message_count;
			$imap->close;
			$imap->delete("$target") ;
		}
	} ;
		#push @tests,  sub { "commented out #46" } ; 	


	if (open TST,"./test.txt" ) {
	while (defined(my $l = <TST>)) {
		chomp $l;
		my($p,$v)=split(/=/,$l);
		for($p,$v) { s/(?:^\s+)|(?:\s+$)//g; }
		$parms{$p}=$v if $v;
	}
	close TST;
	}

	if ( 	-f 	"./test.txt" 
		and	%parms
		and 	length 	$parms{server}
		and 	length 	$parms{user}
		and 	length 	$parms{passed} 
	) { 
		print "1..${\(scalar @tests)}\n";  # update here if adding test to existing sub
	} else {		
		print "1..1\n"; 	
	}	

	$main::loaded = 1;
	print "ok 1\n";
	$| = 1; 
	unless ( -f "./test.txt" ) { exit;}

}

=begin debugging

$db = IO::File->new(">/tmp/de.bug");
local *TMP = $db ;
open(STDERR,">&TMP");
select(((select($db),$|=1))[0]);

=end debugging

=cut

exit unless		%parms 
	and 	length 	$parms{server}
	and 	length 	$parms{user}
	and 	length 	$parms{passed} ;

# print "Uid=$uidplus and Fast = $fast\n";

eval { $imap = Mail::IMAPClient->new( 
		Server 	=> "$parms{server}"||"localhost",
		Port 	=> "$parms{port}"  || '143',
		User 	=> "$parms{user}"  || scalar(getpwuid($<)),
                ( $authmech ? ( Authmechanism  => $authmech) : 
			( $parms{authmechanism}&&$parms{authmechanism} eq "LOGIN" ? () : 
			  ( Authmechanism => $parms{authmechanism}||undef) )
		),
		Password=> "$parms{passed}"|| scalar(getpwuid($<)),
		Clear   => 0,
		Timeout => 30,
		Debug   => $ARGV[0],
		Debug_fh   => ($ARGV[0]?IO::File->new(">imap1.debug"):undef),
		Fast_IO => $fast,
		Uid 	=> $uidplus,
		Range 	=> $range,
) 	or 
	print STDERR "\nCannot log into $parms{server} as $parms{user}. Are server/user/password correct?\n" 
	and exit
} ;

$imap->Debug_fh and $imap->Debug_fh->autoflush();
for my $test (@tests) { $test->(); }
#print $db $imap->Report,"\n";

sub testmsg {
		my $m = qq{Date:  @{[$imap->Rfc822_date(time)]}
To: <$parms{user}\@$parms{server}>
From: Perl <$parms{user}\@$parms{server}>
Subject: Testing from pid $$

This is a test message generated by $0 during a 'make test' as part of the installation of
that nifty Mail::IMAPClient module from CPAN. Like all things perl, it's 
way cool.

};

	return $m;
}

# History:
# $Log: basic.t,v $
# Revision 19991216.27  2003/06/12 21:38:35  dkernen
#
# Preparing 2.2.8
# Added Files: COPYRIGHT
# Modified Files: Parse.grammar
# Added Files: Makefile.old
# 	Makefile.PL Todo sample.perldb
# 	BodyStructure.pm
# 	Parse.grammar Parse.pod
#  	range.t
#  	Thread.grammar
#  	draft-crispin-imapv-17.txt rfc1731.txt rfc2060.txt rfc2062.txt
#  	rfc2221.txt rfc2359.txt rfc2683.txt
#
# Revision 19991216.26  2002/12/13 18:08:50  dkernen
# Made changes for version 2.2.6 (see Changes file for more info)
#
# Revision 19991216.25  2002/11/08 15:49:05  dkernen
#
# Modified Files: Changes
# 		IMAPClient.pm
# 		MessageSet.pm
# 	 	t/basic.t
#
# Revision 19991216.24  2002/10/23 20:46:09  dkernen
#
# Modified Files: Changes IMAPClient.pm MANIFEST Makefile.PL
# Added Files: Makefile.PL MessageSet.pm
# Added Files: range.t
# Modified Files: basic.t
#
# Revision 19991216.23  2002/09/26 17:56:58  dkernen
#
# Modified Files:
# BUG_REPORTS Changes IMAPClient.pm INSTALL_perl5.80 MANIFEST
# Makefile.PL for version 2.2.3. See the Changes file for details.
# Modified Files: BodyStructure.pm -- cosmetic changes to pod doc
# Modified Files:
# 	migrate_mail2.pl -- fixed a small little bug and added a feature
# Modified Files: basic.t -- to add tests for idle/done
#
# Revision 19991216.22  2002/08/30 20:48:52  dkernen
#
# #
# Modified Files:
# 	Changes IMAPClient.pm MANIFEST Makefile Makefile.PL README
# 	Todo test.txt
# 	BodyStructure/Parse/Makefile
# 	BodyStructure/Parse/Parse.pm
# 	BodyStructure/Parse/Parse.pod
# 	BodyStructure/Parse/t/parse.t
# 	t/basic.t
# for version 2.2.1
# #
#
# Revision 19991216.21  2002/08/23 13:29:59  dkernen
#
# Modified Files: Changes IMAPClient.pm INSTALL MANIFEST Makefile Makefile.PL README Todo test.txt
# Made changes to create version 2.1.6.
# Modified Files:
# imap_to_mbox.pl populate_mailbox.pl
# Added Files:
# cleanTest.pl migrate_mbox.pl
# Modified Files: basic.t
#
# Revision 19991216.20  2001/02/07 20:20:43  dkernen
#
# Modified Files: Changes IMAPClient.pm MANIFEST Makefile test.txt  -- up to version 2.1.0
# Added Files: cyrus_expunge.pl -- a new example script
# Modified Files:  	basic.t -- to close folders before trying to delete them
# Added Files: 		uidfast.t -- a new test suite
#
# Revision 19991216.19  2001/01/09 19:24:37  dkernen
#
# Modified Files:
# 	Changes IMAPClient.pm Makefile test.txt  -- to add Phil Lobbe's patch.
#
# Revision 19991216.18  2000/12/20 19:37:02  dkernen
#
# ---------------------------------------------------------------------------------
# Modified Files: IMAPClient.pm -- added bug fix to I/O engine, also cleaned up doc
# 		Changes	      -- documented same
# ---------------------------------------------------------------------------------
#
# Revision 19991216.17  2000/11/10 22:08:15  dkernen
#
# Modified Files: Changes IMAPClient.pm Makefile t/basic.t -- to add Peek parm and to make several bug fixes
#
# Revision 19991216.16  2000/10/30 21:04:11  dkernen
#
# Modified Files: Changes IMAPClient.pm  -- to update documentation
# Modified Files: basic.t -- added tests for message_to_string.
#
# Revision 19991216.15  2000/10/30 18:40:50  dkernen
#
# Modified Files: Changes IMAPClient.pm INSTALL MANIFEST Makefile README test.txt  -- for 2.0.1
# Added Files:
# 	rfc1731.txt rfc1732.txt rfc1733.txt rfc2061.txt rfc2062.txt
# 	rfc2086.txt rfc2087.txt rfc2088.txt rfc2177.txt rfc2180.txt
# 	rfc2192.txt rfc2193.txt rfc2195.txt rfc2221.txt rfc2222.txt
# 	rfc2234.txt rfc2245.txt rfc2342.txt rfc2359.txt rfc2683.txt
#
# Revision 19991216.14  2000/10/27 14:43:59  dkernen
#
# Modified Files: Changes IMAPClient.pm Todo -- major rewrite of I/O et al.
# Modified Files: basic.t fast_io.t uidplus.t -- more tests in basic.t. Other
# tests just "do basic.t" with different options set.
#
# Revision 19991216.13  2000/07/10 20:54:19  dkernen
#
# Modified Files: Changes IMAPClient.pm MANIFEST Makefile README
# Modified Files: find_dup_msgs.pl
# : Modified Files: basic.t fast_io.t
#
# Revision 19991216.12  2000/06/23 19:08:40  dkernen
#
# Modified Files:
# 	Changes IMAPClient.pm Makefile test.txt  -- for v1.16
# Modified Files: basic.t  -- to remove uidplus tests and to make copy test copy to different folder
# Added Files: 	uidplus.t -- moved all uidplus tests here
#
# Revision 19991216.11  2000/06/21 21:07:44  dkernen
#
# Modified Files: Changes IMAPClient.pm Makefile
# Modified Files: basic.t
#
# Revision 19991216.10  2000/04/27 18:00:15  dkernen
# Modified Files: basic.t
#
# Revision 19991216.9  2000/03/10 16:04:39  dkernen
#
# Renamed .test file to test.txt to support weird platforms that don't support filenames
# beginning with a dot.
#
# Modified Files: Changes INSTALL MANIFEST Makefile Makefile.PL
#
# Added Files: test.txt test_template.txt
#
# Removed Files: .test .test_template Makefile.old
#
# Revision 19991216.8  2000/03/02 19:59:15  dkernen
#
# Modified Files: build_ldif.pl -- to support new option to all "To:" and "Cc:" to be included in ldif file
# Modified Files: basic.t -- to work better with UW IMAP server
#
# Revision 19991216.7  2000/01/12 18:58:05  dkernen
# *** empty log message ***
#
# Revision 19991216.6  1999/12/28 13:57:22  dkernen
# tested with v1.08
#
# Revision 19991216.5  1999/12/16 17:19:17  dkernen
# Bring up to same level
#
# Revision 19991124.7  1999/12/16 17:14:27  dkernen
# Incorporate changes for exists method performance enhancement
#
# Revision 19991124.6  1999/12/01 22:11:06  dkernen
# Enhance support for UID and add tests to t/basic for same
#
# Revision 19991124.5  1999/11/30 20:41:55  dkernen
# Bring CVS repository up to latest level
#
# Revision 19991124.4  1999/11/24 19:58:45  dkernen
#
# Modified Files:
# basic.t  - to add $Id and $Log data in comments
#

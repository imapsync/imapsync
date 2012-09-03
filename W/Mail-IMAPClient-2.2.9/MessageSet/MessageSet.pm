package Mail::IMAPClient::MessageSet;
#$Id: MessageSet.pm,v 1.3 2002/12/13 18:08:49 dkernen Exp $

=head1 NAME

Mail::IMAPClient::MessageSet -- an extension to Mail::IMAPClient that
expresses lists of message sequence numbers or message UID's in the shortest
way permissable by RFC2060.

=cut

sub str { 
	# print "Overloaded ", overload::StrVal(${$_[0]}),"\n";
	return overload::StrVal(${$_[0]}); 
}
sub rem {
	my $self = shift;
	my $minus = ref($self)->new(@_);
	my %deleted = map { $_ => 1 } @{$minus->unfold} ;
	${$self} = $self->range(
		map { exists $deleted{$_} ? () : $_ } @{$self->unfold}
	);
	return $self;	
}
sub cat {
	my $self = shift;
	my @a = ("$self",@_);
	${$self} = $self->range(@a);
	return $self;	
}
use overload 	qq/""/ => "str" ,
		qq/.=/=>"cat", 
		qq/+=/=>"cat", 
		qq/-=/=>"rem", 
		q/@{}/=>"unfold", 
		fallback => "TRUE";

sub new {
	my $class = shift;
	my $range = $class->range(@_);
	my $object = \$range;
	bless $object, $class;
	return $object ;	
}

sub range {
	my $class = shift;	
	if ( 	scalar(@_) == 1 and 
		ref($_[0]) =~ /Mail::IMAPClient::MessageSet/
	) {
		return $_[0] ;
	}

	my @msgs = ();
	for my $m (@_) {
		next if !defined($m) or $m eq "";
		if ( ref($m) ) {
		   foreach my $mm (@$m) {
			foreach my $c ( split(/,/,$mm) ) {
			 	if ( $c =~ /:/ ) {
					my($l,$h) = split(/:/,$c) ;
					push @msgs,$l .. $h ;
				} else {
					push @msgs,$c;
				}
			}
		   }
		} else {
			#print STDERR "m=$m\n";
			foreach my $c ( split(/,/,$m) ) {
			 	if ( $c =~ /:/ ) {
					my($l,$h) = split(/:/,$c) ;
					push @msgs,$l .. $h ;
				} else {
					push @msgs,$c;
				}
			}
		}
	} 
	return undef unless @msgs;
	my @range = ();
	my $high = $low = "";
	for my $m (sort {$a<=>$b} @msgs) {
		$low = $m if $low eq "";
		next if $high ne "" and $high == $m ; # been here, done this
		if ( $high eq "" ) { 
			$high = $m ;
		} elsif ( $m == $high + 1 ) {
			$high = $m ;
		} else {
			push @range, $low == $high ? "$low," : "$low:$high," ;
			$low = $m ;
			$high = $m ;
		}
	}
	push @range, $low == $high ? "$low" : "$low:$high" ;
	my $range = join("",@range);
	return $range;
}

sub unfold {
	my $self = $_[0];
	return wantarray ? 
		(	map { my($l,$h)= split(/:/,$_) ; $h?($l..$h):$l }
			split(/,/,$$self) 	
		) : 
		[	map { my($l,$h)= split(/:/,$_) ; $h?($l..$h):$l }
			split(/,/,$$self) 	
		]
	;
}

=head2 DESCRIPTION

The B<Mail::IMAPClient::MessageSet> module is designed to make life easier
for programmers who need to manipulate potentially large sets of IMAP
message UID's or sequence numbers.

This module presents an object-oriented interface into handling your message
sets. The object reference returned by the L<new> method is an overloaded 
reference to a scalar variable that contains the message set's compact
RFC2060 representation. The object is overloaded so that using it like a string
returns this compact message set representation. You can also add messages to
the set (using either a '.=' operator or a '+=' operator) or remove messages
(with the '-=' operator). And if you use it as an array reference, it will 
humor you and act like one by calling L<unfold> for you. (But you need perl 5.6
or above to do this.)

RFC2060 specifies that multiple messages can be provided to certain IMAP
commands by separating them with commas. For example, "1,2,3,4,5" would 
specify messages 1, 2, 3, 4, and (you guessed it!) 5. However, if you are
performing an operation on lots of messages, this string can get quite long.
So long that it may slow down your transaction, and perhaps even cause the
server to reject it. So RFC2060 also permits you to specifiy a range of
messages, so that messages 1, 2, 3, 4 and 5 can also be specified as
"1:5". 

This is where B<Mail::IMAPClient::MessageSet> comes in. It will convert your
message set into the shortest correct syntax. This could potentially save you 
tons of network I/O, as in the case where you want to fetch the flags for
all messages in a 10000 message folder, where the messages are all numbered
sequentially. Delimited as commas, and making the best-case assumption that 
the first message is message "1", it would take 48893 bytes to specify the 
whole message set using the comma-delimited method. To specify it as a range, 
it takes just seven bytes (1:10000). 

=head2 SYNOPSIS

To illustrate, let's take the trivial example of a search that returns these
message uids: 1,3,4,5,6,9,10, as follows:
	
	@msgs = $imap->search("SUBJECT","Virus"); # returns 1,3,4,5,6,9,10
	my $msgset = Mail::IMAPClient::MessageSet->new(@msgs);
	print "$msgset\n";  # prints "1,3:6,9:10\n"
	# add message 14 to the set:
	$msgset += 14;	
	print "$msgset\n";  # prints "1,3:6,9:10,14\n"
	# add messages 16,17,18,19, and 20 to the set:
	$msgset .= "16,17,18:20";	
	print "$msgset\n";  # prints "1,3:6,9:10,14,16:20\n"
	# Hey, I didn't really want message 17 in there; let's take it out:
	$msgset -= 17;
	print "$msgset\n";  # prints "1,3:6,9:10,14,16,18:20\n"
	# Now let's iterate over each message:
	for my $msg (@$msgset) {
		print "$msg\n";
	}       # Prints: "1\n3\n4\n5\n6\n9\n10\n14\n16\n18\n19\n20"

(Note that the L<Mail::IMAPClient> B<Range> method can be used as 
a short-cut to specifying C<Mail::IMAPClient::MessageSet-E<gt>new(@etc)>.) 

=cut

=head1 CLASS METHODS

The only class method you need to worry about is B<new>. And if you create
your B<Mail::IMAPClient::MessageSet> objects via L<Mail::IMAPClient>'s 
B<Range> method then you don't even need to worry about B<new>.

=head2 new

Example:

	my $msgset = Mail::IMAPClient::MessageSet->new(@msgs);

The B<new> method requires at least one argument. That argument can be 
either a message, a comma-separated list of messages, a colon-separated 
range of messages, or a combination of comma-separated messages and 
colon-separated ranges. It can also be a reference to an array of messages,
comma-separated message lists, and colon separated ranges.

If more then one argument is supplied to B<new>, then those arguments should
be more message numbers, lists, and ranges (or references to arrays of them)
just as in the first argument.

The message numbers passed to B<new> can really be any kind of number at
all but to be useful in a L<Mail::IMAPClient> session they should be either
message UID's (if your I<Uid> parameter is true) or message sequence numbers.

The B<new> method will return a reference to a B<Mail::IMAPClient::MessageSet>
object. That object, when double quoted, will act just like a string whose
value is the message set expressed in the shortest possible way, with the
message numbers sorted in ascending order and with duplicates removed. 

=head1 OBJECT METHODS

The only object method currently available to a B<Mail::IMAPClient::MessageSet>
object is the L<unfold> method.

=head2 unfold

Example:

	my $msgset = $imap->Range( $imap->messages ) ;
	my @all_messages = $msgset->unfold;

The B<unfold> method returns an array of messages that belong to the 
message set. If called in a scalar context it returns a reference to the 
array instead.

=head1 OVERRIDDEN OPERATIONS

B<Mail::IMAPClient::MessageSet> overrides a number of operators in order
to make manipulating your message sets easier. The overridden operations are:

=head2 stringify

Attempts to stringify a B<Mail::IMAPClient::MessageSet> object will result in
the compact message specification being returned, which is almost certainly
what you will want.

=head2 Auto-increment

Attempts to autoincrement a B<Mail::IMAPClient::MessageSet> object will 
result in a message (or messages) being added to the object's message set. 

Example:

	$msgset += 34;
	# Message #34 is now in the message set 

=head2 Concatenate

Attempts to concatenate to a B<Mail::IMAPClient::MessageSet> object will 
result in a message (or messages) being added to the object's message set. 

Example:

	$msgset .= "34,35,36,40:45";
	# Messages 34,35,36,40,41,42,43,44,and 45 are now in the message set 

The C<.=> operator and the C<+=> operator can be used interchangeably, but
as you can see by looking at the examples there are times when use of one
has an aesthetic advantage over use of the other.

=head2 Autodecrement

Attempts to autodecrement a B<Mail::IMAPClient::MessageSet> object will 
result in a message being removed from the object's message set. 

Examples:

	$msgset -= 34;
	# Message #34 is no longer in the message set 
	$msgset -= "1:10";
	# Messages 1 through 10 are no longer in the message set 

If you attempt to remove a message that was not in the original message set
then your resulting message set will be the same as the original, only more
expensive. However, if you attempt to remove several messages from the message
set and some of those messages were in the message set and some were not,
the additional overhead of checking for the messages that were not there
is negligable. In either case you get back the message set you want regardless
of whether it was already like that or not.

=cut

=head1 REPORTING BUGS

Please feel free to e-mail the author at C<bug-Mail-IMAPClient@rt.cpan.org>
if you encounter any strange behaviors. Don't worry about hurting my 
feelings or sounding like a whiner or anything like that; 
if there's a problem with this module you'll be doing me a favor by
reporting it.  However, I probably won't be able to do much about it if 
you don't include enough information, so please read and follow these
instructions carefully.

When reporting a bug, please be sure to include the following:

- As much information about your environment as possible. I especially
need to know B<which version of Mail::IMAPClient you are running> and the
B<type/version of IMAP server> to which you are connecting. Your OS and
perl verions would be helpful too.

- As detailed a description of the problem as possible. (What are you
doing? What happens? Have you found a work-around?)

- An example script that demonstrates the problem (preferably with as
few lines of code as possible!) and which calls the Mail::IMAPClient's
L<new> method with the L<Debug> parameter set to "1". (If this generates
a ridiculous amount of output and you're sure you know where the problem
is, you can create your object with debugging turned off and then 
turn it on later, just before you issue the commands that recreate the 
problem. On the other hand, if you can do this you can probably also 
reduce the program rather than reducing the output, and this would be 
the best way to go under most circumstances.)

- Output from the example script when it's running with the Debug
parameter turned on. You can edit the output to remove (or preferably
to "X" out) sensitive data, such as hostnames, user names, and
passwords, but PLEASE do not remove the text that identifies the TYPE
of IMAP server to which you are connecting. Note that in most versions
of B<Mail::IMAPClient>, debugging does not print out the user or
password from the login command line. However, if you use some other
means of authenticating then you may need to edit the debugging output
with an eye to security.

- If something worked in a previous release and doesn't work now,
please tell me which release did work. You don't have to test every
intervening release; just let me know it worked in version x but
doesn't work in version (x+n) or whatever.

- Don't be surprised if I come back asking for a trace of the problem.
To provide this, you should create a file called I<.perldb> in your
current working directory and include the following line of text in
that file:

C<&parse_options("NonStop=1 LineInfo=mail_imapclient_db.out");>

For your debugging convenience, a sample .perldb file, which was
randomly assigned the name F<sample.perldb>, is provided in the
distribution.

Next, without changing your working directory, debug the example script
like this: C<perl -d example_script.pl [ args ]>

Note that in these examples, the script that demonstrates your problem
is named "example_script.pl" and the trace output will be saved in
"mail_imapclient_db.out". You should either change these values to suit
your needs, or change your needs to suit these values.

Bug reports should be mailed to: 

	bug-Mail-IMAPClient@rt.cpan.org

Please remember to place a SHORT description of the problem in the subject
of the message. Please try to be a bit specific; things like "Bug
in Mail::IMAPClient" or "Computer Problem" won't exactly expedite things
on my end.

=head1 REPORTING THINGS THAT ARE NOT BUGS

If you have suggestions for extending this functionality of this module, or
if you have a question and you can't find an answer in any of the 
documentation (including the RFC's, which are included in this distribution
for a reason), then you can e-mail me at the following address:

	comment-Mail-IMAPClient@rt.cpan.org

Please note that this address is for questions, suggestions, and other comments
about B<Mail::IMAPClient>. It's not for reporting bugs, it's not for general 
correspondence, and it's especially not for selling porn, mortgages, Viagra, 
or anything else.

=head1 AUTHOR

	David J. Kernen
	The Kernen Consulting Group, Inc
	DJKERNEN@cpan.org

=cut

=head1 COPYRIGHT

          Copyright 1999, 2000, 2001, 2002 The Kernen Group, Inc.
          All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item a) the "Artistic License" which comes with this Kit, or

=item b) the GNU General Public License as published by the Free Software 
Foundation; either version 1, or (at your option) any later version.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See either the GNU
General Public License or the Artistic License for more details. All your
base are belong to us.

=cut

my $not_void = 11; # This module goes all the way up to 11!

# History: 
# $Log: MessageSet.pm,v $
# Revision 1.3  2002/12/13 18:08:49  dkernen
# Made changes for version 2.2.6 (see Changes file for more info)
#
# Revision 1.2  2002/11/08 15:48:42  dkernen
#
# Modified Files: Changes
# 		IMAPClient.pm
# Modified Files: MessageSet.pm
#
# Revision 1.1  2002/10/23 20:45:55  dkernen
#
# Modified Files: Changes IMAPClient.pm MANIFEST Makefile.PL
# Added Files: Makefile.PL MessageSet.pm
#
#

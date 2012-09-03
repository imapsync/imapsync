package Mail::IMAPClient::BodyStructure;
#$Id: BodyStructure.pm,v 1.3 2003/06/12 21:41:37 dkernen Exp $
#use Parse::RecDescent;
use Mail::IMAPClient;
use Mail::IMAPClient::BodyStructure::Parse;
use vars qw/$parser/;
use Exporter;
push @ISA, "Exporter";
push @EXPORT_OK , '$parser';

$Mail::IMAPClient::BodyStructure::VERSION = '0.0.2';
# Do it once more to show we mean it!
$Mail::IMAPClient::BodyStructure::VERSION = '0.0.2'; 

$parser = Mail::IMAPClient::BodyStructure::Parse->new()

	or 	die 	"Cannot parse rules: $@\n"	.
			"Try remaking Mail::IMAPClient::BodyStructure::Parse.\n" 
	and 	return undef;


sub new {
	my $class = shift;
	my $bodystructure = shift;
	my $self 		= $parser->start($bodystructure) or return undef;
	$self->{_prefix}	= "";

	if ( exists $self->{bodystructure} ) {
		$self->{_id}	= 'HEAD' ;
	} else {
		$self->{_id}	= 1;
	}

	$self->{_top}		= 1;

	return bless($self ,ref($class)||$class);
}

sub _get_thingy {
	my $thingy = shift;
	my $object = shift||(ref($thingy)?$thingy:undef);
	unless ( defined($object) and ref($object) ) {
		$@ = "No argument passed to $thingy method." 	;
		$^W and print STDERR "$@\n" ;
		return undef;
	}
	unless ( 	"$object" =~ /HASH/ 
		and 	exists($object->{$thingy}) 
	) {
		$@ = 	ref($object) 					.
			" $object does not have " 			. 
			( $thingy =~ /^[aeiou]/i ? "an " : "a " ) 	.
			"${thingy}. " 					.
			( ref($object) =~ /HASH/ ? "It has " . join(", ",keys(%$object)) : "") ; 
		$^W and print STDERR "$@\n" ;
		return undef;
	}
	return Unwrapped($object->{$thingy});
}

BEGIN {
 foreach my $datum (qw/	bodytype bodysubtype 	bodyparms 	bodydisp bodyid
			bodydesc bodyenc 	bodysize 	bodylang 
			envelopestruct  	textlines
		   /
 ) {
        no strict 'refs';
        *$datum = sub { _get_thingy($datum, @_); };
 }

}

sub parts {
	my $self = shift;


	if ( exists $self->{PartsList} )  {
		return wantarray ? @{$self->{PartsList}} : $self->{PartsList} ;
	}

	my @parts = ();
	$self->{PartsList} = \@parts;

	unless ( exists($self->{bodystructure}) ) {
		$self->{PartsIndex}{1} = $self ;
		@parts = ("HEAD",1);
		return wantarray ? @parts : \@parts;
	}
	#@parts = ( 1 );
	#} else {

	foreach my $p ($self->bodystructure()) {
		push @parts, $p->id();
		$self->{PartsIndex}{$p->id()} = $p ;
		if ( uc($p->bodytype()||"") eq "MESSAGE" ) {
			#print "Part $parts[-1] is a ",$p->bodytype,"\n";
			push @parts,$parts[-1] . ".HEAD";
		#} else {
		#	print "Part $parts[-1] is a ",$p->bodytype,"\n";
		}
	}

	#}

	return wantarray ? @parts : \@parts;
}

sub oldbodystructure {
	my $self = shift;
	if ( exists $self->{_bodyparts} ) { 
		return wantarray ? @{$self->{_bodyparts}} : $self->{_bodyparts} ;
	}
	my @bodyparts = ( $self );
	$self->{_id} ||= "HEAD";	# aka "0"
	my $count = 0;
	#print STDERR "Analyzing a ",$self->bodytype, " part which I think is part number ",
	#	$self->{_id},"\n";
	my $dump = Data::Dumper->new( [ $self ] , [ 'bodystructure' ] );
	$dump->Indent(1);
	
	foreach my $struct (@{$self->{bodystructure}}) {
		$struct->{_prefix} ||= $self->{_prefix} . +$count . "." unless $struct->{_top};	
		$struct->{_id} ||= $self->{_prefix} . $count unless $struct->{_top};
		#if (
		#	uc($struct->bodytype) eq 'MULTIPART' or 	
		#	uc($struct->bodytype) eq 'MESSAGE'
		#) {
		#} else 	{
		#}
		push @bodyparts, $struct, 
			ref($struct->{bodystructure}) ? $struct->bodystructure : () ;
	}
	$self->{_bodyparts} = \@bodyparts ;
	return wantarray ? @bodyparts : $self->bodyparts ;
}

sub bodystructure {
	my $self = shift;
	my @parts = ();
	my $partno = 0;

        my $prefix = $self->{_prefix} || "";

	#print STDERR 	"Analyzing a ",($self->bodytype||"unknown ") , 
		#	" part which I think is part number ",
		#	$self->{_id},"\n";

	my $bs = $self;
        $prefix = "$prefix." if ( $prefix and $prefix !~ /\.$/);

	if ( $self->{_top} ) {
		$self->{_id} ||= "HEAD";
		$self->{_prefix} ||= "HEAD";
		$partno = 0;
		for (my $x = 0; $x < scalar(@{$self->{bodystructure}}) ; $x++) {
			$self->{bodystructure}[$x]{_id} = ++$partno ;
			$self->{bodystructure}[$x]{_prefix} = $partno ;
			push @parts, $self->{bodystructure}[$x] , 
				$self->{bodystructure}[$x]->bodystructure;
		}
				
		
	} else {
	  $partno = 0;
	  foreach my $p ( @{$self->{bodystructure}}  ) {
		$partno++;
		if (
			! exists $p->{_prefix}  
		) {
			$p->{_prefix} = "$prefix$partno";
		}
		$p->{_prefix} = "$prefix$partno";
		$p->{_id} ||= "$prefix$partno";
		#my $bt = $p->bodytype;
		#if ($bt eq 'MESSAGE') {
			#$p->{_id} = $prefix . 
			#$partno = 0;
		#} 
		push @parts, $p, $p->{bodystructure} ? $p->bodystructure : ();
	  }
	}

	return wantarray ? @parts : \@parts;
}

sub id {
	my $self = shift;
	
	return $self->{_id} if exists $self->{_id};
	return "HEAD" if $self->{_top};
	#if ($self->bodytype eq 'MESSAGE') {
	#	return 
	#}

	if ($self->{bodytype} eq 'MULTIPART') {
		my $p = $self->{_id}||$self->{_prefix} ;
		$p =~ s/\.$//;
		return $p;
	} else {
		return $self->{_id} ||= 1;
	}
}

sub Unwrapped {
	my $unescape = Mail::IMAPClient::Unescape(@_);
	$unescape =~ s/^"(.*)"$/$1/ if defined($unescape);
	return $unescape;
}

package Mail::IMAPClient::BodyStructure::Part;
@ISA = qw/Mail::IMAPClient::BodyStructure/;


package Mail::IMAPClient::BodyStructure::Envelope;
@ISA = qw/Mail::IMAPClient::BodyStructure/;

sub new {
	my $class = shift;
	my $envelope = shift;
	my $self 		= $Mail::IMAPClient::BodyStructure::parser->envelope($envelope);
	return $self;
}


sub _do_accessor {
  my $datum = shift;
  if (scalar(@_) > 1) {
    return $_[0]->{$datum} = $_[1] ;
  } else {
    return $_[0]->{$datum};
  }
}

# the following for loop sets up accessor methods for 
# the object's address attributes:

sub _mk_address_method {
	my $datum = shift;
	my $method1 = $datum . "_addresses" ;
        no strict 'refs';
        *$method1 = sub { 
		my $self = shift;
		return undef unless ref($self->{$datum}) eq 'ARRAY';
		my @list = map {
			my $pn = $_->personalname ; 
			$pn = "" if $pn eq 'NIL' ;
			( $pn ? "$pn " : "" ) 	. 
			"<"			.
			$_->mailboxname		.
			'@'			.
			$_->hostname		.
			">" 
		} 	@{$self->{$datum}} 	;
		if ( $senderFields{$datum} ) {
			return wantarray ? @list : $list[0] ;
		} else {
			return wantarray ? @list : \@list ;
		}
	};
}

BEGIN {

 for my $datum ( 
	qw( subject inreplyto from messageid bcc date replyto to sender cc )
 ) {
        no strict 'refs';
        *$datum = sub { _do_accessor($datum, @_); };
 }
 my %senderFields = map { ($_ => 1) } qw/from sender replyto/ ;
 for my $datum ( 
	qw( from bcc replyto to sender cc )
 ) {
	_mk_address_method($datum);
 }
}


package Mail::IMAPClient::BodyStructure::Address;
@ISA = qw/Mail::IMAPClient::BodyStructure/;

for my $datum ( 
	qw( personalname mailboxname hostname sourcename )
 ) {
	no strict 'refs';
	*$datum = sub { return $_[0]->{$datum}; };
}

1;
__END__

=head1 NAME

Mail::IMAPClient::BodyStructure - Perl extension to Mail::IMAPClient to facilitate 
the parsing of server responses to the FETCH BODYSTRUCTURE and FETCH ENVELOPE
IMAP client commands.

=head1 SYNOPSIS

  use Mail::IMAPClient::BodyStructure;
  use Mail::IMAPClient;

  my $imap = Mail::IMAPClient->new(Server=>$serv,User=>$usr,Password=>$pwd);
  $imap->select("INBOX") or die "cannot select the inbox for $usr: $@\n";

  my @recent = $imap->search("recent");

  foreach my $new (@recent) {

	my $struct = Mail::IMAPClient::BodyStructure->new(
			$imap->fetch($new,"bodystructure")
	);

	print	"Msg $new (Content-type: ",$struct->bodytype,"/",$struct->bodysubtype,
        	") contains these parts:\n\t",join("\n\t",$struct->parts),"\n\n";


  }


  

=head1 DESCRIPTION

This extension will parse the result of an IMAP FETCH BODYSTRUCTURE command into a perl 
data structure. It also provides helper methods that will help you pull information out 
of the data structure.

Use of this extension requires Parse::RecDescent. If you don't have Parse::RecDescent 
then you must either get it or refrain from using this module.

=head2 EXPORT

Nothing is exported by default. C<$parser> is exported upon request. C<$parser> 
is the BodyStucture object's Parse::RecDescent object, which you'll probably 
only need for debugging purposes. 

=head1 Class Methods

The following class method is available:

=head2 new

This class method is the constructor method for instantiating new 
Mail::IMAPClient::BodyStructure objects. The B<new> method accepts one argument, 
a string containing a server response to a FETCH BODYSTRUCTURE directive.  
Only one message's body structure should be described in this 
string, although that message may contain an arbitrary number of parts.

If you know the messages sequence number or unique ID (UID) but haven't got its 
body structure, and you want to get the body structure and parse it into a 
B<Mail::IMAPClient::BodyStructure> object, then you might as well save yourself 
some work and use B<Mail::IMAPClient>'s B<get_bodystructure> method, which 
accepts a message sequence number (or UID if I<Uid> is true) and returns a 
B<Mail::IMAPClient::BodyStructure> object. It's functionally equivalent to issuing the 
FETCH BODYSTRUCTURE IMAP client command and then passing the results to 
B<Mail::IMAPClient::BodyStructure>'s B<new> method but it does those things in one 
simple method call.

=head1 Object Methods

The following object methods are available:

=head2 bodytype

The B<bodytype> object method requires no arguments.  
It returns the bodytype for the message whose structure is described by the calling 
B<Mail::IMAPClient::Bodystructure> object.

=cut

=head2 bodysubtype

The B<bodysubtype> object method requires no arguments.  
It returns the bodysubtype for the message whose structure is described by the calling 
B<Mail::IMAPClient::Bodystructure> object.

=cut



=head2 bodyparms

The B<bodyparms> object method requires no arguments.  
It returns the bodyparms for the message whose structure is described by the calling 
B<Mail::IMAPClient::Bodystructure> object.

=cut


	
=head2 bodydisp

The B<bodydisp> object method requires no arguments.  
It returns the bodydisp for the message whose structure is described by the calling 
B<Mail::IMAPClient::Bodystructure> object.

=cut


	
=head2 bodyid

The B<bodyid> object method requires no arguments.  
It returns the bodyid for the message whose structure is described by the calling 
B<Mail::IMAPClient::Bodystructure> object.

=cut


	
=head2 bodydesc

The B<bodydesc> object method requires no arguments.  
It returns the bodydesc for the message whose structure is described by the calling 
B<Mail::IMAPClient::Bodystructure> object.

=cut


	
=head2 bodyenc

The B<bodyenc> object method requires no arguments.  
It returns the bodyenc for the message whose structure is described by the calling 
B<Mail::IMAPClient::Bodystructure> object.

=cut



=head2 bodysize

The B<bodysize> object method requires no arguments.  
It returns the bodysize for the message whose structure is described by the calling 
B<Mail::IMAPClient::Bodystructure> object.

=cut


	
=head2 bodylang

The B<bodylang> object method requires no arguments.  
It returns the bodylang for the message whose structure is described by the calling 
B<Mail::IMAPClient::Bodystructure> object.

=cut

=head2 bodystructure

The B<bodystructure> object method requires no arguments.  
It returns the bodystructure for the message whose structure is described by the calling 
B<Mail::IMAPClient::Bodystructure> object.

=cut


	
=head2 envelopestruct

The B<envelopestruct> object method requires no arguments.  
It returns the envelopestruct for the message whose structure is described by the 
calling B<Mail::IMAPClient::Bodystructure> object. This envelope structure is blessed
into the B<Mail::IMAPClient::BodyStructure::Envelope> subclass, which is explained more
fully below.

=cut

	
=head2 textlines

The B<textlines> object method requires no arguments.  
It returns the textlines for the message whose structure is described by the calling 
B<Mail::IMAPClient::Bodystructure> object.

=cut

=head1 Envelopes and the Mail::IMAPClient::BodyStructure::Envelope Subclass

The IMAP standard specifies that output from the IMAP B<FETCH ENVELOPE> command 
will be an RFC2060 envelope structure. It further specifies that output from the 
B<FETCH BODYSTRUCTURE> command may also contain embedded envelope structures (if, 
for example, a message's subparts contain one or more included messages). Objects
belonging to B<Mail::IMAPClient::BodyStructure::Envelope> are Perl representations
of these envelope structures, which is to say the nested parenthetical lists of 
RFC2060 translated into a Perl datastructure.

Note that all of the fields relate to the specific part to which they belong. In other
words, output from a FETCH nnnn ENVELOPE command (or, in B<Mail::IMAPClient>,
C<$imap->fetch($msgid,"ENVELOPE")> or C<my $env = $imap->get_envelope($msgid)>) are for
the message, but fields from within a bodystructure relate to the message subpart and 
not the parent message.

An envelope structure's B<Mail::IMAPClient::BodyStructure::Envelope> representation 
is a hash of thingies that looks like this:

{
                     subject => 	"subject",
                     inreplyto =>	"reference_message_id",
                     from => 		[ addressStruct1 ],
                     messageid => 	"message_id",
                     bcc => 		[ addressStruct1, addressStruct2 ],
                     date => 		"Tue, 09 Jul 2002 14:15:53 -0400",
                     replyto => 	[ adressStruct1, addressStruct2 ],
                     to => 		[ adressStruct1, addressStruct2 ],
                     sender => 		[ adressStruct1 ],
                     cc => 		[ adressStruct1, addressStruct2 ],
}

The B<...::Envelope> object also has methods for accessing data in the structure. They
are:

=over 4

=item date

Returns the date of the message.

=item inreplyto

Returns the message id of the message to which this message is a reply.

=item subject

Returns the subject of the message. 

=item messageid

Returns the message id of the message.

=back

You can also use the following methods to get addressing information. Each of these methods
returns an array of B<Mail::IMAPClient::BodyStructure::Address> objects, which are perl 
data structures representing RFC2060 address structures. Some of these arrays would naturally  
contain one element (such as B<from>, which normally contains a single "From:" address); others
will often contain more than one address. However, because RFC2060 defines all of these as "lists
of address structures", they are all translated into arrays of B<...::Address> objects. 

See the section on B<Mail::IMAPClient::BodyStructure::Address>", below, for alternate (and 
preferred) ways of accessing these data.

The methods available are:

=over 4

=item bcc

Returns an array of blind cc'ed recipients' address structures. (Don't expect much in here
unless the message was sent from the mailbox you're poking around in, by the way.)

=item cc

Returns an array of cc'ed recipients' address structures.

=item from

Returns an array of "From:" address structures--usually just one.

=item replyto

Returns an array of "Reply-to:" address structures. Once again there is usually
just one address in the list.

=item sender

Returns an array of senders' address structures--usually just one and usually the same
as B<from>.

=item to

Returns an array of recipients' address structures.

=back

Each of the methods that returns a list of address structures (i.e. a list of 
B<Mail::IMAPClient::BodyStructure::Address> arrays) also has an analagous method
that will return a list of E-Mail addresses instead. The addresses are in the  
format C<personalname E<lt>mailboxname@hostnameE<gt>> (see the section on 
B<Mail::IMAPClient::BodyStructure::Address>, below) However, if the personal name 
is 'NIL' then it is omitted from the address. 

These methods are:

=over 4

=item bcc_addresses

Returns a list (or an array reference if called in scalar context) of blind cc'ed 
recipients' email addresses. (Don't expect much in here unless the message was sent 
from the mailbox you're poking around in, by the way.)

=item cc_addresses

Returns a list of cc'ed recipients' email addresses. If called in a scalar 
context it returns a reference to an array of email addresses.

=item from_addresses

Returns a list of "From:" email addresses.  If called in a scalar context
it returns the first email address in the list. (It's usually a list of just
one anyway.)

=item replyto_addresses

Returns a list of "Reply-to:" email addresses.  If called in a scalar context
it returns the first email address in the list.

=item sender_addresses

Returns a list of senders' email addresses.  If called in a scalar context
it returns the first email address in the list.

=item to_addresses

Returns a list of recipients' email addresses.  If called in a scalar context
it returns a reference to an array of email addresses.

=back

Note that context affects the behavior of all of the above methods. 

Those fields that will commonly contain multiple entries (i.e. they are 
recipients) will return an array reference when called in scalar context. 
You can use this behavior to optimize performance.

Those fields that will commonly contain just one address (the sender's) will 
return the first (and usually only) address. You can use this behavior to 
optimize your development time.

=head1 Addresses and the Mail::IMAPClient::BodyStructure::Address

Several components of an envelope structure are address structures. They are each 
parsed into their own object, B<Mail::IMAPClient::BodyStructure::Address>, which 
looks like this:

	  {
            mailboxname 	=> 'somebody.special',
            hostname 		=> 'somplace.weird.com',
            personalname 	=> 'Somebody Special
            sourceroute 	=> 'NIL'
          } 

RFC2060 specifies that each address component of a bodystructure is a list of 
address structures, so B<Mail::IMAPClient::BodyStructure> parses each of these into
an array of B<Mail::IMAPClient::BodyStructure::Address> objects.

Each of these objects has the following methods available to it:

=over 4

=item mailboxname

Returns the "mailboxname" portion of the address, which is the part to the left 
of the '@' sign.

=item hostname

Returns the "hostname" portion of the address, which is the part to the right of the
'@' sign. 

=item personalname

Returns the "personalname" portion of the address, which is the part of 
the address that's treated like a comment.

=item sourceroute

Returns the "sourceroute" portion of the address, which is typically "NIL".

=back

Taken together, the parts of an address structure form an address that will 
look something like this:

C<personalname E<lt>mailboxname@hostnameE<gt>>

Note that because the B<Mail::IMAPClient::BodyStructure::Address> objects come in 
arrays, it's generally easier to use the methods available to 
B<Mail::IMAPClient::BodyStructure::Envelope> to obtain all of the addresses in a 
particular array in one operation. These methods are provided, however, in case 
you'd rather do things the hard way. (And also because the aforementioned methods
from B<Mail::IMAPClient::BodyStructure::Envelope> need them anyway.)

=cut

=head1 AUTHOR

David J. Kernen

=head1 SEE ALSO

perl(1), Mail::IMAPClient, and RFC2060. See also Parse::RecDescent if you want
to understand the internals of this module.

=cut


# History: 
# $Log: BodyStructure.pm,v $
# Revision 1.3  2003/06/12 21:41:37  dkernen
# Cleaning up cvs repository
#
# Revision 1.1  2003/06/12 21:37:03  dkernen
#
# Preparing 2.2.8
# Added Files: COPYRIGHT
# Modified Files: Parse.grammar
# Added Files: Makefile.old
# 	Makefile.PL Todo sample.perldb
# 	BodyStructure.pm
#
# Revision 1.2  2002/09/26 17:56:14  dkernen
#
# Modified Files:
# BUG_REPORTS Changes IMAPClient.pm INSTALL_perl5.80 MANIFEST
# Makefile.PL for version 2.2.3. See the Changes file for details.
# Modified Files: BodyStructure.pm -- cosmetic changes to pod doc
#
# Revision 1.1  2002/08/30 20:58:51  dkernen
#
# In Mail::IMAPClient/IMAPClient, added files: BUG_REPORTS getGrammer runtest sample.perldb
# In Mail::IMAPClient/IMAPClient/BodyStructure, added files: BodyStructure.pm Makefile.PL debug.ksh runtest
#

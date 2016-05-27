use warnings;
use strict;

package Mail::IMAPClient::BodyStructure;
use Mail::IMAPClient::BodyStructure::Parse;

# BUG?: old code used name "HEAD" instead of "HEADER", change?
my $HEAD = "HEAD";

# my has file scope, not limited to package!
my $parser = Mail::IMAPClient::BodyStructure::Parse->new
  or die "Cannot parse rules: $@\n"
  . "Try remaking Mail::IMAPClient::BodyStructure::Parse.\n";

sub new {
    my $class         = shift;
    my $bodystructure = shift;

    my $self = $parser->start($bodystructure)
      or return undef;

    $self->{_prefix} = "";
    $self->{_id}     = exists $self->{bodystructure} ? $HEAD : 1;
    $self->{_top}    = 1;

    bless $self, ref($class) || $class;
}

sub _get_thingy {
    my $thingy = shift;
    my $object = shift || ( ref $thingy ? $thingy : undef );

    unless ( $object && ref $object ) {
        warn $@ = "No argument passed to $thingy method.";
        return undef;
    }

    unless ( UNIVERSAL::isa( $object, 'HASH' ) && exists $object->{$thingy} ) {
        my $a = $thingy =~ /^[aeiou]/i ? 'an' : 'a';
        my $has = ref $object eq 'HASH' ? join( ", ", keys %$object ) : '';
        warn $@ =
            ref($object)
          . " $object does not have $a $thingy. "
          . ( $has ? "It has $has" : '' );
        return undef;
    }

    my $value = $object->{$thingy};
    $value =~ s/\\ ( [\\\(\)"\x0d\x0a] )/$1/gx;
    $value =~ s/^"(.*)"$/$1/;
    $value;
}

BEGIN {
    no strict 'refs';
    foreach my $datum (
        qw/ bodytype bodysubtype bodyparms bodydisp bodyid bodydesc bodyenc
        bodysize bodylang envelopestruct textlines /
      )
    {
        *$datum = sub { _get_thingy( $datum, @_ ) };
    }
}

sub parts {
    my $self = shift;
    return wantarray ? @{ $self->{PartsList} } : $self->{PartsList}
      if exists $self->{PartsList};

    my @parts;
    $self->{PartsList} = \@parts;

    # BUG?: should this default to ($HEAD, TEXT)
    unless ( exists $self->{bodystructure} ) {
        $self->{PartsIndex}{1} = $self;
        @parts = ( $HEAD, 1 );
        return wantarray ? @parts : \@parts;
    }

    foreach my $p ( $self->bodystructure ) {
        my $id = $p->id;
        push @parts, $id;
        $self->{PartsIndex}{$id} = $p;
        my $type = uc $p->bodytype || '';

        push @parts, "$id.$HEAD"
          if $type eq 'MESSAGE';
    }

    wantarray ? @parts : \@parts;
}

sub bodystructure {
    my $self   = shift;
    my $partno = 0;
    my @parts;

    if ( $self->{_top} ) {
        $self->{_id}     ||= $HEAD;
        $self->{_prefix} ||= $HEAD;
        $partno = 0;
        foreach my $b ( @{ $self->{bodystructure} } ) {
            $b->{_id}     = ++$partno;
            $b->{_prefix} = $partno;
            push @parts, $b, $b->bodystructure;
        }
        return wantarray ? @parts : \@parts;
    }

    my $prefix = $self->{_prefix} || "";
    $prefix =~ s/\.?$/./;

    foreach my $p ( @{ $self->{bodystructure} } ) {
        $partno++;

        # BUG?: old code didn't add .TEXT sections, should we skip these?
        # - This code needs to be generalised (maybe it belongs in parts()?)
        # - Should every message should have HEAD (actually MIME) and TEXT?
        #   at least dovecot and iplanet appear to allow this even for
        #   non-multipart sections
        my $pno   = $partno;
        my $stype = $self->{bodytype} || "";
        my $ptype = $p->{bodytype} || "";

        # a message and the multipart inside of it "collapse together"
        if ( $partno == 1 and $stype eq 'MESSAGE' and $ptype eq 'MULTIPART' ) {
            $pno = "TEXT";
            $p->{_prefix} = "$prefix";
        }
        else {
            $p->{_prefix} = "$prefix$partno";
        }
        $p->{_id} ||= "$prefix$pno";

        push @parts, $p, $p->{bodystructure} ? $p->bodystructure : ();
    }

    wantarray ? @parts : \@parts;
}

sub id {
    my $self = shift;
    return $self->{_id}
      if exists $self->{_id};

    return $HEAD
      if $self->{_top};

    # BUG?: can this be removed? ... seems wrong
    if ( $self->{bodytype} eq 'MULTIPART' ) {
        my $p = $self->{_id} || $self->{_prefix};
        $p =~ s/\.$//;
        return $p;
    }
    else {
        return $self->{_id} ||= 1;
    }
}

package Mail::IMAPClient::BodyStructure::Part;
our @ISA = qw/Mail::IMAPClient::BodyStructure/;

package Mail::IMAPClient::BodyStructure::Envelope;
our @ISA = qw/Mail::IMAPClient::BodyStructure/;

sub new {
    my ( $class, $envelope ) = @_;
    $parser->envelope($envelope);
}

sub parse_string {
    my ( $class, $envelope ) = @_;
    $envelope = "(" . $envelope . ")" unless ( $envelope =~ /^\(/ );
    $parser->envelopestruct($envelope);
}

sub from_addresses    { shift->_addresses( from    => 1 ) }
sub sender_addresses  { shift->_addresses( sender  => 1 ) }
sub replyto_addresses { shift->_addresses( replyto => 1 ) }
sub to_addresses      { shift->_addresses( to      => 0 ) }
sub cc_addresses      { shift->_addresses( cc      => 0 ) }
sub bcc_addresses     { shift->_addresses( bcc     => 0 ) }

sub _addresses($$$) {
    my ( $self, $name, $isSender ) = @_;
    ref $self->{$name} eq 'ARRAY'
      or return ();

    my @list;
    foreach ( @{ $self->{$name} } ) {
        my $pn = $_->personalname;
        my $name = $pn && $pn ne 'NIL' ? "$pn " : '';
        push @list, $name . '<' . $_->mailboxname . '@' . $_->hostname . '>';
    }

    wantarray     ? @list
      : $isSender ? $list[0]
      :             \@list;
}

BEGIN {
    no strict 'refs';
    for my $datum (
        qw(subject inreplyto from messageid bcc date
        replyto to sender cc)
      )
    {
        *$datum = sub { @_ > 1 ? $_[0]->{$datum} = $_[1] : $_[0]->{$datum} }
    }
}

package Mail::IMAPClient::BodyStructure::Address;
our @ISA = qw/Mail::IMAPClient::BodyStructure/;

for my $datum (qw(personalname mailboxname hostname sourcename)) {
    no strict 'refs';
    *$datum = sub { shift->{$datum}; };
}

1;

__END__

=head1 NAME

Mail::IMAPClient::BodyStructure - parse fetched results

=head1 SYNOPSIS

  use Mail::IMAPClient;
  use Mail::IMAPClient::BodyStructure;

  my $imap = Mail::IMAPClient->new(
      Server => $server, User => $login, Password => $pass
  );

  $imap->select("INBOX") or die "Could not select INBOX: $@\n";

  my @recent = $imap->search("recent") or die "No recent msgs in INBOX\n";

  foreach my $id (@recent) {
      my $bsdat = $imap->fetch( $id, "bodystructure" );
      my $bso   = Mail::IMAPClient::BodyStructure->new( join("", $imap->History) );
      my $mime  = $bso->bodytype . "/" . $bso->bodysubtype;
      my $parts = map( "\n\t" . $_, $bso->parts );
      print "Msg $id (Content-type: $mime) contains these parts:$parts\n";
  }

=head1 DESCRIPTION

This extension will parse the result of an IMAP FETCH BODYSTRUCTURE
command into a perl data structure.  It also provides helper methods
to help pull information out of the data structure.

This module requires Parse::RecDescent.

=head1 Class Methods

The following class method is available:

=head2 new

This class method is the constructor method for instantiating new
Mail::IMAPClient::BodyStructure objects.  The B<new> method accepts
one argument, a string containing a server response to a FETCH
BODYSTRUCTURE directive.

The module B<Mail::IMAPClient> provides the B<get_bodystructure>
convenience method to simplify use of this module when starting with
just a messages sequence number or unique ID (UID).

=head1 Object Methods

The following object methods are available:

=head2 bodytype

The B<bodytype> object method requires no arguments.  It returns the
bodytype for the message whose structure is described by the calling
B<Mail::IMAPClient::Bodystructure> object.

=head2 bodysubtype

The B<bodysubtype> object method requires no arguments.  It returns the
bodysubtype for the message whose structure is described by the calling
B<Mail::IMAPClient::Bodystructure> object.

=head2 bodyparms

The B<bodyparms> object method requires no arguments.  It returns the
bodyparms for the message whose structure is described by the calling
B<Mail::IMAPClient::Bodystructure> object.

=head2 bodydisp

The B<bodydisp> object method requires no arguments.  It returns the
bodydisp for the message whose structure is described by the calling
B<Mail::IMAPClient::Bodystructure> object.

=head2 bodyid

The B<bodyid> object method requires no arguments.  It returns the
bodyid for the message whose structure is described by the calling
B<Mail::IMAPClient::Bodystructure> object.

=head2 bodydesc

The B<bodydesc> object method requires no arguments.  It returns the
bodydesc for the message whose structure is described by the calling
B<Mail::IMAPClient::Bodystructure> object.

=head2 bodyenc

The B<bodyenc> object method requires no arguments.  It returns the
bodyenc for the message whose structure is described by the calling
B<Mail::IMAPClient::Bodystructure> object.

=head2 bodysize

The B<bodysize> object method requires no arguments.  It returns the
bodysize for the message whose structure is described by the calling
B<Mail::IMAPClient::Bodystructure> object.

=head2 bodylang

The B<bodylang> object method requires no arguments.  It returns the
bodylang for the message whose structure is described by the calling
B<Mail::IMAPClient::Bodystructure> object.

=head2 bodystructure

The B<bodystructure> object method requires no arguments.  It returns
the bodystructure for the message whose structure is described by the
calling B<Mail::IMAPClient::Bodystructure> object.

=head2 envelopestruct

The B<envelopestruct> object method requires no arguments.  It returns
a B<Mail::IMAPClient::BodyStructure::Envelope> object for the message
from the calling B<Mail::IMAPClient::Bodystructure> object.

=head2 textlines

The B<textlines> object method requires no arguments.  It returns the
textlines for the message whose structure is described by the calling
B<Mail::IMAPClient::Bodystructure> object.

=head1 Mail::IMAPClient::BodyStructure::Envelope

The IMAP standard specifies that output from the IMAP B<FETCH
ENVELOPE> command will be an RFC2060 envelope structure.  It further
specifies that output from the B<FETCH BODYSTRUCTURE> command may also
contain embedded envelope structures (if, for example, a message's
subparts contain one or more included messages).  Objects belonging to
B<Mail::IMAPClient::BodyStructure::Envelope> are Perl representations
of these envelope structures, which is to say the nested parenthetical
lists of RFC2060 translated into a Perl datastructure.

Note that all of the fields relate to the specific part to which they
belong.  In other words, output from a FETCH nnnn ENVELOPE command
(or, in B<Mail::IMAPClient>, C<$imap->fetch($msgid,"ENVELOPE")> or
C<my $env = $imap->get_envelope($msgid)>) are for the message, but
fields from within a bodystructure relate to the message subpart and
not the parent message.

An envelope structure's B<Mail::IMAPClient::BodyStructure::Envelope>
representation is a hash of thingies that looks like this:

  {
     subject   => "subject",
     inreplyto => "reference_message_id",
     from      => [ addressStruct1 ],
     messageid => "message_id",
     bcc       => [ addressStruct1, addressStruct2 ],
     date      => "Tue, 09 Jul 2002 14:15:53 -0400",
     replyto   => [ adressStruct1, addressStruct2 ],
     to        => [ adressStruct1, addressStruct2 ],
     sender    => [ adressStruct1 ],
     cc        => [ adressStruct1, addressStruct2 ],
  }

The B<...::Envelope> object also has methods for accessing data in the
structure. They are:

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

You can also use the following methods to get addressing information.
Each of these methods returns an array of
B<Mail::IMAPClient::BodyStructure::Address> objects, which are perl
data structures representing RFC2060 address structures.  Some of
these arrays would naturally contain one element (such as B<from>,
which normally contains a single "From:" address); others will often
contain more than one address.  However, because RFC2060 defines all
of these as "lists of address structures", they are all translated
into arrays of B<...::Address> objects.

See the section on B<Mail::IMAPClient::BodyStructure::Address>, below,
for alternate (and preferred) ways of accessing these data.

The methods available are:

=over 4

=item bcc

Returns an array of blind cc'ed recipients' address structures.
(Don't expect much in here unless the message was sent from the
mailbox you're poking around in, by the way.)

=item cc

Returns an array of cc'ed recipients' address structures.

=item from

Returns an array of "From:" address structures--usually just one.

=item replyto

Returns an array of "Reply-to:" address structures.  Once again there
is usually just one address in the list.

=item sender

Returns an array of senders' address structures--usually just one and
usually the same as B<from>.

=item to

Returns an array of recipients' address structures.

=back

Each of the methods that returns a list of address structures (i.e. a
list of B<Mail::IMAPClient::BodyStructure::Address> arrays) also has
an analogous method that will return a list of E-Mail addresses
instead.  The addresses are in the format C<personalname
E<lt>mailboxname@hostnameE<gt>> (see the section on
B<Mail::IMAPClient::BodyStructure::Address>, below) However, if the
personal name is 'NIL' then it is omitted from the address.

These methods are:

=over 4

=item bcc_addresses

Returns a list (or an array reference if called in scalar context) of
blind cc'ed recipients' email addresses.  (Don't expect much in here
unless the message was sent from the mailbox you're poking around in,
by the way.)

=item cc_addresses

Returns a list of cc'ed recipients' email addresses.  If called in a
scalar context it returns a reference to an array of email addresses.

=item from_addresses

Returns a list of "From:" email addresses.  If called in a scalar
context it returns the first email address in the list.  (It's usually
a list of just one anyway.)

=item replyto_addresses

Returns a list of "Reply-to:" email addresses.  If called in a scalar
context it returns the first email address in the list.

=item sender_addresses

Returns a list of senders' email addresses.  If called in a scalar
context it returns the first email address in the list.

=item to_addresses

Returns a list of recipients' email addresses.  If called in a scalar
context it returns a reference to an array of email addresses.

=back

Note that context affects the behavior of all of the above methods.

Those fields that will commonly contain multiple entries (i.e. they
are recipients) will return an array reference when called in scalar
context.  You can use this behavior to optimize performance.

Those fields that will commonly contain just one address (the
sender's) will return the first (and usually only) address.  You can
use this behavior to optimize your development time.

=head1 Addresses and the Mail::IMAPClient::BodyStructure::Address

Several components of an envelope structure are address structures.
They are each parsed into their own object,
B<Mail::IMAPClient::BodyStructure::Address>, which looks like this:

   {
      mailboxname  => 'somebody.special',
      hostname     => 'somplace.weird.com'
      personalname => 'Somebody Special
      sourceroute  => 'NIL'
   }

RFC2060 specifies that each address component of a bodystructure is a
list of address structures, so B<Mail::IMAPClient::BodyStructure>
parses each of these into an array of
B<Mail::IMAPClient::BodyStructure::Address> objects.

Each of these objects has the following methods available to it:

=over 4

=item mailboxname

Returns the "mailboxname" portion of the address, which is the part to
the left of the '@' sign.

=item hostname

Returns the "hostname" portion of the address, which is the part to
the right of the '@' sign.

=item personalname

Returns the "personalname" portion of the address, which is the part
of the address that's treated like a comment.

=item sourceroute

Returns the "sourceroute" portion of the address, which is typically "NIL".

=back

Taken together, the parts of an address structure form an address that
will look something like this:

C<personalname E<lt>mailboxname@hostnameE<gt>>

Note that because the B<Mail::IMAPClient::BodyStructure::Address>
objects come in arrays, it's generally easier to use the methods
available to B<Mail::IMAPClient::BodyStructure::Envelope> to obtain
all of the addresses in a particular array in one operation.  These
methods are provided, however, in case you'd rather do things the hard
way.  (And also because the aforementioned methods from
B<Mail::IMAPClient::BodyStructure::Envelope> need them anyway.)

=cut

=head1 AUTHOR

Original author: David J. Kernen; Reworked by: Mark Overmeer;
Maintained by Phil Pearl.

=head1 SEE ALSO

perl(1), Mail::IMAPClient, Parse::RecDescent, and RFC2060.

=cut


# _{name} methods are undocumented and meant to be private.

require 5.008_001;

use strict;
use warnings;

package Mail::IMAPClient;
our $VERSION = '3.39';

use Mail::IMAPClient::MessageSet;

use IO::Socket qw(:crlf SOL_SOCKET SO_KEEPALIVE);
use IO::Select ();
use Carp qw(carp);    #local $SIG{__WARN__} = \&Carp::cluck; #DEBUG

use Fcntl qw(F_GETFL F_SETFL O_NONBLOCK);
use Errno qw(EAGAIN EBADF ECONNRESET EPIPE);
use List::Util qw(first min max sum);
use MIME::Base64 qw(encode_base64 decode_base64);
use File::Spec ();

use constant APPEND_BUFFER_SIZE => 1024 * 1024;

use constant {
    Unconnected   => 0,
    Connected     => 1,    # connected; not logged in
    Authenticated => 2,    # logged in; no mailbox selected
    Selected      => 3,    # mailbox selected
};

use constant {
    INDEX => 0,    # Array index for output line number
    TYPE  => 1,    # Array index for line type (OUTPUT, INPUT, or LITERAL)
    DATA  => 2,    # Array index for output line data
};

my %SEARCH_KEYS = map { ( $_ => 1 ) } qw(
  ALL ANSWERED BCC BEFORE BODY CC DELETED DRAFT FLAGGED
  FROM HEADER KEYWORD LARGER NEW NOT OLD ON OR RECENT
  SEEN SENTBEFORE SENTON SENTSINCE SINCE SMALLER SUBJECT
  TEXT TO UID UNANSWERED UNDELETED UNDRAFT UNFLAGGED
  UNKEYWORD UNSEEN);

# modules require(d) during runtime when applicable
my %Load_Module = (
    "Compress-Zlib" => "Compress::Zlib",
    "INET"          => "IO::Socket::INET6",
    "SSL"           => "IO::Socket::SSL",
    "UNIX"          => "IO::Socket::UNIX",
    "BodyStructure" => "Mail::IMAPClient::BodyStructure",
    "Envelope"      => "Mail::IMAPClient::BodyStructure::Envelope",
    "Thread"        => "Mail::IMAPClient::Thread",
);

sub _load_module {
    my $self   = shift;
    my $modkey = shift;
    my $module = $Load_Module{$modkey} || $modkey;

    my $err = do {
        local ($@);
        eval "require $module";
        $@;
    };
    if ($err) {
        $self->LastError("Unable to load '$module': $err");
        return undef;
    }
    return $module;
}

sub _debug {
    my $self = shift;
    return unless $self->Debug;

    my $text = join '', @_;
    $text =~ s/$CRLF/\n  /og;
    $text =~ s/\s*$/\n/;

    #use POSIX (); $text = POSIX::strftime("%F %T ", localtime).$text; #DEBUG
    my $fh = $self->{Debug_fh} || \*STDERR;
    print $fh $text;
}

BEGIN {

    # set-up accessors
    foreach my $datum (
        qw(Authcallback Authmechanism Authuser Buffer Count Compress
        Debug Debug_fh Domain Folder Ignoresizeerrors Keepalive
        Maxappendstringlength Maxcommandlength Maxtemperrors
        Password Peek Port Prewritemethod Proxy Ranges Readmethod
        Readmoremethod Reconnectretry Server Showcredentials
        Socketargs Ssl Starttls Supportedflags Timeout Uid User)
      )
    {
        no strict 'refs';
        *$datum = sub {
            @_ > 1 ? ( $_[0]->{$datum} = $_[1] ) : $_[0]->{$datum};
        };
    }
}

sub LastError {
    my $self = shift;
    @_ or return $self->{LastError};
    my $err = shift;

    # allow LastError to be reset with undef
    if ( defined $err ) {
        $err =~ s/$CRLF$//og;
        local ($!);    # old versions of Carp could reset $!
        $self->_debug( Carp::longmess("ERROR: $err") );

        # hopefully this is rare...
        if ( $err =~ /NO not connected/ ) {
            my $lerr = $self->{LastError} || "";
            my $emsg = "Trying command when NOT connected!";
            $emsg .= " LastError was: $lerr" if $lerr;
            Carp::cluck($emsg);
        }
    }

    # 2.x API support requires setting $@
    $@ = $self->{LastError} = $err;
}

sub Fast_io(;$) {
    my ( $self, $use ) = @_;
    defined $use
      or return $self->{Fast_io};

    my $socket = $self->{Socket}
      or return undef;

    local ( $@, $! );    # avoid stomping on globals
    unless ($use) {
        eval { fcntl( $socket, F_SETFL, delete $self->{_fcntl} ) }
          if exists $self->{_fcntl};
        $self->{Fast_io} = 0;
        return undef;
    }

    my $fcntl = eval { fcntl( $socket, F_GETFL, 0 ) };
    if ($@) {
        $self->{Fast_io} = 0;
        $self->_debug("not using Fast_IO; not available on this platform")
          unless $self->{_fastio_warning_}++;
        return undef;
    }

    $self->{Fast_io} = 1;
    my $newflags = $self->{_fcntl} = $fcntl;
    $newflags |= O_NONBLOCK;
    fcntl( $socket, F_SETFL, $newflags );
}

# removed
sub EnableServerResponseInLiteral { undef }

sub Wrap { shift->Clear(@_) }

# The following class method is for creating valid dates in appended msgs:
my @dow = qw(Sun Mon Tue Wed Thu Fri Sat);
my @mnt = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);

sub Rfc822_date {
    my $class = shift;
    my $date  = $class =~ /^\d+$/ ? $class : shift;    # method or function?
    my @date  = gmtime($date);

    #Date: Fri, 09 Jul 1999 13:10:55 -0000
    sprintf(
        "%s, %02d %s %04d %02d:%02d:%02d -%04d",
        $dow[ $date[6] ],
        $date[3],
        $mnt[ $date[4] ],
        $date[5] + 1900,
        $date[2], $date[1], $date[0], $date[8]
    );
}

# The following methods create valid dates for use in IMAP search strings
# - provide Rfc2060* methods/functions for backwards compatibility
sub Rfc2060_date {
    $_[0] =~ /^\d+$/ ? Rfc3501_date(@_) : shift->Rfc3501_date(@_);
}

sub Rfc3501_date {
    my $class = shift;
    my $stamp = $class =~ /^\d+$/ ? $class : shift;
    my @date  = gmtime($stamp);

    # 11-Jan-2000
    sprintf( "%02d-%s-%04d", $date[3], $mnt[ $date[4] ], $date[5] + 1900 );
}

sub Rfc2060_datetime($;$) {
    $_[0] =~ /^\d+$/ ? Rfc3501_datetime(@_) : shift->Rfc3501_datetime(@_);
}

sub Rfc3501_datetime($;$) {
    my $class = shift;
    my $stamp = $class =~ /^\d+$/ ? $class : shift;
    my $zone  = shift || '+0000';
    my @date  = gmtime($stamp);

    # 11-Jan-2000 04:04:04 +0000
    sprintf(
        "%02d-%s-%04d %02d:%02d:%02d %s",
        $date[3],
        $mnt[ $date[4] ],
        $date[5] + 1900,
        $date[2], $date[1], $date[0], $zone
    );
}

# Change CRLF into \n
sub Strip_cr {
    my $class = shift;
    if ( !ref $_[0] && @_ == 1 ) {
        ( my $string = $_[0] ) =~ s/$CRLF/\n/og;
        return $string;
    }

    return wantarray
      ? map { s/$CRLF/\n/og; $_ } ( ref $_[0] ? @{ $_[0] } : @_ )
      : [ map { s/$CRLF/\n/og; $_ } ( ref $_[0] ? @{ $_[0] } : @_ ) ];
}

# The following defines a special method to deal with the Clear parameter:
sub Clear {
    my ( $self, $clear ) = @_;
    defined $clear or return $self->{Clear};

    my $oldclear = $self->{Clear};
    $self->{Clear} = $clear;

    my @keys = reverse $self->_trans_index;

    for ( my $i = $clear ; $i < @keys ; $i++ ) {
        delete $self->{History}{ $keys[$i] };
    }

    return $oldclear;
}

# read-only access to the transaction number
sub Transaction { shift->Count }

# remove doubles from list
sub _remove_doubles(@) {
    my %seen;
    grep { !$seen{ $_->{name} }++ } @_;
}

# the constructor:
sub new {
    my $class = shift;
    my $self  = {
        LastError             => "",
        Uid                   => 1,
        Count                 => 0,
        Clear                 => 2,
        Keepalive             => 0,
        Maxappendstringlength => 1024**2,
        Maxcommandlength      => 1000,
        Maxtemperrors         => undef,
        State                 => Unconnected,
        Authmechanism         => 'LOGIN',
        Timeout               => 600,
        History               => {},
    };
    while (@_) {
        my $k = ucfirst lc shift;
        my $v = shift;
        $self->{$k} = $v if defined $v;
    }
    bless $self, ref($class) || $class;

    # Fast_io is enabled by default when not given a socket
    unless ( exists $self->{Fast_io} || $self->{Socket} || $self->{Rawsocket} )
    {
        $self->{Fast_io} = 1;
    }

    if ( my $sup = $self->{Supportedflags} ) {    # unpack into case-less HASH
        my %sup = map { m/^\\?(\S+)/ ? lc $1 : () } @$sup;
        $self->{Supportedflags} = \%sup;
    }

    $self->{Debug_fh} ||= \*STDERR;
    CORE::select( ( select( $self->{Debug_fh} ), $|++ )[0] );

    if ( $self->Debug ) {
        $self->_debug( "Started at " . localtime() );
        $self->_debug("Using Mail::IMAPClient version $VERSION on perl $]");
    }

    # BUG? return undef on Socket() failure?
    $self->Socket( $self->{Socket} )
      if $self->{Socket};

    if ( $self->{Rawsocket} ) {
        my $sock = delete $self->{Rawsocket};

        # Ignore Rawsocket if Socket is set.  BUG? should we carp/croak?
        $self->RawSocket($sock) unless $self->{Socket};
    }

    if ( !$self->{Socket} && $self->{Server} ) {
        $self->connect or return undef;
    }
    return $self;
}

sub connect(@) {
    my $self = shift;

    # BUG? We should restrict which keys can be passed/set here.
    %$self = ( %$self, @_ ) if @_;

    my @sockargs = $self->Timeout ? ( Timeout => $self->Timeout ) : ();
    push( @sockargs, $self->Debug ? ( Debug => $self->Debug ) : () );

    # give caller control of IO::Socket::... args to new if desired
    if ( $self->Socketargs and ref $self->Socketargs eq "ARRAY" ) {
        push( @sockargs, @{ $self->Socketargs } );
    }

    my $server = $self->Server;
    my $port = $self->Port || $self->Port( $self->Ssl ? "993" : "143" );
    my ( $ioclass, $sock );

    if ( File::Spec->file_name_is_absolute($server) ) {
        $ioclass = $self->_load_module("UNIX");
        unshift( @sockargs, Peer => $server );
    }
    else {
        unshift(
            @sockargs,
            PeerAddr => $server,
            PeerPort => $port,
            Proto    => "tcp",
        );

        # extra control of SSL args is supported
        if ( $self->Ssl ) {
            $ioclass = $self->_load_module("SSL");
            push( @sockargs, @{ $self->Ssl } ) if ref $self->Ssl eq "ARRAY";
        }
        else {
            $ioclass = $self->_load_module("INET");
        }
    }

    if ($ioclass) {
        $self->_debug("Connecting with $ioclass @sockargs");
        $sock = $ioclass->new(@sockargs);
    }

    if ($sock) {
        $self->_debug( "Connected to $server" . ( $! ? " errno($!)" : "" ) );
        return $self->Socket($sock);
    }
    else {
        my $lasterr = $self->LastError;
        if ( !$lasterr and $self->Ssl and $ioclass ) {
            $lasterr = $ioclass->errstr;
        }
        $lasterr ||= "";
        $self->LastError("Unable to connect to $server: $lasterr");
        return undef;
    }
}

sub RawSocket(;$) {
    my ( $self, $sock ) = @_;
    defined $sock
      or return $self->{Socket};

    $self->{Socket}  = $sock;
    $self->{_select} = IO::Select->new($sock);

    delete $self->{_fcntl};
    $self->Fast_io( $self->Fast_io );

    return $sock;
}

sub Socket($) {
    my ( $self, $sock ) = @_;
    defined $sock
      or return $self->{Socket};

    $self->RawSocket($sock);
    $self->State(Connected);

    setsockopt( $sock, SOL_SOCKET, SO_KEEPALIVE, 1 ) if $self->Keepalive;

    # LastError may be set by _read_line via _get_response
    # look for "* (OK|BAD|NO|PREAUTH)"
    my $code = $self->_get_response( '*', 'PREAUTH' ) or return undef;

    if ( $code eq 'BYE' || $code eq 'NO' ) {
        $self->State(Unconnected);
        return undef;
    }
    elsif ( $code eq 'PREAUTH' ) {
        $self->State(Authenticated);
        return $self;
    }

    if ( $self->Starttls ) {
        $self->starttls or return undef;
    }

    if ( defined $self->User && defined $self->Password ) {
        $self->login or return undef;
    }

    return $self->{Socket};
}

# RFC2595 section 3.1
sub starttls {
    my ($self) = @_;

    # BUG? RFC requirement checks commented out for now...
    #if ( $self->IsUnconnected or $self->IsAuthenticated ) {
    #    $self->LastError("NO must be connected but not authenticated");
    #    return undef;
    #}

    # BUG? strict check on capability commented out for now...
    #return undef unless $self->has_capability("STARTTLS");

    $self->_imap_command("STARTTLS") or return undef;

    # MUST discard cached capability info; should re-issue capability command
    delete $self->{CAPABILITY};

    my $ioclass  = $self->_load_module("SSL") or return undef;
    my $sock     = $self->RawSocket;
    my $blocking = $sock->blocking;

    # BUG: force blocking for now
    $sock->blocking(1);

    # give caller control of args to start_SSL if desired
    my @sslargs =
        ( $self->Starttls and ref( $self->Starttls ) eq "ARRAY" )
      ? ( @{ $self->Starttls } )
      : ( Timeout => 30 );

    unless ( $ioclass->start_SSL( $sock, @sslargs ) ) {
        $self->LastError( "Unable to start TLS: " . $ioclass->errstr );
        return undef;
    }

    # return blocking to previous setting
    $sock->blocking($blocking);

    return $self;
}

# RFC4978 COMPRESS
sub compress {
    my ($self) = @_;

    # BUG? strict check on capability commented out for now...
    #my $can = $self->has_capability("COMPRESS")
    #return undef unless $can and $can eq "DEFLATE";

    $self->_imap_command("COMPRESS DEFLATE") or return undef;

    my $zcl = $self->_load_module("Compress-Zlib") or return undef;

    # give caller control of args if desired
    $self->Compress(
        [
            -WindowBits => -$zcl->MAX_WBITS(),
            -Level      => $zcl->Z_BEST_SPEED()
        ]
    ) unless ( $self->Compress and ref( $self->Compress ) eq "ARRAY" );

    my ( $rc, $do, $io );

    ( $do, $rc ) = Compress::Zlib::deflateInit( @{ $self->Compress } );
    unless ( $rc == $zcl->Z_OK ) {
        $self->LastError("deflateInit failed (rc=$rc)");
        return undef;
    }

    ( $io, $rc ) =
      Compress::Zlib::inflateInit( -WindowBits => -$zcl->MAX_WBITS() );
    unless ( $rc == $zcl->Z_OK ) {
        $self->LastError("inflateInit failed (rc=$rc)");
        return undef;
    }

    $self->{Prewritemethod} = sub {
        my ( $imap, $string ) = @_;

        my ( $rc, $out1, $out2 );
        ( $out1, $rc ) = $do->deflate($string);
        ( $out2, $rc ) = $do->flush( $zcl->Z_PARTIAL_FLUSH() )
          unless ( $rc != $zcl->Z_OK );

        unless ( $rc == $zcl->Z_OK ) {
            $self->LastError("deflate/flush failed (rc=$rc)");
            return undef;
        }

        return $out1 . $out2;
    };

    # need to retain some state for Readmoremethod/Readmethod calls
    my ( $Zbuf, $Ibuf ) = ( "", "" );

    $self->{Readmoremethod} = sub {
        my $self = shift;
        return 1 if ( length($Zbuf) || length($Ibuf) );
        $self->__read_more(@_);
    };

    $self->{Readmethod} = sub {
        my ( $imap, $fh, $buf, $len, $off ) = @_;

        # get more data, but empty $Ibuf first if any data is left
        my ( $lz, $li ) = ( length $Zbuf, length $Ibuf );
        if ( $lz || !$li ) {
            my $ret = sysread( $fh, $Zbuf, $len, length $Zbuf );
            $lz = length $Zbuf;
            return $ret if ( !$ret && !$lz );    # $ret is undef or 0
        }

        # accumulate inflated data in $Ibuf
        if ($lz) {
            my ( $tbuf, $rc ) = $io->inflate( \$Zbuf );
            unless ( $rc == $zcl->Z_OK ) {
                $self->LastError("inflate failed (rc=$rc)");
                return undef;
            }
            $Ibuf .= $tbuf;
        }

        # pull desired length of data from $Ibuf
        my $tbuf = substr( $Ibuf, 0, $len );
        substr( $Ibuf, 0, $len ) = "";
        substr( $$buf, $off ) = $tbuf;

        return length $tbuf;
    };

    return $self;
}

sub login {
    my $self = shift;
    my $auth = $self->Authmechanism;

    if ( $auth && $auth ne 'LOGIN' ) {
        $self->authenticate( $auth, $self->Authcallback )
          or return undef;
    }
    else {
        my $user   = $self->User;
        my $passwd = $self->Password;

        return undef unless ( defined($passwd) and defined($user) );

        # if user is passed as a literal:
        # 1. send passwd as a literal
        # 2. empty literal passwd are sent as an blank line ($CRLF)
        $user = $self->Quote($user);
        if ( $user =~ /^{/ ) {
            my $nopasswd = ( $passwd eq "" ) ? 1 : 0;
            $passwd = $self->Quote( $passwd, 1 );    # force literal
            $passwd .= $CRLF if ($nopasswd);         # blank line
        }
        else {
            $passwd = $self->Quote($passwd);
        }

        $self->_imap_command("LOGIN $user $passwd")
          or return undef;
    }

    $self->State(Authenticated);
    if ( $self->Compress ) {
        $self->compress or return undef;
    }
    return $self;
}

sub noop {
    my ($self) = @_;
    $self->_imap_command("NOOP") ? $self->Results : undef;
}

sub proxyauth {
    my ( $self, $user ) = @_;
    $user = $self->Quote($user);
    $self->_imap_command("PROXYAUTH $user") ? $self->Results : undef;
}

sub separator {
    my ( $self, $target ) = @_;
    unless ( defined $target ) {

        # separator is namespace's 1st thing's 1st thing's 2nd thing:
        my $ns = $self->namespace or return undef;
        if ($ns) {
            my $sep = $ns->[0][0][1];
            return $sep if $sep;
        }
        $target = '';
    }

    return $self->{separators}{$target}
      if exists $self->{separators}{$target};

    my $list = $self->list( undef, $target ) or return undef;

    foreach my $line (@$list) {
        my $rec = $self->_list_or_lsub_response_parse($line);
        next unless defined $rec->{name};
        $self->{separators}{ $rec->{name} } = $rec->{delim};
    }
    return $self->{separators}{$target};
}

# BUG? caller gets empty list even if Error
# - returning an array with a single undef value seems even worse though
sub sort {
    my ( $self, $crit, @a ) = @_;

    $crit =~ /^\(.*\)$/    # wrap criteria in parens
      or $crit = "($crit)";

    my @hits;
    if ( $self->_imap_uid_command( SORT => $crit, @a ) ) {
        my @results = $self->History;
        foreach (@results) {
            chomp;
            s/$CR$//;
            s/^\*\s+SORT\s+// or next;
            push @hits, grep /\d/, split;
        }
    }
    return wantarray ? @hits : \@hits;
}

sub _list_or_lsub {
    my ( $self, $cmd, $reference, $target ) = @_;
    defined $reference or $reference = '';
    defined $target    or $target    = '*';
    length $target     or $target    = '""';

    $target eq '*' || $target eq '""'
      or $target = $self->Quote($target);

    $self->_imap_command(qq($cmd "$reference" $target))
      or return undef;

    return wantarray ? $self->Escaped_history : $self->Escaped_results;
}

sub list { shift->_list_or_lsub( "LIST", @_ ) }
sub lsub { shift->_list_or_lsub( "LSUB", @_ ) }

# deprecated 3.34
sub xlist {
    my ($self) = @_;
    return undef unless $self->has_capability("XLIST");
    shift->_list_or_lsub( "XLIST", @_ );
}

sub _folders_or_subscribed {
    my ( $self, $method, $what ) = @_;
    my @folders;

    # do BLOCK allowing use of "last if undef/error" and avoiding dup code
    do {
        {
            my @list;
            if ($what) {
                my $sep = $self->separator($what) || $self->separator(undef);
                last unless defined $sep;

                my $whatsub = $what =~ m/\Q${sep}\E$/ ? "$what*" : "$what$sep*";

                my $tref = $self->$method( undef, $whatsub ) or last;
                shift @$tref;    # remove command
                push @list, @$tref;

                # BUG?: this behavior has been around since 2.x, why?
                my $cansel = $self->selectable($what);
                last unless defined $cansel;
                if ($cansel) {
                    $tref = $self->$method( undef, $what ) or last;
                    shift @$tref;    # remove command
                    push @list, @$tref;
                }
            }
            else {
                my $tref = $self->$method( undef, undef ) or last;
                shift @$tref;        # remove command
                push @list, @$tref;
            }

            foreach my $resp (@list) {
                my $rec = $self->_list_or_lsub_response_parse($resp);
                next unless defined $rec->{name};
                push @folders, $rec;
            }
        }
    };

    my @clean = _remove_doubles @folders;
    return wantarray ? @clean : \@clean;
}

sub folders {
    my ( $self, $what ) = @_;

    my @folders =
      map( $_->{name}, $self->_folders_or_subscribed( "list", $what ) );
    return wantarray ? @folders : \@folders;
}

sub folders_hash {
    my ( $self, $what ) = @_;

    my @folders_hash = $self->_folders_or_subscribed( "list", $what );
    return wantarray ? @folders_hash : \@folders_hash;
}

# deprecated 3.34
sub xlist_folders {
    my ($self) = @_;
    my $xlist = $self->xlist;
    return undef unless defined $xlist;

    my %xlist;
    my $xlist_re = qr/\A\\(Inbox|AllMail|Trash|Drafts|Sent|Spam|Starred)\Z/;

    for my $resp (@$xlist) {
        my $rec = $self->_list_or_lsub_response_parse($resp);
        next unless defined $rec->{name};
        for my $attr ( @{ $rec->{attrs} } ) {
            $xlist{$1} = $rec->{name} if ( $attr =~ $xlist_re );
        }
    }

    return wantarray ? %xlist : \%xlist;
}

sub subscribed {
    my ( $self, $what ) = @_;
    my @folders =
      map( $_->{name}, $self->_folders_or_subscribed( "lsub", $what ) );
    return wantarray ? @folders : \@folders;
}

sub deleteacl {
    my ( $self, $target, $user ) = @_;
    $target = $self->Quote($target);
    $user   = $self->Quote($user);

    $self->_imap_command(qq(DELETEACL $target $user))
      or return undef;

    return wantarray ? $self->History : $self->Results;
}

sub setacl {
    my ( $self, $target, $user, $acl ) = @_;
    $target ||= $self->Folder;
    $target = $self->Quote($target);

    $user ||= $self->User;
    $user = $self->Quote($user);
    $acl  = $self->Quote($acl);

    $self->_imap_command(qq(SETACL $target $user $acl))
      or return undef;

    return wantarray ? $self->History : $self->Results;
}

sub getacl {
    my ( $self, $target ) = @_;
    defined $target or $target = $self->Folder;
    my $mtarget = $self->Quote($target);
    $self->_imap_command(qq(GETACL $mtarget))
      or return undef;

    my @history = $self->History;
    my $hash;
    for ( my $x = 0 ; $x < @history ; $x++ ) {
        next if $history[$x] !~ /^\* ACL/;

        my $perm =
            $history[$x] =~ /^\* ACL $/
          ? $history[ ++$x ] . $history[ ++$x ]
          : $history[$x];

        $perm =~ s/\s?$CRLF$//o;
        until ( $perm =~ /\Q$target\E"?$/ || !$perm ) {
            $perm =~ s/\s([^\s]+)\s?$// or last;
            my $p = $1;
            $perm =~ s/\s([^\s]+)\s?$// or last;
            my $u = $1;
            $hash->{$u} = $p;
            $self->_debug("Permissions: $u => $p");
        }
    }
    return $hash;
}

sub listrights {
    my ( $self, $target, $user ) = @_;
    $target ||= $self->Folder;
    $target = $self->Quote($target);

    $user ||= $self->User;
    $user = $self->Quote($user);

    $self->_imap_command(qq(LISTRIGHTS $target $user))
      or return undef;

    my $resp = first { /^\* LISTRIGHTS/ } $self->History;
    my @rights = split /\s/, $resp;
    my $rights = join '', @rights[ 4 .. $#rights ];
    $rights =~ s/"//g;
    return wantarray ? split( //, $rights ) : $rights;
}

sub select {
    my ( $self, $target ) = @_;
    defined $target or return undef;

    my $qqtarget = $self->Quote($target);
    my $old      = $self->Folder;

    $self->_imap_command("SELECT $qqtarget")
      or return undef;

    $self->State(Selected);
    $self->Folder($target);
    return $old || $self;    # ??$self??
}

sub message_string {
    my ( $self, $msg ) = @_;

    return undef unless defined $self->imap4rev1;
    my $peek = $self->Peek      ? '.PEEK'        : '';
    my $cmd  = $self->imap4rev1 ? "BODY$peek\[]" : "RFC822$peek";

    my $string;
    $self->message_to_file( \$string, $msg );

    unless ( $self->Ignoresizeerrors ) {    # Check size with expected size
        my $expected_size = $self->size($msg);
        return undef unless defined $expected_size;

        # RFC822.SIZE may be wrong, see RFC2683 3.4.5 "RFC822.SIZE"
        if ( length($string) != $expected_size ) {
            $self->LastError( "message_string() "
                  . "expected $expected_size bytes but received "
                  . length($string)
                  . " you may need the IgnoreSizeErrors option" );
            return undef;
        }
    }

    return $string;
}

sub bodypart_string {
    my ( $self, $msg, $partno, $bytes, $offset ) = @_;

    unless ( $self->imap4rev1 ) {
        $self->LastError( "Unable to get body part; server "
              . $self->Server
              . " does not support IMAP4REV1" )
          unless $self->LastError;
        return undef;
    }

    $offset ||= 0;
    my $cmd = "BODY"
      . ( $self->Peek ? '.PEEK' : '' )
      . "[$partno]"
      . ( $bytes ? "<$offset.$bytes>" : '' );

    $self->fetch( $msg, $cmd )
      or return undef;

    $self->_transaction_literals;
}

# message_to_file( $self, $file, @msgs )
sub message_to_file {
    my ( $self, $file, @msgs ) = @_;

    # $file can be a name or a scalar reference (for in memory file)
    # avoid IO::File bug handling scalar refs in perl <= 5.8.8?
    # - buggy: $fh = IO::File->new( $file, 'r' )
    my $fh;
    if ( ref $file and ref $file ne "SCALAR" ) {
        $fh = $file;
    }
    else {
        $$file = "" if ( ref $file eq "SCALAR" and !defined $$file );
        local ($!);
        open( $fh, ">>", $file );
        unless ( defined($fh) ) {
            $self->LastError("Unable to open file '$file': $!");
            return undef;
        }
    }

    binmode($fh);

    unless (@msgs) {
        $self->LastError("message_to_file: NO messages specified!");
        return undef;
    }

    my $peek = $self->Peek ? '.PEEK' : '';
    $peek = sprintf( $self->imap4rev1 ? "BODY%s\[]" : "RFC822%s", $peek );

    my @args = ( join( ",", @msgs ), $peek );

    return $self->_imap_uid_command( { outref => $fh }, "FETCH" => @args )
      ? $self
      : undef;
}

sub message_uid {
    my ( $self, $msg ) = @_;

    my $ref = $self->fetch( $msg, "UID" ) or return undef;
    foreach (@$ref) {
        return $1 if m/\(UID\s+(\d+)\s*\)$CR?$/o;
    }
    return undef;
}

# cleaned up and simplified but see TODO in code...
sub migrate {
    my ( $self, $peer, $msgs, $folder ) = @_;

    unless ( $peer and $peer->IsConnected ) {
        $self->LastError( ( $peer ? "Invalid" : "Unconnected" )
            . " target "
              . ref($self)
              . " object in migrate()"
              . ( $peer ? ( ": " . $peer->LastError ) : "" ) );
        return undef;
    }

    # sanity check to see if $self is same object as $peer
    if ( $self eq $peer ) {
        $self->LastError("dest must not be the same object as self");
        return undef;
    }

    $folder = $self->Folder unless ( defined $folder );
    unless ($folder) {
        $self->LastError("No folder selected on source mailbox.");
        return undef;
    }

    unless ( $peer->exists($folder) or $peer->create($folder) ) {
        $self->LastError( "Create folder '$folder' on target host failed: "
              . $peer->LastError );
        return undef;
    }

    if ( !defined $msgs or uc($msgs) eq "ALL" ) {
        $msgs = $self->search("ALL") or return undef;
    }

    # message size and (internal) date
    my @headers = qw(RFC822.SIZE INTERNALDATE FLAGS);
    my $range   = $self->Range($msgs);

    $self->_debug("Messages to migrate from '$folder': $range");

    foreach my $mid ( $range->unfold ) {

        # fetch size internaldate and flags of original message
        # - TODO: add flags here...
        my $minfo = $self->fetch_hash( $mid, @headers )
          or return undef;

        my ( $size, $date ) = @{ $minfo->{$mid} }{@headers};
        return undef unless ( defined $size and defined $date );

        $self->_debug("Copy message $mid (sz=$size,dt=$date) from '$folder'");

        my @flags = grep !/\\Recent/i, $self->flags($mid);
        my $flags = join ' ', $peer->supported_flags(@flags);

        # TODO: - use File::Temp tempfile if $msg > bufferSize?
        # read message to $msg
        my $msg;
        $self->message_to_file( \$msg, $mid )
          or return undef;

        my $newid = $peer->append_file( $folder, \$msg, undef, $flags, $date );

        unless ( defined $newid ) {
            $self->LastError(
                "Append to '$folder' on target failed: " . $peer->LastError );
            return undef;
        }

        $self->_debug("Copied UID $mid in '$folder' to target UID $newid");
    }

    return $self;
}

# Optimization of wait time between syswrite calls only runs if syscalls
# run too fast and fill the buffer causing "EAGAIN: Resource Temp. Unavail"
# errors. The premise is that $maxwrite will be approx. the same as the
# smallest buffer between the sending and receiving side. Waiting time
# between syscalls should ideally be exactly as long as it takes the
# receiving side to empty that buffer, minus a little bit to prevent it
# from emptying completely and wasting time in the select call.

sub _optimal_sleep($$$) {
    my ( $self, $maxwrite, $waittime, $last5writes ) = @_;

    push @$last5writes, $waittime;
    shift @$last5writes if @$last5writes > 5;

    my $bufferavail = ( sum @$last5writes ) / @$last5writes;

    if ( $bufferavail < .4 * $maxwrite ) {

        # Buffer is staying pretty full; we should increase the wait
        # period to reduce transmission overhead/number of packets sent
        $waittime *= 1.3;
    }
    elsif ( $bufferavail > .9 * $maxwrite ) {

        # Buffer is nearly or totally empty; we're wasting time in select
        # call that could be used to send data, so reduce the wait period
        $waittime *= .5;
    }

    CORE::select( undef, undef, undef, $waittime );
    $waittime;
}

sub body_string {
    my ( $self, $msg ) = @_;
    my $ref =
      $self->fetch( $msg, "BODY" . ( $self->Peek ? ".PEEK" : "" ) . "[TEXT]" )
      or return undef;

    my $string = join '', map { $_->[DATA] }
      grep { $self->_is_literal($_) } @$ref;

    return $string
      if $string;

    my $head;
    while ( $head = shift @$ref ) {
        $self->_debug("body_string: head = '$head'");

        last
          if $head =~
          /(?:.*FETCH .*\(.*BODY\[TEXT\])|(?:^\d+ BAD )|(?:^\d NO )/i;
    }

    unless (@$ref) {
        $self->LastError(
            "Unable to parse server response from " . $self->LastIMAPCommand );
        return undef;
    }

    my $popped;
    $popped = pop @$ref
      until ( $popped && $popped =~ /^\)$CRLF$/o )
      || !grep /^\)$CRLF$/o, @$ref;

    if ( $head =~ /BODY\[TEXT\]\s*$/i ) {    # Next line is a literal
        $string .= shift @$ref while @$ref;
        $self->_debug("String is now $string")
          if $self->Debug;
    }

    $string;
}

sub examine {
    my ( $self, $target ) = @_;
    defined $target or return undef;

    $self->_imap_command( 'EXAMINE ' . $self->Quote($target) )
      or return undef;

    my $old = $self->Folder;
    $self->Folder($target);
    $self->State(Selected);
    $old || $self;
}

sub idle {
    my $self  = shift;
    my $good  = '+';
    my $count = $self->Count + 1;
    $self->_imap_command( "IDLE", $good ) ? $count : undef;
}

sub idle_data {
    my $self    = shift;
    my $timeout = scalar(@_) ? shift : 0;
    my $socket  = $self->Socket;

    # current index in Results array
    my $trans_c1 = $self->_next_index;

    # look for all untagged responses
    my ( $rc, $ret );

    do {
        $ret =
          $self->_read_more( { error_on_timeout => 0 }, $socket, $timeout );

        # set rc on first pass or on errors
        $rc = $ret if ( !defined($rc) or $ret < 0 );

        # not using /\S+/ because that can match 0 in "* 0 RECENT"
        # leading the library to act as if things failed
        if ( $ret > 0 ) {
            $self->_get_response( '*', qr/(?!BAD|BYE|NO)(?:\d+\s+\w+|\S+)/ )
              or return undef;
            $timeout = 0;    # check for more data without blocking!
        }
    } while $ret > 0 and $self->IsConnected;

    # select returns -1 on errors
    return undef if $rc < 0;

    my $trans_c2 = $self->_next_index;

    # if current index in Results array has changed return data
    my @res;
    if ( $trans_c1 < $trans_c2 ) {
        @res = $self->Results;
        @res = @res[ $trans_c1 .. ( $trans_c2 - 1 ) ];
    }
    return wantarray ? @res : \@res;
}

sub done {
    my $self = shift;
    my $count = shift || $self->Count;

    # DONE looks like a tag when sent and not already in IDLE
    $self->_imap_command(
        { addtag => 0, tag => qr/(?:$count|DONE)/, doretry => 0 }, "DONE" )
      or return undef;
    return $self->Results;
}

# tag_and_run( $self, $string, $good )
sub tag_and_run {
    my $self = shift;
    $self->_imap_command(@_) or return undef;
    return $self->Results;
}

sub reconnect {
    my $self = shift;

    if ( $self->IsAuthenticated ) {
        $self->_debug("reconnect called but already authenticated");
        return 1;
    }

    # safeguard from deep recursion via connect
    if ( $self->{_doing_reconnect} ) {
        $self->_debug("recursive call to reconnect, returning 0\n");
        $self->LastError("unexpected reconnect recursion")
          unless $self->LastError;
        return 0;
    }

    my $einfo = $self->LastError || "";
    $self->_debug( "reconnecting to ", $self->Server, ", last error: $einfo" );
    $self->{_doing_reconnect} = 1;

    # reconnect and select appropriate folder
    my $ret;
    if ( $self->connect ) {
        $ret = 1;
        if ( defined $self->Folder ) {
            $ret = defined( $self->select( $self->Folder ) ) ? 1 : undef;
        }
    }

    delete $self->{_doing_reconnect};
    return $ret ? 1 : $ret;
}

# wrapper for _imap_command_do to enable retrying on lost connections
# options:
#   doretry => 0|1 - suppress|allow retry after reconnect
sub _imap_command {
    my $self = shift;
    my $opt = ref( $_[0] ) eq "HASH" ? $_[0] : {};

    my $tries = 0;
    my $retry = $self->Reconnectretry || 0;
    my ( $rc, @err );

    # LastError (if set) will be overwritten masking any earlier errors
    while ( $tries++ <= $retry ) {

        # do command on the first try or if Connected (reconnect ongoing)
        if ( $tries == 1 or $self->IsConnected ) {
            $rc = $self->_imap_command_do(@_);
            push( @err, $self->LastError ) if $self->LastError;
        }

        if ( !defined($rc) and $retry and $self->IsUnconnected ) {
            last
              unless (
                   $! == EPIPE
                or $! == ECONNRESET
                or $self->LastError =~ /(?:error\(.*?\)|timeout) waiting\b/
                or $self->LastError =~ /(?:socket closed|\* BYE)\b/

                # BUG? reconnect if caller ignored/missed earlier errors?
                # or $self->LastError =~ /NO not connected/
              );
            my $ret = $self->reconnect;
            if ($ret) {
                $self->_debug("reconnect success($ret) on try #$tries/$retry");
                last if exists $opt->{doretry} and !$opt->{doretry};
            }
            elsif ( defined $ret and $ret == 0 ) {    # escaping recursion
                return undef;
            }
            else {
                $self->_debug("reconnect failure on try #$tries/$retry");
                push( @err, $self->LastError ) if $self->LastError;
            }
        }
        else {
            last;
        }
    }

    unless ($rc) {
        my ( %seen, @keep, @info );

        foreach my $str (@err) {
            my ( $sz, $len ) = ( 96, length($str) );
            $str =~ s/$CR?$LF$/\\n/omg;
            if ( !$self->Debug and $len > $sz * 2 ) {
                my $beg = substr( $str, 0,    $sz );
                my $end = substr( $str, -$sz, $sz );
                $str = $beg . "..." . $end;
            }
            next if $seen{$str}++;
            push( @keep, $str );
        }
        foreach my $msg (@keep) {
            push( @info, $msg . ( $seen{$msg} > 1 ? " ($seen{$msg}x)" : "" ) );
        }
        $self->LastError( join( "; ", @info ) );
    }

    return $rc;
}

# _imap_command_do runs a command, inserting a tag and CRLF as requested
# options:
#   addcrlf => 0|1  - suppress adding CRLF to $string
#   addtag  => 0|1  - suppress adding $tag to $string
#   tag     => $tag - use this $tag instead of incrementing $self->Count
#   outref  => ...  - see _get_response()
sub _imap_command_do {
    my $self   = shift;
    my $opt    = ref( $_[0] ) eq "HASH" ? shift : {};
    my $string = shift or return undef;
    my $good   = shift;

    my @gropt = ( $opt->{outref} ? { outref => $opt->{outref} } : () );

    $opt->{addcrlf} = 1 unless exists $opt->{addcrlf};
    $opt->{addtag}  = 1 unless exists $opt->{addtag};

    # reset error in case the last error was non-fatal but never cleared
    if ( $self->LastError ) {

        #DEBUG $self->_debug( "Reset LastError: " . $self->LastError );
        $self->LastError(undef);
    }

    my $clear = $self->Clear;
    $self->Clear($clear)
      if $self->Count >= $clear && $clear > 0;

    my $count = $self->Count( $self->Count + 1 );
    my $tag = $opt->{tag} || $count;
    $string = "$tag $string" if $opt->{addtag};

    # for APPEND (append_string) only log first line of command
    my $logstr = ( $string =~ /^($tag\s+APPEND\s+.*?)$CR?$LF/ ) ? $1 : $string;

    # BUG? use $self->_next_index($tag) ? or 0 ???
    # $self->_record($tag, [$self->_next_index($tag), "INPUT", $logstr] );
    $self->_record( $count, [ 0, "INPUT", $logstr ] );

    # $suppress (adding CRLF) set to 0 if $opt->{addcrlf} is TRUE
    unless ( $self->_send_line( $string, $opt->{addcrlf} ? 0 : 1 ) ) {
        $self->LastError( "Error sending '$logstr': " . $self->LastError );
        return undef;
    }

    # look for "<tag> (OK|BAD|NO|$good)" (or "+..." if $good is '+')
    my $code = $self->_get_response( @gropt, $tag, $good ) or return undef;

    if ( $code eq 'OK' ) {
        return $self;
    }
    elsif ( $good and $code eq $good ) {
        return $self;
    }
    else {
        return undef;
    }
}

sub _response_code_sub {
    my ( $self, $tag, $good ) = @_;

    # tag/good can be a ref (compiled regex) otherwise quote it
    my $qtag  = ref($tag)  ? $tag  : defined($tag)  ? quotemeta($tag)  : undef;
    my $qgood = ref($good) ? $good : defined($good) ? quotemeta($good) : undef;

    # using closure, a variable alias, and sub returns on first match
    # - $_[0] is $o->[DATA]
    # - returns list ( $code, $byemsg )
    my $getcodesub = sub {
        if ( defined $qgood ) {
            if ( $good eq '+' and $_[0] =~ /^$qgood/ ) {
                return ($good);
            }
            if ( defined $qtag and $_[0] =~ /^$qtag\s+($qgood)/i ) {
                return ( ref($qgood) ? $1 : uc($1) );
            }
        }
        if ( defined $qtag ) {
            if ( $tag eq '+' and $_[0] =~ /^$qtag/ ) {
                return ($tag);
            }
            if ( $_[0] =~ /^$qtag\s+(OK|BAD|NO)\b/i ) {
                my $code = uc($1);
                $self->LastError( $_[0] ) unless ( $code eq 'OK' );
                return ($code);
            }
        }
        if ( $_[0] =~ /^\*\s+(BYE)\b/i ) {
            return ( uc($1), $_[0] );    # ( 'BYE', $byemsg )
        }
        return (undef);
    };

    return $getcodesub;
}

# _get_response get IMAP response optionally send data somewhere
# options:
#   outref => GLOB|CODE - reference to send output to (see _read_line)
sub _get_response {
    my $self = shift;
    my $opt  = ref( $_[0] ) eq "HASH" ? shift : {};
    my $tag  = shift;
    my $good = shift;

    my $outref  = $opt->{outref};
    my @readopt = defined($outref) ? ($outref) : ();
    my $getcode = $self->_response_code_sub( $tag, $good );

    my ( $count, $out, $code, $byemsg ) = ( $self->Count, [], undef, undef );
    until ( defined $code ) {
        my $output = $self->_read_line(@readopt) or return undef;
        $out = $output;    # keep last response just in case

        # not using last on first match? paranoia or right thing?
        # only uc() when match is not on case where $tag|$good is a ref()
        foreach my $o (@$output) {
            $self->_record( $count, $o );
            $self->_is_output($o) or next;
            my ( $tcode, $tbyemsg ) = $getcode->( $o->[DATA] );
            $code   = $tcode   if ( defined $tcode );
            $byemsg = $tbyemsg if ( defined $tbyemsg );
        }
    }

    if ( defined $code ) {
        $code =~ s/$CR?$LF?$//o;
        $code = uc($code) unless ( $good and $code eq $good );

        # RFC 3501 7.1.5: $code on successful LOGOUT is OK not BYE
        # sometimes we may fail to wait long enough to read a tagged
        # OK so don't be strict about setting an error on LOGOUT!
        if ( $code eq 'BYE' ) {
            $self->State(Unconnected);
            if ($byemsg) {
                $self->LastError($byemsg)
                  unless ( $good and $code eq $good );
            }
        }
    }
    elsif ( !$self->LastError ) {
        my $info = "unexpected response: " . join( " ", @$out );
        $self->LastError($info);
    }

    return $code;
}

sub _imap_uid_command {
    my $self = shift;
    my @opt  = ref( $_[0] ) eq "HASH" ? (shift) : ();
    my $cmd  = shift;

    my $args = @_ ? join( " ", '', @_ ) : '';
    my $uid = $self->Uid ? 'UID ' : '';
    $self->_imap_command( @opt, "$uid$cmd$args" );
}

sub run {
    my $self = shift;
    my $string = shift or return undef;

    my $tag = $string =~ /^(\S+) / ? $1 : undef;
    unless ($tag) {
        $self->LastError("No tag found in string passed to run(): $string");
        return undef;
    }

    $self->_imap_command( { addtag => 0, addcrlf => 0, tag => $tag }, $string )
      or return undef;

    $self->{History}{$tag} = $self->{History}{ $self->Count }
      unless $tag eq $self->Count;

    return $self->Results;
}

# _record saves the conversation into the History structure:
sub _record {
    my ( $self, $count, $array ) = @_;
    if ( $array->[DATA] =~ /^\d+ LOGIN/i && !$self->Showcredentials ) {
        $array->[DATA] =~ s/LOGIN.*/LOGIN XXXXXXXX XXXXXXXX/i;
    }

    push @{ $self->{History}{$count} }, $array;
}

# try to avoid exposing auth info via debug unless Showcredentials is true
sub _redact_line {
    my ( $self, $string ) = @_;
    $self->Showcredentials and return undef;

    my ( $tag, $cmd ) = ( $self->Count, undef );
    my $retext = "[Redact: Count=$tag Showcredentials=OFF]";
    my $show   = $retext;

    # tagged command?
    if ( $string =~ s/^($tag\s+(\S+)\s+)// ) {
        ( $show, $cmd ) = ( $1, $2 );

        # login <username|literal> <password|literal>
        if ( $cmd =~ /login/i ) {

            # username as literal
            if ( $string =~ /^{/ ) {
                $show .= $string;
            }

            # username (possibly quoted) string, then literal? password
            elsif ( $string =~ s/^((?:"(?>(?:(?>[^"\\]+)|\\.)*)"|\S+)\s*)// ) {
                $show .= $1;
                $show .= ( $string =~ /^{/ ) ? $string : $retext;
            }
        }
        elsif ( $cmd =~ /^auth/i ) {
            $show .= $string;
        }
        else {
            return undef;    # show it all
        }
    }

    return $show;
}

# _send_line handles literal data and supports the Prewritemethod
sub _send_line {
    my ( $self, $string, $suppress ) = @_;

    $string =~ s/$CR?$LF?$/$CRLF/o
      unless $suppress;

    # handle case where string contains a literal
    if ( $string =~ s/^([^$LF\{]*\{\d+\}$CRLF)(?=.)//o ) {
        my $first = $1;
        if ( $self->Debug ) {
            my $dat =
              ( $self->IsConnected and !$self->IsAuthenticated )
              ? $self->_redact_line($string)
              : undef;
            $self->_debug( "Sending literal: $first\tthen: ", $dat || $string );
        }
        $self->_send_line($first) or return undef;

        # look for "$tag NO" or "+ ..."
        my $code = $self->_get_response( $self->Count, '+' ) or return undef;
        return undef unless $code eq '+';
    }

    # non-literal part continues...
    if ( my $prew = $self->Prewritemethod ) {
        $string = $prew->( $self, $string );
    }

    if ( $self->Debug ) {
        my $dat =
          ( $self->IsConnected and !$self->IsAuthenticated )
          ? $self->_redact_line($string)
          : undef;
        $self->_debug( "Sending: ", $dat || $string );
    }

    unless ( $self->IsConnected ) {
        $self->LastError("NO not connected");
        return undef;
    }

    $self->_send_bytes( \$string );
}

sub _send_bytes($) {
    my ( $self, $byteref ) = @_;
    my ( $total, $temperrs, $maxwrite ) = ( 0, 0, 0 );
    my $waittime = .02;
    my @previous_writes;

    my $maxagain = $self->Maxtemperrors;
    undef $maxagain if $maxagain and lc($maxagain) eq 'unlimited';

    local $SIG{PIPE} = 'IGNORE';    # handle SIGPIPE as normal error

    my $socket = $self->Socket;
    while ( $total < length $$byteref ) {
        my $written =
          syswrite( $socket, $$byteref, length($$byteref) - $total, $total );

        if ( defined $written ) {
            $temperrs = 0;
            $total += $written;
            next;
        }

        if ( $! == EAGAIN ) {
            if ( defined $maxagain && $temperrs++ > $maxagain ) {
                $self->LastError("Persistent error '$!'");
                return undef;
            }

            $waittime =
              $self->_optimal_sleep( $maxwrite, $waittime, \@previous_writes );
            next;
        }

        # Unconnected might be apropos for more than just these?
        my $emsg = $! ? "$!" : "no error caught";
        $self->State(Unconnected)
          if ( $! == EPIPE or $! == ECONNRESET or $! == EBADF );
        $self->LastError("Write failed '$emsg'");

        return undef;    # no luck
    }

    $self->_debug("Sent $total bytes");
    return $total;
}

# _read_line: read one line from the socket
#
# $output = $self->_read_line($literal_callback)
#    literal_callback is optional, but if supplied it must be either
#    be a filehandle, coderef, or undef.
#
#    Returns a reference to an array of arrays, i.e.:
#    $output = [
#        [ $index, 'OUTPUT|LITERAL', $output_line ],
#        [ $index, 'OUTPUT|LITERAL', $output_line ],
#        ...
#    \];

# BUG?: make memory more efficient
sub _read_line {
    my ( $self, $literal_callback ) = @_;

    my $socket = $self->Socket;
    unless ( $self->IsConnected && $socket ) {
        $self->LastError("NO not connected");
        return undef;
    }

    my $iBuffer = "";
    my $oBuffer = [];
    my $index   = $self->_next_index;
    my $timeout = $self->Timeout;
    my $readlen = $self->Buffer || 4096;
    my $transno = $self->Transaction;

    my $literal_cbtype = "";
    if ($literal_callback) {
        if ( UNIVERSAL::isa( $literal_callback, "GLOB" ) ) {
            $literal_cbtype = "GLOB";
        }
        elsif ( UNIVERSAL::isa( $literal_callback, "CODE" ) ) {
            $literal_cbtype = "CODE";
        }
        else {
            $self->LastError( "'$literal_callback' is an "
                  . "invalid callback; must be a filehandle or CODE" );
            return undef;
        }
    }

    my $temperrs = 0;
    my $maxagain = $self->Maxtemperrors;
    undef $maxagain if $maxagain and lc($maxagain) eq 'unlimited';

    until (
        @$oBuffer    # there's stuff in output buffer:
          && $oBuffer->[-1][TYPE] eq 'OUTPUT'    # that thing is an output line:
          && $oBuffer->[-1][DATA] =~
          /$CR?$LF$/o            # the last thing there has cr-lf:
          && !length $iBuffer    # and the input buffer has been MT'ed:
      )
    {

        if ($timeout) {
            my $rc = $self->_read_more( $socket, $timeout );
            return undef unless ( $rc > 0 );
        }

        my $emsg;
        my $ret =
          $self->_sysread( $socket, \$iBuffer, $readlen, length $iBuffer );

        if ($timeout) {
            if ( defined $ret ) {
                $temperrs = 0;
            }
            else {
                $emsg = "error while reading data from server: $!";
                if ( $! == ECONNRESET ) {
                    $self->State(Unconnected);
                }
                elsif ( $! == EAGAIN ) {
                    if ( defined $maxagain && $temperrs++ >= $maxagain ) {
                        $emsg .= " ($temperrs)";
                    }
                    else {
                        next;    # try again
                    }
                }
            }
        }

        if ( defined $ret && $ret == 0 ) {    # Caught EOF...
            $emsg = "socket closed while reading data from server";
            $self->State(Unconnected);
        }

        # save errors and return
        if ($emsg) {
            $self->LastError($emsg);
            $self->_record(
                $transno,
                [
                    $self->_next_index($transno), "ERROR", "$transno * NO $emsg"
                ]
            );
            return undef;
        }

        while ( $iBuffer =~ s/^(.*?$CR?$LF)//o )    # consume line
        {
            my $current_line = $1;
            if ( $current_line !~ s/\{(\d+)\}$CR?$LF$//o ) {
                push @$oBuffer, [ $index++, 'OUTPUT', $current_line ];
                next;
            }

            push @$oBuffer, [ $index++, 'OUTPUT', $current_line ];

            ## handle LITERAL
            # BLAH BLAH {nnn}$CRLF
            # [nnn bytes of literally transmitted stuff]
            # [part of line that follows literal data]$CRLF

            my $expected_size = $1;

            $self->_debug( "LITERAL: received literal in line "
                  . "$current_line of length $expected_size; attempting to "
                  . "retrieve from the "
                  . length($iBuffer)
                  . " bytes in: $iBuffer<END_OF_iBuffer>" );

            my $litstring;
            if ( length $iBuffer >= $expected_size ) {

                # already received all data
                $litstring = substr $iBuffer, 0, $expected_size, '';
            }
            else {    # literal data still to arrive
                $litstring = $iBuffer;
                $iBuffer   = '';

                my $litreadb = length($litstring);
                my $temperrs = 0;
                my $maxagain = $self->Maxtemperrors;
                undef $maxagain if $maxagain and lc($maxagain) eq 'unlimited';

                while ( $expected_size > $litreadb ) {
                    if ($timeout) {
                        my $rc = $self->_read_more( $socket, $timeout );
                        return undef unless ( $rc > 0 );
                    }
                    else {    # 25 ms before retry
                        CORE::select( undef, undef, undef, 0.025 );
                    }

                    # $litstring is emptied when $literal_cbtype is GLOB
                    my $ret =
                      $self->_sysread( $socket, \$litstring,
                        $expected_size - $litreadb,
                        length($litstring) );

                    if ($timeout) {
                        if ( defined $ret ) {
                            $temperrs = 0;
                        }
                        else {
                            $emsg = "error while reading data from server: $!";
                            if ( $! == ECONNRESET ) {
                                $self->State(Unconnected);
                            }
                            elsif ( $! == EAGAIN ) {
                                if ( defined $maxagain
                                    && $temperrs++ >= $maxagain )
                                {
                                    $emsg .= " ($temperrs)";
                                }
                                else {
                                    undef $emsg;
                                    next;    # try again
                                }
                            }
                        }
                    }

                    # EOF: note IO::Socket::SSL does not support eof()
                    if ( defined $ret and $ret == 0 ) {
                        $emsg = "socket closed while reading data from server";
                        $self->State(Unconnected);
                    }
                    elsif ( defined $ret and $ret > 0 ) {
                        $litreadb += $ret;

                        # conserve memory when using literal_callback GLOB
                        if ( $literal_cbtype eq "GLOB" ) {
                            print $literal_callback $litstring;
                            $litstring = "" unless ($emsg);
                        }
                    }

                    $self->_debug( "Received ret="
                          . ( defined($ret) ? $ret : "<undef>" )
                          . " $litreadb of $expected_size" );

                    # save errors and return
                    if ($emsg) {
                        $self->LastError($emsg);
                        $self->_record(
                            $transno,
                            [
                                $self->_next_index($transno), "ERROR",
                                "$transno * NO $emsg"
                            ]
                        );
                        $litstring = "" unless defined $litstring;
                        $self->_debug( "ERROR while processing LITERAL, "
                              . " buffer=\n"
                              . $litstring
                              . "<END>\n" );
                        return undef;
                    }
                }
            }

            if ( defined $litstring ) {
                if ( $literal_cbtype eq "GLOB" ) {
                    print $literal_callback $litstring;
                }
                elsif ( $literal_cbtype eq "CODE" ) {
                    $literal_callback->($litstring);
                }
            }

            push @$oBuffer, [ $index++, 'LITERAL', $litstring ]
              if ( $literal_cbtype ne "GLOB" );
        }
    }

    $self->_debug( "Read: " . join "", map { "\t" . $_->[DATA] } @$oBuffer )
      if ( $self->Debug );

    @$oBuffer ? $oBuffer : undef;
}

sub _sysread {
    my ( $self, $fh, $buf, $len, $off ) = @_;
    my $rm = $self->Readmethod;
    $rm ? $rm->(@_) : sysread( $fh, $$buf, $len, $off );
}

sub _read_more {
    my $self = shift;
    my $rm   = $self->Readmoremethod;
    $rm ? $rm->( $self, @_ ) : $self->__read_more(@_);
}

sub __read_more {
    my $self = shift;
    my $opt = ref( $_[0] ) eq "HASH" ? shift : {};
    my ( $socket, $timeout ) = @_;

    # IO::Socket::SSL buffers some data internally, so there might be some
    # data available from the previous sysread of which the file-handle
    # (used by select()) doesn't know of.
    return 1 if $socket->isa("IO::Socket::SSL") && $socket->pending;

    my $rvec = '';
    vec( $rvec, fileno($socket), 1 ) = 1;

    my $rc = CORE::select( $rvec, undef, $rvec, $timeout );

    # fast track success
    return $rc if $rc > 0;

    # by default set an error on timeout
    my $err_on_timeout =
      exists $opt->{error_on_timeout} ? $opt->{error_on_timeout} : 1;

    # $rc is 0 then we timed out
    return $rc if !$rc and !$err_on_timeout;

    # set the appropriate error and return
    my $transno = $self->Transaction;
    my $msg =
        ( $rc ? "error($rc)" : "timeout" )
      . " waiting ${timeout}s for data from server"
      . ( $! ? ": $!" : "" );
    $self->LastError($msg);
    $self->_record( $transno,
        [ $self->_next_index($transno), "ERROR", "$transno * NO $msg" ] );
    $self->_disconnect;    # BUG: can not handle timeouts gracefully
    return $rc;
}

sub _trans_index() {
    sort { $a <=> $b } keys %{ $_[0]->{History} };
}

# all default to last transaction
sub _transaction(;$) {
    @{ $_[0]->{History}{ $_[1] || $_[0]->Transaction } || [] };
}

sub _trans_data(;$) {
    map { $_->[DATA] } $_[0]->_transaction( $_[1] );
}

sub _escaped_trans_data(;$) {
    my ( $self, $trans ) = @_;
    my @a;
    my $prevwasliteral = 0;
    foreach my $line ( $self->_transaction($trans) ) {
        next unless defined $line;

        my $data = $line->[DATA];

        # literal is appended to previous data
        if ( $self->_is_literal($line) ) {
            $data = $self->Escape($data);
            $a[-1] .= qq("$data");
            $prevwasliteral = 1;
        }
        else {
            if ($prevwasliteral) {
                $a[-1] .= $data;
            }
            else {
                push( @a, $data );
            }
            $prevwasliteral = 0;
        }
    }

    return wantarray ? @a : \@a;
}

sub Report {
    my $self = shift;
    map { $self->_trans_data($_) } $self->_trans_index;
}

sub LastIMAPCommand(;$) {
    my ( $self, $trans ) = @_;
    my $msg = ( $self->_transaction($trans) )[0];
    $msg ? $msg->[DATA] : undef;
}

sub History(;$) {
    my ( $self, $trans ) = @_;
    my ( $cmd,  @a )     = $self->_trans_data($trans);
    return wantarray ? @a : \@a;
}

sub Results(;$) {
    my ( $self, $trans ) = @_;
    my @a = $self->_trans_data($trans);
    return wantarray ? @a : \@a;
}

sub _transaction_literals() {
    my $self = shift;
    join '', map { $_->[DATA] }
      grep { $self->_is_literal($_) } $self->_transaction;
}

sub Escaped_history {
    my ( $self, $trans ) = @_;
    my ( $cmd,  @a )     = $self->_escaped_trans_data($trans);
    return wantarray ? @a : \@a;
}

sub Escaped_results {
    my ( $self, $trans ) = @_;
    my @a = $self->_escaped_trans_data($trans);
    return wantarray ? @a : \@a;
}

sub Escape {
    my $data = $_[1];
    $data =~ s/([\\\"])/\\$1/og;
    return $data;
}

sub Unescape {
    my $data = $_[1];
    $data =~ s/\\([\\\"])/$1/og;
    return $data;
}

sub logout {
    my $self = shift;
    my $rc = $self->_imap_command( "LOGOUT", "BYE" );
    $self->_disconnect;
    return $rc;
}

sub _disconnect {
    my $self = shift;

    delete $self->{CAPABILITY};
    delete $self->{_IMAP4REV1};
    $self->State(Unconnected);
    if ( my $sock = delete $self->{Socket} ) {
        local ($@);
        eval { $sock->close };
    }
    return $self;
}

# LIST/XLIST/LSUB Response
#   Contents: name attributes, hierarchy delimiter, name
#   Example: * LIST (\Noselect) "/" ~/Mail/foo
# NOTE: liberal matching as folder name data may be Escape()d
sub _list_or_lsub_response_parse {
    my ( $self, $resp ) = @_;

    return undef unless defined $resp;
    my %info;

    $resp =~ s/\015?\012$//;
    if (
        $resp =~ / ^\* \s+ (?:LIST|XLIST|LSUB) \s+ # * LIST|XLIST|LSUB
                 \( ([^\)]*) \)                \s+ # (attrs)
           (?:   \" ([^"]*)  \" | NIL  )       \s  # "delimiter" or NIL
           (?:\s*\" (.*)     \" | (.*) )           # "name" or name
         /ix
      )
    {
        @info{qw(attrs delim name)} =
          ( [ split( / /, $1 ) ], $2, defined($3) ? $self->Unescape($3) : $4 );
    }
    return wantarray ? %info : \%info;
}

sub exists {
    my ( $self, $folder ) = @_;
    $self->status($folder) ? $self : undef;
}

# Updated to handle embedded literal strings
sub get_bodystructure {
    my ( $self, $msg ) = @_;

    my $class = $self->_load_module("BodyStructure") or return undef;

    my $out = $self->fetch( $msg, "BODYSTRUCTURE" ) or return undef;

    my $bs = "";
    my $output = first { /BODYSTRUCTURE\s+\(/i } @$out;

    unless ( $output =~ /$CRLF$/o ) {
        $output = '';
        $self->_debug("get_bodystructure: reassembling original response");
        my $started = 0;
        foreach my $o ( $self->_transaction ) {
            next unless $self->_is_output_or_literal($o);
            $started++ if $o->[DATA] =~ /BODYSTRUCTURE \(/i;
            $started or next;

            if ( length($output) && $self->_is_literal($o) ) {
                my $data = $o->[DATA];
                $data =~ s/"/\\"/g;
                $data =~ s/\(/\\\(/g;
                $data =~ s/\)/\\\)/g;
                $output .= qq("$data");
            }
            else {
                $output .= $o->[DATA];
            }
        }
        $self->_debug("get_bodystructure: reassembled output=$output<END>");
    }

    {
        local ($@);
        $bs = eval { $class->new($output) };
    }

    $self->_debug(
        "get_bodystructure: msg $msg returns: " . ( $bs || "UNDEF" ) );
    $bs;
}

# Updated to handle embedded literal strings
sub get_envelope {
    my ( $self, $msg ) = @_;

    # Envelope class is defined within BodyStructure
    my $class = $self->_load_module("BodyStructure") or return undef;
    $class .= "::Envelope";

    my $out = $self->fetch( $msg, 'ENVELOPE' ) or return undef;

    my $bs = "";
    my $output = first { /ENVELOPE \(/i } @$out;

    unless ( $output =~ /$CRLF$/o ) {
        $output = '';
        $self->_debug("get_envelope: reassembling original response");
        my $started = 0;
        foreach my $o ( $self->_transaction ) {
            next unless $self->_is_output_or_literal($o);
            $started++ if $o->[DATA] =~ /ENVELOPE \(/i;
            $started or next;

            if ( length($output) && $self->_is_literal($o) ) {
                my $data = $o->[DATA];
                $data =~ s/"/\\"/g;
                $data =~ s/\(/\\\(/g;
                $data =~ s/\)/\\\)/g;
                $output .= qq("$data");
            }
            else {
                $output .= $o->[DATA];
            }
        }
        $self->_debug("get_envelope: reassembled output=$output<END>");
    }

    {
        local ($@);
        $bs = eval { $class->new($output) };
    }

    $self->_debug( "get_envelope: msg $msg returns: " . ( $bs || "UNDEF" ) );
    $bs;
}

# fetch( [{option},] [$seq_set|ALL], @msg_data_items )
# options:
#   escaped => 0|1  # return Results or Escaped_results
sub fetch {
    my $self = shift;
    my $opt  = ref( $_[0] ) eq "HASH" ? shift : {};
    my $what = shift || "ALL";

    my $take = $what;
    if ( $what eq 'ALL' ) {
        my $msgs = $self->messages or return undef;
        $take = $self->Range($msgs);
    }
    elsif ( ref $what || $what =~ /^[,:\d]+\w*$/ ) {
        $take = $self->Range($what);
    }

    my ( @data, $cmd );
    my ( $seq_set, @fetch_att ) = $self->_split_sequence( $take, "FETCH", @_ );

    for ( my $x = 0 ; $x <= $#$seq_set ; $x++ ) {
        my $seq = $seq_set->[$x];
        $self->_imap_uid_command( FETCH => $seq, @fetch_att, @_ )
          or return undef;
        my $res = $opt->{escaped} ? $self->Escaped_results : $self->Results;

        # only keep last command and last response (* OK ...)
        $cmd = shift(@$res);
        pop(@$res) if ( $x != $#{$seq_set} );
        push( @data, @$res );
    }

    if ( $cmd and !wantarray ) {
        $cmd =~ s/^(\d+\s+.*?FETCH\s+)\S+(\s*)/$1$take$2/;
        unshift( @data, $cmd );
    }

    #wantarray ? $self->History : $self->Results;
    return wantarray ? @data : \@data;
}

# Some servers have a maximum command length.  If Maxcommandlength is
# set, split a sequence to fit within the length restriction.
sub _split_sequence {
    my ( $self, $take, @args ) = @_;

    # split take => sequence-set and (optional) fetch-att
    my ( $seq, @att ) = split( / /, $take, 2 );

    # use the entire sequence unless Maxcommandlength is set
    my @seqs;
    my $maxl = $self->Maxcommandlength;
    if ($maxl) {

        # estimate command length, the sum of the lengths of:
        #   tag, command, fetch-att + $CRLF
        push @args, $self->Transaction, $self->Uid ? "UID" : (), "\015\012";

        # do not split on anything smaller than 64 chars
        my $clen = length join( " ", @att, @args );
        my $diff = $maxl - $clen;
        my $most = $diff > 64 ? $diff : 64;

        @seqs = ( $seq =~ m/(.{1,$most})(?:,|$)/g ) if defined $seq;
        $self->_debug( "split_sequence: length($maxl-$clen) parts: ",
            $#seqs + 1 )
          if ( $#seqs != 0 );
    }
    else {
        push( @seqs, $seq ) if defined $seq;
    }
    return \@seqs, @att;
}

# fetch_hash( [$seq_set|ALL], @msg_data_items, [\%msg_by_ids] )
# - TODO: make more efficient use of memory on large fetch results
sub fetch_hash {
    my $self  = shift;
    my $uids  = ref $_[-1] ? pop @_ : {};
    my @words = @_;

    # take an optional leading list of messages argument or default to
    # ALL let fetch turn that list of messages into a msgref as needed
    # fetch has similar logic for dealing with message list
    my $msgs = 'ALL';
    if ( defined $words[0] ) {
        if ( ref $words[0] ) {
            $msgs = shift @words;
        }
        else {
            if ( $words[0] eq 'ALL' ) {
                $msgs = shift @words;
            }
            elsif ( $words[0] =~ s/^([*,:\d]+)\s*// ) {
                $msgs = $1;
                shift @words if $words[0] eq "";
            }
        }
    }

    # message list (if any) is now removed from @words
    my $what = ( @words > 1 or $words[0] =~ /\s/ ) ? "(@words)" : "@words";

    # RFC 3501:
    #   fetch = "FETCH" SP sequence-set SP ("ALL" / "FULL" / "FAST" /
    #           fetch-att / "(" fetch-att *(SP fetch-att) ")")
    my $output = $self->fetch( $msgs, $what )
      or return undef;

    my $asked_for_uid = $what =~ /[\s(]UID[)\s]/i;

    while ( my $l = shift @$output ) {
        next if $l !~ m/^\*\s(\d+)\sFETCH\s\(/g;
        my ( $mid, $entry ) = ( $1, {} );
        my ( $key, $value );
      ATTR:
        while ( $l and $l !~ m/\G\s*\)\s*$/gc ) {
            if ( $l =~ m/\G\s*([^\s\[]+(?:\[[^\]]*\])?(?:<[^>]*>)?)\s*/gc ) {
                $key = uc($1);
            }
            elsif ( !defined $key ) {

                # some kind of malformed response
                $self->LastError("Invalid item name in FETCH response: $l");
                return undef;
            }
            if ( $l =~ m/\G\s*$/gc ) {
                $value         = shift @$output;
                $entry->{$key} = $value;
                $l             = shift @$output;
                next ATTR;
            }
            elsif (
                $l =~ m/\G(?:"((?>(?:(?>[^"\\]+)|\\.)*))"|([^()\s]+))\s*/gc )
            {
                $value = defined $1 ? $1 : $2;
                $entry->{$key} = $value;
                next ATTR;
            }
            elsif ( $l =~ m/\G\(/gc ) {
                my $depth = 1;
                $value = "";
                while ( $l =~
                    m/\G("((?>(?:(?>[^"\\]+)|\\.)*))"\s*|[()]|[^()"]+)/gc )
                {
                    my $stuff = $1;
                    if ( $stuff eq "(" ) {
                        $depth++;
                        $value .= "(";
                    }
                    elsif ( $stuff eq ")" ) {
                        $depth--;
                        if ( $depth == 0 ) {
                            $entry->{$key} = $value;
                            next ATTR;
                        }
                        $value .= ")";
                    }
                    else {
                        $value .= $stuff;
                    }

                    # consume literal data if any
                    if ( $l =~ m/\G\s*$/gc and scalar(@$output) ) {
                        my $elit = $self->Escape( shift @$output );
                        $l = shift @$output;
                        $value .= ( length($value) ? " " : "" ) . qq{"$elit"};
                    }
                }
                $l =~ m/\G\s*/gc;
            }
            else {
                $self->LastError("Invalid item value in FETCH response: $l");
                return undef;
            }
        }

        # NOTE: old code tried to remove any "unrequested" data in $entry
        # - UID is sometimes not explicitly requested, are there others?
        # - rt#115726: Uid and $entry->{UID} not set, ignore unsolicited data
        if ( $self->Uid ) {
            if ( $entry->{UID} ) {
                $uids->{ $entry->{UID} } = $entry;
                delete $entry->{UID} unless $asked_for_uid;
            }
            else {
                $self->_debug("ignoring unsolicited response: $l");
            }
        }
        else {
            $uids->{$mid} = $entry;
        }
    }

    return wantarray ? %$uids : $uids;
}

sub store {
    my ( $self, @a ) = @_;
    $self->_imap_uid_command( STORE => @a )
      or return undef;
    return wantarray ? $self->History : $self->Results;
}

sub _imap_folder_command($$@) {
    my ( $self, $command ) = ( shift, shift );
    my $folder = $self->Quote(shift);

    $self->_imap_command( join ' ', $command, $folder, @_ )
      or return undef;

    return wantarray ? $self->History : $self->Results;
}

sub subscribe($)   { shift->_imap_folder_command( SUBSCRIBE   => @_ ) }
sub unsubscribe($) { shift->_imap_folder_command( UNSUBSCRIBE => @_ ) }
sub create($)      { shift->_imap_folder_command( CREATE      => @_ ) }

sub delete($) {
    my $self = shift;
    $self->_imap_folder_command( DELETE => @_ ) or return undef;
    $self->Folder(undef);
    return wantarray ? $self->History : $self->Results;
}

# rfc2086
sub myrights($) { $_[0]->_imap_folder_command( MYRIGHTS => $_[1] ) }

sub close {
    my $self = shift;
    $self->_imap_command('CLOSE')
      or return undef;
    return wantarray ? $self->History : $self->Results;
}

sub expunge {
    my ( $self, $folder ) = @_;

    return undef unless ( defined $folder or defined $self->Folder );

    my $old = defined $self->Folder ? $self->Folder : '';

    if ( !defined($folder) || $folder eq $old ) {
        $self->_imap_command('EXPUNGE')
          or return undef;
    }
    else {
        $self->select($folder) or return undef;
        my $succ = $self->_imap_command('EXPUNGE');

        # if $old eq '' IMAP4 select should close $folder without EXPUNGE
        return undef unless ( $self->select($old) and $succ );
    }

    return wantarray ? $self->History : $self->Results;
}

sub uidexpunge {
    my ( $self, $msgspec ) = ( shift, shift );

    return undef unless $self->has_capability("UIDPLUS");
    unless ( $self->Uid ) {
        $self->LastError("Uid must be enabled for uidexpunge");
        return undef;
    }

    my $msg =
      UNIVERSAL::isa( $msgspec, 'Mail::IMAPClient::MessageSet' )
      ? $msgspec
      : $self->Range($msgspec);

    $msg->cat(@_) if @_;

    my ( @data, $cmd );
    my ($seq_set) = $self->_split_sequence( $msg, "UID EXPUNGE" );

    for ( my $x = 0 ; $x <= $#$seq_set ; $x++ ) {
        my $seq = $seq_set->[$x];
        $self->_imap_uid_command( "EXPUNGE" => $seq )
          or return undef;
        my $res = $self->Results;

        # only keep last command and last response (* OK ...)
        $cmd = shift(@$res);
        pop(@$res) if ( $x != $#{$seq_set} );
        push( @data, @$res );
    }

    if ( $cmd and !wantarray ) {
        $cmd =~ s/^(\d+\s+.*?EXPUNGE\s+)\S+(\s*)/$1$msg$2/;
        unshift( @data, $cmd );
    }

    #wantarray ? $self->History : $self->Results;
    return wantarray ? @data : \@data;
}

sub rename {
    my ( $self, $from, $to ) = @_;

    $from = $self->Quote($from);
    $to   = $self->Quote($to);

    $self->_imap_command(qq(RENAME $from $to)) ? $self : undef;
}

sub status {
    my ( $self, $folder ) = ( shift, shift );
    defined $folder or return undef;

    my $which = @_ ? join( " ", @_ ) : 'MESSAGES';

    my $box = $self->Quote($folder);
    $self->_imap_command("STATUS $box ($which)")
      or return undef;

    return wantarray ? $self->History : $self->Results;
}

sub flags {
    my ( $self, $msgspec ) = ( shift, shift );
    my $msg =
      UNIVERSAL::isa( $msgspec, 'Mail::IMAPClient::MessageSet' )
      ? $msgspec
      : $self->Range($msgspec);

    $msg->cat(@_) if @_;

    # Send command
    my $ref = $self->fetch( $msg, "FLAGS" ) or return undef;

    my $u_f     = $self->Uid;
    my $flagset = {};

    # Parse results, setting entry in result hash for each line
    foreach my $line (@$ref) {
        $self->_debug("flags: line = '$line'");
        if (
            $line =~ /\* \s+ (\d+) \s+ FETCH \s+    # * nnn FETCH
             \(
               (?:\s* UID \s+ (\d+) \s* )? # optional: UID nnn <space>
               FLAGS \s* \( (.*?) \) \s*   # FLAGS (\Flag1 \Flag2) <space>
               (?:\s* UID \s+ (\d+) \s* )? # optional: UID nnn
             \)
            /x
          )
        {
            my $mailid = $u_f ? ( $2 || $4 ) : $1;
            $flagset->{$mailid} = [ split " ", $3 ];
        }
    }

    # Or did he want a hash from msgid to flag array?
    return $flagset
      if ref $msgspec;

    # or did the guy want just one response? Return it if so
    my $flagsref = $flagset->{$msgspec};
    return wantarray ? @$flagsref : $flagsref;
}

# reduce a list, stripping undeclared flags. Flags with or without
# leading backslash.
sub supported_flags(@) {
    my $self = shift;
    my $sup  = $self->Supportedflags
      or return @_;

    return map { $sup->($_) } @_
      if ref $sup eq 'CODE';

    grep { $sup->{ /^\\(\S+)/ ? lc $1 : () } } @_;
}

sub parse_headers {
    my ( $self, $msgspec, @fields ) = @_;
    my $fields = join ' ', @fields;
    my $msg = ref $msgspec eq 'ARRAY' ? $self->Range($msgspec) : $msgspec;
    my $peek = !defined $self->Peek || $self->Peek ? '.PEEK' : '';

    my $string = "$msg BODY$peek"
      . ( $fields eq 'ALL' ? '[HEADER]' : "[HEADER.FIELDS ($fields)]" );

    my $raw = $self->fetch($string) or return undef;
    my $cmd = shift @$raw;

    my %headers;    # message ids to headers
    my $h;          # fields for current msgid
    my $field;      # previous field name, for unfolding
    my %fieldmap = map { ( lc($_) => $_ ) } @fields;
    my $msgid;

    # BUG: parsing this way is prone to be buggy but works most of the time
    # some example responses:
    # * OK Message 1 no longer exists
    # * 1 FETCH (UID 26535 BODY[HEADER] "")
    # * 5 FETCH (UID 30699 BODY[HEADER] {1711}
    # header: value...
    foreach my $header ( map { split /$CR?$LF/o } @$raw ) {

        # Windows2003/Maillennium/others? have UID after headers
        if (
            $header =~ s/^\* \s+ (\d+) \s+ FETCH \s+
                        \( (.*?) BODY\[HEADER (?:\.FIELDS)? .*? \]\s*//ix
          )
        {    # start new message header
            ( $msgid, my $msgattrs ) = ( $1, $2 );
            $h = {};
            if ( $self->Uid )    # undef when win2003
            {
                $msgid = $msgattrs =~ m/\b UID \s+ (\d+)/x ? $1 : undef;
            }
            $headers{$msgid} = $h if $msgid;
        }
        $header =~ /\S/ or next;    # skip empty lines.

        # ( for vi
        if ( $header =~ /^\)/ ) {    # end of this message
            undef $h;                # inbetween headers
            next;
        }
        elsif ( !$msgid && $header =~ /^\s*UID\s+(\d+).*\)$/ ) {
            $headers{$1} = $h;       # found UID win2003/Maillennium

            undef $h;
            next;
        }

        unless ( defined $h ) {
            $self->_debug("found data between fetch headers: $header");
            next;
        }

        if ( $header and $header =~ s/^(\S+)\:\s*// ) {
            $field = $fieldmap{ lc $1 } || $1;
            push @{ $h->{$field} }, $header;
        }
        elsif ( $field and ref $h->{$field} eq 'ARRAY' ) {    # folded header
            $h->{$field}[-1] .= $header;
        }
        else {

            # show data if it is not like  '"")' or '{123}'
            $self->_debug("non-header data between fetch headers: $header")
              if ( $header !~ /^(?:\s*\"\"\)|\{\d+\})$CR?$LF$/o );
        }
    }

    # if we asked for one message, just return its hash,
    # otherwise, return hash of numbers => header hash
    ref $msgspec eq 'ARRAY' ? \%headers : $headers{$msgspec};
}

sub subject { $_[0]->get_header( $_[1], "Subject" ) }
sub date    { $_[0]->get_header( $_[1], "Date" ) }
sub rfc822_header { shift->get_header(@_) }

sub get_header {
    my ( $self, $msg, $field ) = @_;
    my $headers = $self->parse_headers( $msg, $field );
    $headers ? $headers->{$field}[0] : undef;
}

sub recent_count {
    my ( $self, $folder ) = ( shift, shift );

    $self->status( $folder, 'RECENT' )
      or return undef;

    my $r =
      first { s/\*\s+STATUS\s+.*\(RECENT\s+(\d+)\s*\)/$1/ } $self->History;
    chomp $r;
    $r;
}

sub message_count {
    my $self = shift;
    my $folder = shift || $self->Folder;

    $self->status( $folder, 'MESSAGES' )
      or return undef;

    foreach my $result ( $self->Results ) {
        return $1 if $result =~ /\(MESSAGES\s+(\d+)\s*\)/i;
    }

    undef;
}

sub recent()   { shift->search('recent') }
sub seen()     { shift->search('seen') }
sub unseen()   { shift->search('unseen') }
sub messages() { shift->search('ALL') }

sub sentbefore($$) { shift->_search_date( sentbefore => @_ ) }
sub sentsince($$)  { shift->_search_date( sentsince  => @_ ) }
sub senton($$)     { shift->_search_date( senton     => @_ ) }
sub since($$)      { shift->_search_date( since      => @_ ) }
sub before($$)     { shift->_search_date( before     => @_ ) }
sub on($$)         { shift->_search_date( on         => @_ ) }

sub _search_date($$$) {
    my ( $self, $how, $time ) = @_;
    my $imapdate;

    if ( $time =~ /\d\d-\D\D\D-\d\d\d\d/ ) {
        $imapdate = $time;
    }
    elsif ( $time =~ /^\d+$/ ) {
        my @ltime = localtime $time;
        $imapdate = sprintf( "%2.2d-%s-%4.4d",
            $ltime[3],
            $mnt[ $ltime[4] ],
            $ltime[5] + 1900 );
    }
    else {
        $self->LastError("Invalid date format supplied for '$how': $time");
        return undef;
    }

    $self->_imap_uid_command( SEARCH => $how, $imapdate )
      or return undef;

    my @hits;
    foreach ( $self->History ) {
        chomp;
        s/$CR?$LF$//o;
        s/^\*\s+SEARCH\s+//i or next;
        push @hits, grep /\d/, split;
    }
    $self->_debug("Hits are: @hits");
    return wantarray ? @hits : \@hits;
}

sub or {
    my ( $self, @what ) = @_;
    if ( @what < 2 ) {
        $self->LastError("Invalid number of arguments passed to or()");
        return undef;
    }

    my $or =
      "OR " . $self->Quote( shift @what ) . " " . $self->Quote( shift @what );

    $or = "OR $or " . $self->Quote($_) for @what;

    $self->_imap_uid_command( SEARCH => $or )
      or return undef;

    my @hits;
    foreach ( $self->History ) {
        chomp;
        s/$CR?$LF$//o;
        s/^\*\s+SEARCH\s+//i or next;
        push @hits, grep /\d/, split;
    }
    $self->_debug("Hits are now: @hits");

    return wantarray ? @hits : \@hits;
}

sub disconnect { shift->logout }

sub _quote_search {
    my ( $self, @args ) = @_;
    my @ret;
    foreach my $v (@args) {
        if ( ref($v) eq "SCALAR" ) {
            push( @ret, $$v );
        }
        elsif ( exists $SEARCH_KEYS{ uc($v) } ) {
            push( @ret, $v );
        }
        elsif ( @args == 1 ) {
            push( @ret, $v );    # <3.17 compat: caller responsible for quoting
        }
        else {
            push( @ret, $self->Quote($v) );
        }
    }
    return @ret;
}

sub search {
    my ( $self, @args ) = @_;

    @args = $self->_quote_search(@args);

    $self->_imap_uid_command( SEARCH => @args )
      or return undef;

    my @hits;
    foreach ( $self->History ) {
        chomp;
        s/$CR?$LF$//o;
        s/^\*\s+SEARCH\s+(?=.*?\d)// or next;
        push @hits, grep /^\d+$/, split;
    }

    @hits
      or $self->_debug("Search successful but found no matching messages");

    # return empty list
    return
        wantarray     ? @hits
      : !@hits        ? \@hits
      : $self->Ranges ? $self->Range( \@hits )
      :                 \@hits;
}

# returns a Thread data structure
my $thread_parser;

sub thread {
    my $self = shift;

    return undef unless defined $self->has_capability("THREAD=REFERENCES");
    my $algorythm = shift
      || (
        $self->has_capability("THREAD=REFERENCES")
        ? 'REFERENCES'
        : 'ORDEREDSUBJECT'
      );

    my $charset = shift || 'UTF-8';
    my @a = @_ ? @_ : 'ALL';

    $a[-1] = $self->Quote( $a[-1], 1 )
      if @a > 1 && !exists $SEARCH_KEYS{ uc $a[-1] };

    $self->_imap_uid_command( THREAD => $algorythm, $charset, @a )
      or return undef;

    unless ($thread_parser) {
        return if ( defined($thread_parser) and $thread_parser == 0 );

        my $class = $self->_load_module("Thread");
        unless ($class) {
            $thread_parser = 0;
            return undef;
        }
        $thread_parser = $class->new;
    }

    my $thread;
    foreach ( $self->History ) {
        /^\*\s+THREAD\s+/ or next;
        s/$CR?$LF|$LF+/ /og;
        $thread = $thread_parser->start($_);
    }

    unless ($thread) {
        $self->LastError(
"Thread search completed successfully but found no matching messages"
        );
        return undef;
    }

    $thread;
}

sub delete_message {
    my $self = shift;
    my @msgs = map { ref $_ eq 'ARRAY' ? @$_ : split /\,/ } @_;

    $self->store( join( ',', @msgs ), '+FLAGS.SILENT', '(\Deleted)' )
      ? scalar @msgs
      : undef;
}

sub restore_message {
    my $self = shift;
    my $msgs = join ',', map { ref $_ eq 'ARRAY' ? @$_ : split /\,/ } @_;

    $self->store( $msgs, '-FLAGS', '(\Deleted)' ) or return undef;
    scalar grep /^\*\s\d+\sFETCH\s\(.*FLAGS.*(?!\\Deleted)/, $self->Results;
}

sub uidvalidity {
    my ( $self, $folder ) = @_;
    $self->status( $folder, "UIDVALIDITY" ) or return undef;
    my $line = first { /UIDVALIDITY/i } $self->History;
    defined $line && $line =~ /\(UIDVALIDITY\s+([^\)]+)/ ? $1 : undef;
}

sub uidnext {
    my ( $self, $folder ) = @_;
    $self->status( $folder, "UIDNEXT" ) or return undef;
    my $line = first { /UIDNEXT/i } $self->History;
    defined $line && $line =~ /\(UIDNEXT\s+([^\)]+)/ ? $1 : undef;
}

sub capability {
    my $self = shift;

    if ( $self->{CAPABILITY} ) {
        my @caps = keys %{ $self->{CAPABILITY} };
        return wantarray ? @caps : \@caps;
    }

    $self->_imap_command('CAPABILITY')
      or return undef;

    my @caps = map { split } grep s/^\*\s+CAPABILITY\s+//, $self->History;
    foreach (@caps) {
        $self->{CAPABILITY}{ uc $_ }++;
        $self->{ uc $1 } = uc $2 if /(.*?)\=(.*)/;
    }

    return wantarray ? @caps : \@caps;
}

# use "" not undef when lookup fails to differentiate imap command
# failure vs lack of capability
sub has_capability {
    my ( $self, $which ) = @_;
    $self->capability or return undef;
    $which ? $self->{CAPABILITY}{ uc $which } : "";
}

sub imap4rev1 {
    my $self = shift;
    return $self->{_IMAP4REV1} if exists $self->{_IMAP4REV1};
    $self->{_IMAP4REV1} = $self->has_capability('IMAP4REV1');
}

#??? what a horror!
sub namespace {

    # Returns a nested list as follows:
    # [
    #  [
    #   [ $user_prefix,  $user_delim  ] (,[$user_prefix2  ,$user_delim  ],...),
    #  ],
    #  [
    #   [ $shared_prefix,$shared_delim] (,[$shared_prefix2,$shared_delim],... ),
    #  ],
    #  [
    #   [$public_prefix, $public_delim] (,[$public_prefix2,$public_delim],...),
    #  ],
    # ];

    my $self = shift;
    unless ( $self->has_capability("NAMESPACE") ) {
        $self->LastError( "NO NAMESPACE not supported by " . $self->Server )
          unless $self->LastError;
        return undef;
    }

    my $got = $self->_imap_command("NAMESPACE") or return undef;
    my @namespaces = map { /^\* NAMESPACE (.*)/ ? $1 : () } $got->Results;

    my $namespace = shift @namespaces;
    $namespace =~ s/$CR?$LF$//o;

    my ( $personal, $shared, $public ) = $namespace =~ m#
        (NIL|\((?:\([^\)]+\)\s*)+\))\s
        (NIL|\((?:\([^\)]+\)\s*)+\))\s
        (NIL|\((?:\([^\)]+\)\s*)+\))
    #xi;

    my @ns;
    $self->_debug("NAMESPACE: pers=$personal, shared=$shared, pub=$public");
    foreach ( $personal, $shared, $public ) {
        uc $_ ne 'NIL' or next;
        s/^\((.*)\)$/$1/;

        my @pieces = m#\(([^\)]*)\)#g;
        $self->_debug("NAMESPACE pieces: @pieces");

        push @ns, [ map { [m#"([^"]*)"\s*#g] } @pieces ];
    }

    return wantarray ? @ns : \@ns;
}

sub internaldate {
    my ( $self, $msg ) = @_;
    $self->_imap_uid_command( FETCH => $msg, 'INTERNALDATE' )
      or return undef;
    my $hist = join '', $self->History;
    return $hist =~ /\bINTERNALDATE "([^"]*)"/i ? $1 : undef;
}

sub is_parent {
    my ( $self, $folder ) = @_;
    my $list = $self->list( undef, $folder ) or return undef;

    my $attrs;
    foreach my $resp (@$list) {
        my $rec = $self->_list_or_lsub_response_parse($resp);
        next unless defined $rec->{attrs};
        $self->_debug("unexpected attrs data: @$list\n") if $attrs;
        $attrs = $rec->{attrs};
    }

    if ($attrs) {
        return undef if grep { /\A\\NoInferiors\Z/i } @$attrs;
        return 1     if grep { /\A\\HasChildren\Z/i } @$attrs;
        return 0     if grep { /\A\\HasNoChildren\Z/i } @$attrs;
    }
    else {
        $self->_debug( join( "\n\t", "no attrs for '$folder' in:", @$list ) );
    }

    # BUG? This may be overkill for normal use cases...
    # flag not supported or not returned for some reason, try via folders()
    my $sep = $self->separator($folder) || $self->separator(undef);
    return undef unless defined $sep;

    my $lead = $folder . $sep;
    my $len  = length $lead;
    scalar grep { $lead eq substr( $_, 0, $len ) } $self->folders;
}

sub selectable {
    my ( $self, $f ) = @_;
    my $info = $self->list( "", $f ) or return undef;
    return not( grep /[\s(]\\Noselect[)\s]/i, @$info );
}

# append( $self, $folder, $text [, $optmsg] )
# - conserve memory and use $_[0] to avoid copying $text (it may be huge!)
# - BUG?: should deprecate this method in favor of append_string
sub append {
    my $self   = shift;
    my $folder = shift;

    # $message_string is whatever is left in @_
    $self->append_string( $folder, ( @_ > 1 ? join( $CRLF, @_ ) : $_[0] ) );
}

sub _clean_flags {
    my ( $self, $flags ) = @_;
    $flags =~ s/^\s+//;
    $flags =~ s/\s+$//;
    $flags = "($flags)" if $flags !~ /^\(.*\)$/;
    return $flags;
}

# RFC 3501: date-day-fixed = (SP DIGIT) / 2DIGIT
sub _clean_date {
    my ( $self, $date ) = @_;
    $date =~ s/^\s+// if $date !~ /^\s\d/;
    $date =~ s/\s+$//;
    $date = qq("$date") if $date !~ /^"/;
    return $date;
}

sub _append_command {
    my ( $self, $folder, $flags, $date, $length ) = @_;
    return join( " ",
        "APPEND $folder",
        ( $flags ? $flags : () ),
        ( $date  ? $date  : () ),
        "{" . $length . "}",
    );
}

# append_string( $self, $folder, $text, $flags, $date )
# - conserve memory and use $_[2] to avoid copying $text (it may be huge!)
sub append_string($$$;$$) {
    my ( $self, $folder, $flags, $date ) = @_[ 0, 1, 3, 4 ];

    #my $text = $_[2]; # conserve memory and use $_[2] instead!
    my $maxl = $self->Maxappendstringlength;

    # on "large" strings use append_file to conserve memory
    if ( $_[2] and $maxl and length( $_[2] ) > $maxl ) {
        $self->_debug("append_string: using in memory file");
        return $self->append_file( $folder, \( $_[2] ), undef, $flags, $date );
    }

    my $text = defined( $_[2] ) ? $_[2] : '';

    $folder = $self->Quote($folder);
    $flags  = $self->_clean_flags($flags) if ( defined $flags );
    $date   = $self->_clean_date($date) if ( defined $date );
    $text =~ s/\r?\n/$CRLF/og;

    my $cmd = $self->_append_command( $folder, $flags, $date, length($text) );
    $cmd .= $CRLF . $text . $CRLF;

    $self->_imap_command( { addcrlf => 0 }, $cmd ) or return undef;

    my $data = join '', $self->Results;

    # look for something like return size or self if no size found:
    # <tag> OK [APPENDUID <uid> <size>] APPEND completed
    my $ret = $data =~ m#\s+(\d+)\]# ? $1 : $self;

    return $ret;
}

# BUG?: not much/any savings on cygwin perl 5.10 when using in memory file
# BUG?: we do not retry if sending data fails after getting the OK to send
sub append_file {
    my ( $self, $folder, $file, $control, $flags, $date ) = @_;

    my @err;
    push( @err, "folder not specified" )
      unless ( defined($folder) and $folder ne "" );

    my $fh;
    if ( !defined($file) ) {
        push( @err, "file not specified" );
    }
    elsif ( ref($file) and ref($file) ne "SCALAR" ) {
        $fh = $file;    # let the caller pass in their own file handle directly
    }
    elsif ( !ref($file) and !-f $file ) {
        push( @err, "file '$file' not found" );
    }
    else {

        # $file can be a name or a scalar reference (for in memory file)
        # avoid IO::File bug handling scalar refs in perl <= 5.8.8?
        # - buggy: $fh = IO::File->new( $file, 'r' )
        local ($!);
        open( $fh, "<", $file )
          or push( @err, "Unable to open file '$file': $!" );
    }

    if (@err) {
        $self->LastError( join( ", ", @err ) );
        return undef;
    }

    binmode($fh);

    $folder = $self->Quote($folder)       if ( defined $folder );
    $flags  = $self->_clean_flags($flags) if ( defined $flags );

    # allow the date to be specified or even use mtime on file
    if ($date) {
        $date = $self->Rfc3501_datetime( ( stat($fh) )[9] ) if ( $date eq "1" );
        $date = $self->_clean_date($date);
    }

    # BUG? seems wasteful to do this always, provide a "fast path" option?
    my $length = 0;
    {
        local $/ = "\n";    # just in case global is not default
        while ( my $line = <$fh> ) {    # do no read the whole file at once!
            $line =~ s/\r?\n$/$CRLF/;
            $length += length($line);
        }
        seek( $fh, 0, 0 );
    }

    my $cmd = $self->_append_command( $folder, $flags, $date, $length );
    my $rc = $self->_imap_command( $cmd, '+' );
    unless ($rc) {
        $self->LastError( "Error sending '$cmd': " . $self->LastError );
        return undef;
    }

    # Now send the message itself
    my ( $buffer, $buflen ) = ( "", 0 );
    until ( !$buflen and eof($fh) ) {

        if ( $buflen < APPEND_BUFFER_SIZE ) {
          FILLBUFF:
            while ( my $line = <$fh> ) {
                $line =~ s/\r?\n$/$CRLF/;
                $buffer .= $line;
                $buflen = length($buffer);
                last FILLBUFF if ( $buflen >= APPEND_BUFFER_SIZE );
            }
        }

        # exit loop entirely if we are out of data
        last unless $buflen;

        # save anything over desired buffer size for next iteration
        my $savebuff =
          ( $buflen > APPEND_BUFFER_SIZE )
          ? substr( $buffer, APPEND_BUFFER_SIZE )
          : undef;

        # reduce buffer to desired size
        $buffer = substr( $buffer, 0, APPEND_BUFFER_SIZE );

        my $bytes_written = $self->_send_bytes( \$buffer );
        unless ($bytes_written) {
            $self->LastError( "Error appending message: " . $self->LastError );
            return undef;
        }

        # retain any saved data and continue loop
        $buffer = defined($savebuff) ? $savebuff : "";
        $buflen = length($buffer);
    }

    # finish off append
    unless ( $self->_send_bytes( \$CRLF ) ) {
        $self->LastError( "Error appending CRLF: " . $self->LastError );
        return undef;
    }

    # Now for the crucial test: Did the append work or not?
    # look for "<tag> (OK|BAD|NO)"
    my $code = $self->_get_response( $self->Count ) or return undef;

    if ( $code eq 'OK' ) {
        my $data = join '', $self->Results;

        # look for something like return size or self if no size found:
        # <tag> OK [APPENDUID <uid> <size>] APPEND completed
        my $ret = $data =~ m#\s+(\d+)\]# ? $1 : $self;

        return $ret;
    }
    else {
        return undef;
    }
}

# BUG? we should retry if "socket closed while..." but do not currently
sub authenticate {
    my ( $self, $scheme, $response ) = @_;
    $scheme   ||= $self->Authmechanism;
    $response ||= $self->Authcallback;
    my $clear = $self->Clear;
    $self->Clear($clear)
      if $self->Count >= $clear && $clear > 0;

    if ( !$scheme ) {
        $self->LastError("Authmechanism not set");
        return undef;
    }
    elsif ( $scheme eq 'LOGIN' ) {
        $self->LastError("Authmechanism LOGIN is invalid, use login()");
        return undef;
    }

    my $string = "AUTHENTICATE $scheme";

    # use _imap_command for retry mechanism...
    $self->_imap_command( $string, '+' ) or return undef;

    my $count = $self->Count;
    my $code;

    # look for "+ <anyword>" or just "+"
    foreach my $line ( $self->Results ) {
        if ( $line =~ /^\+\s*(.*?)\s*$/ ) {
            $code = $1;
            last;
        }
    }

    # BUG? use _load_module for these too?
    if ( $scheme eq 'CRAM-MD5' ) {
        $response ||= sub {
            my ( $code, $client ) = @_;
            require Digest::HMAC_MD5;
            my $hmac =
              Digest::HMAC_MD5::hmac_md5_hex( decode_base64($code),
                $client->Password );
            encode_base64( $client->User . " " . $hmac, '' );
        };
    }
    elsif ( $scheme eq 'DIGEST-MD5' ) {
        $response ||= sub {
            my ( $code, $client ) = @_;
            require Authen::SASL;
            require Digest::MD5;

            my $authname =
              defined $client->Authuser ? $client->Authuser : $client->User;

            my $sasl = Authen::SASL->new(
                mechanism => 'DIGEST-MD5',
                callback  => {
                    user     => $client->User,
                    pass     => $client->Password,
                    authname => $authname
                }
            );

            # client_new is an empty function for DIGEST-MD5
            my $conn = $sasl->client_new( 'imap', 'localhost', '' );
            my $answer = $conn->client_step( decode_base64 $code);

            encode_base64( $answer, '' )
              if defined $answer;
        };
    }
    elsif ( $scheme eq 'PLAIN' ) {    # PLAIN SASL
        $response ||= sub {
            my ( $code, $client ) = @_;
            encode_base64(            # [authname] user password
                join(
                    chr(0),
                    defined $client->Proxy
                    ? ( $client->User, $client->Proxy )
                    : ( "", $client->User ),
                    defined $client->Password ? $client->Password : "",
                ),
                ''
            );
        };
    }
    elsif ( $scheme eq 'NTLM' ) {
        $response ||= sub {
            my ( $code, $client ) = @_;

            require Authen::NTLM;
            Authen::NTLM::ntlm_user( $client->User );
            Authen::NTLM::ntlm_password( $client->Password );
            Authen::NTLM::ntlm_domain( $client->Domain ) if $client->Domain;
            Authen::NTLM::ntlm($code);
        };
    }

    my $resp = $response->( $code, $self );
    unless ( defined($resp) ) {
        $self->LastError( "Error getting $scheme data: " . $self->LastError );
        return undef;
    }
    unless ( $self->_send_line($resp) ) {
        $self->LastError( "Error sending $scheme data: " . $self->LastError );
        return undef;
    }

    # this code may be a little too custom to try and use _get_response()
    # look for "+ <anyword>" (not just "+") otherwise "<tag> (OK|BAD|NO)"
    undef $code;
    until ($code) {
        my $output = $self->_read_line or return undef;
        foreach my $o (@$output) {
            $self->_record( $count, $o );
            $code = $o->[DATA] =~ /^\+\s+(.*?)\s*$/ ? $1 : undef;

            if ($code) {
                unless ( $self->_send_line( $response->( $code, $self ) ) ) {
                    $self->LastError(
                        "Error sending $scheme data: " . $self->LastError );
                    return undef;
                }
                undef $code;    # clear code as we are not finished yet
            }

            if ( $o->[DATA] =~ /^$count\s+(OK|NO|BAD)\b/i ) {
                $code = uc($1);
                $self->LastError( $o->[DATA] ) unless ( $code eq 'OK' );
            }
            elsif ( $o->[DATA] =~ /^\*\s+BYE/ ) {
                $self->State(Unconnected);
                $self->LastError( $o->[DATA] );
                return undef;
            }
        }
    }

    return undef unless $code eq 'OK';

    Authen::NTLM::ntlm_reset()
      if $scheme eq 'NTLM';

    $self->State(Authenticated);
    return $self;
}

# UIDPLUS response from a copy: [COPYUID (uidvalidity) (origuid) (newuid)]
sub copy {
    my ( $self, $target, @msgs ) = @_;

    my $msgs =
        $self->Ranges
      ? $self->Range(@msgs)
      : join ',', map { ref $_ ? @$_ : $_ } @msgs;

    $self->_imap_uid_command( COPY => $msgs, $self->Quote($target) )
      or return undef;

    my @results = $self->History;

    my @uids;
    foreach (@results) {
        chomp;
        s/$CR?$LF$//o;
        s/^.*\[COPYUID\s+\d+\s+[\d:,]+\s+([\d:,]+)\].*/$1/ or next;
        push @uids, /(\d+):(\d+)/ ? ( $1 ... $2 ) : ( split /\,/ );

    }
    return @uids ? join( ",", @uids ) : $self;
}

sub move {
    my ( $self, $target, @msgs ) = @_;

    $self->exists($target)
      or $self->create($target) && $self->subscribe($target);

    my $uids =
      $self->copy( $target, map { ref $_ eq 'ARRAY' ? @$_ : $_ } @msgs )
      or return undef;

    unless ( $self->delete_message(@msgs) ) {
        local ($!);    # old versions of Carp could reset $!
        carp $self->LastError;
    }

    return $uids;
}

sub set_flag {
    my ( $self, $flag, @msgs ) = @_;
    @msgs = @{ $msgs[0] } if ref $msgs[0] eq 'ARRAY';
    $flag = "\\$flag"
      if $flag =~ /^(?:Answered|Flagged|Deleted|Seen|Draft)$/i;

    my $which = $self->Ranges ? $self->Range(@msgs) : join( ',', @msgs );
    return $self->store( $which, '+FLAGS.SILENT', "($flag)" );
}

sub see {
    my ( $self, @msgs ) = @_;
    @msgs = @{ $msgs[0] } if ref $msgs[0] eq 'ARRAY';
    return $self->set_flag( '\\Seen', @msgs );
}

sub mark {
    my ( $self, @msgs ) = @_;
    @msgs = @{ $msgs[0] } if ref $msgs[0] eq 'ARRAY';
    return $self->set_flag( '\\Flagged', @msgs );
}

sub unmark {
    my ( $self, @msgs ) = @_;
    @msgs = @{ $msgs[0] } if ref $msgs[0] eq 'ARRAY';
    return $self->unset_flag( '\\Flagged', @msgs );
}

sub unset_flag {
    my ( $self, $flag, @msgs ) = @_;
    @msgs = @{ $msgs[0] } if ref $msgs[0] eq 'ARRAY';

    $flag = "\\$flag"
      if $flag =~ /^(?:Answered|Flagged|Deleted|Seen|Draft)$/i;

    return $self->store( join( ",", @msgs ), "-FLAGS.SILENT ($flag)" );
}

sub deny_seeing {
    my ( $self, @msgs ) = @_;
    @msgs = @{ $msgs[0] } if ref $msgs[0] eq 'ARRAY';
    return $self->unset_flag( '\\Seen', @msgs );
}

sub size {
    my ( $self, $msg ) = @_;
    my $data = $self->fetch( $msg, "(RFC822.SIZE)" ) or return undef;

    # beware of response like: * NO Cannot open message $msg
    my $cmd = shift @$data;
    my $err;
    foreach my $line (@$data) {
        return $1 if ( $line =~ /RFC822\.SIZE\s+(\d+)/ );
        $err = $line if ( $line =~ /\* NO\b/ );
    }

    if ($err) {
        my $info = "$err was returned for $cmd";
        $info =~ s/$CR?$LF//og;
        $self->LastError($info);
    }
    elsif ( !$self->LastError ) {
        my $info = "no RFC822.SIZE found in: " . join( " ", @$data );
        $self->LastError($info);
    }
    return undef;
}

sub getquotaroot {
    my ( $self, $what ) = @_;
    my $who = defined $what ? $self->Quote($what) : "INBOX";
    return $self->_imap_command("GETQUOTAROOT $who") ? $self->Results : undef;
}

# BUG? using user/$User here and INBOX in quota/quota_usage
sub getquota {
    my ( $self, $what ) = @_;
    my $who = defined $what ? $self->Quote($what) : "user/" . $self->User;
    return $self->_imap_command("GETQUOTA $who") ? $self->Results : undef;
}

# usage: $self->setquota($quotaroot, storage => 512, ...)
sub setquota(@) {
    my ( $self, $what ) = ( shift, shift );
    my $who = defined $what ? $self->Quote($what) : "user/" . $self->User;
    my @limits;
    while (@_) {
        my ( $k, $v ) = ( $self->Quote( uc( shift @_ ) ), shift @_ );
        push( @limits, "($k $v)" );
    }
    my $limits = join( ' ', @limits );
    $self->_imap_command("SETQUOTA $who $limits") ? $self->Results : undef;
}

sub quota {
    my ( $self, $what ) = ( shift, shift || "INBOX" );
    my $tref = $self->getquota($what) or return undef;
    shift @$tref;    # pop off command
    return ( map { /.*STORAGE\s+\d+\s+(\d+).*\n$/ ? $1 : () } @$tref )[0];
}

sub quota_usage {
    my ( $self, $what ) = ( shift, shift || "INBOX" );
    my $tref = $self->getquota($what) or return undef;
    shift @$tref;    # pop off command
    return ( map { /.*STORAGE\s+(\d+)\s+\d+.*\n$/ ? $1 : () } @$tref )[0];
}

# rfc3501:
#   atom-specials   = "(" / ")" / "{" / SP / CTL / list-wildcards /
#                  quoted-specials / resp-specials
#   list-wildcards  = "%" / "*"
#   quoted-specials = DQUOTE / "\"
#   resp-specials   = "]"
# rfc2060:
#   CTL ::= <any ASCII control character and DEL, 0x00 - 0x1f, 0x7f>
# Paranoia/safety:
#   encode strings with "}" / "[" / "]" / non-ascii chars
sub Quote($;$) {
    my ( $self, $name, $force ) = @_;
    if ( $force or $name =~ /["\\[:^ascii:][:cntrl:]]/s ) {
        return "{" . length($name) . "}" . $CRLF . $name;
    }
    elsif ( $name =~ /[(){}\s%*\[\]]/s or $name eq "" ) {
        return qq("$name");
    }
    else {
        return $name;
    }
}

# legacy behavior: strip double quote around folder name args!
sub Massage($;$) {
    my ( $self, $name, $notFolder ) = @_;
    $name =~ s/^\"(.*)\"$/$1/s unless $notFolder;
    return $self->Quote($name);
}

sub unseen_count {
    my ( $self, $folder ) = ( shift, shift );
    $folder ||= $self->Folder;
    $self->status( $folder, 'UNSEEN' ) or return undef;

    my $r =
      first { s/\*\s+STATUS\s+.*\(UNSEEN\s+(\d+)\s*\)/$1/ } $self->History;

    $r =~ s/\D//g;
    return $r;
}

sub State($) {
    my ( $self, $state ) = @_;

    if ( defined $state ) {
        $self->{State} = $state;

        # discard cached capability info after authentication
        delete $self->{CAPABILITY} if ( $state == Authenticated );
    }

    return defined( $self->{State} ) ? $self->{State} : Unconnected;
}

sub Status          { shift->State }
sub IsUnconnected   { shift->State == Unconnected }
sub IsConnected     { shift->State >= Connected }
sub IsAuthenticated { shift->State >= Authenticated }
sub IsSelected      { shift->State == Selected }

# The following private methods all work on an output line array.
# _data returns the data portion of an output array:
sub _data { ref $_[1] && defined $_[1]->[TYPE] ? $_[1]->[DATA] : undef }

# _index returns the index portion of an output array:
sub _index { ref $_[1] && defined $_[1]->[TYPE] ? $_[1]->[INDEX] : undef }

# _type returns the type portion of an output array:
sub _type { ref $_[1] && $_[1]->[TYPE] }

# _is_literal returns true if this is a literal:
sub _is_literal { ref $_[1] && $_[1]->[TYPE] && $_[1]->[TYPE] eq 'LITERAL' }

# _is_output_or_literal returns true if this is an
#      output line (or the literal part of one):

sub _is_output_or_literal {
    ref $_[1]
      && defined $_[1]->[TYPE]
      && ( $_[1]->[TYPE] eq "OUTPUT" || $_[1]->[TYPE] eq "LITERAL" );
}

# _is_output returns true if this is an output line:
sub _is_output { ref $_[1] && $_[1]->[TYPE] && $_[1]->[TYPE] eq "OUTPUT" }

# _is_input returns true if this is an input line:
sub _is_input { ref $_[1] && $_[1]->[TYPE] && $_[1]->[TYPE] eq "INPUT" }

# _next_index returns next_index for a transaction; may legitimately
# return 0 when successful.
sub _next_index { my $r = $_[0]->_transaction( $_[1] ); $r }

sub Range {
    my ( $self, $targ ) = ( shift, shift );

    UNIVERSAL::isa( $targ, 'Mail::IMAPClient::MessageSet' )
      ? $targ->cat(@_)
      : Mail::IMAPClient::MessageSet->new( $targ, @_ );
}

1;

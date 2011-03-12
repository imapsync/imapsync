
package Mail::IMAPClient;
our $VERSION = '2.99_02';

use Mail::IMAPClient::MessageSet;

use Socket();
use IO::Socket();
use IO::Select();
use IO::File();
use Carp qw(carp);

use Fcntl       qw(F_GETFL F_SETFL O_NONBLOCK);
use Errno       qw/EAGAIN/;
use List::Util  qw/first min max sum/;
use Digest::HMAC_MD5 qw/hmac_md5_hex/; 
use MIME::Base64;

use constant Unconnected   => 0;
use constant Connected     => 1; # connected; not logged in
use constant Authenticated => 2; # logged in; no mailbox selected
use constant Selected      => 3; # mailbox selected

use constant INDEX         => 0; # Array index for output line number
use constant TYPE          => 1; # Array index for line type
                                 #    (either OUTPUT, INPUT, or LITERAL)
use constant DATA          => 2; # Array index for output line data

use constant NonFolderArg => 1;  # Value to pass to Massage to
                                 #    indicate non-folder argument

my %SEARCH_KEYS = map { ( $_ => 1 ) } qw/
    ALL ANSWERED BCC BEFORE BODY CC DELETED DRAFT FLAGGED
    FROM HEADER KEYWORD LARGER NEW NOT OLD ON OR RECENT
    SEEN SENTBEFORE SENTON SENTSINCE SINCE SMALLER SUBJECT
    TEXT TO UID UNANSWERED UNDELETED UNDRAFT UNFLAGGED
    UNKEYWORD UNSEEN/;

sub _debug
{   my $self = shift;
    return unless $self->Debug;
    my $fh   = $self->{Debug_fh} || \*STDERR;
    print $fh @_;
}

BEGIN {
   # set-up accessors
   foreach my $datum (
     qw(State Port Server Folder Peek User Password Timeout Buffer
        Debug Count Uid Debug_fh Maxtemperrors
        EnableServerResponseInLiteral Authmechanism Authcallback Ranges
        Readmethod Showcredentials Prewritemethod Ignoresizeerrors
        Supportedflags Proxy))
   { no strict 'refs';
     *$datum = sub { @_ > 1 ? $_[0]->{$datum} = $_[1] : $_[0]->{$datum} };
   }
}

sub LastError
{   my $self = shift;
    $self->{LastError} = shift if @_;
    $@ = $self->{LastError};
}

sub Fast_io(;$)
{   my ($self, $use) = @_;
    defined $use
       or return $self->{File_io};

    my $socket = $self->{Socket}
       or return;

    unless($use)
    {   eval { fcntl($socket, F_SETFL, delete $self->{_fcntl}) }
            if exists $self->{_fcntl};
        $@ = '';
        $self->{Fast_io} = 0;
        return;
    }

    my $fcntl = eval { fcntl($Socket, F_GETFL, 0) };
    if($@)
    {   $self->{Fast_io} = 0;
        $self->_debug("not using Fast_IO; not available on this platform")
           unless $self->{_fastio_warning_}++;
        $@ = '';
        return;
    }

    $self->{Fast_io} = 1;
    my $newflags = $self->{_fcntl} = $fcntl;
    $newflags   |= O_NONBLOCK;
    fcntl($socket, F_SETFL, $newflags);
}

sub Socket(;$)
{   my ($self, $sock) = @_;
    defined $sock
       or return $self->{Socket};

    delete $self->{_fcntl};
    # Register this handle in a select vector:
    $self->{_select} = IO::Select->new($_[1]);
}

sub Wrap { shift->Clear(@_) }

# The following class method is for creating valid dates in appended msgs:

my @dow  = qw/Sun Mon Tue Wed Thu Fri Sat/;
my @mnt  = qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/;

sub Rfc822_date
{   my $class = shift;   #Date: Fri, 09 Jul 1999 13:10:55 -0000#
    my $date  = $class =~ /^\d+$/ ? $class : shift;  # method or function?
    my @date  = gmtime $date;

    sprintf "%s, %2.2d %s %4.4s %2.2d:%2.2d:%2.2d -%4.4d"
      , $dow[$date[6]], $date[3], $mnt[$date[4]], $date[5]+=1900
      , $date[2], $date[1], $date[0], $date[8];
}

# The following class method is for creating valid dates for use
# in IMAP search strings:

sub Rfc2060_date
{   my $class = shift; # 11-Jan-2000
    my $date  = $class =~ /^\d+$/ ? $class : shift; # method or function
    my @date  = gmtime $date;

    sprintf "%2.2d-%s-%4.4s", $date[3], $mnt[$date[4]], $date[5]+=1900;
}

# Change CRLF into \n

sub Strip_cr
{   my $class = shift;
    if( !ref $_[0] && @_==1 )
    {   (my $string = $_[0]) =~ s/\x0d\x0a/\n/g;
        return $string;
    }

    wantarray
    ?   map { s/\x0d\x0a/\n/gm; $_ } (ref $_[0] ? @{$_[0]} : @_)
    : [ map { s/\x0d\x0a/\n/gm; $_ } (ref $_[0] ? @{$_[0]} : @_) ];
}

# The following defines a special method to deal with the Clear parameter:

sub Clear
{   my ($self, $clear) = @_;
    defined $clear or return $self->{Clear};

    my $oldclear   = $self->{Clear};
    $self->{Clear} = $clear;

    my @keys = reverse $self->_trans_index;

    for(my $i = $clear; $i < @keys ; $i++ )
    {   delete $self->{History}{$keys[$i]};
    }

    $oldclear;
}

# read-only access to the transaction number:
sub Transaction { shift->Count };

# the constructor:
sub new
{   my $class = shift;
    my $self  =
      { LastError     => "",
      , Uid           => 1
      , Count         => 0
      , Fast_io       => 1
      , Clear         => 5
      , Maxtemperrors => 'unlimited'
      , State         => Unconnected
      };
    while(@_)
    {   my $k = ucfirst lc shift;
        $self->{$k} = shift;
    }
    bless $self, ref($class)||$class;

    if($self->{Supportedflags})  # unpack into case-less HASH
    {  my %sup = map { m/^\\?(\S+)/ ? lc $1 : () } @$sup;
       $self->{Supportedflags} = \%sup;
    }

    $self->{Debug_fh} ||= \*STDERR;
    select((select($self->{Debug_fh}),$|++)[0]);

    $self->_debug("Using Mail::IMAPClient version $Mail::IMAPClient::VERSION " .
        "and perl version " . (defined $^V ? join(".",unpack("CCC",$^V)) : "") .
        " ($])\n") if $self->Debug;

    if($self->{Socket})    { $self->Socket($self->{Socket}) }
    elsif($self->{Server}) { $self->connect }

    $self;
}

sub connect
{   my $self = shift;
    %$self = (%$self, @_);

    my $sock = IO::Socket::INET->new
      ( PeerAddr => $self->Server
      , PeerPort => ( $self->Port   || 'imap(143)')
      , Timeout  => ($self->Timeout || 0)
      , Proto    => 'tcp'
      , Debug    => $self->Debug
      );

    unless($sock)
    {   $self->LastError("Unable to connect to $self->{Server}: $!");
        return undef;
    }

    $self->Socket($sock);
    $self->State(Connected);
    $sock->autoflush(1);

    my $code;
  LINE:
    while(my $output = $self->_read_line)
    {   foreach my $o (@$output)
        {   $self->_debug("Connect: Received this from readline: @$o\n");
            $self->_record($self->Count, $o);
            next unless $o->[TYPE] eq "OUTPUT";

            my $code = $o->[DATA] =~ /^\*\s+(OK|BAD|NO|PREAUTH)/i ? $1 : undef;
            last LINE;
        }
    }
    $code or return undef;

    if($code =~ /BYE|NO /)
    {   $self->State(Unconnected);
        return undef;
    }

    if($code =~ /PREAUTH/ )
    {   $self->State(Authenticated);
        return $self;
    }

    $self->User && $self->Password ? $self->login : $self;
}

sub login
{   my $self = shift;
    return $self->authenticate($self->Authmechanism, $self->Authcallback)
        if $self->{Authmechanism} && $self->{Authmechanism} ne 'LOGIN';

    my $passwd = $self->Password;
    my $id     = $self->User;
    $id        = qq{"$id"} if $id !~ /^".*"$/;

    unless($self->_imap_command("LOGIN $id $passwd\r\n"))
    {   my $carp = $self->LastError;
        $carp    =~ s/^[\S]+ ([^\x0d\x0a]*)\x0d?\x0a/$1/;
        carp $carp unless defined wantarray;
        return undef;
    }

    $self->State(Authenticated);
    $self;
}

sub separator
{   my ($self, $target) = @_;
    unless(defined($target))
    {   # separator is namespace's 1st thing's 1st thing's 2nd thing:
        my $sep = eval { $self->namespace->[0][0][1] };
        return $sep if $sep;
    }

    $target ||= '""';

    # The fact that the response might end with {123} doesn't matter here:

    my $targetsep = $target. $; .'SEPARATOR';
    unless($self->{$targetset})
    {   my $list = $self->list(undef, $target) || 'NO';
        my $s    = $list =~ /^\*\s+LIST\s+(\S+)/ ? $1 : qq("/");
        $self->{$targetset} = $s eq 'NIL' ? 'NIL' : substr($s,1,length($s)-2)
            if defined $s;
    }
    $self->{$targetsep};
}

sub sort
{   my ($self, $crit, @a) = @_;

    $crit =~ /^\(.*\)$/        # wrap criteria in parens
        or $crit = "($crit)";

    $self->_imap_uid_command(SORT => $crit, @a)
         or return wantarray ? () : [];

    my @results = $self->History;
    my @hits;
    foreach (@results)
    {   chomp;
        s/\r$//;
        s/^\*\s+SORT\s+// or next;
        push @hits, grep /\d/, split;
    }
    wantarray ? @hits : \@hits;
}

sub list
{   my ($self, $reference, $target) = @_;
    defined $reference or $reference = "";
    defined $target    or $target = '*';
    length $target     or $target = '""';

    $target eq '*' || $target eq '""'
         or $target = $self->Massage($target);
;
    $self->_imap_command( qq[LIST "$reference" $target] )
        or return undef;

    wantarray ? $self->History : $self->Results;
}

sub lsub
{   my ($self, $reference, $target) = @_;
    defined $reference or $reference = "";
    defined $target    or $target = '*';
    $target = $self->Massage($target);

    my $string      =
    $self->_imap_command( qq[LSUB "$reference" $target] )
         or return undef;

    wantarray ? $self->History : $self->Results;
}

sub subscribed
{   my ($self, $what) = @_;
    my $known = $what ? $what.$self->separator($what)."*" : undef;

    my @list = $self->lsub(undef, $known);
    push @list, $self->lsub(undef, $what) if $what && $self->exists($what);

    my @folders;
    for(my $m = 0; $m < @list; $m++ )
    {   $list[$m] or next;

        if($list[$m] !~ /\x0d\x0a$/)
        {   $list[$m]  .= $list[$m+1];
            $list[$m+1] = "";
        }

        # $self->_debug("Subscribed: examining $list[$m]\n");

        push @folders, $1||$2
            if $list[$m] =~
                m/ ^ \* \s+ LSUB            # * LSUB
                     \s+ \( [^\)]* \) \s+   # (Flags)
                     (?:"[^"]*"|NIL)\s+     # "delimiter" or NIL
                     (?:"([^"]*)"|(.*))\x0d\x0a$  # Name or "Folder name"
                 /ix;
    }

    # for my $f (@folders) { $f =~ s/^\\FOLDER LITERAL:://;}
    # remove doubles
    my @clean; my %memory;
    foreach (@folders) { push @clean, $_ unless $memory{$_}++ }
    wantarray ? @clean : \@clean;
}

sub deleteacl
{   my ($self, $target, $user) = @_;
    $target = $self->Massage($target);
    $user   =~ s/^"(.*)"$/$1/;
    $user   =~ s/"/\\"/g;

    $self->_imap_command( qq[DELETEACL $target "$user"] )
        or return undef;

    wantarray ? $self->History : $self->Results;
}

sub setacl
{   my ($self, $target, $user, $acl) = @_;
    length $user   or $user   = $self->User;
    length $targer or $target = $self->Folder;

    $target = $self->Massage($target);
    $user   =~ s/^"(.*)"$/$1/;
    $user   =~ s/"/\\"/g;
    $acl    =~ s/^"(.*)"$/$1/;
    $acl    =~ s/"/\\"/g;

    $self->_imap_command( qq[SETACL $target "$user" "$acl"] )
        or return undef;

    wantarray ? $self->History : $self->Results;
}


sub getacl
{   my ($self, $target) = @_;
    defined $target or $target = $self->Folder;
    my $mtarget = $self->Massage($target);
    $self->_imap_command( qq[GETACL $mtarget] )
        or return undef;

    my @history = $self->History;
    my $hash;
    for(my $x = 0; $x < @history; $x++ )
    {
        next if $history[$x] !~ /^\* ACL/;

        my $perm = $history[$x]=~ /^\* ACL $/
                 ? $history[++$x].$history[++$x]
                 : $history[$x];

        $perm =~ s/\s?\x0d\x0a$//;
        until( $perm =~ /\Q$target\E"?$/ || !$perm)
        {   $perm =~ s/\s([^\s]+)\s?$// or last;
            my $p = $1;
            $perm =~ s/\s([^\s]+)\s?$// or last;
            my $u = $1;
            $hash->{$u} = $p;
            $self->_debug("Permissions: $u => $p \n");
        }
    }
    $hash;
}

sub listrights
{   my ($self, $target, $user) = @_;
    $target ||= $self->Folder;
    $target   = $self->Massage($target);

    $user   ||= $self->User;
    $user     =~ s/^"(.*)"$/$1/;
    $user     =~ s/"/\\"/g;

    $self->_imap_command( qq[LISTRIGHTS $target "$user"] )
        or return undef;

    my $resp   = first { /^\* LISTRIGHTS/ } $self->History;
    my @rights = split /\s/, $resp;
    my $rights = join '', @rights[4..$#rights];
    $rights    =~ s/"//g;
    wantarray ? split(//, $rights) : $rights;
}

sub select
{   my ($self, $target) = @_;
    defined $target or return undef;

    my $qqtarget = $self->Massage($target);
    my $old = $self->Folder;

    $self->_imap_command("SELECT $qqtarget") && $self->State(Selected)
        or return undef;

    $self->Folder($target);
    $old || $self;  # ??$self??
}

sub message_string
{   my ($self, $msg) = @_;
    my $expected_size = $self->size($msg);
    defined $expected_size or return undef;  # unable to get size

    my $peek = $self->Peek ? '.PEEK' : '';
    my $cmd  = $self->map4rev1 ? "BODY${peek}[]" : "RFC822$peek";

    $self->fetch($msg, $cmd)
        or return undef;

    my $string = $self->transactionLiterals;

    unless($self->Ignoresizeerrors)
    {   # Should this return undef if length != expected?
        # now, attempts are made to salvage parts of the message.
        if( length($string) != $expected_size )
        {   carp "${self}::message_string: " .
                "expected $expected_size bytes but received ".length($string)
                if $self->Debug || $^W;
        }

        $string = substr $string, 0, $expected_size
            if length($string) > $expected_size;

        if( length($string) < $expected_size )
        {    $self->LastError("${self}::message_string: expected ".
                "$expected_size bytes but received ".length($string));
            return undef;
        }
    }

    $string;
}

sub bodypart_string
{   my($self, $msg, $partno, $bytes, $offset) = @_;

    unless( $self->has_capability('IMAP4REV1') )
    {   $self->LastError("Unable to get body part; server ".$self->Server
                . " does not support IMAP4REV1");
        return undef;
    }

    $offset ||= 0;
    my $cmd = "BODY" . ($self->Peek ? '.PEEK' : '') . "[$partno]"
            . ($bytes ? "<$offset.$bytes>" : '');

    $self->fetch($msg, $cmd)
        or return undef;

    $self->transactionLiterals;
}

sub message_to_file
{   my $self = shift;
    my $fh   = shift;
    my $msgs = join ',', @_;

    my $handle;
    if(ref $fh) { $handle = $fh }
    else
    {   $handle = IO::File->new(">>$fh");
        unless(defined($handle))
        {   $self->LastError("Unable to open $fh: $!");
            return undef;
        }
        binmode $handle; # For those of you who need something like this...
    }


    my $clear = $self->Clear;
    $self->Clear($clear)
        if $self->Count >= $clear && $clear > 0;

    my $peek   = $self->Peek ? '.PEEK' : '';
    my $cmd    = $self->imap4rev1 ? "RFC822$peek" : "BODY${peek}[]";
    my $uid    = $self->Uid ? "UID " : "";
    my $trans  = $self->Count($self->Count+1);
    my $string = "$trans ${uid}FETCH $msgs $cmd";

    $self->_record($trans, [0, "INPUT", "$string\x0d\x0a"] );

    my $feedback = $self->_send_line($string);
    unless($feedback)
    {    $self->LastError("Error sending '$string' to IMAP: $!");
         return undef;
    }

    my $code;

  READ:
    until($code)
    {   my $output = $self->_read_line($handle)
            or return undef;

        foreach my $o (@$output)
        {   $self->_record($trans,$o);
            next unless $self->_is_output($o);

            ($code) = $o->[DATA] =~ /^$trans (OK|BAD|NO)/mi;
            if($o->[DATA] =~ /^\*\s+BYE/im)
            {    $self->State(Unconnected);
                 return undef;
            }
        }
    }
    ref $fh or close $handle;
    $code =~ /^OK/im ? $self : undef;
}

sub message_uid
{   my ($self, $msg) = @_;

    foreach ($self->fetch($msg, "UID"))
    {   return $1 if m/\(UID\s+(\d+)\s*\)\r?$/;
    }
    undef;
}

sub original_migrate
{   my ($self, $peer, $msgs, $folder) = @_;
    unless( eval { $peer->IsConnected } )
    {   $self->LastError("Invalid or unconnected " . ref($self).
                 " object used as target for migrate." );
        return undef;
    }

    unless($folder)
    {   $folder = $self->Folder;
        unless($peer->exists($folder) || $peer->create($folder))
        {   $self->LastError("Unable to created folder $folder on target "
                 . "mailbox: ".$peer->LastError);
            return undef;
        }
    }

    $msgs = $self->search("ALL")
        if uc $msgs eq 'ALL';

    foreach my $mid (ref($msgs) ? @$msgs : $msgs)
    {   my $uid = $peer->append($folder, $self->message_string($mid));
        $self->LastError("Trouble appending to peer: ". $peer->LastError);
    }
}

sub migrate
{   my ($self, $peer, $msgs, $folder) = @_;
    my $toSock     = $peer->Socket,
    my $fromSock   = $self->Socket;
    my $bufferSize = $self->Buffer || 4096;

    unless(eval {$peer->IsConnected} )
    {    $self->LastError("Invalid or unconnected " .  ref($self)
             . " object used as target for migrate. $@");
        return undef;
    }

    unless($folder)
    {   unless($folder = $self->Folder)
        {   $self->LastError( "No folder selected on source mailbox.");
            return undef;
        }

        unless($peer->exists($folder) || $peer->create($folder))
        {   $self->LastError("Unable to create folder $folder on target "
                 . "mailbox: ". $peer->LastError);
            return undef
        };
    }

    defined $msgs or $msgs = "ALL";
    $msgs = $self->search("ALL")
        if uc $msgs eq 'ALL';

    my $range = $self->Range($msgs);
    my $clear = $self->Clear;

    $self->_debug("Migrating the following msgs from $folder: $range\n");
  MSG:
    foreach my $mid ($range->unfold)
    {
        $self->_debug("Migrating message $mid in folder $folder\n")
            if $self->Debug;

        my $leftSoFar = my $size = $self->size($mid);

        # fetch internaldate and flags of original message:
        my $intDate = $self->internaldate($mid);
        my @flags   = grep !/\\Recent/i, $self->flags($mid);
        my $flags   = join ' ', $peer->supported_flags(@flags);

        # set up transaction numbers for from and to connections:
        my $trans   = $self->Count($self->Count+1);
        my $ptrans  = $peer->Count($peer->Count+1);

        # If msg size is less than buffersize then do whole msg in one
        # transaction:
        if($size <= $bufferSize)
        {   my $new_mid = $peer->append_string
               ($folder, $self->message_string($mid), $flags, $intDate);

            unless(defined $new_mid)
            {   $self->LastError("Unable to append to $folder "
                   . "on target mailbox. ".  $peer->LastError);
                return undef;
            }

            $self->_debug("Copied message $mid in folder $folder to "
                . $peer->User . '@' . $peer->Server
                . ". New Message UID is $new_mid.\n")
                if $self->Debug;

            $peer->_debug("Copied message $mid in folder $folder from "
                .  $self->User .  '@' . $self->Server
                . ". New Message UID is $new_mid.\n")
                if $peer->Debug;

            next MSG;
        }

        # otherwise break it up into digestible pieces:
        my ($cmd, $pattern);
        if($self->imap4rev1)
        {   $cmd = $self->Peek ? 'BODY.PEEK[]' : 'BODY[]';
            $pattern = sub { $_[0] =~ /\(.*BODY\[\]<\d+> \{(\d+)\}/i; $1 };
        }
        else
        {   $cmd = $self->Peek ? 'RFC822.PEEK' : 'RFC822';
            $pattern = sub { $_[0] =~ /\(RFC822\[\]<\d+> \{(\d+)\}/i; $1 };
        }

        # Now let's warn the peer that there's a message coming:

        my $pstring = "$ptrans APPEND " . $self->Massage($folder)
           . (length $flags ? " ($flags)" : '') . qq[ "$intDate" {$size}];

        $self->_debug("About to issue APPEND command to peer for msg $mid\n")
            if $self->Debug;

        $peer->_record($ptrans, [0, "INPUT", $pstring] );
        unless($peer->_send_line($pstring))
        {   $self->LastError("Error sending '$pstring' to target IMAP: $!");
            return undef;
        }

        # Get the "+ Go ahead" response:
        my $code = 0;
        until($code eq '+' || $code =~ /NO|BAD|OK/)
        {
             my $readSoFar  = 0;
             my $fromBuffer = '';;
             $readSoFar += sysread($toSock, $fromBuffer, 1, $readSoFar) || 0
                 until $fromBuffer =~ /\x0d\x0a/;

             $code = $fromBuffer =~ /^\+/ ? $1
                   : $fromBuffer =~ / ^(?:\d+\s(BAD|NO))/ ? $1 : 0;

             $peer->_debug( "$folder: received $fromBuffer from server\n")
                if $peer->Debug;

             # ... and log it in the history buffers
             $self->_record($trans, [0, "OUTPUT",
     "Mail::IMAPClient migrating message $mid to $peer->User\@$peer->Server"] );
             $peer->_record($ptrans, [0, "OUTPUT", $fromBuffer] );
        }

        if($code ne '+')
        {   $self->_debug("Error writing to target host: $@\n");
            next MIGMSG;
        }

        # Here is where we start sticking in UID if that parameter
        # is turned on:
        my $string = ($self->Uid ? "UID " : "") . "FETCH $mid $cmd";

        # Clean up history buffer if necessary:
        $self->Clear($clear)
            if $self->Count >= $clear && $clear > 0;

       # position will tell us how far from beginning of msg the
       # next IMAP FETCH should start (1st time start at offet zero):
       my $position   = 0;
       my $chunkCount = 0;
       while($leftSoFar > 0)
       {   my $take      = min $leftSoFar, $bufferSize;
           my $newstring = "$trans $string<$position.$take>";

            $self->_record($trans, [0, "INPUT", "$newstring\x0d\x0a"] );
            $self->_debug("Issuing migration command: $newstring\n" )
                if $self->Debug;;

            unless($self->_send_line($newstring))
            {   $self->LastError("Error sending '$newstring' to source IMAP: $!");
                return undef;
            }

            my $chunk;
            until($chunk = $pattern->($fromBuffer))
            {   $fromBuffer = "";
                until($fromBuffer=~/\x0d\x0a$/ )
                {    sysread($fromSock, $fromBuffer, 1, length($fromBuffer));
                }

                $self->_record($trans, [0, "OUTPUT", "$fromBuffer"]);

                if($fromBuffer =~ /^$trans (?:NO|BAD)/ )
                {   $self->LastError($fromBuffer);
                    next MIGMSG;
                }

                if($fromBuffer =~ /^$trans (?:OK)/ )
                {   $self->LastError("Unexpected good return code " .
                        "from source host: $fromBuffer");
                    next MIGMSG;
                }

            }

            $fromBuffer = "";
            my $readSoFar = 0;
            while($readSoFar < $chunk)
            {   $readSoFar += sysread($fromSock, $fromBuffer
                                 , $chunk-$readSoFar,$readSoFar) ||0;
            }

            my $wroteSoFar = 0;
            my $temperrs   = 0;
            my $waittime   = .02;
            my $maxagain   = $self->Maxtemperrors || 10;
            undef $maxagain if $maxagain eq 'unlimited';
            my @previous_writes;

            while($wroteSoFar < $chunk)
            {   while($wroteSoFar < $readSoFar)
                {   my $ret = syswrite($toSock, $fromBuffer
                       , $chunk - $wroteSoFar, $wroteSoFar);

                    if(defined $ret)
                    {   $wroteSoFar += $ret;
                        $maxwrite = max $maxwrite, $ret;
                        $temperrs = 0;
                    }

                    if($! == EAGAIN)
                    {   if(defined $maxagain && $temperrs++ > $maxagain)
                        {   $self->LastError("Persistent '$!' errors");
                            return undef;
                        }

                        $waittime = $self->_optimal_sleep($maxwrite,
                             $waittime, \@previous_writes);
                        next;
                    }

                    return;  # no luck
                }

                $peer->_debug("Chunk $chunkCount: Wrote $wroteSoFar (of $chunk)\n");
            }
        }

        $position  += $readSoFar;
        $leftSoFar -= $readSoFar;
        $fromBuffer = "";

        # Finish up reading the server response from the fetch cmd
        #     on the source system:

        undef $code;
        until($code)
        {   $self->_debug("Reading from source server; expecting ') OK' type response\n");
            $output = $self->_read_line or return undef;
            foreach my $o (@$output)
            {   $self->_record($trans, $o);
                $self->_is_output($o) or next;

                $code = $o->[DATA] =~ /^$trans (OK|BAD|NO)/mi ? $1 : undef;
                if($o->[DATA] =~ /^\*\s+BYE/im)
                {   $self->State(Unconnected);
                   return undef;
                }
            }
        }
    }

    # Now let's send a <CR><LF> to the peer to signal end of APPEND cmd:
    {   my $wroteSoFar = 0;
        $fromBuffer = "\x0d\x0a";
        $wroteSoFar += syswrite($toSock,$fromBuffer,2-$wroteSoFar,$wroteSoFar)||0
                until $wroteSoFar >= 2;

    }

    # Finally, let's get the new message's UID from the peer:
    my $new_mid;
    undef $code;
    until($code)
    {   $peer->_debug("Reading from target: expect new uid in response\n");

        $output = $peer->_read_line or last;
        foreach my $o (@$output)
        {   $peer->_record($ptrans,$o);
            next unless $peer->_is_output($o);

            $code    = $o->[DATA] =~ /^$ptrans (OK|BAD|NO)/mi ? $1 : undef;
            $new_mid = $o->[DATA] =~ /APPENDUID \d+ (\d+)/ ? $1 : undef
                if $code;

            if($o->[DATA] =~ /^\*\s+BYE/im)
            {   $peer->State(Unconnected);
                return undef;
            }
        }

        $new_mid ||= "unknown";
    }

    if($self->Debug)
    {   $self->_debug("Copied message $mid in folder $folder to "
          . $peer->User.'@'.$peer->Server. ". New Message UID is $new_mid.\n");

        $peer->_debug("Copied message $mid in folder $folder from "
          . $self->User.'@'.$self->Server . ". New Message UID is $new_mid.\n");
    }

    $self;
}

# Optimization of wait time between syswrite calls only runs if syscalls
# run too fast and fill the buffer causing "EAGAIN: Resource Temp. Unavail"
# errors. The premise is that $maxwrite will be approx. the same as the
# smallest buffer between the sending and receiving side. Waiting time
# between syscalls should ideally be exactly as long as it takes the
# receiving side to empty that buffer, minus a little bit to prevent it
# from emptying completely and wasting time in the select call.

sub _optimal_sleep($$$)
{   my ($self, $maxwrite, $waittime, $last5writes) = @_;

    push  @$last5writes, $ret;
    shift @$last5writes if @$last5writes > 5;

    my $bufferavail = (sum @$last5writes) / @$last5writes;

    if($bufferavail < .4 * $maxwrite)
    {   # Buffer is staying pretty full; we should increase the wait
        # period to reduce transmission overhead/number of packets sent
        $waittime *= 1.3;
    }
    elsif($bufferavail > .9 * $maxwrite)
    {   # Buffer is nearly or totally empty; we're wasting time in select
        # call that could be used to send data, so reduce the wait period
        $waittime *= .5;
    }

    CORE::select(undef, undef, undef, $waittime);
    $waittime;
}

sub body_string
{   my ($self, $msg) = @_;
    my $ref = $self->fetch($msg, "BODY" .($self->Peek ? ".PEEK" : "")."[TEXT]");

    my $string = join '', map {$_->[DATA]}
        grep {defined $_ && $self->_is_literal($_)} @$ref;

    return $string
        if $string;

    while(my $head = shift @$ref)
    {   $self->_debug("body_string: head = '$head'\n");

        last if $head =~
            /(?:.*FETCH .*\(.*BODY\[TEXT\])|(?:^\d+ BAD )|(?:^\d NO )/i;
    }

    unless(@$ref)
    {   $self->LastError("Unable to parse server response from ".$self->LastIMAPCommand);
        return undef;
    }

    my $popped;
    $popped = pop @$ref    # (-: vi
        until ($popped && $popped =~ /\)\x0d\x0a$/)  # (-: vi
           || ! grep /\)\x0d\x0a$/, @$ref;

     if($head =~ /BODY\[TEXT\]\s*$/i )
     {   # Next line is a literal
         $string .= shift @$ref while @$ref;
         $self->_debug("String is now $string\n")
             if $self->Debug;
     }

     $string;
}


sub examine
{   my ($self, $target) = @_;
    defined $target or return undef;

    $target = $self->Massage($target);

    my $old = $self->Folder;

    $self->_imap_command("EXAMINE $target") && $self->State(Selected)
        or return undef;

    $self->Folder($target);
    $old || $self;
}

sub idle
{   my $self  = shift;
    my $good  = '+';
    my $count = $self->Count +1;
    $self->_imap_command("IDLE", $good) ? $count : undef;
}

sub done
{   my $self  = shift;
    my $count = shift || $self->Count;

    my $clear = $self->Clear;
    $self->Clear($clear)
        if $self->Count >= $clear && $clear > 0;

    my $string = "DONE\x0d\x0a";
    $self->_record($count, [$self->_next_index($count), "INPUT", "$string\x0d\x0a"] );

    unless($self->_send_line($string, 1))
    {   $self->LastError("Error sending '$string' to IMAP: $!");
        return undef;
    }

    my ($code, $output);
    $output = "";

    until($code && $code =~ /(OK|BAD|NO)/m)
    {   $output = $self->_read_line or return undef;
        for my $o (@$output)
        {   $self->_record($count,$o);
            next unless $self->_is_output($o);
            ($code) = $o->[DATA] =~ /^(?:$count) (OK|BAD|NO)/m;
            $self->State(Unconnected) if $o->[DATA] =~ /^\*\s+BYE/;
        }
    }
    $code =~ /^OK/ ? @{$self->Results} : undef;
}

sub tag_and_run
{   my ($self, $string, $good) = @_;
    $self->_imap_command($string, $good);
    @{$self->Results};  #??? enforce list context
}

# _{name} methods are undocumented and meant to be private.

# _imap_command runs a command, inserting the correct tag
# and <CR><LF> and whatnot.
# When updating _imap_command, remember to examine the run method,
# too, since it is very similar.

sub _imap_command
{   my $self   = shift;
    my $string = shift or return undef;
    my $good   = shift || 'GOOD';
    my $qgood  = quotemeta $good;

    my $clear = $clear = $self->Clear;
    $self->Clear($clear)
        if $self->Count >= $clear and $clear > 0;

    my $count  = $self->Count($self->Count+1);
    $string    = "$count $string";

    $self->_record($count, [0, "INPUT", "$string\x0d\x0a"] );

    unless($self->_send_line($string))
    {   $self->LastError("Error sending '$string' to IMAP: $!");
        return undef;
    }

    my $code;

   READ:
    until($code)
    {   my $output = $self->_read_line or return undef;
        foreach my $o (@$output)
        {   $self->_record($count, $o);
            $self->_is_output($o) or next;

            if($good eq '+')
            {   $o->[DATA] =~ /^$count (OK|BAD|NO|$qgood)|^($qgood)/mi;
                $code = $1||$2;
            }
            else
            {   ($code) = $o->[DATA] =~ /^$count (OK|BAD|NO|$qgood)/mi;
            }
            if ($o->[DATA] =~ /^\*\s+BYE/im)
            {   $self->State(Unconnected);
                return undef;
            }
        }
    }

    $code =~ /^OK|$qgood/im ? $self : undef;

}

sub _imap_uid_command
{   my $self = shift;
    my $cmd  = shift;
    my $args = @_ ? join(" ", '', @_) : '';
    my $uid  = $self->Uid ? 'UID ' : '';
    $self->_imap_command("$uid$cmd$args");
}

sub run
{
    my $self   = shift;
    my $string = shift or return undef;
    my $good   = shift || 'GOOD';
    my $count  = $self->Count($self->Count+1);
    my $tag    = $string =~ /^(\S+) / ? $1 : undef;

    $tag or $self->LastError("Invalid string passed to run method; no tag found.");

    my $qgood  = quotemeta($good);
    my $clear  = $self->Clear;
    $self->Clear($clear)
        if $self->Count >= $clear && $clear > 0;

    $self->_record($count, [$self->_next_index($count), "INPUT", "$string"] );

    unless($self->_send_line("$string",1))
    {   $self->LastError("Error sending '$string' to IMAP: $!");
        return undef;
    }

    my ($code, $output);
    $output = "";

    until($code =~ /(OK|BAD|NO|$qgood)/m )
    {   $output = $self->_read_line or return undef;
        foreach my $o (@$output)
        {   $self->_record($count,$o);
            next unless $self->_is_output($o);
            if($good eq '+')
            {   $o->[DATA] =~ /^(?:$tag|\*) (OK|BAD|NO|$qgood)|(^$qgood)/m;
                $code = $1 || $2;
            }
            else
            {   ($code) = $o->[DATA] =~ /^(?:$tag|\*) (OK|BAD|NO|$qgood)/m;
            }

            $o->[DATA] =~ /^\*\s+BYE/
                and $self->State(Unconnected);
        }
    }

    $tag eq $count
        or $self->{History}{$tag} = $self->{History}{$count};

    $code =~ /^OK|$qgood/ ? @{$self->Results} : undef;
}

# _record saves the conversation into the History structure:
sub _record
{   my ($self, $count, $array) = @_;
    local($^W)= undef;

    if ($array->[DATA] =~ /^\d+ LOGIN/i && !$self->Showcredentials)
    {   $array->[DATA] =~ s/LOGIN.*/LOGIN XXXXXXXX XXXXXXXX/i;
    }

    push @{$self->{History}{$count}}, $array;

    if($array->[DATA] =~ /^\d+\s+(BAD|NO)\s/im )
    {    $self->LastError($array->[DATA]);
         carp "$array->[DATA]" if $^W;
    }
    $self;
}

#_send_line writes to the socket:
sub _send_line
{   my ($self, $string,$suppress) = (shift, shift, shift);

    unless($self->IsConnected && $self->Socket)
    {   $self->LastError("NO Not connected.");
        carp "Not connected" if $^W;
        return undef;
    }

    unless($string =~ /\x0d\x0a$/ || $suppress )
    {   chomp $string;
        $string .= "\x0d" unless $string =~ /\x0d$/;
        $string .= "\x0a";
    }

    if ($string =~ /^[^\x0a{]*\{(\d+)\}\x0d\x0a/)  # ;-} vi
    {   my ($p1,$p2,$len);
        if( ($p1,$len) = $string =~ /^([^\x0a{]*\{(\d+)\}\x0d\x0a)/ # }-:  vi
            && ( $len < 32766
                 ? (($p2) = $string =~ / ^[^\x0a{]* \{\d+\} \x0d\x0a
                                        ( .{$len} .*\x0d\x0a) /x )
                 : (($p2) = $string =~ / ^[^\x0a{]* \{\d+\} \x0d\x0a
                                        (.*\x0d\x0a) /x
                    && length($p2) == $len  ) # }} vi
                )
           )
        {
            $self->_debug("Sending literal string " .
                "in two parts: $p1\n\tthen: $p2\n");

            $self->_send_line($p1) or return undef;
            $output = $self->_read_line or return undef;

            foreach my $o (@$output)
            {   $self->_record($self->Count, $o);
                ($code) = $o->[DATA] =~ /(^\+|NO|BAD)/i;

                if($o->[DATA] =~ /^\*\s+BYE/)
                {   $self->State(Unconnected);
                    close $fh;
                    return undef;
                }
                elsif($o->[DATA]=~ /^\d+\s+(NO|BAD)/i )
                {   close $fh;
                    return undef;
                }
            }

            $code eq '+' or return undef;
            $string = $p2;
        }
    }

    if($self->Debug)  # debug must not show password
    {   my $dstring = $string;
        my ($user, $passwd) = ($self->{Password}, $self->{User});
        $dstring =~ s#\b(?:\Q$passwd\E|\Q$user\E)\b#'X' x length($Passwd)#eg
           if $dstring =~ m[\d+\s+Login\s+]i;
        $self->_debug("Sending: $dstring\n");
    }

    if(my $prew = $self->Prewritemethod)
    {   $string = $prew->($self, $string);
        $self->_debug("Sending: $string\n");
    }

    my $total    = 0;
    my $temperrs = 0;
    my $maxwrite = 0;
    my $waittime = .02;
    my @previous_writes;

    my $maxagain = $self->Maxtemperrors || 10;
    undef $maxagain if $maxagain eq 'unlimited';

    while($total < length $string)
    {   my $ret = syswrite($self->Socket, $string, length($string)-$total,
                    $total);

        if(defined $ret)
        {   $temperrs = 0;
            $total += $ret;
            next;
        }

        if($! == EAGAIN)
        {   if(defined $maxagain && $temperrs++ > $maxagain)
            {   $self->LastError("Persistent '$!' errors");
                return undef;
            }

            $waittime = $self->_optimal_sleep($maxwrite, $waittime, \@previous_writes);
            next;
        }

        return;  # no luck
    }

    $self->_debug("Sent $total bytes\n");
    $total;
}

# _read_line: read one line from the socket

# It is also re-implemented in: message_to_file
#
# syntax: $output = $self->_readline( ( $literal_callback|undef ) , ( $output_callback|undef ) );
#    Both input argument are optional, but if supplied must either be a filehandle, coderef, or undef.
#
#    Returned argument is a reference to an array of arrays, ie:
#    $output = [
#            [ $index, 'OUTPUT'|'LITERAL', $output_line ] ,
#            [ $index, 'OUTPUT'|'LITERAL', $output_line ] ,
#            ...     # etc,
#    ];

sub _read_line
{   my ($self, $literal_callback, $output_callback) = @_;

    my $sh = $self->Socket;
    unless($self->IsConnected && $self->Socket)
    {   $self->LastError("NO Not connected.");
        return undef;
    }

    my $iBuffer  = "";
    my $oBuffer  = [];
    my $count    = 0;
    my $index    = $self->_next_index($self->Transaction);
    my $rvec     = my $ready = my $errors = 0;
    my $timeout  = $self->Timeout;

    my $readlen  = 1;
    my $fast_io  = $self->Fast_io;

    if($fast_io)
    {   $self->Fast_io($fast_io) if exists $self->{_fcntl};
        $readlen = $self->{Buffer} || 4096;
    }

    until(@$oBuffer # there's stuff in output buffer:
      && $oBuffer->[-1][DATA] =~ /\x0d\x0a$/ # the last thing there has cr-lf:
      && $oBuffer->[-1][TYPE] eq "OUTPUT" # that thing is an output line:
      && !length($iBuffer)                # and the input buffer has been MT'ed:
    )
    {   my $transno = $self->Transaction;

        if($timeout)
        {   vec($rvec, fileno($self->Socket), 1) = 1;

            my @ready = $self->{_select}->can_read($timeout);
            unless(@ready)
            {   $self->LastError("Tag $transno: Timeout after $timeout seconds"
                    . " waiting for data from server");

                $self->_record($transno,
                    [ $self->_next_index($transno), "ERROR"
                    , "$transno * NO Timeout after $timeout seconds " .
                        "during read from server\x0d\x0a"]);

                $self->LastError("Timeout after $timeout seconds during "
                    . "read from server\x0d\x0a");

                return undef;
            }
        }

        no warnings;

        my $ret = $self->_sysread($sh, \$iBuffer, $readlen, length($iBuffer));

        if($timeout && !defined $ret)
        {   # Blocking read error...
            my $msg = "Error while reading data from server: $!\x0d\x0a";
            $self->_record($transno,
               [ $self->_next_index($transno), "ERROR", "$transno * NO $msg "]);
            $@ = $msg;
            return undef;
        }

        if(defined $ret && $ret == 0)    # Caught EOF...
        {   my $msg = "Socket closed while reading data from server.\x0d\x0a";
            $self->_record($transno,
                [ $self->_next_index($transno), "ERROR","$transno * NO $msg "]);
            $@ = $msg;
            return undef;
        }

        # successfully wrote to other end, keep going...
        $count += $ret;

        while($iBuffer =~ s/^(.*?\x0d?\x0a)// )
        {   my $current_line = $1;

            # This part handles IMAP "Literals",
            # which according to rfc2060 look something like this:
            # [tag]|* BLAH BLAH {nnn}\r\n
            # [nnn bytes of literally transmitted stuff]
            # [part of line that follows literal data]\r\n

            if($current_line !~ s/\{(\d+)\}\x0d\x0a$//)
            {   push @$oBuffer, [$index++, "OUTPUT" , $current_line];
                next;
            }

            ## handle LITERAL

            # Set $len to be length of impending literal:
            my $len = $1;

            $self->_debug("LITERAL: received literal in line ".
               "$current_line of length $len; attempting to ".
               "retrieve from the " . length($iBuffer) .
               " bytes in: $iBuffer<END_OF_iBuffer>\n");

            # Xfer up to $len bytes from front of $iBuffer to $litstring:
            my $litstring = substr $iBuffer, 0, $len, '';

            # Figure out what's left to read (i.e. what part of
            # literal wasn't in buffer):
            my $remainder_count = $len - length $litstring;
            my $callback_value = "";

            if(!$literal_callback) { ; }
            elsif(UNIVERSAL::isa($literal_callback, 'GLOB'))
            {   print $literal_callback $litstring;
                $litstring = "";
            }
            elsif(UNIVERSAL::isa($literal_callback, 'CODE'))
            {   ; } # ignore
            else
            {   $self->LastError(ref($literal_callback) . " is an "
                  . "invalid callback; must be a filehandle or CODE");
            }

            if($remainder_count > 0 && $timeout)
            {
                 # wait for data from the the IMAP socket.
                 vec($rvec, fileno($self->Socket), 1) = 1;
                 unless(CORE::select($ready = $rvec, undef,
                             $errors = $rvec, $timeout))
                 {    $self->LastError("Tag $transno: Timeout waiting for "
                         . "literal data from server");
                     return undef;
                 }
            }

            fcntl($sh, F_SETFL, $self->{_fcntl})
                if $fast_io && defined $self->{_fcntl};

            while($remainder_count > 0 )
            {   $self->_debug("Still need $remainder_count to " .
                    "complete literal string\n");

                my $ret = $self->_sysread($sh
                   , \$litstring, $remainder_count, length $litstring);

                $self->_debug("Received ret=$ret and buffer = " .
                   "\n$litstring<END>\nwhile processing LITERAL\n");

                if($timeout && !defined $ret)
                {   $self->_record($transno,
                        [ $self->_next_index($transno), "ERROR",
                   "$transno * NO Error reading data from server: $!\n" ]);
                    return undef;
                }

                if($ret == 0 && $sh->eof)
                {   $self->_record($transno,
                       [ $self->_next_index($transno), "ERROR",
            "$transno * BYE Server unexpectedly closed connection: $!\n" ]);
                    $self->State(Unconnected);
                    return undef;
                }

                $remainder_count -= $ret;

                if(length $litstring > $len)
                {    # copy the extra struff into the iBuffer:
                     $iBuffer = substr $litstring, $len
                        , length($litstring) - $len, '';

                     if($literal_callback
                        && UNIVERSAL::isa($literal_callback, 'GLOB'))
                     {   print $literal_callback $litstring;
                         $litstring = "";
                     }
                }
            }

            $literal_callback->($litstring)
                if defined $litstring
                && UNIVERSAL::isa($literal_callback, 'CODE');

            $self->Fast_io($fast_io) if $fast_io;

            # Now let's make sure there are no IMAP server output lines
            # (i.e. [tag|*] BAD|NO|OK Text) embedded in the literal string
            # (There shouldn't be but I've seen it done!), but only if
            # EnableServerResponseInLiteral is set to true

            my $embedded_output = 0;
            my $lastline = ( split(/\x0d?\x0a/,$litstring))[-1]
                if $litstring;

            if(  $self->EnableServerResponseInLiteral
               && $lastline
               && $lastline =~ /^(?:\*|(\d+))\s(BAD|NO|OK)/i)
            {
                $litstring =~ s/\Q$lastline\E\x0d?\x0a//;
                $embedded_output++;

                $self->_debug("Got server output mixed in with literal: $lastline\n");
            }

            # Finally, we need to stuff the literal onto the
            # end of the oBuffer:
            push @$oBuffer, [$index++, "OUTPUT", $current_line],
                    [ $index++, "LITERAL", $litstring   ];

            push @$oBuffer, [$index++, "OUTPUT", $lastline]
                    if $embedded_output;

        }
    }

    $self->_debug("Read: " . join("",map {$_->[DATA]} @$oBuffer) ."\n");
    @$oBuffer ? $oBuffer : undef;
}

sub _sysread($$$$)
{   my ($self, $fh, $buf, $len, $off) = @_;
    my $rm   = $self->Readmethod;
    $rm ? $rm->($self, @_) : sysread($fh, $buf, $len, $off);
}

sub _trans_index()   { sort {$a <=> $b} keys %{$_[0]->{History}} }

# all default to last transaction
sub _transaction(;$) { @{$_[0]->{History}{$_[1] || $_[0]->Transaction}} }
sub _trans_data(;$)  { map { $_->[DATA] } $_[0]->_transaction($_[1]) }

sub Report {
    my $self = shift;
    map { $self->_trans_data($_) } $self->_trans_index;
}

sub Results(;$)
{   my ($self, $trans) = @_;
    my @a = $self->_trans_data($trans);
    wantarray ? @a : \@a;
}

sub LastIMAPCommand(;$)
{   my ($self, $trans) = @_;
    my $cmd = ($self->_transaction($trans))[0];
    $msg ? $msg->[DATA] : undef;
}

sub History(;$)
{   my ($self, $trans) = @_;
    my ($cmd, @a) = $self->_trans_data($trans);
    wantarray ? @a : \@a;
}

# Don't know what it does, but used a few times.
sub transactionLiterals()
{   my $self = shift;
    join '', map { $_->[DATA] }
       grep { defined $_ && $self->_is_literal($_) }
          $self->_transaction;
}

sub Escaped_results
{   my ($self, $trans) = @_;
    my @a;
    foreach my $line (grep defined, $self->Results($trans))
    {   if($self->_is_literal($line))
        {   $line->[DATA] =~ s/([\\\(\)"\x0d\x0a])/\\$1/g;
            push @a, qq("$line->[DATA]");
        }
        else { push @a, $line->[DATA] }
    }

    shift @a;    # remove cmd
    wantarray ? @a : \@a;
}

sub Unescape
{   my $whatever = defined $_[1] ? $_[1] : $_[0];
    $whatever =~ s/\\([\\\(\)"\x0d\x0a])/$1/g;
    $whatever;
}

sub logout {
    my $self = shift;
    $self->_imap_command("LOGOUT");

    delete $self->{Folders};
    delete $self->{_IMAP4REV1};
    eval {$self->Socket->close} if $self->Socket;
    delete $self->{Socket};

    $self->State(Unconnected);
    $self;
}

sub folders
{   my ($self, $what) = @_;

    ref $self->{Folders} && !$what
        or return wantarray ? @{$self->{Folders}} : $self->{Folders};

    my @folders;
    my @list = $self->list(undef,($what ? $what.$self->separator($what)."*" : undef ) );
    push @list, $self->list(undef, $what)
        if $what && $self->exists($what);

    for(my $m = 0; $m < scalar(@list); $m++ )
    {   if($list[$m] && $list[$m] !~ /\x0d\x0a$/ )
        {   $self->_debug("folders: concatenating $list[$m] and $list[$m+1]\n");
            $list[$m] .= $list[$m+1];
            $list[$m+1] = "";
            $list[$m] .= "\x0d\x0a" unless $list[$m] =~ /\x0d\x0a$/;
        }

        $list[$m] =~ / ^\*\s+LIST               # * LIST
                        \s+\([^\)]*\)\s+         # (Flags)
                        (?:"[^"]*"|NIL)\s+     # "delimiter" or NIL
                        (?:"([^"]*)"|(.*))\x0d\x0a$  # Name or "Folder name"
                     /ix
            or next;

        my $folder = $1 || $2;
        $folder = qq("$folder")
            if $1 && !$self->exists($folder);

        push @folders, $folder
   }

    my (@clean, %memory);
    foreach my $f (@folders) { push @clean, $f unless $memory{$f}++ }
    $self->{Folders} = \@clean unless $what;

    wantarray ? @clean : \@clean;
}


sub exists
{   my ($self, $what) = @_;
    $self->STATUS($self->Massage($what),"(MESSAGES)") ? $self : undef;
}

# Updated to handle embedded literal strings
sub get_bodystructure
{   my($self, $msg) = @_;
    unless(eval {require Mail::IMAPClient::BodyStructure; 1} )
    {   $self->LastError("Unable to use get_bodystructure: $@");
        return undef;
    }

    my @out = $self->fetch($msg,"BODYSTRUCTURE");
    my $bs = "";
    my $output = grep /BODYSTRUCTURE \(/i, @out;    # Wee! ;-)
    if($output =~ /\r\n$/)
    {   $bs = eval { Mail::IMAPClient::BodyStructure->new($output) };
    }
    else
    {   $self->_debug("get_bodystructure: reassembling original response\n");
        my $start = 0;
        foreach my $o ($self->Results)
        {   next unless $self->_is_output_or_literal($o);
            next unless $start or
                $o->[DATA] =~ /BODYSTRUCTURE \(/i and ++$start; # Hi, vi! ;-)

            if(length $output && $self->_is_literal($o) )
            {   my $data = $o->[DATA];
                $data =~ s/"/\\"/g;
                $data =~ s/\(/\\\(/g;
                $data =~ s/\)/\\\)/g;
                $output .= qq("$data");
            }
            else { $output .= $o->[DATA] }

            $self->_debug("get_bodystructure: reassembled output=$output<END>\n");
        }
        eval { $bs = Mail::IMAPClient::BodyStructure->new( $output )};
    }

    $self->_debug("get_bodystructure: msg $msg returns: ".($bs||"UNDEF")."\n");
    $bs;
}

# Updated to handle embedded literal strings
sub get_envelope
{   my ($self,$msg) = @_;
    unless( eval {require Mail::IMAPClient::BodyStructure ; 1 } )
    {   $self->LastError("Unable to use get_envelope: $@");
        return undef;
    }

    my @out = $self->fetch($msg,"ENVELOPE");
    my $bs = "";
    my $output = first { /ENVELOPE \(/i } @out;    # Wee! ;-)
    if($output =~ /\r\n$/ )
    {   eval { $bs = Mail::IMAPClient::BodyStructure::Envelope->new($output) };
    }
    else
    {   $self->_debug("get_envelope: reassembling original response\n");
        my $start = 0;
        foreach my $o ($self->Results)
        {   next unless $self->_is_output_or_literal($o);
            $self->_debug("o->[DATA] is $o->[DATA]\n");

            next unless $start or
                $o->[DATA] =~ /ENVELOPE \(/i and ++$start;
                # Hi, vi! ;-)

            if ( length($output) and $self->_is_literal($o) ) {
                my $data = $o->[DATA];
                $data =~ s/"/\\"/g;
                $data =~ s/\(/\\\(/g;
                $data =~ s/\)/\\\)/g;
                $output .= '"'.$data.'"';
            } else {
                $output .= $o->[DATA];
            }
            $self->_debug("get_envelope: " .
                "reassembled output=$output<END>\n");
        }

        eval { $bs=Mail::IMAPClient::BodyStructure::Envelope->new($output) };
    }

    $self->_debug("get_envelope: msg $msg returns ref: ".($bs||"UNDEF")."\n");
    $bs;
}

sub fetch
{   my $self = shift;
    my $what = shift || "ALL";

    my $take
      = $what eq 'ALL' ? $self->Range($self->messages)
      : ref $what || $what =~ /^[,:\d]+\w*$/ ? $self->Range($what)
      : $what;

    $self->_imap_uid_command(FETCH => $take, @_)
        or return ();

    wantarray ? $self->History : $self->Results;
}

sub fetch_hash
{   my $self  = shift;
    my $uids  = ref $_[-1] ? pop @_ : {};
    my @words = @_;
    my $what  = join ' ', @_;

    for(@words)
    {  s/([\( ])FAST([\) ])/${1}FLAGS INTERNALDATE RFC822\.SIZE$2/i;
       s/([\( ])FULL([\) ])/${1}FLAGS INTERNALDATE RFC822\.SIZE ENVELOPE BODY$2/i;
    }

    my $msgref = scalar $self->messages;
    my $output = scalar $self->fetch($msgref, "($what)");

    for(my $x = 0;  $x <= $#$output ; $x++)
    {   my $entry = {};
        my $l = $output->[$x];

        if($self->Uid)
        {   my $uid = $l =~ /\bUID\s+(\d+)/i ? $1 : undef;
            $uid or next;

            if($uids->{$uid}) { $entry = $uids->{$uid} }
            else              { $uids->{$uid} ||= $entry }

        }
        else
        {   my $mid = $l =~ /^\* (\d+) FETCH/i ? $1 : undef;
            $mid or next;

            if($uids->{$mid}) { $entry = $uids->{$mid} }
            else              { $uids->{$mid} ||= $entry }
        }

        foreach my $w (@words)
        {   if($l =~ /\Q$w\E\s*$/i )
            {  $entry->{$w} = $output->[$x+1];
               $entry->{$w} =~ s/(?:\x0a?\x0d)+$//g;
               chomp $entry->{$w};
            }
            else
            {
            $l =~ /\(      # open paren followed by ...
                (?:.*\s)?  # ...optional stuff and a space
                \Q$w\E\s   # escaped fetch field<sp>
                (?:"       # then: a dbl-quote
                  (\\.|    # then bslashed anychar(s) or ...
                   [^"]+)  # ... nonquote char(s)
                "|         # then closing quote; or ...
                \(         # ...an open paren
                  (\\.|    # then bslashed anychar or ...
                   [^\)]+) # ... non-close-paren char
                \)|        # then closing paren; or ...
                (\S+))     # unquoted string
                (?:\s.*)?  # possibly followed by space-stuff
                \)         # close paren
            /xi;
            $entry->{$w} = defined $1 ? $1 : defined $2 ? $2 : $3;
           }
        }
    }
    wantarray ? %$uids : $uids;
}

sub store
{   my ($self, @a) = @_;
    delete $self->{Folders};
    $self->_imap_uid_command(store => @a)
        or return undef;
    wantarray ? $self->History : $self->Results;
}

sub subscribe
{   my ($self, @a) = @_;
    delete $self->{Folders};
    $a[-1] = $self->Massage($a[-1]) if @a;
    $self->_imap_uid_command(SUBSCRIBE => @a)
        or return undef;
    wantarray ? $self->History : $self->Results;
}

sub delete
{   my ($self, @a) = @_;
    delete $self->{Folders};
    $a[-1] = $self->Massage($a[-1]) if @a;
    $self->_imap_uid_command(DELETE => @a)
        or return undef;
    wantarray ? $self->History : $self->Results;
}

sub myrights
{   my ($self, @a) = @_;
    delete $self->{Folders};
    $a[-1] = $self->Massage($a[-1]) if @a;
    $self->_imap_uid_command(MYRIGHTS => @a)
        or return undef;
    wantarray ? $self->History : $self->Results;
}

sub create
{   my ($self, @a) = @_;
    delete $self->{Folders};
    $a[0] = $self->Massage($a[0]) if @a;
    $self->_imap_uid_command(CREATE => @a)
        or return undef;
    wantarray ? $self->History : $self->Results;
}

sub close
{   my $self = shift;
    $self->Folders(undef);
    $self->_imap_uid_command('CLOSE')
        or return undef;
    wantarray ? $self->History : $self->Results;
}

sub expunge
{   my ($self, $folder) = @_;
    defined $folder
        or return;

    my $old = $self->Folder;
    if(defined $old && $folder eq $old)
    {   $self->select($folder);
        my $succ = $self->_imap_command('EXPUNGE');
        $self->select($old);
        $succ or return undef;
    }
    else
    {   $self->_imap_command('EXPUNGE')
            or return undef;
    }

    wantarray ? $self->History : $self->Results;
}

sub rename
{   my ($self, $from, $to) = @_;

    if($from =~ /^"(.*)"$/)
    {   $from = $1 unless $self->exists($from);
        $from =~ s/"/\\"/g;
    }

    if($to =~ /^"(.*)"$/)
    {   $to = $1 unless $self->exists($from) && $from =~ /^".*"$/;
        $to =~ s/"/\\"/g;
    }

    $self->_imap_command( qq[RENAME "$from" "$to"] ) ? $self : undef;
}

sub status
{   my $self   = shift;
    my $folder = shift;
    defined $folder or return;

    my $box = $self->Massage($folder);
    my $which = @_ ? join(" ", @_) : 'MESSAGES';

    $self->_imap_command("STATUS $box ($which)")
       or return undef;

    wantarray ? $self->History : $self->Results;
}

sub flags
{   my ($self, $msgspec) = @_;
    my $msg
      = ref $msgspec && $msgspec->isa('Mail::IMAPClient::MessageSet')
      ? $msgspec
      : $self->Range($msgspec);

    $msg->cat(@_) if @_;

    # Send command
    $self->fetch($msg, "FLAGS")
        or return undef;

    my $u_f = $self->Uid;
    my $flagset = {};

    # Parse results, setting entry in result hash for each line
    foreach my $resultline ($self->Results)
    {   $self->_debug("flags: line = '$resultline'\n");
        if (    $resultline =~
            /\*\s+(\d+)\s+FETCH\s+    # * nnn FETCH
             \(            # open-paren
             (?:\s?UID\s(\d+)\s?)?    # optional: UID nnn <space>
             FLAGS\s?\((.*)\)\s?      # FLAGS (\Flag1 \Flag2) <space>
             (?:\s?UID\s(\d+))?       # optional: UID nnn
             \)                       # close-paren
            /x
        )
        {   my $mailid = $u_f ? ($2||$4) : $1;
            $flagset->{$mailid} = [ split " ", $3 ];
        }
    }

    # Or did he want a hash from msgid to flag array?
    return $flagset
        if ref $msgspec;

    # or did the guy want just one response? Return it if so
    my $flagsref = $flagset->{$msgspec};
    wantarray ? @$flagsref : $flagsref;
}

# reduce a list, stripping undeclared flags. Flags with or without
# leading backslash.
sub supported_flags(@)
{   my $self = shift;
    my $sup  = $self->Supportedflags
        or return @_;

    return map { $sup->($_) } @_
        if ref $sup eq 'CODE';

    grep { $sup->{ /^\\(\S+)/ ? lc $1 : ()} } @_;
}

# parse_headers modified to allow second param to also be a
# reference to a list of numbers. If this is a case, the headers
# are read from all the specified messages, and a reference to
# an hash of mail numbers to references to hashes, are returned.
# I found, with a mailbox of 300 messages, this was
# *significantly* faster against our mailserver (< 1 second
# vs. 20 seconds)
#
# 2000-03-22 Adrian Smith (adrian.smith@ucpag.com)

sub parse_headers
{   my ($self, $msgspec, @fields) = @_;
    my $fields = join ' ', @fields;
    my $msg    = ref $msgspec eq 'ARRAY' ? $self->Range($msgspec) : $msgspec;
    my $peek   = !defined $self->Peek || $self->Peek ? '.PEEK' : '';

    my $string = "$msg body$peek"
       . ($fields eq 'ALL' ? '[HEADER]' : "[HEADER.FIELDS ($fields)]");

    my @raw = $self->fetch($string)
        or return undef;

    my %headers; # HASH from message ids to headers
    my $h;       # HASH of fields for current msgid
    my $field;   # previous field name
    my %fieldmap = map { ( lc($_) => $_ ) } @fields;

    foreach my $header (map {split /\x0d?\x0a/} @raw)
    {
        if($header =~ s/^(?:\*|UID) \s+ (\d+) \s+ FETCH \s+
                        \( \s* BODY\[HEADER (?:\.FIELDS)? .*? \]\s*//ix)
        {   # start new message header
            $h = $headers{$1} = {};
        }
        $header =~ /\S/ or next;

        # ( for vi
        if($header =~ /^\)/)  # end of this message
        {   undef $h;  # inbetween headers
            next;
        }

        unless(defined $h)
        {   $self->_debug("found data between fetch headers: $header");
            next;
        }

        if($header =~ s/^(\S+)\:\s*//)
        {   $field = $fieldmap{lc $1} || $1;
            push @{$h->{$field}}, $header;
        }
        elsif(ref $h->{$field} eq 'ARRAY')  # folded header
        {   $h->{$field}[-1] .= $header;
        }
    }

    # if we asked for one message, just return its hash,
    # otherwise, return hash of numbers => header hash
    ref $msgspec eq 'ARRAY' ? \%headers : $headers{$msgspec};
}

sub subject       { $_[0]->get_header($_[1], "Subject") }
sub date          { $_[0]->get_header($_[1], "Date") }
sub rfc822_header { shift->get_header(@_) }

sub get_header
{   my ($self, $msg, $field) = @_;
    my $headers = $self->parse_headers($msg, $field);
    $headers ? $headers->{$field}[0] : undef;
}

sub recent_count
{   my ($self, $folder) = (shift, shift);

    $self->status($folder, 'RECENT')
        or return undef;

    my $r = first {s/\*\s+STATUS\s+.*\(RECENT\s+(\d+)\s*\)/$1/} $self->History;
    chomp $r;
    $r;
}

sub message_count
{   my $self   = shift;
    my $folder = shift || $self->Folder;

    $self->status($folder, 'MESSAGES')
        or return undef;

    foreach my $result ($self->Results)
    {   return $1 if $result->[DATA] =~ /\(MESSAGES\s+(\d+)\s*\)/;
    }

    undef;
}

sub recent()       { shift->search('recent') }
sub seen()         { shift->search('seen')   }
sub unseen()       { shift->search('unseen') }
sub messages()     { shift->search('ALL')    }

sub sentbefore($$) { shift->_search_date(sentbefore => @_) }
sub sentsince($$)  { shift->_search_date(sentsince  => @_) }
sub senton($$)     { shift->_search_date(senton     => @_) }
sub since($$)      { shift->_search_date(since      => @_) }
sub before($$)     { shift->_search_date(before     => @_) }
sub on($$)         { shift->_search_date(on         => @_) }

sub _search_date($$$)
{   my($self, $how, $time) = @_;
    my $imapdate;

    if($time =~ /\d\d-\D\D\D-\d\d\d\d/ )
    {   $imapdate = $time;
    }
    elsif($time =~ /^\d+$/ )
    {   my @ltime = localtime $time;
        $imapdate = sprintf "%2.2d-%s-%4.4d"
           , $ltime[3], $mnt[$ltime[4]], $ltime[5] + 1900;
    }
    else
    {   $self->LastError("Invalid date format supplied to '$datum' method.");
        return undef;
    }

    $self->_imap_uid_command(SEARCH => $datum, $imapdate)
        or return undef;

    my @hits;
    foreach ($self->History)
    {   chomp;
        s/\r$//;
        s/^\*\s+SEARCH\s+//i or next;
        push @hits, grep /\d/, split;
    }
    $self->_debug("Hits are: @hits\n");
    wantarray ? @hits : \@hits;
}

sub or
{   my ($self, @what) = @_;
    if(@what < 2)
    {   $self->LastError("Invalid number of arguments passed to or()");
        return undef;
    }

    my $or = "OR ".$self->Massage(shift @what)." ".$self->Massage(shift @what);

    $or    = "OR $or " . $self->Massage($_)
        for @what;

    $self->_imap_uid_command(SEARCH => $or)
        or return undef;

    my @hits;
    foreach ($self->History)
    {   chomp;
        s/\r$//;
        s/^\*\s+SEARCH\s+//i or next;
        push @hits, grep /\d/, split;
    }
    $self->_debug("Hits are now: @hits\n");

    wantarray ? @hits : \@hits;
}

sub disconnect { shift->logout }

sub search
{   my ($self, @a) = @_;

    $@ = "";
    # massage?
    $a[-1] = $self->Massage($a[-1], 1)
        if @a > 1 && !exists $SEARCH_KEYS{uc $a[-1]};

    $self->_imap_uid_command(SEARCH => @a)
        or return undef;

    my @hits;
    foreach ($self->History)
    {   chomp;
        s/\r\n?/ /g;
        s/^\*\s+SEARCH\s+(?=.*\d.*)// or next;
        push @hits, grep /^\d+$/, split;
    }

    @hits
        or $self->LastError("Search completed successfully but "
              . "found no matching messages");

      wantarray     ? @hits
    : !@hits        ? undef
    : $self->Ranges ? $self->Range(\@hits)
    :                 \@hits;
}

# returns a Thread data structure
my $thread_parser;
sub thread
{   my $self      = shift;
    my $algorythm = shift ||
     ($self->has_capability("THREAD=REFERENCES")?"REFERENCES":"ORDEREDSUBJECT");
    my $charset   = shift || "UTF-8";
    my @a         = @_ ? @_ : 'ALL';

    $a[-1] = $self->Massage($a[-1], 1)
        if @a > 1 && ! exists $SEARCH_KEYS{uc $a[-1]};

    $self->_imap_uid_command(THREAD => $algorythm, $charset, @a)
        or return undef;

    unless($thread_parser)
    {   return if $thread_parser == 0;

        eval "require Mail::IMAPClient::Thread";
        if($@)
        {   $self->LastError($@);
            $thread_parser = 0;
            return undef;
        }
        $thread_parser = Mail::IMAPClient::Thread->new;
    }

    my $thread;
    foreach ($self->History)
    {   chomp $r;
        s/\r\n?/ /g;
        /^\*\s+THREAD\s+/ or next;

        $thread = $thread_parser->start($r);
    }

    unless($thread)
    {   $self->LastError("Thread search completed successfully but found no matching messages");
        return undef;
    }

    $thread;
}

sub delete_message
{   my $self = shift;
    my @msgs = map {ref $arg eq 'ARRAY' ? @$arg : split /\,/, $arg} @_;

      $self->store(join(',',@msgs),'+FLAGS.SILENT','(\Deleted)')
    ? scalar @msgs
    : 0
}

sub restore_message
{   my $self = shift;
    my @msgs = map {ref $arg eq 'ARRAY' ? @$arg : split /\,/, $arg} @_;

    $self->store(join(',',@msgs),'-FLAGS','(\Deleted)');
    scalar grep /^\*\s\d+\sFETCH\s\(.*FLAGS.*(?!\\Deleted)/, $self->Results;
}

#??? compare to uidnext.  Why is Massage missing?
sub uidvalidity
{   my ($self, $folder) = @_;
    my $vline = first { /UIDVALIDITY/i } $self->status($folder, "UIDVALIDITY");
    defined $vline && $vline =~ /\(UIDVALIDITY\s+([^\)]+)/ ? $1 : undef;
}

sub uidnext
{   my $self   = shift;
    my $folder = $self->Massage(shift);
    my $line   = first { /UIDNEXT/i } $self->status($folder, "UIDNEXT");
    defined $line && $line =~ /\(UIDNEXT\s+([^\)]+)/ ? $1 : undef;
}

sub capability
{   my $self = shift;
    $self->_imap_command('CAPABILITY')
        or return undef;

    if($self->{CAPABILITY})
    {   my @caps = keys %{$self->{CAPABILITY}};
        return wantarray ? @caps : \@caps;
    }
     
    my @caps = map { split } grep s/^\*\s+CAPABILITY\s+//, $self->History;
    foreach (@caps)
    {   $self->{CAPABILITY}{uc $_}++;
        $self->{uc $1} = uc $2 if /(.*?)\=(.*)/;
    }

    wantarray ? @caps : \@caps;
}

sub has_capability
{   my ($self, $which) = @_;
    $self->capability;
    $which ? $self->{CAPABILITY}{uc $which} : undef;
}

sub imap4rev1 {
    my $self = shift;
    return $self->{_IMAP4REV1} if exists $self->{_IMAP4REV1};
    $self->{_IMAP4REV1} = $self->has_capability(IMAP4REV1);
}

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
    unless($self->has_capability("NAMESPACE"))
    {   $self->LastError($self->Count." NO NAMESPACE not supported by "
          . $self->Server);
        return undef;
    }

    my @namespaces = map { /^\* NAMESPACE (.*)/ ? $1 : () }
       $self->_imap_command("NAMESPACE")->Results;

    my $namespace = shift @namespaces;
    $namespace    =~ s/\x0d?\x0a$//;

    my($personal, $shared, $public) = $namespace =~ m#
        (NIL|\((?:\([^\)]+\)\s*)+\))\s
        (NIL|\((?:\([^\)]+\)\s*)+\))\s
        (NIL|\((?:\([^\)]+\)\s*)+\))
    #xi;

    my @ns;
    $self->_debug("NAMESPACE: pers=$personal, shared=$shared, pub=$public\n");
    foreach ($personal, $shared, $public)
    {   s/^\((.*)\)$/$1/;
        lc $_ ne 'NIL' or next;

        my @pieces = m#\(([^\)]*)\)#g;
        $self->_debug("NAMESPACE pieces: @pieces\n");

        push @ns, [ map { [ m#"([^"]*)"\s*#g ] } @pieces ]; 
    }

    wantarray ? @ns : \@ns;
}

sub internaldate
{   my ($self, $msg) = @_;
    $self->_imap_uid_command(FETCH => $msg, 'INTERNALDATE')
        or return undef;
    my $internalDate = join '',  $self->History;
    $internalDate =~ s/^.*INTERNALDATE "//si;
    $internalDate =~ s/\".*$//s;
    $internalDate;
}

sub is_parent
{   my ($self, $folder) = (shift, shift);
    my $list = $self->list(undef, $folder) || "NO NO BAD BAD";
    my $line;

    for(my $m = 0; $m < @$list; $m++)
    {
        #$self->_debug("Judging whether or not $list->[$m] is fit for parenthood\n");

       return undef
           if $list->[$m] =~ /NoInferior/i;

       if($list->[$m]  =~ s/(\{\d+\})\x0d\x0a$// )
       {   $list->[$m] .= $list->[$m+1];
           $list->[$m+1] = "";
       }

        $line = $list->[$m]
            if $list->[$m] =~
                    /       ^\*\s+LIST              # * LIST
                            \s+\([^\)]*\)\s+            # (Flags)
                            "[^"]*"\s+              # "delimiter"
                            (?:"([^"]*)"|(.*))\x0d\x0a$  # Name or "Folder name"
                    /x;
    }

    unless(length $line)
    {  $self->_debug("Warning: separator method found no correct o/p in:\n\t" .
            join("\t",@list)."\n");
    }
    my $f  = defined $line && $line =~ /^\*\s+LIST\s+\(([^\)]*)\s*\)/ ? $1 : undef;
    return 1 if $f =~ /HasChildren/i;
    return 0 if $f =~ /HasNoChildren/i;

    unless($f =~ /\\/)        # no flags at all unless there's a backslash
    {   my $sep  = $self->separator($folder) || $self->separator(undef);
        my $lead = $folder . $sep;
        my $len  = length $lead;
        return scalar grep {$lead eq substr($_, 0, $len)} $self->folders;
    }

    0;  # ???
}

sub selectable
{   my ($self, $f) = @_;
    not grep /NoSelect/i, $self->list("", $f);
}

sub append_string($$$;$$)
{   my $self   = shift;
    my $folder = $self->Massage(shift);
    my ($text, $flags, $date) = @_;

    $text =~ s/\x0d?\x0a/\x0d\x0a/g;

    if(defined($flags))
    {   $flags =~ s/^\s+//g;
        $flags =~ s/\s+$//g;
        $flags = "($flags)" if $flags !~ /^\(.*\)$/;
    }

    if(defined $date)
    {   $date  =~ s/^\s+//g;
        $date  =~ s/\s+$//g;
        $date  = qq/"$date"/ if $date  !~ /^"/;
    }

    my $clear  = $self->Clear;
    $self->Clear($clear)
        if $self->Count >= $clear and $clear > 0;

    my $count  = $self->Count($self->Count+1);

    my $string = "$count APPEND $folder " . ($flags ? "$flags " : "") .
        ($date ? "$date " : "") .  "{" . length($text)  . "}\x0d\x0a";

    $self->_record($count, [$self->_next_index($count), "INPUT", "$string\x0d\x0a" ] );

    # Step 1: Send the append command.

    unless($self->_send_line($string))
    {   $self->LastError("Error sending '$string' to IMAP: $!");
        return undef;
    }

    my $code;

    # Step 2: Get the "+ go ahead" response
    until($code)
    {
        my $output = $self->_read_line or return undef;
        foreach my $o (@$output)
        {   $self->_record($count, $o);
            next unless $self->_is_output($o);

            $code = $o->[DATA] =~ /(^\+|^\d*\s*NO\s|^\d*\s*BAD\s)/i ? $1 :undef;

            if($o->[DATA] =~ /^\*\s+BYE/i)
            {   $self->LastError("Error trying to append string: "
                      . "$o->[DATA]; Disconnected.");
                $self->State(Unconnected);
            }
            elsif($o->[DATA] =~ /^\d*\s*(NO|BAD)/i )   # i and / transposed!!!
            {   $self->LastError("Error trying to append string: $o->[DATA]");
                return undef;
            }
        }
    }

    $self->_record($count,[$self->_next_index($count),"INPUT","$text\x0d\x0a"]);

    # Step 3: Send the actual text of the message:
    unless($self->_send_line("$text\x0d\x0a"))
    {   $self->LastError("Error sending append msg text to IMAP: $!");
        return undef;
    }

    # Step 4: Figure out the results:
    $code = undef;
    until($code)
    {   $output = $self->_read_line or return undef;
        foreach my $o (@$output)
        {   $self->_record($count, $o);
            $code = $o->[DATA] =~ /^(?:$count|\*)\s+(OK|NO|BAD)\s/i ? $1 :undef;

            if($o->[DATA] =~ /^\*\s+BYE/im)
            {   $self->State(Unconnected);
                $self->LastError("Error trying to append: $o->[DATA]");
            }

            if($code && $code !~ /^OK/im)
            {   $self->LastError("Error trying to append: $o->[DATA]");
                return undef;
            }
        }
    }

    my $data = join "",map {$_->[TYPE] eq "OUTPUT" ? $_->[DATA] : ()} @$output;
    $data =~ m#\s+(\d+)\]# ? $1 : $self;
}

sub append
{   my $self   = shift;
    my $folder = shift;
    my $text   = join "\x0d\x0a", @_;

    $text =~ s/\x0d?\x0a/\x0d\x0a/g;
    $self->append_string($folder, $text);
}

sub append_file
{   my $self    = shift;
    my $folder  = $self->Massage(shift);
    my $file    = shift;
    my $control = shift;

    my $count   = $self->Count($self->Count+1);  #???? too early?

    unless(-f $file)
    {   $self->LastError("File $file not found.");
        return undef;
    }

    my $fh = IO::File->new($file);
    unless($fh)
    {   $self->LastError("Unable to open $file: $!");
        return undef;
    }

    my $bare_nl_count = grep m/^\x0a$|[^\x0d]\x0a$/, <$fh>;

    seek($fh,0,0);

    my $clear = $self->Clear;
    $self->Clear($clear)
        if $self->Count >= $clear and $clear > 0;

    my $length = $bare_nl_count + -s $file;
    my $string = "$count APPEND $folder {$length}\x0d\x0a";

    $self->_record($count, [$self->_next_index($count), "INPUT", $string] );

    unless($self->_send_line($string))
    {   $self->LastError("Error sending '$string' to IMAP: $!");
        $fh->close;
        return undef;
    }

    my $code;

    until($code)
    {   my $output = $self->_read_line;
        unless($output)
        {   $fh->close;
            return undef;
        }

        foreach my $o (@$output)
        {   $self->_record($count,$o);
            $code = $o->[DATA] =~ /(^\+|^\d+\sNO\s|^\d+\sBAD)\s/i ? $1 : undef;

            if($o->[DATA] =~ /^\*\s+BYE/ )
            {   $self->State(Unconnected);
                $fh->close;
                return undef;
            }
            elsif($o->[DATA]=~ /^\d+\s+(NO|BAD)/i )
            {   $fh->close;
                return undef;
            }
        }
    }

    # Slurp up headers: later we'll make this more efficient I guess

    local $/ = "\x0d\x0a\x0d\x0a";
    my $text = <$fh>;

    $text =~ s/\x0d?\x0a/\x0d\x0a/g;
    $self->_record($count,
        [$self->_next_index($count), "INPUT", "{From file $file}"] );

    unless($self->_send_line($text))
    {   $self->LastError("Error sending append msg text to IMAP: $!");
        $fh->close;
        return undef;
    }
    $self->_debug("control points to $$control\n") if ref $control;

    $/ = ref $control ? "\x0a" : $control ? $control : "\x0a";
    while(defined($text = <$fh>))
    {   $text =~ s/\x0d?\x0a/\x0d\x0a/g;
        $self->_record($count,
            [ $self->_next_index($count), "INPUT", "{from $file}\x0d\x0a"]);

        unless($self->_send_line($text,1))
        {   $self->LastError("Error sending append msg text to IMAP: $!");
            $fh->close;
            return undef;
        }
    }

    unless($self->_send_line("\x0d\x0a"))
    {   $self->LastError("Error sending append msg text to IMAP: $!");
        $fh->close;
        return undef;
    }

    # Now for the crucial test: Did the append work or not?
    my $uid;
    undef $code;
    until($code)
    {   my $output = $self->_read_line or return undef;
        foreach my $o (@$output)
        {   $self->_record($count,$o);
            $self->_debug("append_file: Does $o->[DATA] have the code\n");
            $code = $o->[DATA]  =~ m/^\d+\s(NO|BAD|OK)/i  ? $1 : undef;
            $uid  = $o->[DATA]  =~ m/UID\s+\d+\s+(\d+)\]/ ? $1 : undef;

            if($o->[DATA] =~ /^\*\s+BYE/)
            {   carp $o->[DATA] if $^W;
                $self->State(Unconnected);
                $fh->close;
                return undef;
            }
            elsif($o->[DATA]=~ /^\d+\s+(NO|BAD)/i )
            {   carp $o->[DATA] if $^W;
                $fh->close;
                return undef;
            }
        }
    }
    $fh->close;

      $code eq 'OK' ? undef
    : defined $uid  ? $uid
    :                 $self;
}


sub authenticate
{   my ($self, $scheme, $response) = @_;
    $scheme   ||= $self->Authmechanism;
    $response ||= $self->Authcallback;
    my $clear   = $self->Clear;
    $self->Clear($clear)
        if $self->Count >= $clear && $clear > 0;

    my $count   = $self->Count($self->Count+1);
    my $string  = "$count AUTHENTICATE $scheme";

    $self->_record($count,
       [ $self->_next_index($self->Transaction), "INPUT", "$string\x0d\x0a"] );

    unless($self->_send_line($string))
    {   $self->LastError("Error sending '$string' to IMAP: $!");
        return undef;
    }

    my $code;
    until($code)
    {   my $output = $self->_read_line or return undef;
        foreach my $o (@$output)
        {   $self->_record($count,$o);
            $code = $o->[DATA] =~ /^\+(.*)$/ ? $1 : undef;

            if ($o->[DATA] =~ /^\*\s+BYE/)
            {   $self->State(Unconnected);
                return undef;
            }
        }
    }

    return undef
        if $code =~ /^BAD|^NO/;

    if($scheme eq 'CRAM-MD5')
    {   $response ||= sub
          { my ($code, $client) = @_;
            my $hmac = hmac_md5_hex(decode_base64($code), $client->Password);
            encode_base64($client->User." ".$hmac);
          }
    }
    elsif($schema eq 'PLAIN')  # PLAIN SASL
    {   $response ||= sub
          { my ($code, $client) = @_;
            encode_base64($client->User . chr(0) . $client->Proxy
               . chr(0) . $client->Password);
          };
    }

    unless($self->_send_line($response->($code, $self)))
    {   $self->LastError("Error sending append msg text to IMAP: $!");
        return undef;
    }

    undef $code = $schema eq 'PLAIN' ? 'OK' : undef;
    until($code)
    {   my $output = $self->_read_line or return undef;
        foreach my $o (@$output)
        {   $self->_record($count,$o);
            $code = $o->[DATA] =~ /^\+ (.*)$/ ? $1 : undef;

            if($code)
            {   unless($self->_send_line($response->($code, $self)))
                {   $self->LastError("Error sending append msg text to IMAP: $!");
                    return undef;
                }
                undef $code;  # Clear code; we're still not finished
            }

            $code = $1 if $o->[DATA] =~ /^$count\s+(OK|NO|BAD)\b/;
            if($o->[DATA] =~ /^\*\s+BYE/)
            {   $self->State(Unconnected);
                return undef;
            }
        }
    }


    $code eq 'OK'
        or return undef;

    $self->State(Authenticated);
    $self;

}

# UIDPLUS response from a copy: [COPYUID (uidvalidity) (origuid) (newuid)]
sub copy
{   my ($self, $target, @msgs) = @_;

    $target  = $self->Massage($target);
    @msgs    = $self->Ranges ? $self->Range(@msgs)
       : sort { $a <=> $b } map { ref $_ ? @$_ : split(',',$_) } @msgs;

    my $msgs = $self->Ranges ? $self->Range(@msgs)
       : join ',', map {ref $_ ? @$_ : $_} @msgs;

    $self->_imap_uid_command(COPY => $msgs, $target)
        or return undef;

    my @results = $self->History;

    my @uids;
    foreach (@results)
    {   chomp;
        s/\r$//;
        s/^.*\[COPYUID\s+\d+\s+[\d:,]+\s+([\d:,]+)\].*/$1/ or next;
        push @uids, /(\d+):(\d+)/ ? ($1 ... $2) : (split /\,/);

    }
    @uids ? join(",",@uids) : $self;
}

sub move
{   my ($self, $target, @msgs) = @_;

    $self->exists($target)
        or $self->create($target) && $self->subscribe($target);

    my $uids = $self->copy($target, map {ref $_ eq 'ARRAY' ? @$_ : $_} @msgs)
        or return undef;

    $self->delete_message(@msgs)
        or carp $self->LastError;

    $uids;
}

sub set_flag
{   my ($self, $flag, @msgs) = @_;
    @msgs = @{$msgs[0]} if ref $msgs[0] eq 'ARRAY';
    $flag = "\\$flag"
        if $flag =~ /^(?:Answered|Flagged|Deleted|Seen|Draft)$/i;

    my $which = $self->Ranges ? $self->Range(@msgs) : join(',',@msgs);
    $self->store( "$which+FLAGS.SILENT ($flag)" );
}

sub see
{   my($self, @msgs) = @_;
    @msgs = @{$msgs[0]} if ref $msgs[0] eq 'ARRAY';
    $self->set_flag('\\Seen', @msgs);
}

sub mark
{   my($self, @msgs) = @_;
    @msgs = @{$msgs[0]} if ref $msgs[0] eq 'ARRAY';
    $self->set_flag('\\Flagged', @msgs);
}

sub unmark
{   my($self, @msgs) = @_;
    @msgs = @{$msgs[0]} if ref $msgs[0] eq 'ARRAY';
    $self->unset_flag('\\Flagged', @msgs);
}

sub unset_flag {
    my ($self, $flag, @msgs) = @_;
    @msgs = @{$msgs[0]} if ref $msgs[0] eq 'ARRAY';

    $flag = "\\$flag"
        if $flag =~ /^(?:Answered|Flagged|Deleted|Seen|Draft)$/i;

    $self->store( join(",",@msgs), "-FLAGS.SILENT ($flag)" );
}

sub deny_seeing
{   my ($self, @msgs) = @_;
    @msgs = @{$msgs[0]} if ref $msgs[0] eq 'ARRAY';
    $self->unset_flag('\\Seen', @msgs);
}

sub size
{   my ($self,$msg) = @_;
    my @data = $self->fetch($msg,"(RFC822.SIZE)");
    defined $data[0] or return undef;

    my $size = first { /RFC822\.SIZE/ } @data;
    $size =~ /RFC822\.SIZE\s+(\d+)/;
    $1;
}

sub getquotaroot
{   my ($self, $what) = @_;
    my $who = $what ? $self->Massage($what) : "INBOX";
    $self->_imap_command("GETQUOTAROOT $who") ? $self->Results : undef;
}

sub getquota
{   my ($self, $what) = @_;
    my $how = $what ? $self->Massage($what) : "user/$self->{User}";
    $self->_imap_command("GETQUOTA $who") ? $self->Results : undef;
}

sub quota
{   my $self = shift;
    my $what = shift || "INBOX";
    $self->_imap_command("GETQUOTA $what") || $self->getquotaroot($what);
    (map { /.*STORAGE\s+\d+\s+(\d+).*\n$/ ? $1 : () } $self->Results)[0];
}

sub quota_usage
{   my $self = shift;
    my $what = shift || "INBOX";
    $self->_imap_command("GETQUOTA $what") || $self->getquotaroot($what);
    ( map { /.*STORAGE\s+(\d+)\s+\d+.*\n$/ ? $1 : () } $self->Results)[0];
}

sub Quote {
    my ($class, $arg) = @_;
    return $class->Massage($arg, NonFolderArg);
}

sub Massage
{   my ($self, $arg, $notFolder) = @_;
    $arg or return;
    my $escaped_arg = $arg;
    $escaped_arg =~ s/"/\\"/g;
    $arg = substr($arg, 1, length($arg)-2) if $arg =~ /^".*"$/
       && ! ( $notFolder || $self->STATUS(qq("$escaped_arg"),"(MESSAGES)"));

       if($arg =~ /["\\]/)     { $arg = "{".length($arg). "}\x0d\x0a$arg" }
    elsif($arg =~ /\s|[{}()]/) { $arg = qq("$arg") unless $arg =~ /^"/ }

    $arg;
}

sub unseen_count
{   my ($self, $folder) = (shift, shift);
    $folder ||= $self->Folder;
    $self->status($folder, 'UNSEEN') or return undef;

    my $r = first { s/\*\s+STATUS\s+.*\(UNSEEN\s+(\d+)\s*\)/$1/ }
        $self->History;

    $r =~ s/\D//g;
    $r;
}

sub Status          { shift->State  }
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
sub _is_literal { ref $_[1] && $_[1]->[TYPE] && $_[1]->[TYPE] eq 'LITERAL' };

# _is_output_or_literal returns true if this is an
#      output line (or the literal part of one):

sub _is_output_or_literal { ref $_[1] && defined $_[1]->[TYPE]
   && ($_[1]->[TYPE] eq "OUTPUT" || $_[1]->[TYPE] eq "LITERAL") };

# _is_output returns true if this is an output line:
sub _is_output { ref $_[1] && $_[1]->[TYPE] && $_[1]->[TYPE] eq "OUTPUT" };

# _is_input returns true if this is an input line:
sub _is_input { ref $_[1] && $_[1]->[TYPE] && $_[1]->[TYPE] eq "INPUT" };

# _next_index returns next_index for a transaction; may legitimately
# return 0 when successful.
sub _next_index { $r = $_[0]->Results($_[1]); @$r }

sub Range
{   my ($self, $targ) = @_;
      ref $targ && $targ->isa('Mail::IMAPClient::MessageSet')
    ? $targ->cat(@_)
    : Mail::IMAPClient::MessageSet->new($targ, @_);
}

1;

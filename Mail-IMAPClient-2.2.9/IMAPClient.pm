package Mail::IMAPClient;

# $Id: IMAPClient.pm,v 20001010.20 2003/06/13 18:30:55 dkernen Exp $

$Mail::IMAPClient::VERSION = '2.2.9';
$Mail::IMAPClient::VERSION = '2.2.9';  	# do it twice to make sure it takes

use Fcntl qw(F_GETFL F_SETFL O_NONBLOCK);
use Socket();
use IO::Socket();
use IO::Select();
use IO::File();
use Carp qw(carp);
#use Data::Dumper;
use Errno qw/EAGAIN/;

#print "Found Fcntl in $INC{'Fcntl.pm'}\n";
#Fcntl->import;

use constant Unconnected => 0;

use constant Connected         => 1;         	# connected; not logged in

use constant Authenticated => 2;      		# logged in; no mailbox selected

use constant Selected => 3;   		        # mailbox selected

use constant INDEX => 0;              		# Array index for output line number

use constant TYPE => 1;               		# Array index for line type 
						#    (either OUTPUT, INPUT, or LITERAL)

use constant DATA => 2;                       	# Array index for output line data

use constant NonFolderArg => 1;			# Value to pass to Massage to 
						# indicate non-folder argument



my %SEARCH_KEYS = map { ( $_ => 1 ) } qw/
	ALL ANSWERED BCC BEFORE BODY CC DELETED DRAFT FLAGGED
	FROM HEADER KEYWORD LARGER NEW NOT OLD ON OR RECENT
	SEEN SENTBEFORE SENTON SENTSINCE SINCE SMALLER SUBJECT
	TEXT TO UID UNANSWERED UNDELETED UNDRAFT UNFLAGGED 
	UNKEYWORD UNSEEN
/;

sub _debug {
	my $self = shift;
	return unless $self->Debug;
	my $fh = $self->{Debug_fh} || \*STDERR; 
	print $fh @_;
}

sub MaxTempErrors {
	my $self = shift;
	$_[0]->{Maxtemperrors} = $_[1] if defined($_[1]);
	return $_[0]->{Maxtemperrors};
}

# This function is used by the accessor methods
#
sub _do_accessor {
  my $datum = shift;

  if ( defined($_[1]) and $datum eq 'Fast_io' and ref($_[0]->{Socket})) {
    if ($_[1]) {                      # Passed the "True" flag
      my $fcntl = 0;
      eval { $fcntl=fcntl($_[0]->{Socket}, F_GETFL, 0) } ;
      if ($@) {
      $_[0]->{Fast_io} = 0;
      carp ref($_[0]) . " not using Fast_IO; not available on this platform"
        if ( ( $^W or $_[0]->Debug) and not $_[0]->{_fastio_warning_}++);
      } else {
      $_[0]->{Fast_io} = 1;
      $_[0]->{_fcntl} = $fcntl;
      my $newflags = $fcntl;
      $newflags |= O_NONBLOCK;
      fcntl($_[0]->{Socket}, F_SETFL, $newflags) ;
      
      }
    } else {
      eval { fcntl($_[0]->{Socket}, F_SETFL, $_[0]->{_fcntl}) } 
		if exists $_[0]->{_fcntl};
      $_[0]->{Fast_io} = 0;
      delete $_[0]->{_fcntl} if exists $_[0]->{_fcntl};
    }
  } elsif ( defined($_[1]) and $datum eq 'Socket' ) {
    
    # Get rid of fcntl settings for obsolete socket handles:
    delete $_[0]->{_fcntl} ;
    # Register this handle in a select vector:
    $_[0]->{_select} = IO::Select->new($_[1]) ;
  }
  
  if (scalar(@_) > 1) {
    $@ = $_[1] if $datum eq 'LastError';
    chomp $@ if $datum eq 'LastError';
    return $_[0]->{$datum} = $_[1] ;
  } else {
    return $_[0]->{$datum};
  }
}

# the following for loop sets up eponymous accessor methods for 
# the object's parameters:

BEGIN {
 for my $datum (
		qw( 	State Port Server Folder Fast_io Peek
			User Password Socket Timeout Buffer
			Debug LastError Count Uid Debug_fh Maxtemperrors
			EnableServerResponseInLiteral
			Authmechanism Authcallback Ranges
			Readmethod Showcredentials
			Prewritemethod
		)
 ) {
        no strict 'refs';
        *$datum = sub { _do_accessor($datum, @_); };
 }

 eval {
   require Digest::HMAC_MD5;
   require MIME::Base64;
 };
 if ($@) {
   $Mail::IMAPClient::_CRAM_MD5_ERR =
     "Internal CRAM-MD5 implementation not available: $@";
   $Mail::IMAPClient::_CRAM_MD5_ERR =~ s/\n+$/\n/;
 }
}

sub Wrap { 	shift->Clear(@_); 	}

# The following class method is for creating valid dates in appended msgs:

sub Rfc822_date {
my $class=      shift;
#Date: Fri, 09 Jul 1999 13:10:55 -0000#
my $date =      $class =~ /^\d+$/ ? $class : shift ;
my @date =      gmtime($date);
my @dow  =      qw{ Sun Mon Tue Wed Thu Fri Sat };
my @mnt  =      qw{ Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec};
#
return          sprintf(
                        "%s, %2.2d %s %4.4s %2.2d:%2.2d:%2.2d -%4.4d",
                        $dow[$date[6]],
                        $date[3],
                        $mnt[$date[4]],
                        $date[5]+=1900,
                        $date[2],
                        $date[1],
                        $date[0],
                        $date[8]) ;
}

# The following class method is for creating valid dates for use in IMAP search strings:

sub Rfc2060_date {
my $class=      shift;
# 11-Jan-2000
my $date =      $class =~ /^\d+$/ ? $class : shift ;
my @date =      gmtime($date);
my @mnt  =      qw{ Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec};
#
return          sprintf(
                        "%2.2d-%s-%4.4s",
                        $date[3],
                        $mnt[$date[4]],
                        $date[5]+=1900
		) ;
}

# The following class method strips out <CR>'s so lines end with <LF> 
#	instead of <CR><LF>:

sub Strip_cr {
	my $class = shift;
	unless ( ref($_[0]) or scalar(@_) > 1 ) {
		(my $string = $_[0]) =~ s/\x0d\x0a/\x0a/gm;
		return $string;
	}
	return wantarray ?     	map { s/\x0d\x0a/\0a/gm ; $_ }  
				(ref($_[0]) ? @{$_[0]}  : @_)  		: 
				[ map { s/\x0d\x0a/\x0a/gm ; $_ } 
				  ref($_[0]) ? @{$_[0]} : @_ 
				] ;
}

# The following defines a special method to deal with the Clear parameter:

sub Clear {
	my $self = shift;
	defined(my $clear = shift) or return $self->{Clear}; 
	
	my $oldclear   = $self->{Clear};
	$self->{Clear} = $clear;

	my (@keys) = sort { $b <=> $a } keys %{$self->{"History"}}  ;

	for ( my $i = $clear; $i < @keys ; $i++ ) 
		{ delete $self->{'History'}{$keys[$i]} }

	return $oldclear;
}

# read-only access to the transaction number:
sub Transaction { shift->Count };

# the constructor:
sub new {
	my $class 	= shift;
	my $self  	= 	{
		LastError	=> "", 
		Uid 		=> 1, 
		Count 		=> 0,
		Fast_io 	=> 1,
		"Clear"		=> 5, 
	};
	while (scalar(@_)) {
		$self->{ucfirst(lc($_[0]))} = $_[1]; shift, shift;
	}
	bless $self, ref($class)||$class;

	$self->State(Unconnected);

	$self->{Debug_fh} ||= \*STDERR;
	select((select($self->{Debug_fh}),$|++)[0]) ;
 	$self->_debug("Using Mail::IMAPClient version $Mail::IMAPClient::VERSION " .
		"and perl version " . (defined $^V ? join(".",unpack("CCC",$^V)) : "") . 
		" ($])\n") if $self->Debug;
	$self->LastError(0);
	$self->Maxtemperrors or $self->Maxtemperrors("unlimited") ;
	return $self->connect if $self->Server and !$self->Socket;
	return $self;
}


sub connect {
	my $self = shift;
	
	$self->Port(143) 
		if 	defined ($IO::Socket::INET::VERSION) 
		and 	$IO::Socket::INET::VERSION eq '1.25' 
		and 	!$self->Port;
	%$self = (%$self, @_);
	my $sock = IO::Socket::INET->new(
		PeerAddr => $self->Server		,
                PeerPort => $self->Port||'imap(143)'	,
                Proto    => 'tcp' 			,
                Timeout  => $self->Timeout||0		,
		Debug	=> $self->Debug 		,
	)						;

	unless ( defined($sock) ) {
		
		$self->LastError( "Unable to connect to $self->{Server}: $!\n");	
		$@ 		= "Unable to connect to $self->{Server}: $!";	
		carp 		  "Unable to connect to $self->{Server}: $!" 
				unless defined wantarray;	
		return undef;
	}
	$self->Socket($sock);
	$self->State(Connected);

	$sock->autoflush(1)				;
	
	my ($code, $output);
        $output = "";

        until ( $code ) {

                $output = $self->_read_line or return undef;
                for my $o (@$output) {
			$self->_debug("Connect: Received this from readline: " . 
					join("/",@$o) . "\n");
                        $self->_record($self->Count,$o);	# $o is a ref
                      next unless $o->[TYPE] eq "OUTPUT";
                      ($code) = $o->[DATA] =~ /^\*\s+(OK|BAD|NO)/i  ;
                }

        }

	if ($code =~ /BYE|NO /) {
		$self->State(Unconnected);
		return undef ;
	}

	if ($self->User and $self->Password) {
		return $self->login ;
	} else {
		return $self;	
	}
}
	

sub login {
	my $self = shift;
	return $self->authenticate($self->Authmechanism,$self->Authcallback) 
		if $self->{Authmechanism};

	my $id   = $self->User;
	my $has_quotes = $id =~ /^".*"$/ ? 1 : 0;
	my $string = 	"Login " . ( $has_quotes ? $id : qq("$id") ) . " " . 
			"{" . length($self->Password) . 
			"}\r\n".$self->Password."\r\n";
	$self->_imap_command($string) 
		and $self->State(Authenticated);
	# $self->folders and $self->separator unless $self->NoAutoList;
	unless ( $self->IsAuthenticated) {
		my($carp) 	=  $self->LastError;
		$carp 		=~ s/^[\S]+ ([^\x0d\x0a]*)\x0d?\x0a/$1/;
 		carp $carp unless defined wantarray;
		return undef;
	}
	return $self;
}

sub separator {
	my $self = shift;
	my $target = shift ; 

	unless ( defined($target) ) {
		my $sep = "";
		# 	separator is namespace's 1st thing's 1st thing's 2nd thing:
		eval { 	$sep = $self->namespace->[0][0][1] } 	;
		return $sep if $sep;
	}	
		
	defined($target) or $target = "";
	$target ||= '""' ;
	
	

	# The fact that the response might end with {123} doesn't really matter here:

	unless (exists $self->{"$target${;}SEPARATOR"}) {
		my $list = (grep(/^\*\s+LIST\s+/,($self->list(undef,$target)||("NO")) ))[0] || 
				qq("/");
		my $s = (split(/\s+/,$list))[3];
		defined($s) and $self->{"$target${;}SEPARATOR"} = 
				( $s eq 'NIL' ? 'NIL' : substr($s, 1,length($s)-2) );
	}
	return $self->{$target,'SEPARATOR'};
}

sub sort {
    my $self = shift;
    my @hits;
    my @a = @_;
    $@ = "";
    $a[0] = "($a[0])" unless $a[0] =~ /^\(.*\)$/;      # wrap criteria in parens
    $self->_imap_command( ( $self->Uid ? "UID " : "" ) . "SORT ". join(' ',@a))
         or return wantarray ? @hits : \@hits ;
    my @results =  $self->History($self->Count);

    for my $r (@results) {
        chomp $r;
        $r =~ s/\r$//;
        $r =~ s/^\*\s+SORT\s+// or next;   
        push @hits, grep(/\d/,(split(/\s+/,$r)));
    }
    return wantarray ? @hits : \@hits;     
}

sub list {
	my $self = shift;
	my ($reference, $target) = (shift, shift);
	$reference = "" unless defined($reference);
	$target = '*' unless defined($target);
	$target = '""' if $target eq "";
	$target 	  = $self->Massage($target) unless $target eq '*' or $target eq '""';
	my $string 	=  qq(LIST "$reference" $target);
	$self->_imap_command($string)  or return undef;
	return wantarray ? 	
			$self->History($self->Count) 				  : 
                       	[ map { $_->[DATA] } @{$self->{'History'}{$self->Count}}] ;
}

sub lsub {
	my $self = shift;
	my ($reference, $target) = (shift, shift);
	$reference = "" unless defined($reference);
	$target = '*' unless defined($target);
	$target           = $self->Massage($target);
	my $string      =  qq(LSUB "$reference" $target);
	$self->_imap_command($string)  or return undef;
	return wantarray ?      $self->History($self->Count)            : 
                              [ map { $_->[DATA] } @{$self->{'History'}{$self->Count}}        ] ;
}

sub subscribed {
        my $self = shift;
	my $what = shift ;

        my @folders ;  

	my @list = $self->lsub(undef,( $what? "$what" . 
		$self->separator($what) . "*" : undef ) );
	push @list, $self->lsub(undef, $what) if $what and $self->exists($what) ;

      	# my @list = map { $self->_debug("Pushing $_->[${\(DATA)}] \n"); $_->[DATA] } 
	#	@$output;

	my $m;

	for ($m = 0; $m < scalar(@list); $m++ ) {
		if ($list[$m] && $list[$m]  !~ /\x0d\x0a$/ ) {
			$list[$m] .= $list[$m+1] ;
			$list[$m+1] = "";	
		}
			
		
		# $self->_debug("Subscribed: examining $list[$m]\n");

		push @folders, $1||$2 
			if $list[$m] =~
                        /       ^\*\s+LSUB               # * LSUB
                                \s+\([^\)]*\)\s+         # (Flags)
                                (?:"[^"]*"|NIL)\s+	 # "delimiter" or NIL
                                (?:"([^"]*)"|(.*))\x0d\x0a$  # Name or "Folder name"
                        /ix;

        } 

        # for my $f (@folders) { $f =~ s/^\\FOLDER LITERAL:://;}
	my @clean = () ; my %memory = (); 
	foreach my $f (@folders) { push @clean, $f unless $memory{$f}++ }
        return wantarray ? @clean : \@clean ;
}


sub deleteacl {
	my $self = shift;
	my ($target, $user ) = @_;
	$target 	  = $self->Massage($target);
	$user		  =~ s/^"(.*)"$/$1/;
	$user 	  	  =~ s/"/\\"/g;
	my $string 	=  qq(DELETEACL $target "$user");
	$self->_imap_command($string)  or return undef;

	return wantarray ? 	$self->History($self->Count) 				: 
                              [ map {$_->[DATA] } @{$self->{'History'}{$self->Count}}] ;
}

sub setacl {
        my $self = shift;
        my ($target, $user, $acl) = @_;
        $user = $self->User unless length($user);
        $target = $self->Folder unless length($target);
        $target           = $self->Massage($target);
        $user             =~ s/^"(.*)"$/$1/;
        $user             =~ s/"/\\"/g;
        $acl              =~ s/^"(.*)"$/$1/;
        $acl              =~ s/"/\\"/g;
        my $string      =  qq(SETACL $target "$user" "$acl");
        $self->_imap_command($string)  or return undef;
        return wantarray			?
		$self->History($self->Count)	:
		[map{$_->[DATA]}@{$self->{'History'}{$self->Count}}]
	;
}


sub getacl {
        my $self = shift;
        my ($target) = @_;
        $target = $self->Folder unless defined($target);
        my $mtarget           = $self->Massage($target);
        my $string      =  qq(GETACL $mtarget);
        $self->_imap_command($string)  or return undef;
	my @history = $self->History($self->Count);
	#$self->_debug("Getacl history: ".join("|",@history).">>>End of History<<<" ) ;
	my $perm = ""; 
	my $hash = {};
	for ( my $x = 0; $x < scalar(@history) ; $x++ ) {
        	if ( $history[$x] =~ /^\* ACL/ ) {
			
			$perm = $history[$x]=~ /^\* ACL $/	? 
				$history[++$x].$history[++$x] 	: 
				$history[$x];		

			$perm =~ s/\s?\x0d\x0a$//;
			piece:  until ( $perm =~ /\Q$target\E"?$/ or !$perm) {
				#$self->_debug(qq(Piece: permline=$perm and " 
				#	"pattern = /\Q$target\E"? \$/));
				$perm =~ s/\s([^\s]+)\s?$// or last piece;
				my($p) = $1;
				$perm =~ s/\s([^\s]+)\s?$// or last piece;
				my($u) = $1;
				$hash->{$u} = $p;
				$self->_debug("Permissions: $u => $p \n");
			}
		
		}
	}
        return $hash;
}

sub listrights {
	my $self = shift;
	my ($target, $user) = @_;
	$user = $self->User unless defined($user);
	$target = $self->Folder unless defined($target);
	$target 	  = $self->Massage($target);
	$user		  =~ s/^"(.*)"$/$1/;
	$user 	  	  =~ s/"/\\"/g;
	my $string 	=  qq(LISTRIGHTS $target "$user");
	$self->_imap_command($string)  or return undef;
	my $resp = ( grep(/^\* LISTRIGHTS/, $self->History($self->Count) ) )[0];
	my @rights = split(/\s/,$resp);	
	shift @rights, shift @rights, shift @rights, shift @rights;
	my $rights = join("",@rights);
	$rights =~ s/"//g;	
	return wantarray ? split(//,$rights) : $rights ;
}

sub select {
	my $self = shift;
	my $target = shift ;  
	return undef unless defined($target);

	my $qqtarget = $self->Massage($target);

	my $string 	=  qq/SELECT $qqtarget/;

	my $old = $self->Folder;

	if ($self->_imap_command($string) and $self->State(Selected)) {
		$self->Folder($target);
		return $old||$self;
	} else { 
		return undef;
	}
}

sub message_string {
	my $self = shift;
	my $msg  = shift;
	my $expected_size = $self->size($msg);
	return undef unless(defined $expected_size);	# unable to get size
	my $cmd  =  	$self->has_capability('IMAP4REV1') 				? 
				"BODY" . ( $self->Peek ? '.PEEK[]' : '[]' ) 		: 
				"RFC822" .  ( $self->Peek ? '.PEEK' : ''  )		;

	$self->fetch($msg,$cmd) or return undef;
	
	my $string = "";

	foreach my $result  (@{$self->{"History"}{$self->Transaction}}) { 
              $string .= $result->[DATA] 
		if defined($result) and $self->_is_literal($result) ;
	}      
	# BUG? should probably return undef if length != expected
	if ( length($string) != $expected_size ) { 
		carp "${self}::message_string: " .
			"expected $expected_size bytes but received " . 
			length($string) 
			if $self->Debug or $^W; 
	}
	if ( length($string) > $expected_size ) 
	{ $string = substr($string,0,$expected_size) }
	if ( length($string) < $expected_size ) {
		$self->LastError("${self}::message_string: expected ".
			"$expected_size bytes but received " . 
			length($string)."\n");
		return undef;
	}
	return $string;
}

sub bodypart_string {
	my($self, $msg, $partno, $bytes, $offset) = @_;

	unless ( $self->has_capability('IMAP4REV1') ) {
		$self->LastError(
				"Unable to get body part; server " . 
				$self->Server . 
				" does not support IMAP4REV1"
		);
		return undef;
	}
	my $cmd = "BODY" . ( $self->Peek ? ".PEEK[$partno]" : "[$partno]" ) 	;
	$offset ||= 0 ;
	$cmd .= "<$offset.$bytes>" if $bytes;

	$self->fetch($msg,$cmd) or return undef;
	
	my $string = "";

	foreach my $result  (@{$self->{"History"}{$self->Transaction}}) { 
              $string .= $result->[DATA] 
		if defined($result) and $self->_is_literal($result) ;
	}      
	return $string;
}

sub message_to_file {
	my $self = shift;
	my $fh   = shift;
	my @msgs = @_;
	my $handle;

	if ( ref($fh) ) {
		$handle = $fh;
	} else { 
		$handle = IO::File->new(">>$fh");
		unless ( defined($handle)) {
			$@ = "Unable to open $fh: $!";
			$self->LastError("Unable to open $fh: $!\n");
			carp $@ if $^W;
			return undef;
		}
		binmode $handle;	# For those of you who need something like this...
	} 

        my $clear = $self->Clear;
	my $cmd = $self->Peek ? 'BODY.PEEK[]' : 'BODY[]';
	$cmd = $self->Peek ? 'RFC822.PEEK' : 'RFC822' unless $self->imap4rev1;
	
	my $string = ( $self->Uid ? "UID " : "" ) . "FETCH " . join(",",@msgs) . " $cmd";

        $self->Clear($clear)
                if $self->Count >= $clear and $clear > 0;

        my $trans       = $self->Count($self->Count+1);

        $string         = "$trans $string" ;

        $self->_record($trans,[ 0, "INPUT", "$string\x0d\x0a"] );

        my $feedback = $self->_send_line("$string");

        unless ($feedback) {
                $self->LastError( "Error sending '$string' to IMAP: $!\n");
                $@ = "Error sending '$string' to IMAP: $!";
                return undef;
        }

        my ($code, $output);
        $output = "";

        READ: until ( $code)  {
                $output = $self->_read_line($handle) or return undef; # avoid possible infinite loop
                for my $o (@$output) {
                        $self->_record($trans,$o);	# $o is a ref
                        # $self->_debug("Received from readline: ${\($o->[DATA])}<<END OF RESULT>>\n");
                        next unless $self->_is_output($o);
                        ($code) = $o->[DATA] =~ /^$trans (OK|BAD|NO)/mi ;
                        if ($o->[DATA] =~ /^\*\s+BYE/im) {
                                $self->State(Unconnected);
                                return undef ;
                        }
                }
        }

        # $self->_debug("Command $string: returned $code\n");
	close $handle unless ref($fh);
        return $code =~ /^OK/im ? $self : undef ;

}

sub message_uid {
	my $self = shift;
	my $msg  = shift;
	my @uid = $self->fetch($msg,"UID");
	my $uid;
	while ( my $u = shift @uid and !$uid) {
		($uid) = $u =~ /\(UID\s+(\d+)\s*\)\r?$/;
	}
	return $uid;
}

sub original_migrate {
	my($self,$peer,$msgs,$folder) = @_;
	unless ( eval { $peer->IsConnected } ) {
		$self->LastError("Invalid or unconnected " .  ref($self). 
				 " object used as target for migrate." );
		return undef;
	}
	unless ($folder) {
		$folder = $self->Folder;
		$peer->exists($folder) 		or 
			$peer->create($folder) 	or 
			(
				$self->LastError("Unable to created folder $folder on target mailbox: ".
					"$peer->LastError") and 
				return undef 
			) ;
	}			
	if ( $msgs =~ /^all$/i ) { $msgs = $self->search("ALL") }
	foreach my $mid ( ref($msgs) ? @$msgs : $msgs ) {
		my $uid = $peer->append($folder,$self->message_string($mid));
		$self->LastError("Trouble appending to peer: " . $peer->LastError . "\n");
	}
}


sub migrate {

	my($self,$peer,$msgs,$folder) 	= @_;
	my($toSock,$fromSock) 		= ( $peer->Socket, $self->Socket);
	my $bufferSize 			= $self->Buffer || 4096;
	my $fromBuffer 			= "";
	my $clear 			= $self->Clear;

	unless ( eval { $peer->IsConnected } ) {
		$self->LastError("Invalid or unconnected " . 
			ref($self) . " object used as target for migrate. $@");
		return undef;
	}

	unless ($folder) {
		$folder = $self->Folder 	or
			$self->LastError( "No folder selected on source mailbox.") 
			and return undef;

		$peer->exists($folder)		or 
			$peer->create($folder)	or 
			(
				$self->LastError(
				  "Unable to create folder $folder on target mailbox: ".
				  $peer->LastError . "\n"
				) and return undef 
			) ;
	}
	$msgs or $msgs eq "0" or $msgs = "all";	
	if ( $msgs =~ /^all$/i ) { $msgs = $self->search("ALL") }
	my $range = $self->Range($msgs) ;
	$self->_debug("Migrating the following msgs from $folder: " . 
		" $range\n");
		# ( ref($msgs) ? join(", ",@$msgs) : $msgs) );

	#MIGMSG:	foreach my $mid ( ref($msgs) ? @$msgs : (split(/,\s*/,$msgs)) ) {#}
	MIGMSG:	foreach my $mid ( $range->unfold ) {
		# Set up counters for size of msg and portion of msg remaining to
		# process:
		$self->_debug("Migrating message $mid in folder $folder\n") 
			if $self->Debug;
		my $leftSoFar = my $size = $self->size($mid);

		# fetch internaldate and flags of original message:
		my $intDate = '"' . $self->internaldate($mid) . '"' ;
		my $flags   = "(" . join(" ",grep(!/\\Recent/i,$self->flags($mid)) ) . ")" ;
		$flags = "" if  $flags eq "()" ;

		# set up transaction numbers for from and to connections:
		my $trans       = $self->Count($self->Count+1);
		my $ptrans      = $peer->Count($peer->Count+1);

		# If msg size is less than buffersize then do whole msg in one 
		# transaction:
		if ( $size <= $bufferSize ) {
			my $new_mid = $peer->append_string($peer->Massage($folder),
					$self->message_string($mid) ,$flags,
					$intDate) ;
		        $self->_debug("Copied message $mid in folder $folder to " . 
				    $peer->User .
				    '@' . $peer->Server . 
				    ". New Message UID is $new_mid.\n" 
		        ) if $self->Debug;

		        $peer->_debug("Copied message $mid in folder $folder from " . 
				$self->User .
				'@' . $self->Server . ". New Message UID is $new_mid.\n" 
		        ) if $peer->Debug;


			next MIGMSG;
		}

		# otherwise break it up into digestible pieces:
		my ($cmd, $pattern);
		if ( $self->imap4rev1 ) {
			# imap4rev1 supports FETCH BODY 
			$cmd = $self->Peek ? 'BODY.PEEK[]' : 'BODY[]';
			$pattern = sub {
                                #$self->_debug("Data fed to pattern: $_[0]<END>\n");
                                my($one) = $_[0] =~ /\(.*BODY\[\]<\d+> \{(\d+)\}/i ; # ;-)
					# or $self->_debug("Didn't match pattern\n") ; 
                                #$self->_debug("Returning from pattern: $1\n") if defined($1);
				return $one ;
                        } ;
		} else {
			# older imaps use (deprecated) FETCH RFC822:
			$cmd = $self->Peek ? 'RFC822.PEEK' : 'RFC822' ;
			$pattern = sub {
				my($one) = shift =~ /\(RFC822\[\]<\d+> \{(\d+)\}/i; 
				return $one ;
			};
		}


		# Now let's warn the peer that there's a message coming:

		my $pstring = 	"$ptrans APPEND " . 
				$self->Massage($folder). 
				" " . 
				( $flags ? "$flags " : () ) . 
				( $intDate ? "$intDate " : () ) . 
				"{" . $size . "}"  ;

		$self->_debug("About to issue APPEND command to peer " .
			"for msg $mid\n") 		if $self->Debug;

		my $feedback2 = $peer->_send_line( $pstring ) ;

		$peer->_record($ptrans,[ 
			0, 
			"INPUT", 
			"$pstring" ,
		] ) ;
		unless ($feedback2) {
		   $self->LastError("Error sending '$pstring' to target IMAP: $!\n");
		   return undef;
		}
		# Get the "+ Go ahead" response:
		my $code = 0;
		until ($code eq '+' or $code =~ /NO|BAD|OK/ ) {
	  	  my $readSoFar = 0 ;
		  $readSoFar += sysread($toSock,$fromBuffer,1,$readSoFar)||0
			until $fromBuffer =~ /\x0d\x0a/;

		  #$peer->_debug("migrate: response from target server: " .
		  #	"$fromBuffer<END>\n") 	if $peer->Debug;

		  ($code)= $fromBuffer =~ /^(\+)|^(?:\d+\s(?:BAD|NO))/ ;
		  $code ||=0;

		  $peer->_debug( "$folder: received $fromBuffer from server\n") 
		  if $peer->Debug;

	  	  # ... and log it in the history buffers
		  $self->_record($trans,[ 
			0, 
			"OUTPUT", 
			"Mail::IMAPClient migrating message $mid to $peer->User\@$peer->Server"
		  ] ) ;
		  $peer->_record($ptrans,[ 
			0, 
			"OUTPUT", 
			$fromBuffer
		  ] ) ;


		}
		unless ( $code eq '+'  ) {
			$^W and warn "$@\n";
			$self->Debug and $self->_debug("Error writing to target host: $@\n");
			next MIGMSG;	
		}
		# Here is where we start sticking in UID if that parameter
		# is turned on:	
		my $string = ( $self->Uid ? "UID " : "" ) . "FETCH $mid $cmd";

		# Clean up history buffer if necessary:
		$self->Clear($clear)
			if $self->Count >= $clear and $clear > 0;


	   # position will tell us how far from beginning of msg the
	   # next IMAP FETCH should start (1st time start at offet zero):
	   my $position = 0;
	   #$self->_debug("There are $leftSoFar bytes left versus a buffer of $bufferSize bytes.\n");
	   my $chunkCount = 0;
	   while ( $leftSoFar > 0 ) {
		$self->_debug("Starting chunk " . ++$chunkCount . "\n");

		my $newstring         ="$trans $string<$position."  .
					( $leftSoFar > $bufferSize ? $bufferSize : $leftSoFar ) . 
					">" ;

		$self->_record($trans,[ 0, "INPUT", "$newstring\x0d\x0a"] );
		$self->_debug("Issuing migration command: $newstring\n" )
			if $self->Debug;;

		my $feedback = $self->_send_line("$newstring");

		unless ($feedback) {
		   $self->LastError("Error sending '$newstring' to source IMAP: $!\n");
		   return undef;
		}
		my $chunk = "";
		until ($chunk = $pattern->($fromBuffer) ) {
		   $fromBuffer = "" ;
	    	   until ( $fromBuffer=~/\x0d\x0a$/ ) {
	    	   	sysread($fromSock,$fromBuffer,1,length($fromBuffer)) ; 
			#$self->_debug("migrate chunk $chunkCount:" . 
			#	"Read from source: $fromBuffer<END>\n");
		   }
		   
		   $self->_record($trans,[ 0, "OUTPUT", "$fromBuffer"] ) ;

		   if ( $fromBuffer =~ /^$trans (?:NO|BAD)/ ) {
			$self->LastError($fromBuffer) ;
			next MIGMSG;
		   }

		   if ( $fromBuffer =~ /^$trans (?:OK)/ ) {
			$self->LastError("Unexpected good return code " .
				"from source host: " . $fromBuffer) ;
			next MIGMSG;
		   }

		}
		$fromBuffer = "";
		my $readSoFar = 0 ;
		$readSoFar += sysread($fromSock,$fromBuffer,$chunk-$readSoFar,$readSoFar)||0
			until $readSoFar >= $chunk;
		#$self->_debug("migrateRead: chunk=$chunk readSoFar=$readSoFar " .
		#	"Buffer=$fromBuffer<END_OF_BUFFER\n") if $self->Debug;

		my $wroteSoFar 	= 0;
		my $temperrs 	= 0;
		my $optimize 	= 0;

		until ( $wroteSoFar >= $chunk ) {
		 #$peer->_debug("Chunk $chunkCount: Next write will attempt to write " .
		 #	"this substring:\n" .
		 #	substr($fromBuffer,$wroteSoFar,$chunk-$wroteSoFar) .
		 #	"<END_OF_SUBSTRING>\n"
		 #);

		 until ( $wroteSoFar >= $readSoFar ) {
		    $!=0;
		    my $ret = syswrite(
				$toSock,
				$fromBuffer,
				$chunk - $wroteSoFar, 
				$wroteSoFar )||0 ;

		    $wroteSoFar += $ret;

		    if ($! == &EAGAIN ) {
			if ( 	$self->{Maxtemperrors} !~ /^unlimited/i
			    	and $temperrs++ > ($self->{Maxtemperrors}||10) 
			) {
				$self->LastError("Persistent '${!}' errors\n");
				$self->_debug("Persistent '${!}' errors\n");
				return undef;
			}
			$optimize = 1;
		    } else {
			# avoid infinite loops on syswrite error
			return undef unless(defined $ret);	 
		    }
		    # Optimization of wait time between syswrite calls
		    # only runs if syscalls run too fast and fill the 
		    # buffer causing "EAGAIN: Resource Temp. Unavail" errors. The
		    # premise is that $maxwrite will be approx. the same as 
		    # the smallest buffer between the sending and receiving side. 
		    # Waiting time between syscalls should ideally be exactly as 
		    # long as it takes the receiving side to empty that buffer, 
		    # minus a little bit to prevent it from
		    # emptying completely and wasting time in the select call.
		    if ($optimize) {
		        my $waittime = .02; 
		    	$maxwrite = $ret if $maxwrite < $ret;
		    	push( @last5writes, $ret );
		    	shift( @last5writes ) if $#last5writes > 5;
			    my $bufferavail = 0;
			    $bufferavail += $_ for ( @last5writes );
			    $bufferavail /= ($#last5writes||1);
			    # Buffer is staying pretty full; 
			    # we should increase the wait period
			    # to reduce transmission overhead/number of packets sent
			    if ( $bufferavail < .4 * $maxwrite ) {
				$waittime *= 1.3;

			    # Buffer is nearly or totally empty; 
			    # we're wasting time in select
			    # call that could be used to send data, 
			    # so reduce the wait period
			    } elsif ( $bufferavail > .9 * $maxwrite ) {
				$waittime *= .5;
			    }
		    	CORE::select(undef, undef, undef, $waittime);
		    }
		    if ( defined($ret) ) {
			$temperrs = 0  ;
		    }
		    $peer->_debug("Chunk $chunkCount: " .
			"Wrote $wroteSoFar bytes (out of $chunk)\n");
		   }
		}
		$position += $readSoFar ;
		$leftSoFar -= $readSoFar;
		$fromBuffer = "";
		# Finish up reading the server response from the fetch cmd
		# 	on the source system:
		{
		my $code = 0;
		until ( $code)  {

			# escape infinite loop if read_line never returns any data:

			$self->_debug("Reading from source server; expecting " .
				"') OK' type response\n") if $self->Debug;

			$output = $self->_read_line or return undef; 
			for my $o (@$output) {

				$self->_record($trans,$o);      # $o is a ref

				# $self->_debug("Received from readline: " .
				# "${\($o->[DATA])}<<END OF RESULT>>\n");

				next unless $self->_is_output($o);

				($code) = $o->[DATA] =~ /^$trans (OK|BAD|NO)/mi ;

				if ($o->[DATA] =~ /^\*\s+BYE/im) {
					$self->State(Unconnected);
					return undef ;
				}
	   		}
	   	}
	   	} # end scope for my $code
	   }
	   # Now let's send a <CR><LF> to the peer to signal end of APPEND cmd:
	   {
	    my $wroteSoFar = 0;
	    $fromBuffer = "\x0d\x0a";
	    $!=0;
	    $wroteSoFar += syswrite($toSock,$fromBuffer,2-$wroteSoFar,$wroteSoFar)||0 
	    		until $wroteSoFar >= 2;

	   }
	   # Finally, let's get the new message's UID from the peer:
	   my $new_mid = "";
           {
                my $code = 0;
                until ( $code)  {
                        # escape infinite loop if read_line never returns any data:
			$peer->_debug("Reading from target: " .
				"expecting new uid in response\n") if $peer->Debug;

                        $output = $peer->_read_line or next MIGMSG;

                        for my $o (@$output) {

                                $peer->_record($ptrans,$o);      # $o is a ref

                                # $peer->_debug("Received from readline: " .
                                # "${\($o->[DATA])}<<END OF RESULT>>\n");

                                next unless $peer->_is_output($o);

                                ($code) = $o->[DATA] =~ /^$ptrans (OK|BAD|NO)/mi ;
				($new_mid)= $o->[DATA] =~ /APPENDUID \d+ (\d+)/ if $code;
				#$peer->_debug("Code line: " . $o->[DATA] . 
				#	"\nCode=$code mid=$new_mid\n" ) if $code;

                                if ($o->[DATA] =~ /^\*\s+BYE/im) {
                                        $peer->State(Unconnected);
                                        return undef ;
                                }
                        }
			$new_mid||="unknown" ;
                }
             } # end scope for my $code

	     $self->_debug("Copied message $mid in folder $folder to " . $peer->User .
			    '@' . $peer->Server . ". New Message UID is $new_mid.\n" 
	     ) if $self->Debug;

	     $peer->_debug("Copied message $mid in folder $folder from " . $self->User .
			    '@' . $self->Server . ". New Message UID is $new_mid.\n" 
	     ) if $peer->Debug;


	  # ... and finish up reading the server response from the fetch cmd
	  # 	on the source system:
	      # {
	#	my $code = 0;
	#	until ( $code)  {
	#		# escape infinite loop if read_line never returns any data:
        #      		unless ($output = $self->_read_line ) {
	#			$self->_debug($self->LastError) ;
	#			next MIGMSG;
	#		}
	#		for my $o (@$output) {
#
#				$self->_record($trans,$o);      # $o is a ref
#
#				# $self->_debug("Received from readline: " .
#				# "${\($o->[DATA])}<<END OF RESULT>>\n");
#
#				next unless $self->_is_output($o);
#
#			 	($code) = $o->[DATA] =~ /^$trans (OK|BAD|NO)/mi ;
#
#			      	if ($o->[DATA] =~ /^\*\s+BYE/im) {
#					$self->State(Unconnected);
#					return undef ;
#				}
#			}
#		}
#		}
		
	     	# and clean up the I/O buffer:
	     	$fromBuffer = "";
	     }
	return $self;	
}


sub body_string {
	my $self = shift;
	my $msg  = shift;
	my $ref = $self->fetch($msg,"BODY" . ( $self->Peek ? ".PEEK" : "" ) . "[TEXT]");

        my $string = "";
    	foreach my $result  (@{$ref}) 	{ 
                $string .= $result->[DATA] if defined($result) and $self->_is_literal($result) ;
        }
	return $string if $string;

        my $head = shift @$ref;
        $self->_debug("body_string: first shift = '$head'\n");

        until ( (! $head)  or $head =~ /(?:.*FETCH .*\(.*BODY\[TEXT\])|(?:^\d+ BAD )|(?:^\d NO )/i ) {
                $self->_debug("body_string: shifted '$head'\n");
                $head = shift(@$ref) ;
        }
	unless ( scalar(@$ref) ) {
			$self->LastError("Unable to parse server response from " . $self->LastIMAPCommand );
			return undef ;
	}
	my $popped ; $popped = pop @$ref until 	
			( 
				( 	defined($popped) and 
					# (-:	Smile!
					$popped =~ /\)\x0d\x0a$/ 
				) 	or
					not grep(
						# (-:	Smile again!
						/\)\x0d\x0a$/,
						@$ref
					)
			);

        if      ($head =~ /BODY\[TEXT\]\s*$/i )     {       # Next line is a literal
                        $string .= shift @$ref while scalar(@$ref);
                        $self->_debug("String is now $string\n") if $self->Debug;
        }

        return $string||undef;
}


sub examine {
	my $self = shift;
	my $target = shift ; return undef unless defined($target);
	$target = $self->Massage($target);
	my $string 	=  qq/EXAMINE $target/;

	my $old = $self->Folder;

	if ($self->_imap_command($string) and $self->State(Selected)) {
		$self->Folder($target);
		return $old||$self;
	} else { 
		return undef;
	}
}

sub idle {
	my $self = shift;
	my $good = '+';
	my $count = $self->Count +1;
	return $self->_imap_command("IDLE",$good) ? $count : undef;
}

sub done {
	my $self 	= shift;

	my $count 	= shift||$self->Count;

	my $clear = "";
	$clear = $self->Clear;

	$self->Clear($clear) 
		if $self->Count >= $clear and $clear > 0;

	my $string = "DONE\x0d\x0a";
	$self->_record($count,[ $self->_next_index($count), "INPUT", "$string\x0d\x0a"] );

	my $feedback = $self->_send_line("$string",1);

	unless ($feedback) {
		$self->LastError( "Error sending '$string' to IMAP: $!\n");
		return undef;
	}

	my ($code, $output);	
	$output = "";

	until ( $code and $code =~ /(OK|BAD|NO)/m ) {

		$output = $self->_read_line or return undef;	
		for my $o (@$output) { 
			$self->_record($count,$o);	# $o is a ref
			next unless $self->_is_output($o);
                      	($code) = $o->[DATA] =~ /^(?:$count) (OK|BAD|NO)/m  ;
                      if ($o->[DATA] =~ /^\*\s+BYE/) {
				$self->State(Unconnected);
			}
		}
	}	
	return $code =~ /^OK/ ? @{$self->Results} : undef ;

}

sub tag_and_run {
	my $self = shift;
	my $string = shift;
	my $good = shift;
	$self->_imap_command($string,$good);
	return @{$self->Results};
}
# _{name} methods are undocumented and meant to be private.

# _imap_command runs a command, inserting the correct tag
# and <CR><LF> and whatnot.
# When updating _imap_command, remember to examine the run method, too, since it is very similar.
#

sub _imap_command {
	
	my $self 	= shift;
	my $string 	= shift 	or return undef;
	my $good 	= shift 	|| 'GOOD';

	my $qgood = quotemeta($good);

	my $clear = "";
	$clear = $self->Clear;

	$self->Clear($clear) 
		if $self->Count >= $clear and $clear > 0;

	my $count 	= $self->Count($self->Count+1);

	$string 	= "$count $string" ;

	$self->_record($count,[ 0, "INPUT", "$string\x0d\x0a"] );

	my $feedback = $self->_send_line("$string");

	unless ($feedback) {
		$self->LastError( "Error sending '$string' to IMAP: $!\n");
		$@ = "Error sending '$string' to IMAP: $!";
		carp "Error sending '$string' to IMAP: $!" if $^W;
		return undef;
	}

	my ($code, $output);	
	$output = "";

	READ: until ( $code)  {
	    	# escape infinite loop if read_line never returns any data:
              	$output = $self->_read_line or return undef; 

		for my $o (@$output) { 
			$self->_record($count,$o);	# $o is a ref
                      # $self->_debug("Received from readline: ${\($o->[DATA])}<<END OF RESULT>>\n");
			next unless $self->_is_output($o);
			if ( $good eq '+' ) {
                      		$o->[DATA] =~ /^$count (OK|BAD|NO|$qgood)|^($qgood)/mi ;
				$code = $1||$2 ;
			} else {
                      		($code) = $o->[DATA] =~ /^$count (OK|BAD|NO|$qgood)/mi ;
			}
                      if ($o->[DATA] =~ /^\*\s+BYE/im) {
				$self->State(Unconnected);
				return undef ;
			}
		}
	}	
	
	# $self->_debug("Command $string: returned $code\n");
	return $code =~ /^OK|$qgood/im ? $self : undef ;

}

sub run {
	my $self 	= shift;
	my $string 	= shift 	or return undef;
	my $good 	= shift 	|| 'GOOD';
	my $count 	= $self->Count($self->Count+1);
	my($tag)	= $string =~ /^(\S+) /  ;

	unless ($tag) {
		$self->LastError("Invalid string passed to run method; no tag found.\n");
	}

	my $qgood = quotemeta($good);

	my $clear = "";
	$clear = $self->Clear;

	$self->Clear($clear) 
		if $self->Count >= $clear and $clear > 0;

	$self->_record($count,[ $self->_next_index($count), "INPUT", "$string"] );

	my $feedback = $self->_send_line("$string",1);

	unless ($feedback) {
		$self->LastError( "Error sending '$string' to IMAP: $!\n");
		return undef;
	}

	my ($code, $output);	
	$output = "";

	until ( $code =~ /(OK|BAD|NO|$qgood)/m ) {

		$output = $self->_read_line or return undef;	
		for my $o (@$output) { 
			$self->_record($count,$o);	# $o is a ref
			next unless $self->_is_output($o);
			if ( $good eq '+' ) {
			   $o->[DATA] =~ /^(?:$tag|\*) (OK|BAD|NO|$qgood)|(^$qgood)/m  ;
			   $code = $1||$2;
			} else {
                      		($code) = 
				   $o->[DATA] =~ /^(?:$tag|\*) (OK|BAD|NO|$qgood)/m  ;
			}
                      if ($o->[DATA] =~ /^\*\s+BYE/) {
				$self->State(Unconnected);
			}
		}
	}	
	$self->{'History'}{$tag} = $self->{"History"}{$count} unless $tag eq $count;
	return $code =~ /^OK|$qgood/ ? @{$self->Results} : undef ;

}
#sub bodystruct {	# return bodystruct 
#}

# _record saves the conversation into the History structure:
sub _record {

	my ($self,$count,$array) = ( shift, shift, shift);
	local($^W)= undef;

	#$self->_debug(sprintf("in _record: count is $count, values are %s/%s/%s and caller is " . 
	#	join(":",caller()) . "\n",@$array));
	
      if (    #       $array->[DATA] and 
              $array->[DATA] =~ /^\d+ LOGIN/i and
		! $self->Showcredentials
      ) { 

              $array->[DATA] =~ s/LOGIN.*/LOGIN XXXXXXXX XXXXXXXX/i ;
	}

	push @{$self->{"History"}{$count}}, $array;

      if ( $array->[DATA] =~ /^\d+\s+(BAD|NO)\s/im ) {
              $self->LastError("$array->[DATA]") ;
              $@ = $array->[DATA];
              carp "$array->[DATA]" if $^W ;
	}
	return $self;
}

#_send_line writes to the socket:
sub _send_line {
	my($self,$string,$suppress) = (shift, shift, shift);

	#$self->_debug("_send_line: Connection state = " . 
	#		$self->State . " and socket fh = " . 
	#		($self->Socket||"undef") . "\n")
	#if $self->Debug;

	unless ($self->IsConnected and $self->Socket) {
		$self->LastError("NO Not connected.\n");
		carp "Not connected" if $^W;
		return undef;
	}

	unless ($string =~ /\x0d\x0a$/ or $suppress ) {

		chomp $string;
		$string .= "\x0d" unless $string =~ /\x0d$/;	
		$string .= "\x0a" ;
	}
	if ( 
		$string =~ /^[^\x0a{]*\{(\d+)\}\x0d\x0a/ 	   # ;-}
	) 	{
		my($p1,$p2,$len) ;
		if ( ($p1,$len)   = 
			$string =~ /^([^\x0a{]*\{(\d+)\}\x0d\x0a)/ # } for vi
			and  (
				$len < 32766 ? 
				( ($p2) = $string =~ /
					^[^\x0a{]*
					\{\d+\}
					\x0d\x0a
					(
						.{$len}
						.*\x0d\x0a
					)
				/x ) :

				( ($p2) = $string =~ /	^[^\x0a{]*
							\{\d+\}
							\x0d\x0a
							(.*\x0d\x0a)
						    /x 	
				   and length($p2) == $len  ) # }} for vi
		     )
		) {
			$self->_debug("Sending literal string " .
				"in two parts: $p1\n\tthen: $p2\n");
			$self->_send_line($p1) or return undef;
			$output = $self->_read_line or return undef;
			foreach my $o (@$output) {
				# $o is already an array ref:
				$self->_record($self->Count,$o);              
                              ($code) = $o->[DATA] =~ /(^\+|NO|BAD)/i;
                              if ($o->[DATA] =~ /^\*\s+BYE/) {
					$self->State(Unconnected);
					close $fh;
					return undef ;
                              } elsif ( $o->[DATA]=~ /^\d+\s+(NO|BAD)/i ) {
					close $fh;
					return undef;
				}
			}
			if ( $code eq '+' ) 	{ $string = $p2; } 
			else 			{ return undef ; }
		}
		
	}
	if ($self->Debug) {
		my $dstring = $string;
		if ( $dstring =~ m[\d+\s+Login\s+]i) {
			$dstring =~ 
			  s(\b(?:\Q$self->{Password}\E|\Q$self->{User}\E)\b)
			('X' x length($self->{Password}))eg;
		}
		_debug $self, "Sending: $dstring\n" if $self->Debug;
	}
	my $total = 0;
	my $temperrs = 0;
	my $optimize = 0;
     	my $maxwrite = 0;
     	my $waittime = .02;
     	my @last5writes = (1);
	$string = $self->Prewritemethod->($self,$string) if $self->Prewritemethod;
	_debug $self, "Sending: $string\n" if $self->Debug and $self->Prewritemethod;

	until ($total >= length($string)) {
		my $ret = 0;
	        $!=0;
		$ret =	syswrite(	
					$self->Socket, 
					$string, 
					length($string)-$total, 
					$total
					);
		$ret||=0;
		if ($! == &EAGAIN ) {
			if ( 	$self->{Maxtemperrors} !~ /^unlimited/i
			    	and $temperrs++ > ($self->{Maxtemperrors}||10) 
			) {
				$self->LastError("Persistent '${!}' errors\n");
				$self->_debug("Persistent '${!}' errors\n");
				return undef;
			}
			$optimize = 1;
		} else {
			# avoid infinite loops on syswrite error
			return undef unless(defined $ret);	 
		}
		# Optimization of wait time between syswrite calls
		# only runs if syscalls run too fast and fill the 
		# buffer causing "EAGAIN: Resource Temp. Unavail" errors. The
		# premise is that $maxwrite will be approx. the same as 
		# the smallest buffer between the sending and receiving side. 
		# Waiting time between syscalls should ideally be exactly as 
		# long as it takes the receiving side to empty that buffer, 
		# minus a little bit to prevent it from
		# emptying completely and wasting time in the select call.
		if ($optimize) {
		    $maxwrite = $ret if $maxwrite < $ret;
		    push( @last5writes, $ret );
		    shift( @last5writes ) if $#last5writes > 5;
		    my $bufferavail = 0;
		    $bufferavail += $_ for ( @last5writes );
		    $bufferavail /= $#last5writes;
		    # Buffer is staying pretty full; 
		    # we should increase the wait period
		    # to reduce transmission overhead/number of packets sent
		    if ( $bufferavail < .4 * $maxwrite ) {
			$waittime *= 1.3;

		    # Buffer is nearly or totally empty; 
		    # we're wasting time in select
		    # call that could be used to send data, 
		    # so reduce the wait period
		    } elsif ( $bufferavail > .9 * $maxwrite ) {
			$waittime *= .5;
		    }
		    $self->_debug("Output buffer full; waiting $waittime seconds for relief\n");
		    CORE::select(undef, undef, undef, $waittime);
		}
		if ( defined($ret) ) {
			$temperrs = 0  ;
			$total += $ret ;
		}
	}
	_debug $self,"Sent $total bytes\n" if $self->Debug;
	return $total;
}

# _read_line reads from the socket. It is called by:
# 	append	append_file	authenticate	connect		_imap_command
#
# It is also re-implemented in:
#	message_to_file
#
# syntax: $output = $self->_readline( ( $literal_callback|undef ) , ( $output_callback|undef ) ) ;
# 	  Both input argument are optional, but if supplied must either be a filehandle, coderef, or undef.
#
#	Returned argument is a reference to an array of arrays, ie: 
#	$output = [ 
#			[ $index, 'OUTPUT'|'LITERAL', $output_line ] ,
#			[ $index, 'OUTPUT'|'LITERAL', $output_line ] ,
#			... 	# etc,
#	];

sub _read_line {
	my $self 	= shift;	
	my $sh		= $self->Socket;
	my $literal_callback    = shift;
	my $output_callback = shift;
	
	unless ($self->IsConnected and $self->Socket) {
		$self->LastError("NO Not connected.\n");
		carp "Not connected" if $^W;
		return undef;
	}

	my $iBuffer	= ""; 
	my $oBuffer	= [];
	my $count	= 0;
	my $index	= $self->_next_index($self->Transaction);
	my $rvec 	= my $ready = my $errors = 0; 
	my $timeout	= $self->Timeout;

	my $readlen 	= 1;
	my $fast_io	= $self->Fast_io;	# Remember setting to reduce future method calls

	if ( $fast_io ) {
		
		# set fcntl if necessary:
		exists $self->{_fcntl} or $self->Fast_io($fast_io);
		$readlen = $self->{Buffer}||4096;
	}
	until (	
		# there's stuff in output buffer:
		scalar(@$oBuffer)	and 			

		# the last thing there has cr-lf:
                $oBuffer->[-1][DATA] =~ /\x0d\x0a$/  and     

		# that thing is an output line:
                $oBuffer->[-1][TYPE]    eq "OUTPUT"  and     

		# and the input buffer has been MT'ed:
		$iBuffer		eq "" 		

	) {
              my $transno = $self->Transaction;  # used below in several places
		if ($timeout) {
			vec($rvec, fileno($self->Socket), 1) = 1;
			my @ready = $self->{_select}->can_read($timeout) ;
			unless ( @ready ) {
				$self->LastError("Tag $transno: " .
					"Timeout after $timeout seconds " .
					"waiting for data from server\n");	
				$self->_record($transno,
					[	$self->_next_index($transno),
						"ERROR",
						"$transno * NO Timeout after ".
						"$timeout seconds " .
						"during read from " .
						"server\x0d\x0a"
					]
				);
				$self->LastError(
					"Timeout after $timeout seconds " .
					"during read from server\x0d\x0a"
				);
				return undef;
			}
		}
		
		local($^W) = undef;	# Now quiet down warnings

		# read "$readlen" bytes (or less):
              # need to check return code from $self->_sysread 
  	      #	in case other end has shut down!!!
              my $ret = $self->_sysread( $sh, \$iBuffer, $readlen, length($iBuffer)) ;
	      # $self->_debug("Read so far: $iBuffer<<END>>\n");
              if($timeout and ! defined($ret)) { # Blocking read error...
                  my $msg = "Error while reading data from server: $!\x0d\x0a";
                  $self->_record($transno,
                                 [ $self->_next_index($transno),
                                   "ERROR", "$transno * NO $msg "
                                   ]);
                  $@ = "$msg";
                  return undef;
              }
              elsif(defined($ret) and $ret == 0) {    # Caught EOF...
                  my $msg="Socket closed while reading data from server.\x0d\x0a";
                  $self->_record($transno,
                                 [ $self->_next_index($transno),
                                   "ERROR", "$transno * NO $msg "
                                   ]);
                  $@ = "$msg";
                  return undef;
              }
              # successfully wrote to other end, keep going...
              $count += $ret;
		LINES: while ( $iBuffer =~ s/^(.*?\x0d?\x0a)// ) {
		   my $current_line = $1;

		   # $self->_debug("BUFFER: pulled from buffer: <BEGIN>${current_line}<END>\n" .
		   # 	"and left with buffer contents of: <BEGIN>${iBuffer}<END>\n");

		   LITERAL: if ($current_line =~ s/\{(\d+)\}\x0d\x0a$//) {
			# This part handles IMAP "Literals", 
			# which according to rfc2060 look something like this:
			# [tag]|* BLAH BLAH {nnn}\r\n
			# [nnn bytes of literally transmitted stuff]
			# [part of line that follows literal data]\r\n

			# Set $len to be length of impending literal:
			my $len = $1 ;
			
			$self->_debug("LITERAL: received literal in line ".
				"$current_line of length $len; ".
				"attempting to ".
				"retrieve from the " . length($iBuffer) . 
				" bytes in: $iBuffer<END_OF_iBuffer>\n");

			# Xfer up to $len bytes from front of $iBuffer to $litstring: 
			my $litstring = substr($iBuffer, 0, $len);
			$iBuffer = substr($iBuffer, length($litstring), 
					length($iBuffer) - length($litstring) ) ;

			# Figure out what's left to read (i.e. what part of 
			# literal wasn't in buffer):
			my $remainder_count = $len - length($litstring);
			my $callback_value = "";

			if ( defined($literal_callback) ) 	{	
				if 	( $literal_callback =~ /GLOB/) 	{	
					print $literal_callback $litstring ;
					$litstring = "";
				} elsif ($literal_callback =~ /CODE/ ) {
					# Don't do a thing

				} else 	{
					$self->LastError(
						ref($literal_callback) . 
						" is an invalid callback type; " .
						"must be a filehandle or coderef\n"
					); 
				}

		
			}
			if ($remainder_count > 0 and $timeout) {
				# If we're doing timeouts then here we set up select 
				# and wait for data from the the IMAP socket.
				vec($rvec, fileno($self->Socket), 1) = 1;
				unless ( CORE::select( $ready = $rvec, 
							undef, 
							$errors = $rvec, 
							$timeout) 
				) {	
					# Select failed; that means bad news. 
					# Better tell someone.
					$self->LastError("Tag " . $transno . 
						": Timeout waiting for literal data " .
						"from server\n");	
					carp "Tag " . $transno . 
						": Timeout waiting for literal data " .
						"from server\n"
						if $self->Debug or $^W;	
					return undef;
				}	
			} 
			
			fcntl($sh, F_SETFL, $self->{_fcntl}) 
				if $fast_io and defined($self->{_fcntl});
			while ( $remainder_count > 0 ) {	   # As long as not done,
				$self->_debug("Still need $remainder_count to " .
					"complete literal string\n");
				my $ret	= $self->_sysread(   	   # bytes read
						$sh, 		   # IMAP handle 
						\$litstring,	   # place to read into
						$remainder_count,  # bytes left to read
						length($litstring) # offset to read into
				) ;
				$self->_debug("Received ret=$ret and buffer = " .
				"\n$litstring<END>\nwhile processing LITERAL\n");
				if ( $timeout and !defined($ret)) { # possible timeout
					$self->_record($transno, [ 
						$self->_next_index($transno),
						"ERROR",
						"$transno * NO Error reading data " .
						"from server: $!\n"
						]
					);
					return undef;
				} elsif ( $ret == 0 and eof($sh) ) {
					$self->_record($transno, [ 
						$self->_next_index($transno),
						"ERROR",
						"$transno * ".
						"BYE Server unexpectedly " .
						"closed connection: $!\n"	
						]
					);
					$self->State(Unconnected);
					return undef;
				}
				# decrement remaining bytes by amt read:
				$remainder_count -= $ret;	   

				if ( length($litstring) > $len ) {
                                    # copy the extra struff into the iBuffer:
                                    $iBuffer = substr(
                                        $litstring,   
                                        $len, 
                                        length($litstring) - $len 
                                    );
                                    $litstring = substr($litstring, 0, $len) ;
                                }

				if ( defined($literal_callback) ) {
					if ( $literal_callback =~ /GLOB/ ) {
						print $literal_callback $litstring;
						$litstring = "";
					} 
				}

			}
			$literal_callback->($litstring) 
				if defined($litstring) and 
				$literal_callback =~ /CODE/;

			$self->Fast_io($fast_io) if $fast_io;

		# Now let's make sure there are no IMAP server output lines 
		# (i.e. [tag|*] BAD|NO|OK Text) embedded in the literal string
		# (There shouldn't be but I've seen it done!), but only if
		# EnableServerResponseInLiteral is set to true

			my $embedded_output = 0;
			my $lastline = ( split(/\x0d?\x0a/,$litstring))[-1] 
				if $litstring;

			if ( 	$self->EnableServerResponseInLiteral and
				$lastline and 
				$lastline =~ /^(?:\*|(\d+))\s(BAD|NO|OK)/i 
			) {
			  $litstring =~ s/\Q$lastline\E\x0d?\x0a//;
			  $embedded_output++;

			  $self->_debug("Got server output mixed in " .
					"with literal: $lastline\n"
			  ) 	if $self->Debug;

			}
		  	# Finally, we need to stuff the literal onto the 
			# end of the oBuffer:
			push @$oBuffer, [ $index++, "OUTPUT" , $current_line],
					[ $index++, "LITERAL", $litstring   ];
			push @$oBuffer,	[ $index++, "OUTPUT",  $lastline    ] 
					if $embedded_output;

		  } else { 
			push @$oBuffer, [ $index++, "OUTPUT" , $current_line ]; 
		  }
		
		}
		#$self->_debug("iBuffer is now: $iBuffer<<END OF BUFFER>>\n");
	}
	#	_debug $self, "Buffer is now $buffer\n";
      _debug $self, "Read: " . join("",map {$_->[DATA]} @$oBuffer) ."\n" 
		if $self->Debug;
	return scalar(@$oBuffer) ? $oBuffer : undef ;
}

sub _sysread {
	my $self = shift @_;
	if ( exists $self->{Readmethod} )  {
		return $self->Readmethod->($self,@_) ;
	} else {
		my($handle,$buffer,$count,$offset) = @_;
		return sysread( $handle, $$buffer, $count, $offset);
	}
}

=begin obsolete

sub old_read_line {
	my $self 	= shift;	
	my $sh		= $self->Socket;
	my $literal_callback    = shift;
	my $output_callback = shift;
	
	unless ($self->IsConnected and $self->Socket) {
		$self->LastError("NO Not connected.\n");
		carp "Not connected" if $^W;
		return undef;
	}

	my $iBuffer	= ""; 
	my $oBuffer	= [];
	my $count	= 0;
	my $index	= $self->_next_index($self->Transaction);
	my $rvec 	= my $ready = my $errors = 0; 
	my $timeout	= $self->Timeout;

	my $readlen 	= 1;
	my $fast_io	= $self->Fast_io;	# Remember setting to reduce future method calls

	if ( $fast_io ) {
		
		# set fcntl if necessary:
		exists $self->{_fcntl} or $self->Fast_io($fast_io);
		$readlen = $self->{Buffer}||4096;
	}
	until (	
		# there's stuff in output buffer:
		scalar(@$oBuffer)	and 			

		# the last thing there has cr-lf:
                $oBuffer->[-1][DATA] =~ /\x0d\x0a$/  and     

		# that thing is an output line:
                $oBuffer->[-1][TYPE]    eq "OUTPUT"  and     

		# and the input buffer has been MT'ed:
		$iBuffer		eq "" 		

	) {
              my $transno = $self->Transaction;  # used below in several places
		if ($timeout) {
			vec($rvec, fileno($self->Socket), 1) = 1;
			my @ready = $self->{_select}->can_read($timeout) ;
			unless ( @ready ) {
				$self->LastError("Tag $transno: " .
					"Timeout after $timeout seconds " .
					"waiting for data from server\n");	
				$self->_record($transno,
					[	$self->_next_index($transno),
						"ERROR",
						"$transno * NO Timeout after ".
						"$timeout seconds " .
						"during read from " .
						"server\x0d\x0a"
					]
				);
				$self->LastError(
					"Timeout after $timeout seconds " .
					"during read from server\x0d\x0a"
				);
				return undef;
			}
		}
		
		local($^W) = undef;	# Now quiet down warnings

		# read "$readlen" bytes (or less):
              # need to check return code from sysread in case other end has shut down!!!
              my $ret = sysread( $sh, $iBuffer, $readlen, length($iBuffer)) ;
		# $self->_debug("Read so far: $iBuffer<<END>>\n");
              if($timeout and ! defined($ret)) { # Blocking read error...
                  my $msg = "Error while reading data from server: $!\x0d\x0a";
                  $self->_record($transno,
                                 [ $self->_next_index($transno),
                                   "ERROR", "$transno * NO $msg "
                                   ]);
                  $@ = "$msg";
                  return undef;
              }
              elsif(defined($ret) and $ret == 0) {    # Caught EOF...
                  my $msg="Socket closed while reading data from server.\x0d\x0a";
                  $self->_record($transno,
                                 [ $self->_next_index($transno),
                                   "ERROR", "$transno * NO $msg "
                                   ]);
                  $@ = "$msg";
                  return undef;
              }
              # successfully wrote to other end, keep going...
              $count += $ret;
		LINES: while ( $iBuffer =~ s/^(.*?\x0d?\x0a)// ) {
		   my $current_line = $1;

		   # $self->_debug("BUFFER: pulled from buffer: <BEGIN>${current_line}<END>\n" .
		   # 	"and left with buffer contents of: <BEGIN>${iBuffer}<END>\n");

		   LITERAL: if ($current_line =~ s/\{(\d+)\}\x0d\x0a$//) {
			# This part handles IMAP "Literals", which according to rfc2060 look something like this:
			# [tag]|* BLAH BLAH {nnn}\r\n
			# [nnn bytes of literally transmitted stuff]
			# [part of line that follows literal data]\r\n

			# Set $len to be length of impending literal:
			my $len = $1 ;
			
			$self->_debug("LITERAL: received literal in line $current_line of length $len; ".
			"attempting to ".
			"retrieve from the " . length($iBuffer) . " bytes in: $iBuffer<END_OF_iBuffer>\n");

			# Transfer up to $len bytes from front of $iBuffer to $litstring: 
			my $litstring = substr($iBuffer, 0, $len);
			$iBuffer = substr($iBuffer, length($litstring), length($iBuffer) - length($litstring) ) ;

			# Figure out what's left to read (i.e. what part of literal wasn't in buffer):
			my $remainder_count = $len - length($litstring);
			my $callback_value = "";

			if ( defined($literal_callback) ) 	{	
				if 	( $literal_callback =~ /GLOB/) 	{	
					print $literal_callback $litstring ;
					$litstring = "";
				} elsif ($literal_callback =~ /CODE/ ) {
					# Don't do a thing

				} else 	{
					$self->LastError(
						ref($literal_callback) . 
						" is an invalid callback type; must be a filehandle or coderef"
					); 
				}

		
			}
			if ($remainder_count > 0 and $timeout) {
				# If we're doing timeouts then here we set up select and wait for data from the
				# the IMAP socket.
				vec($rvec, fileno($self->Socket), 1) = 1;
				unless ( CORE::select( $ready = $rvec, 
							undef, 
							$errors = $rvec, 
							$timeout) 
				) {	
					# Select failed; that means bad news. 
					# Better tell someone.
					$self->LastError("Tag " . $transno . 
						": Timeout waiting for literal data " .
						"from server\n");	
					carp "Tag " . $transno . 
						": Timeout waiting for literal data " .
						"from server\n"
						if $self->Debug or $^W;	
					return undef;
				}	
			} 
			
			fcntl($sh, F_SETFL, $self->{_fcntl}) 
				if $fast_io and defined($self->{_fcntl});
			while ( $remainder_count > 0 ) {	   # As long as not done,

				my $ret	= sysread(	   	   # bytes read
						$sh, 		   # IMAP handle 
						$litstring,	   # place to read into
						$remainder_count,  # bytes left to read
						length($litstring) # offset to read into
				) ;
				if ( $timeout and !defined($ret)) { # possible timeout
					$self->_record($transno, [ 
						$self->_next_index($transno),
						"ERROR",
						"$transno * NO Error reading data " .
						"from server: $!\n"
						]
					);
					return undef;
				} elsif ( $ret == 0 and eof($sh) ) {
					$self->_record($transno, [ 
						$self->_next_index($transno),
						"ERROR",
						"$transno * ".
						"BYE Server unexpectedly " .
						"closed connection: $!\n"	
						]
					);
					$self->State(Unconnected);
					return undef;
				}
				# decrement remaining bytes by amt read:
				$remainder_count -= $ret;	   

				if ( defined($literal_callback) ) {
					if ( $literal_callback =~ /GLOB/ ) {
						print $literal_callback $litstring;
						$litstring = "";
					} 
				}

			}
			$literal_callback->($litstring) 
				if defined($litstring) and 
				$literal_callback =~ /CODE/;

			$self->Fast_io($fast_io) if $fast_io;

		# Now let's make sure there are no IMAP server output lines 
		# (i.e. [tag|*] BAD|NO|OK Text) embedded in the literal string
		# (There shouldn't be but I've seen it done!), but only if
		# EnableServerResponseInLiteral is set to true

			my $embedded_output = 0;
			my $lastline = ( split(/\x0d?\x0a/,$litstring))[-1] 
				if $litstring;

			if ( 	$self->EnableServerResponseInLiteral and
				$lastline and 
				$lastline =~ /^(?:\*|(\d+))\s(BAD|NO|OK)/i 
			) {
			  $litstring =~ s/\Q$lastline\E\x0d?\x0a//;
			  $embedded_output++;

			  $self->_debug("Got server output mixed in " .
					"with literal: $lastline\n"
			  ) 	if $self->Debug;

			}
		  	# Finally, we need to stuff the literal onto the 
			# end of the oBuffer:
			push @$oBuffer, [ $index++, "OUTPUT" , $current_line],
					[ $index++, "LITERAL", $litstring   ];
			push @$oBuffer,	[ $index++, "OUTPUT",  $lastline    ] 
					if $embedded_output;

		  } else { 
			push @$oBuffer, [ $index++, "OUTPUT" , $current_line ]; 
		  }
		
		}
		#$self->_debug("iBuffer is now: $iBuffer<<END OF BUFFER>>\n");
	}
	#	_debug $self, "Buffer is now $buffer\n";
      _debug $self, "Read: " . join("",map {$_->[DATA]} @$oBuffer) ."\n" 
		if $self->Debug;
	return scalar(@$oBuffer) ? $oBuffer : undef ;
}

=end obsolete

=cut


sub Report {
	my $self = shift;
#	$self->_debug( "Dumper: " . Data::Dumper::Dumper($self) . 
#			"\nReporting on following keys: " . join(", ",keys %{$self->{'History'}}). "\n");
	return 	map { 
                      map { $_->[DATA] } @{$self->{"History"}{$_}} 
	}		sort { $a <=> $b } keys %{$self->{"History"}}
	;
}


sub Results {
	my $self 	= shift	;
	my $transaction = shift||$self->Count;
	
	return wantarray 							? 
              map {$_->[DATA] }       @{$self->{"History"}{$transaction}}     : 
              [ map {$_->[DATA] }     @{$self->{"History"}{$transaction}} ]   ;
}


sub LastIMAPCommand {
      my @a = map { $_->[DATA] } @{$_[0]->{"History"}{$_[1]||$_[0]->Transaction}};
	return shift @a;
}


sub History {
      my @a = map { $_->[DATA] } @{$_[0]->{"History"}{$_[1]||$_[0]->Transaction}};
	shift @a;
	return wantarray ? @a : \@a ;

}

sub Escaped_results {
	my @a;
	foreach  my $line (@{$_[0]->{"History"}{$_[1]||$_[0]->Transaction}} ) {
		if (  defined($line) and $_[0]->_is_literal($line) ) { 
			$line->[DATA] =~ s/([\\\(\)"\x0d\x0a])/\\$1/g ;
			push @a, qq("$line->[DATA]");
		} else {
      			push @a, $line->[DATA] ;
		}
	}
	# $a[0] is the ALWAYS the command ; I make sure of that in _imap_command
	shift @a;	
	return wantarray ? @a : \@a ;
}

sub Unescape {
	shift @_ if $_[1];
	my $whatever = shift;
	$whatever =~ s/\\([\\\(\)"\x0d\x0a])/$1/g if defined $whatever;
	return $whatever;
}

sub logout {
	my $self = shift;
	my $string = "LOGOUT";
	$self->_imap_command($string) ; 
	$self->{Folders} = undef;
	$self->{_IMAP4REV1} = undef;
	eval {$self->Socket->close if defined($self->Socket)} ; 
	$self->{Socket} = undef;
	$self->State(Unconnected);
	return $self;
}

sub folders {
        my $self = shift;
	my $what = shift ;
        return wantarray ?      @{$self->{Folders}} :
                                $self->{Folders} 
                if ref($self->{Folders}) and !$what;
	
        my @folders ;  
	my @list = $self->list(undef,( $what? "$what" . $self->separator($what) . "*" : undef ) );
	push @list, $self->list(undef, $what) if $what and $self->exists($what) ;
	# my @list = 
	# foreach (@list) { $self->_debug("Pushing $_\n"); }
	my $m;

	for ($m = 0; $m < scalar(@list); $m++ ) {
		# $self->_debug("Folders: examining $list[$m]\n");

		if ($list[$m] && $list[$m]  !~ /\x0d\x0a$/ ) {
			$self->_debug("folders: concatenating $list[$m] and " . $list[$m+1] . "\n") ;
			$list[$m] .= $list[$m+1] ;
			$list[$m+1] = "";	
			$list[$m] .= "\x0d\x0a" unless $list[$m] =~ /\x0d\x0a$/;
		}
			
		

		push @folders, $1||$2 
			if $list[$m] =~
                        /       ^\*\s+LIST               # * LIST
                                \s+\([^\)]*\)\s+         # (Flags)
                                (?:"[^"]*"|NIL)\s+	 # "delimiter" or NIL
                                (?:"([^"]*)"|(.*))\x0d\x0a$  # Name or "Folder name"
                        /ix;
		$folders[-1] = '"' . $folders[-1] . '"' 
			if $1 and !$self->exists($folders[-1]) ;
		# $self->_debug("folders: line $list[$m]: 1=$1 and 2=$2\n");
        } 

        # for my $f (@folders) { $f =~ s/^\\FOLDER LITERAL:://;}
	my @clean = (); my %memory = ();
	foreach my $f (@folders) { push @clean, $f unless $memory{$f}++ }
        $self->{Folders} = \@clean unless $what;

        return wantarray ? @clean : \@clean ;
}


sub exists {
	my ($self,$what) = (shift,shift);
	return $self if $self->STATUS($self->Massage($what),"(MESSAGES)");
	return undef;
}

# Updated to handle embedded literal strings
sub get_bodystructure {
	my($self,$msg) = @_;
	unless ( eval {require Mail::IMAPClient::BodyStructure ; 1 } ) {
		$self->LastError("Unable to use get_bodystructure: $@\n");
		return undef;
	}
	my @out = $self->fetch($msg,"BODYSTRUCTURE");
	my $bs = "";
	my $output = grep(	
		/BODYSTRUCTURE \(/i,  @out	 # Wee! ;-)
	); 
	if ( $output =~ /\r\n$/ ) {
		eval { $bs = Mail::IMAPClient::BodyStructure->new( $output )};  
	} else {
		$self->_debug("get_bodystructure: reassembling original response\n");
		my $start = 0;
		foreach my $o (@{$self->{"History"}{$self->Transaction}}) {
			next unless $self->_is_output_or_literal($o);
			$self->_debug("o->[DATA] is ".$o->[DATA]."\n");
			next unless $start or 
				$o->[DATA] =~ /BODYSTRUCTURE \(/i and ++$start;	  # Hi, vi! ;-)
			if ( length($output) and $self->_is_literal($o) ) {
				my $data = $o->[DATA];
				$data =~ s/"/\\"/g;
				$data =~ s/\(/\\\(/g;
				$data =~ s/\)/\\\)/g;
				$output .= '"'.$data.'"';
			} else {
				$output .= $o->[DATA] ;
			}
			$self->_debug("get_bodystructure: reassembled output=$output<END>\n");
		}
		eval { $bs = Mail::IMAPClient::BodyStructure->new( $output )};  
	}
	$self->_debug("get_bodystructure: msg $msg returns this ref: ". 
		( $bs ? " $bs" : " UNDEF" ) 
		."\n");
	return $bs;
}

# Updated to handle embedded literal strings 
sub get_envelope {
	my($self,$msg) = @_;
	unless ( eval {require Mail::IMAPClient::BodyStructure ; 1 } ) {
		$self->LastError("Unable to use get_envelope: $@\n");
		return undef;
	}
	my @out = $self->fetch($msg,"ENVELOPE");
	my $bs = "";
	my $output = grep(	
		/ENVELOPE \(/i,  @out	 # Wee! ;-)
	); 
	if ( $output =~ /\r\n$/ ) {
		eval { 
		 $bs = Mail::IMAPClient::BodyStructure::Envelope->new($output)
		};
	} else {
		$self->_debug("get_envelope: " .
			"reassembling original response\n");
		my $start = 0;
		foreach my $o (@{$self->{"History"}{$self->Transaction}}) {
			next unless $self->_is_output_or_literal($o);
			$self->_debug("o->[DATA] is ".$o->[DATA]."\n");
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
				$output .= $o->[DATA] ;
			}
			$self->_debug("get_envelope: " .
				"reassembled output=$output<END>\n");
		}
		eval { 
		  $bs=Mail::IMAPClient::BodyStructure::Envelope->new($output)
		};  
	}
	$self->_debug("get_envelope: msg $msg returns this ref: ". 
		( $bs ? " $bs" : " UNDEF" ) 
		."\n");
	return $bs;
}

=begin obsolete

sub old_get_envelope {
	my($self,$msg) = @_;
	unless ( eval {require Mail::IMAPClient::BodyStructure ; 1 } ) {
		$self->LastError("Unable to use get_envelope: $@\n");
		return undef;
	}
	my $bs = "";
	my @out = $self->fetch($msg,"ENVELOPE");
	my $output = grep(	
		/ENVELOPE \(/i,  @out	 # Wee! ;-)
	); 
	if ( $output =~ /\r\n$/ ) {
		eval { $bs = Mail::IMAPClient::BodyStructure::Envelope->new( $output )};  
	} else {
		$self->_debug("get_envelope: reassembling original response\n");
		my $start = 0;
		foreach my $o (@{$self->{"History"}{$self->Transaction}}) {
			next unless $self->_is_output_or_literal($o);
			$self->_debug("o->[DATA] is ".$o->[DATA]."\n");
			next unless $start or 
				$o->[DATA] =~ /ENVELOPE \(/i and ++$start;	  # Hi, vi! ;-)
			if ( length($output) and $self->_is_literal($o) ) {
				my $data = $o->[DATA];
				$data =~ s/"/\\"/g;
				$data =~ s/\(/\\\(/g;
				$data =~ s/\)/\\\)/g;
				$output .= '"'.$data.'"';
			} else {
				$output .= $o->[DATA] ;
			}
		}
		$self->_debug("get_envelope: reassembled output=$output<END>\n");
		eval { $bs = Mail::IMAPClient::BodyStructure->new( $output )};  
	}
	$self->_debug("get_envelope: msg $msg returns this ref: ". 
		( $bs ? " $bs" : " UNDEF" ) 
		."\n");
	return $bs;
}

=end obsolete

=cut


sub fetch {

	my $self = shift;
	my $what = shift||"ALL";
	#ref($what) and $what = join(",",@$what);	
	if ( $what eq 'ALL' ) {
		$what = $self->Range($self->messages );
	} elsif (ref($what) or $what =~ /^[,:\d]+\w*$/)  {
		$what = $self->Range($what);	
	}
	$self->_imap_command( ( $self->Uid ? "UID " : "" ) .
				"FETCH $what" . ( @_ ? " " . join(" ",@_) : '' )
	) 	 					or return undef;
	return wantarray ? 	$self->History($self->Count) 	: 
                              [ map { $_->[DATA] } @{$self->{'History'}{$self->Count}} ];

}


sub fetch_hash {
	my $self = shift;
	my $hash = ref($_[-1]) ? pop @_ : {};
	my @words = @_;
	for (@words) { 
		s/([\( ])FAST([\) ])/${1}FLAGS INTERNALDATE RFC822\.SIZE$2/i  ;
		s/([\( ])FULL([\) ])/${1}FLAGS INTERNALDATE RFC822\.SIZE ENVELOPE BODY$2/i  ;
	}
	my $msgref = scalar($self->messages);
	my $output = scalar($self->fetch($msgref,"(" . join(" ",@_) . ")")) 
	; #	unless grep(/\b(?:FAST|FULL)\b/i,@words);
	my $x;
	for ($x = 0;  $x <= $#$output ; $x++) {
		my $entry = {};
		my $l = $output->[$x];
		if ($self->Uid) {	
			my($uid) = $l =~ /\((?:.* )?UID (\d+).*\)/i;
			next unless $uid;
			if ( exists $hash->{$uid} ) {
				$entry = $hash->{$uid} ;
			} else {
				$hash->{$uid} ||= $entry;
			}
		} else {
			my($mid) = $l =~ /^\* (\d+) FETCH/i;
			next unless $mid;
			if ( exists $hash->{$mid} ) {
				$entry = $hash->{$mid} ;
			} else {
				$hash->{$mid} ||= $entry;
			}
		}
			
		foreach my $w (@words) {
		   if ( $l =~ /\Q$w\E\s*$/i ) {
			$entry->{$w} = $output->[$x+1];
			$entry->{$w} =~ s/(?:\x0a?\x0d)+$//g;
			chomp $entry->{$w};
		   } else {
			$l =~ /\( 	    # open paren followed by ... 
				(?:.*\s)?   # ...optional stuff and a space
				\Q$w\E\s    # escaped fetch field<sp>
				(?:"	    # then: a dbl-quote
				  (\\.|   # then bslashed anychar(s) or ...
				   [^"]+)   # ... nonquote char(s)
				"|	    # then closing quote; or ...
				\(	    # ...an open paren
				  (\\.|     # then bslashed anychar or ...
				   [^\)]+)  # ... non-close-paren char
				\)|	    # then closing paren; or ...
				(\S+))	    # unquoted string
				(?:\s.*)?   # possibly followed by space-stuff
				\)	    # close paren
			/xi;
			$entry->{$w}=defined($1)?$1:defined($2)?$2:$3;
		   }
		}
	}
	return wantarray ? %$hash : $hash;
}
sub AUTOLOAD {

	my $self = shift;
	return undef if $Mail::IMAPClient::AUTOLOAD =~ /DESTROY$/;
	delete $self->{Folders}  ;
	my $autoload = $Mail::IMAPClient::AUTOLOAD;
	$autoload =~ s/.*:://;
	if (	
			$^W
		and	$autoload =~ /^[a-z]+$/
		and	$autoload !~ 
				/^	(?:
						store	 |
						copy	 |
						subscribe|
						create	 |
						delete	 |
						close	 |
						expunge
					)$
				/x 
	) {
		carp 	"$autoload is all lower-case. " .
			"May conflict with future methods. " .
			"Change method name to be mixed case or all upper case to ensure " .
			"upward compatability"
	}
	if (scalar(@_)) {
		my @a = @_;
		if (	
			$autoload =~ 
				/^(?:subscribe|delete|myrights)$/i
		) {
			$a[-1] = $self->Massage($a[-1]) ;
		} elsif (	
			$autoload =~ 
				/^(?:create)$/i
		) {
			$a[0] = $self->Massage($a[0]) ;
		} elsif (
			$autoload =~ /^(?:store|copy)$/i
		) {
			$autoload = "UID $autoload"
				if $self->Uid;
		} elsif (
			$autoload =~ /^(?:expunge)$/i and defined($_[0])
		) {
			my $old;
			if ( $_[0] ne $self->Folder ) {
				$old = $self->Folder; $self->select($_[0]); 
			} 	
			my $succ = $self->_imap_command(qq/$autoload/) ;
			$self->select($old);
			return undef unless $succ;
			return wantarray ? 	$self->History($self->Count) 	: 
                                              map {$_->[DATA]}@{$self->{'History'}{$self->Count}}     ;
			
		}
		$self->_debug("Autoloading: $autoload " . ( @a ? join(" ",@a):"" ) ."\n" )
			if $self->Debug;
		return undef 
			unless $self->_imap_command(
			 	qq/$autoload/ .  ( @a ? " " . join(" ",@a) : "" )
			)  ;
	} else {
		$self->Folder(undef) if $autoload =~ /^(?:close)/i ; 
		$self->_imap_command(qq/$autoload/) or return undef;
	}
	return wantarray ? 	$self->History($self->Count) 	: 
                              [map {$_->[DATA] } @{$self->{'History'}{$self->Count}}] ;

}

sub rename {
    my $self = shift;
    my ($from, $to) = @_;
    local($_);
    if ($from =~ /^"(.*)"$/) {
	$from = $1 unless $self->exists($from);
        $from =~ s/"/\\"/g;
    }
    if ($to =~ /^"(.*)"$/) {
	$to = $1 unless $self->exists($from) and $from =~ /^".*"$/;
        $to =~ s/"/\\"/g;
    }
    $self->_imap_command(qq(RENAME "$from" "$to")) or return undef;
    return $self;
}

sub status {

	my $self = shift;
	my $box = shift ;  
	return undef unless defined($box);
	$box = $self->Massage($box);
	my @pieces = @_;
	$self->_imap_command("STATUS $box (". (join(" ",@_)||'MESSAGES'). ")") or return undef;
	return wantarray ? 	$self->History($self->Count) 	: 
                              [map{$_->[DATA]}@{$self->{'History'}{$self->Count}}];

}


# Can take a list of messages now.
# If a single message, returns array or ref to array of flags
# If a ref to array of messages, returns a ref to hash of msgid => flag arr
# See parse_headers for more information
# 2000-03-22 Adrian Smith (adrian.smith@ucpag.com)

sub flags {
	my $self = shift;
	my $msgspec = shift;
	my $flagset = {};
	my $msg;
	my $u_f = $self->Uid;

	# Determine if set of messages or just one
	if (ref($msgspec) eq 'ARRAY' ) {
		$msg = $self->Range($msgspec) ;
	} elsif ( !ref($msgspec) ) 	{
		$msg = $msgspec;
		if ( scalar(@_) ) {
			$msgspec = $self->Range($msg) ;
			$msgspec += $_ for (@_);
			$msg = $msgspec;
		}
	} elsif ( ref($msgspec) =~ /MessageSet/ ) {
		if ( scalar(@_) ) {
			$msgspec += $_ for @_;
		}
	} else {
		$self->LastError("Invalid argument passed to fetch.\n");
		return undef;
	}

	# Send command
	unless ( $self->fetch($msg,"FLAGS") ) {
		return undef;
	}

	# Parse results, setting entry in result hash for each line
 	foreach my $resultline ($self->Results) {
		$self->_debug("flags: line = '$resultline'\n") ;
		if (	$resultline =~ 
			/\*\s+(\d+)\s+FETCH\s+	# * nnn FETCH 
			 \(			# open-paren
			 (?:\s?UID\s(\d+)\s?)?	# optional: UID nnn <space>
			 FLAGS\s?\((.*)\)\s?	# FLAGS (\Flag1 \Flag2) <space>
			 (?:\s?UID\s(\d+))?	# optional: UID nnn
			 \) 			# close-paren
			/x
		) {
			{ local($^W=0);
			 $self->_debug("flags: line = '$resultline' " .
			   "and 1,2,3,4 = $1,$2,$3,$4\n") 
			 if $self->Debug;
			}
			my $mailid = $u_f ? ( $2||$4) : $1;
			my $flagsString = $3 ;
			my @flags = map { s/\s+$//; $_ } split(/\s+/, $flagsString);
			$flagset->{$mailid} = \@flags;
		}
	}

	# Did the guy want just one response? Return it if so
	unless (ref($msgspec) ) {
		my $flagsref = $flagset->{$msgspec};
		return wantarray ? @$flagsref : $flagsref;
	}

	# Or did he want a hash from msgid to flag array?
	return $flagset;
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

sub parse_headers {
	my($self,$msgspec,@fields) = @_;
	my(%fieldmap) = map { ( lc($_),$_ )  } @fields;
	my $msg; my $string; my $field;

	# Make $msg a comma separated list, of messages we want
        if (ref($msgspec) eq 'ARRAY') {
		#$msg = join(',', @$msgspec);
		$msg = $self->Range($msgspec);
	} else {
		$msg = $msgspec;
	}

	if ($fields[0] 	=~ 	/^[Aa][Ll]{2}$/ 	) { 

		$string = 	"$msg body" . 
		# use ".peek" if Peek parameter is a) defined and true, 
		# 	or b) undefined, but not if it's defined and untrue:

		( 	defined($self->Peek) 		? 
			( $self->Peek ? ".peek" : "" ) 	: 
			".peek" 
		) .  "[header]" 			; 

	} else {
		$string	= 	"$msg body" .
		# use ".peek" if Peek parameter is a) defined and true, or 
		# b) undefined, but not if it's defined and untrue:

		( defined($self->Peek) 			? 
			( $self->Peek ? ".peek" : "" ) 	: 
			".peek" 
		) .  "[header.fields ("	. join(" ",@fields) 	. ')]' ;
	}

	my @raw=$self->fetch(	$string	) or return undef;

	my $headers = {};	# hash from message ids to header hash
	my $h = 0;		# reference to hash of current msgid, or 0 between msgs
	
        for my $header (map { split(/(?:\x0d\x0a)/,$_) } @raw) {
                local($^W) = undef;
                if ( $header =~ /^\*\s+\d+\s+FETCH\s+\(.*BODY\[HEADER(?:\]|\.FIELDS)/i) {
                        if ($self->Uid) {
                                if ( my($msgid) = $header =~ /UID\s+(\d+)/ ) {
                                        $h = {};
                                        $headers->{$msgid} = $h;
                                } else {
                                        $h = {};
                                }
                        } else {
                                if ( my($msgid) = $header =~ /^\*\s+(\d+)/ ) {
                                        #start of new message header:
                                        $h = {};
                                        $headers->{$msgid} = $h;
                                }
                        }
                }
                next if $header =~ /^\s+$/;

                # ( for vi
                if ($header =~ /^\)/) {           # end of this message
                        $h = 0;                   # set to be between messages
                        next;
                }
                # check for '<optional_white_space>UID<white_space><UID_number><optional_white_space>)'
                # when parsing headers by UID.
                if ($self->Uid and my($msgid) = $header =~ /^\s*UID\s+(\d+)\s*\)/) {
                        $headers->{$msgid} = $h;        # store in results against this message
                        $h = 0;                 	# set to be between messages
                        next;
                }

		if ($h != 0) {			  # do we expect this to be a header?
               		my $hdr = $header;
               		chomp $hdr;
               		$hdr =~ s/\r$//;   
               		if ($hdr =~ s/^(\S+):\s*//) { 
                       		$field = exists $fieldmap{lc($1)} ? $fieldmap{lc($1)} : $1 ;
                       		push @{$h->{$field}} , $hdr ;
               		} elsif ($hdr =~ s/^.*FETCH\s\(.*BODY\[HEADER\.FIELDS.*\)\]\s(\S+):\s*//) { 
                       		$field = exists $fieldmap{lc($1)} ? $fieldmap{lc($1)} : $1 ;
                       		push @{$h->{$field}} , $hdr ;
               		} elsif ( ref($h->{$field}) eq 'ARRAY') {
			        
					$hdr =~ s/^\s+/ /;
                       			$h->{$field}[-1] .= $hdr ;
               		}
		}
	}
	my $candump = 0;
	if ($self->Debug) {
		eval {
			require Data::Dumper;
			Data::Dumper->import;
		};
		$candump++ unless $@;
	}
	# if we asked for one message, just return its hash,
	# otherwise, return hash of numbers => header hash
	# if (ref($msgspec) eq 'ARRAY') {
	if (ref($msgspec) ) {
		#_debug $self,"Structure from parse_headers:\n", 
		#	Dumper($headers) 
		#	if $self->Debug;
		return $headers;
	} else {
		#_debug $self, "Structure from parse_headers:\n", 
		#	Dumper($headers->{$msgspec}) 
		#	if $self->Debug;
		return $headers->{$msgspec};
	}
}

sub subject { return $_[0]->get_header($_[1],"Subject") }
sub date { return $_[0]->get_header($_[1],"Date") }
sub rfc822_header { get_header(@_) }

sub get_header {
	my($self , $msg, $header ) = @_;
	my $val = 0;
	eval { $val = $self->parse_headers($msg,$header)->{$header}[0] };
	return defined($val)? $val : undef;
}

sub recent_count {
	my ($self, $folder) = (shift, shift);

	$self->status($folder, 'RECENT') or return undef;

	chomp(my $r = ( grep { s/\*\s+STATUS\s+.*\(RECENT\s+(\d+)\s*\)/$1/ }
			$self->History($self->Transaction)
	)[0]);

	$r =~ s/\D//g;

	return $r;
}

sub message_count {
	
	my ($self, $folder) = (shift, shift);
	$folder ||= $self->Folder;
	
	$self->status($folder, 'MESSAGES') or return undef;
        foreach my $result  (@{$self->{"History"}{$self->Transaction}}) {
              return $1 if $result->[DATA] =~ /\(MESSAGES\s+(\d+)\s*\)/ ;
        }

	return undef;

}

{
for my $datum (
                qw(     recent seen
                        unseen messages
                 )
) {
        no strict 'refs';
        *$datum = sub {
		my $self = shift;
		#my @hits;

		#my $hits = $self->search($datum eq "messages" ? "ALL" : "$datum")
		#	 or return undef;
		#print "Received $hits from search and array context flag is ",
		#	wantarry,"\n";
		#if ( scalar(@$hits) ) {
		#	return wantarray ? @$hits : $hits ;
		#}
		return $self->search($datum eq "messages" ? "ALL" : "$datum") ;


        };
}
}
{
for my $datum (
                qw(     sentbefore 	sentsince 	senton
			since 		before 		on
                 )
) {
	no strict 'refs';
	*$datum = sub {

		my($self,$time) = (shift,shift);

		my @hits; my $imapdate;
		my @mnt  =      qw{ Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec};

		if ( $time =~ /\d\d-\D\D\D-\d\d\d\d/ ) {
			$imapdate = $time;
		} elsif ( $time =~ /^\d+$/ ) {
			my @ltime = localtime($time);
			$imapdate = sprintf(	"%2.2d-%s-%4.4d", 
						$ltime[3], $mnt[$ltime[4]], $ltime[5] + 1900);
		} else {
			$self->LastError("Invalid date format supplied to '$datum' method.");
			return undef;
		}
		$self->_imap_command( ($self->Uid ? "UID " : "") . "SEARCH $datum $imapdate")
			or return undef;
		my @results =  $self->History($self->Count)     ;

		for my $r (@results) {

		       chomp $r;
		       $r =~ s/\r$//;
		       $r =~ s/^\*\s+SEARCH\s+//i or next;
		       push @hits, grep(/\d/,(split(/\s+/,$r)));
			_debug $self, "Hits are now: ",join(',',@hits),"\n" if $self->Debug;
		}

		return wantarray ? @hits : \@hits;
	}
}
}

sub or {

	my $self = shift ;
	my @what = @_; 
	my @hits;

	if ( scalar(@what) < 2 ) {
		$self->LastError("Invalid number of arguments passed to or method.\n");
		return undef;
	}

	my $or = "OR " . $self->Massage(shift @what);
	$or .= " " . $self->Massage(shift @what);
		

	for my $w ( @what ) {
		my $w = $self->Massage($w) ;
		$or = "OR " . $or . " " . $w ;
	}

	$self->_imap_command( ($self->Uid ? "UID " : "") . "SEARCH $or")
		or return undef;
	my @results =  $self->History($self->Count)     ;

	for my $r (@results) {

	       chomp $r;
	       $r =~ s/\r$//;
	       $r =~ s/^\*\s+SEARCH\s+//i or next;
	       push @hits, grep(/\d/,(split(/\s+/,$r)));
		_debug $self, "Hits are now: ",join(',',@hits),"\n" 
				if $self->Debug;
	}

	return wantarray ? @hits : \@hits;
}

#sub Strip_cr {
#	my $self = shift;

#	my $in = $_[0]||$self ;

#	$in =~ s/\r//g  ;

#	return $in;
#}


sub disconnect { $_[0]->logout }


sub search {

	my $self = shift;
	my @hits;
	my @a = @_;
	$@ = "";
	# massage?
	$a[-1] = $self->Massage($a[-1],1) 
		if scalar(@a) > 1 and !exists($SEARCH_KEYS{uc($a[-1])}); 
	$self->_imap_command( ( $self->Uid ? "UID " : "" ) . "SEARCH ". join(' ',@a)) 
			 or return undef;
	my $results =  $self->History($self->Count) ;


	for my $r (@$results) {
	#$self->_debug("Considering the search result line: $r");			
               chomp $r;
               $r =~ s/\r\n?/ /g;
               $r =~ s/^\*\s+SEARCH\s+(?=.*\d.*)// or next;
               my @h = grep(/^\d+$/,(split(/\s+/,$r)));
	       push @hits, @h if scalar(@h) ; # and grep(/\d/,@h) );

	}

	$self->{LastError}="Search completed successfully but found no matching messages\n"
		unless scalar(@hits);

	if ( wantarray ) {
		return @hits;
	} else {
		if ($self->Ranges) {
			#print STDERR "Fetch: Returning range\n";
			return scalar(@hits) ? $self->Range(\@hits) : undef;
		} else {
			#print STDERR "Fetch: Returning ref\n";
			return scalar(@hits) ? \@hits : undef;
		}
	}
}

sub thread {
	# returns a Thread data structure
	#
	# $imap->thread($algorythm, $charset, @search_args);
	my $self = shift;

	my $algorythm     = shift;
	   $algorythm   ||= $self->has_capability("THREAD=REFERENCES") ? "REFERENCES" : "ORDEREDSUBJECT";
	my $charset 	  = shift;
	   $charset 	||= "UTF-8";

	my @a = @_;

	$a[0]||="ALL" ;
	my @hits;
	# massage?

	$a[-1] = $self->Massage($a[-1],1) 
		if scalar(@a) > 1 and !exists($SEARCH_KEYS{uc($a[-1])}); 
	$self->_imap_command( ( $self->Uid ? "UID " : "" ) . 
				"THREAD $algorythm $charset " . 
				join(' ',@a)
	) or return undef;
	my $results =  $self->History($self->Count) ;

	my $thread = "";
	for my $r (@$results) {
		#$self->_debug("Considering the search result line: $r");			
               	chomp $r;
               	$r =~ s/\r\n?/ /g;
               	if ( $r =~ /^\*\s+THREAD\s+/ ) {
			eval { require "Mail/IMAPClient/Thread.pm" }
				or ( $self->LastError($@), return undef);
			my $parser = Mail::IMAPClient::Thread->new();
			$thread = $parser->start($r) ;
		} else {
			next;
		}
	       	#while ( $r =~ /(\([^\)]*\))/ ) { 
		#	push @hits, [ split(/ /,$1) ] ;
		#}
	}

	$self->{LastError}="Thread search completed successfully but found no matching messages\n"
		unless ref($thread);
	return $thread ||undef;

	if ( wantarray ) {

		return @hits;
	} else {
		return scalar(@hits) ? \@hits : undef;
	}
}




sub delete_message {

	my $self = shift;
	my $count = 0;
	my @msgs = ();
	for my $arg (@_) {
		if (ref($arg) eq 'ARRAY') {
			push @msgs, @{$arg};
		} else {
			push @msgs, split(/\,/,$arg);
		}
	}
	

	$self->store(join(',',@msgs),'+FLAGS.SILENT','(\Deleted)') and $count = scalar(@msgs);

	return $count;
}

sub restore_message {

	my $self = shift;
	my @msgs = ();
	for my $arg (@_) {
		if (ref($arg) eq 'ARRAY') {
			push @msgs, @{$arg};
		} else {
			push @msgs, split(/\,/,$arg);
		}
	}
	

	$self->store(join(',',@msgs),'-FLAGS','(\Deleted)') ;
	my $count = grep(
			/
				^\*			# Start with an asterisk
				\s\d+			# then a space then a number
				\sFETCH			# then a space then the string 'FETCH'
				\s\(			# then a space then an open paren :-) 
				.*			# plus optional anything
				FLAGS			# then the string "FLAGS"
				.*			# plus anything else
				(?!\\Deleted)		# but never "\Deleted"
			/x,
			$self->Results
	);
	

	return $count;
}


sub uidvalidity {

	my $self = shift; my $folder = shift;

	my $vline = (grep(/UIDVALIDITY/i, $self->status($folder, "UIDVALIDITY")))[0];

	my($validity) = $vline =~ /\(UIDVALIDITY\s+([^\)]+)/;

	return $validity;
}

# 3 status folder (uidnext)
# * STATUS folder (UIDNEXT 290)

sub uidnext {

	my $self = shift; my $folder = $self->Massage(shift);

	my $line = (grep(/UIDNEXT/i, $self->status($folder, "UIDNEXT")))[0];

	my($uidnext) = $line =~ /\(UIDNEXT\s+([^\)]+)/;

	return $uidnext;
}

sub capability {

	my $self = shift;

	$self->_imap_command('CAPABILITY') or return undef;

	my @caps = ref($self->{CAPABILITY}) 		? 
			keys %{$self->{CAPABILITY}} 	: 
			map { split } 
				grep (s/^\*\s+CAPABILITY\s+//, 
				$self->History($self->Count));

	unless ( exists $self->{CAPABILITY} ) { 
		for (@caps) { 
			$self->{CAPABILITY}{uc($_)}++ ;
			if (/=/) {
				my($k,$v)=split(/=/,$_) ;
				$self->{uc($k)} = uc($v) ;
			}
		} 
	}
	

	return wantarray ? @caps : \@caps;
}

sub has_capability {
	my $self = shift;
	$self->capability;
	local($^W)=0;
	return $self->{CAPABILITY}{uc($_[0])};
}

sub imap4rev1 {
	my $self = shift;
	return exists($self->{_IMAP4REV1}) ?  
		$self->{_IMAP4REV1} : 
		$self->{_IMAP4REV1} = $self->has_capability(IMAP4REV1) ;
}

sub namespace {
	# Returns a (reference to a?) nested list as follows:
	# [ 
	#  [
	#   [ $user_prefix,  $user_delim  ] (,[$user_prefix2  ,$user_delim  ], [etc,etc] ),
	#  ],
	#  [
	#   [ $shared_prefix,$shared_delim] (,[$shared_prefix2,$shared_delim], [etc,etc] ),
	#  ],
	#  [
	#   [$public_prefix, $public_delim] (,[$public_prefix2,$public_delim], [etc,etc] ),
	#  ],
	# ] ;
		
	my $self = shift;
	unless ( $self->has_capability("NAMESPACE") ) {
			my $error = $self->Count . " NO NAMESPACE not supported by " . $self->Server ;
			$self->LastError("$error\n") ;
			$self->_debug("$error\n") ;
			$@ = $error;
			carp "$@" if $^W;
			return undef;
	}
	my $namespace = (map({ /^\* NAMESPACE (.*)/ ? $1 : () } @{$self->_imap_command("NAMESPACE")->Results}))[0] ;
	$namespace =~ s/\x0d?\x0a$//;
	my($personal,$shared,$public) = $namespace =~ m#
		(NIL|\((?:\([^\)]+\)\s*)+\))\s
		(NIL|\((?:\([^\)]+\)\s*)+\))\s
		(NIL|\((?:\([^\)]+\)\s*)+\))
	#xi;
	
	my @ns = ();
	$self->_debug("NAMESPACE: pers=$personal, shared=$shared, pub=$public\n");
	push @ns, map {
		$_ =~ s/^\((.*)\)$/$1/;
		my @pieces = m#\(([^\)]*)\)#g;
		$self->_debug("NAMESPACE pieces: " . join(", ",@pieces) . "\n");
		my $ref = [];
		foreach my $atom (@pieces) {
			push @$ref, [ $atom =~ m#"([^"]*)"\s*#g ] ;
		}
		$_ =~ /^NIL$/i ? undef : $ref;
	} ( $personal, $shared, $public) ;
	return wantarray ? @ns : \@ns;
}

# Contributed by jwm3
sub internaldate {
        my $self = shift;
        my $msg  = shift;
        $self->_imap_command( ( $self->Uid ? "UID " : "" ) . "FETCH $msg INTERNALDATE") or return undef;
        my $internalDate = join("", $self->History($self->Count));
        $internalDate =~ s/^.*INTERNALDATE "//si;
        $internalDate =~ s/\".*$//s;
        return $internalDate;
}

sub is_parent {
	my ($self, $folder) = (shift, shift);
	# $self->_debug("Checking parentage ".( $folder ? "for folder $folder" : "" )."\n");
        my $list = $self->list(undef, $folder)||"NO NO BAD BAD";
	my $line = '';

        for (my $m = 0; $m < scalar(@$list); $m++ ) {
		#$self->_debug("Judging whether or not $list->[$m] is fit for parenthood\n");
		return undef 
		  if $list->[$m] =~ /NoInferior/i;       # let's not beat around the bush!

                if ($list->[$m]  =~ s/(\{\d+\})\x0d\x0a$// ) {
                        $list->[$m] .= $list->[$m+1];
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
	if ( $line eq "" ) {
		$self->_debug("Warning: separator method found no correct o/p in:\n\t" .
			join("\t",@list)."\n");
	}
	my($f) = $line =~ /^\*\s+LIST\s+\(([^\)]*)\s*\)/ if $line;
	return  1 if $f =~ /HasChildren/i ;
	return 0 if $f =~ /HasNoChildren/i ;
	unless ( $f =~ /\\/) {		# no flags at all unless there's a backslash
		my $sep = $self->separator($folder);
		return 1 if scalar(grep /^${folder}${sep}/, $self->folders);
		return 0;
	}
}

sub selectable {my($s,$f)=@_;return grep(/NoSelect/i,$s->list("",$f))?0:1;}

sub append_string {

        my $self = shift;
        my $folder = $self->Massage(shift);

	my $text = shift;
	$text =~ s/\x0d?\x0a/\x0d\x0a/g;
 
	my($flags,$date) = (shift,shift);

	if (defined($flags)) {
		$flags =~ s/^\s+//g;
		$flags =~ s/\s+$//g;
	}

	if (defined($date)) {
		$date =~ s/^\s+//g;
		$date =~ s/\s+$//g;
	}

	$flags = "($flags)"  if $flags and $flags !~ /^\(.*\)$/ ;
	$date  = qq/"$date"/ if $date  and $date  !~ /^"/ 	;

        my $clear = $self->Clear;

        $self->Clear($clear)
                if $self->Count >= $clear and $clear > 0;

	my $count 	= $self->Count($self->Count+1);

        my $string = 	  "$count APPEND $folder "  	  . 
			( $flags ? "$flags " : "" 	) . 
			( $date ? "$date " : "" 	) . 
			"{" . length($text)  . "}\x0d\x0a" ;

        $self->_record($count,[ $self->_next_index($count), "INPUT", "$string\x0d\x0a" ] );

	# Step 1: Send the append command.

	my $feedback = $self->_send_line("$string");

	unless ($feedback) {
		$self->LastError("Error sending '$string' to IMAP: $!\n");
		return undef;
	}

	my ($code, $output) = ("","");	
	
	# Step 2: Get the "+ go ahead" response
	until ( $code ) {
		$output = $self->_read_line or return undef;	
		foreach my $o (@$output) { 

			$self->_record($count,$o);	# $o is already an array ref
			next unless $self->_is_output($o);

                      ($code) = $o->[DATA] =~ /(^\+|^\d*\s*NO|^\d*\s*BAD)/i ;

                      if ($o->[DATA] =~ /^\*\s+BYE/i) {
                              $self->LastError("Error trying to append string: " . 
						$o->[DATA]. "; Disconnected.\n");
                              $self->_debug("Error trying to append string: " . $o->[DATA]. 
					"; Disconnected.\n");
                              carp("Error trying to append string: " . $o->[DATA] ."; Disconnected") if $^W;
				$self->State(Unconnected);

                      } elsif ( $o->[DATA] =~ /^\d*\s*(NO|BAD)/i ) { # i and / transposed!!!
                              $self->LastError("Error trying to append string: " . $o->[DATA]  . "\n");
                              $self->_debug("Error trying to append string: " . $o->[DATA] . "\n");
                              carp("Error trying to append string: " . $o->[DATA]) if $^W;
				return undef;
			}
		}
	}	
	
	$self->_record($count,[ $self->_next_index($count), "INPUT", "$text\x0d\x0a" ] );

	# Step 3: Send the actual text of the message:
        $feedback = $self->_send_line("$text\x0d\x0a");

        unless ($feedback) {
                $self->LastError("Error sending append msg text to IMAP: $!\n");
                return undef;
        }
	$code = undef;			# clear out code

	# Step 4: Figure out the results:
        until ($code) {
                $output = $self->_read_line or return undef;
              $self->_debug("Append results: " . map({ $_->[DATA] } @$output) . "\n" )
			if $self->Debug;
                foreach my $o (@$output) {
			$self->_record($count,$o); # $o is already an array ref

                      ($code) = $o->[DATA] =~ /^(?:$count|\*) (OK|NO|BAD)/im  ;
			
                      if ($o->[DATA] =~ /^\*\s+BYE/im) {
				$self->State(Unconnected);
                              $self->LastError("Error trying to append: " . $o->[DATA] . "\n");
                              $self->_debug("Error trying to append: " . $o->[DATA] . "\n");
                              carp("Error trying to append: " . $o->[DATA] ) if $^W;
			}
			if ($code and $code !~ /^OK/im) {
                              $self->LastError("Error trying to append: " . $o->[DATA] . "\n");
                              $self->_debug("Error trying to append: " . $o->[DATA] . "\n");
                              carp("Error trying to append: " . $o->[DATA] ) if $^W;
				return undef;
			}
        	}
	}

      my($uid) = join("",map { $_->[TYPE] eq "OUTPUT" ? $_->[DATA] : () } @$output ) =~ m#\s+(\d+)\]#;

        return defined($uid) ? $uid : $self;
}
sub append {

        my $self = shift;
	# now that we're passing thru to append_string we won't massage here
        # my $folder = $self->Massage(shift); 
        my $folder = shift;

	my $text = join("\x0d\x0a",@_);
	$text =~ s/\x0d?\x0a/\x0d\x0a/g;
	return $self->append_string($folder,$text);
}

sub append_file {

        my $self 	= shift;
        my $folder 	= $self->Massage(shift);
	my $file 	= shift; 
	my $control 	= shift || undef;
	my $count 	= $self->Count($self->Count+1);


	unless ( -f $file ) {
		$self->LastError("File $file not found.\n");
		return undef;
	}

	my $fh = IO::File->new($file) ;

	unless ($fh) {
		$self->LastError("Unable to open $file: $!\n");
		$@ = "Unable to open $file: $!" ;
		carp "unable to open $file: $!" if $^W;
		return undef;
	}

	my $bare_nl_count = scalar grep { /^\x0a$|[^\x0d]\x0a$/} <$fh>;

	seek($fh,0,0);
	
        my $clear = $self->Clear;

        $self->Clear($clear)
                if $self->Count >= $clear and $clear > 0;

	my $length = ( -s $file ) + $bare_nl_count;

        my $string = "$count APPEND $folder {" . $length  . "}\x0d\x0a" ;

        $self->_record($count,[ $self->_next_index($count), "INPUT", "$string" ] );

	my $feedback = $self->_send_line("$string");

	unless ($feedback) {
		$self->LastError("Error sending '$string' to IMAP: $!\n");
		close $fh;
		return undef;
	}

	my ($code, $output) = ("","");	
	
	until ( $code ) {
		$output = $self->_read_line or close $fh, return undef;	
		foreach my $o (@$output) {
			$self->_record($count,$o);		# $o is already an array ref
                      ($code) = $o->[DATA] =~ /(^\+|^\d+\sNO|^\d+\sBAD)/i; 
                      if ($o->[DATA] =~ /^\*\s+BYE/) {
                              carp $o->[DATA] if $^W;
				$self->State(Unconnected);
				close $fh;
				return undef ;
                      } elsif ( $o->[DATA]=~ /^\d+\s+(NO|BAD)/i ) {
                              carp $o->[DATA] if $^W;
				close $fh;
				return undef;
			}
		}
	}	
	
	{ 	# Narrow scope
		# Slurp up headers: later we'll make this more efficient I guess
		local $/ = "\x0d\x0a\x0d\x0a"; 
		my $text = <$fh>;
		$text =~ s/\x0d?\x0a/\x0d\x0a/g;
		$self->_record($count,[ $self->_next_index($count), "INPUT", "{From file $file}" ] ) ;
		$feedback = $self->_send_line($text);

		unless ($feedback) {
			$self->LastError("Error sending append msg text to IMAP: $!\n");
			close $fh;
			return undef;
		}
		_debug $self, "control points to $$control\n" if ref($control) and $self->Debug;
		$/ = 	ref($control) ?  "\x0a" : $control ? $control : 	"\x0a";	
		while (defined($text = <$fh>)) {
			$text =~ s/\x0d?\x0a/\x0d\x0a/g;
			$self->_record(	$count,
					[ $self->_next_index($count), "INPUT", "{from $file}\x0d\x0a" ] 
			);
			$feedback = $self->_send_line($text,1);

			unless ($feedback) {
				$self->LastError("Error sending append msg text to IMAP: $!\n");
				close $fh;
				return undef;
			}
		}
		$feedback = $self->_send_line("\x0d\x0a");

		unless ($feedback) {
			$self->LastError("Error sending append msg text to IMAP: $!\n");
			close $fh;
			return undef;
		}
	} 

	# Now for the crucial test: Did the append work or not?
	($code, $output) = ("","");	

	my $uid = undef;	
	until ( $code ) {
		$output = $self->_read_line or return undef;	
		foreach my $o (@$output) {
			$self->_record($count,$o);		# $o is already an array ref
                      $self->_debug("append_file: Deciding if " . $o->[DATA] . " has the code.\n") 
				if $self->Debug;
                      ($code) = $o->[DATA]  =~ /^\d+\s(NO|BAD|OK)/i; 
			# try to grab new msg's uid from o/p
                      $o->[DATA]  =~ m#UID\s+\d+\s+(\d+)\]# and $uid = $1; 
                      if ($o->[DATA] =~ /^\*\s+BYE/) {
                              carp $o->[DATA] if $^W;
				$self->State(Unconnected);
				close $fh;
				return undef ;
                      } elsif ( $o->[DATA]=~ /^\d+\s+(NO|BAD)/i ) {
                              carp $o->[DATA] if $^W;
				close $fh;
				return undef;
			}
		}
	}	
	close $fh;

	if ($code !~ /^OK/i) {
		return undef;
	}


        return defined($uid) ? $uid : $self;
}


sub authenticate {

        my $self 	= shift;
        my $scheme 	= shift;
        my $response 	= shift;
	
	$scheme   ||= $self->Authmechanism;
	$response ||= $self->Authcallback;
        my $clear = $self->Clear;

        $self->Clear($clear)
                if $self->Count >= $clear and $clear > 0;

	my $count 	= $self->Count($self->Count+1);


        my $string = "$count AUTHENTICATE $scheme";

        $self->_record($count,[ $self->_next_index($self->Transaction), 
				"INPUT", "$string\x0d\x0a"] );

	my $feedback = $self->_send_line("$string");

	unless ($feedback) {
		$self->LastError("Error sending '$string' to IMAP: $!\n");
		return undef;
	}

	my ($code, $output);	
	
	until ($code) {
		$output = $self->_read_line or return undef;	
		foreach my $o (@$output) {
			$self->_record($count,$o);	# $o is a ref
			($code) = $o->[DATA] =~ /^\+(.*)$/ ;
			if ($o->[DATA] =~ /^\*\s+BYE/) {
				$self->State(Unconnected);
				return undef ;
			}
		}
	}	
	
        return undef if $code =~ /^BAD|^NO/ ;

        if ('CRAM-MD5' eq $scheme && ! $response) {
          if ($Mail::IMAPClient::_CRAM_MD5_ERR) {
            $self->LastError($Mail::IMAPClient::_CRAM_MD5_ERR);
            carp $Mail::IMAPClient::_CRAM_MD5_ERR if $^W;
          } else {
            $response = \&_cram_md5;
          }
        }

        $feedback = $self->_send_line($response->($code, $self));

        unless ($feedback) {
                $self->LastError("Error sending append msg text to IMAP: $!\n");
                return undef;
        }

	$code = ""; 	# clear code
        until ($code) {
                $output = $self->_read_line or return undef;
		foreach my $o (@$output) {
                	$self->_record($count,$o);	# $o is a ref
			if ( ($code) = $o->[DATA] =~ /^\+ (.*)$/ ) {
				$feedback = $self->_send_line($response->($code,$self));
				unless ($feedback) {
					$self->LastError("Error sending append msg text to IMAP: $!\n");
					return undef;
				}
				$code = "" ;		# Clear code; we're still not finished
			} else {
				$o->[DATA] =~ /^$count (OK|NO|BAD)/ and $code = $1;
				if ($o->[DATA] =~ /^\*\s+BYE/) {
					$self->State(Unconnected);
					return undef ;
				}
			}
		}
        }

        $code =~ /^OK/ and $self->State(Authenticated) ;
        return $code =~ /^OK/ ? $self : undef ;

}

# UIDPLUS response from a copy: [COPYUID (uidvalidity) (origuid) (newuid)]
sub copy {

	my($self, $target, @msgs) = @_;

	$target = $self->Massage($target);
	if ( $self->Ranges ) {
		@msgs = ($self->Range(@msgs));
	} else {
		@msgs   = sort { $a <=> $b } map { ref($_)? @$_ : split(',',$_) } @msgs;
	}

	$self->_imap_command( 
	  ( 	$self->Uid ? "UID " : "" ) . 
		"COPY " . 
		( $self->Ranges ? $self->Range(@msgs) : 
		join(',',map { ref($_)? @$_ : $_ } @msgs)) . 
		" $target"
	) 			or return undef		;
	my @results =  $self->History($self->Count) 	;
	
	my @uids;

	for my $r (@results) {
			
               chomp $r;
               $r =~ s/\r$//;
               $r =~ s/^.*\[COPYUID\s+\d+\s+[\d:,]+\s+([\d:,]+)\].*/$1/ or next;
               push @uids, ( $r =~ /(\d+):(\d+)/ ? $1 ... $2 : split(/,/,$r) ) ;

	}

	return scalar(@uids) ? join(",",@uids) : $self;
}

sub move {

	my($self, $target, @msgs) = @_;

	$self->create($target) and $self->subscribe($target) 
		unless $self->exists($target);
	
	my $uids = $self->copy($target, map { ref($_) =~ /ARRAY/ ? @{$_} : $_ } @msgs) 
		or return undef;

	$self->delete_message(@msgs) or carp $self->LastError;
	
	return $uids;
}

sub set_flag {
	my($self, $flag, @msgs) = @_;
	if ( ref($msgs[0]) =~ /ARRAY/ ) { @msgs = @{$msgs[0]} };
	$flag =~ /^\\/ or $flag = "\\" . $flag 
		if $flag =~ /^(Answered|Flagged|Deleted|Seen|Draft)$/i;
	if ( $self->Ranges ) {
		$self->store( $self->Range(@msgs), "+FLAGS.SILENT (" . $flag . ")" );
	} else {
		$self->store( join(",",@msgs), "+FLAGS.SILENT (" . $flag . ")" );
	}
}

sub see {
	my($self, @msgs) = @_;
	if ( ref($msgs[0]) =~ /ARRAY/ ) { @msgs = @{$msgs[0]} };
	$self->set_flag('\\Seen', @msgs);
}

sub mark {
	my($self, @msgs) = @_;
	if ( ref($msgs[0]) =~ /ARRAY/ ) { @msgs = @{$msgs[0]} };
	$self->set_flag('\\Flagged', @msgs);
}

sub unmark {
	my($self, @msgs) = @_;
	if ( ref($msgs[0]) =~ /ARRAY/ ) { @msgs = @{$msgs[0]} };
	$self->unset_flag('\\Flagged', @msgs);
}

sub unset_flag {
	my($self, $flag, @msgs) = @_;
	if ( ref($msgs[0]) =~ /ARRAY/ ) { @msgs = @{$msgs[0]} };
	$flag =~ /^\\/ or $flag = "\\" . $flag 
		if $flag =~ /^(Answered|Flagged|Deleted|Seen|Draft)$/i;
	$self->store( join(",",@msgs), "-FLAGS.SILENT (" . $flag . ")" );
}

sub deny_seeing {
	my($self, @msgs) = @_;
	if ( ref($msgs[0]) =~ /ARRAY/ ) { @msgs = @{$msgs[0]} };
	$self->unset_flag('\\Seen', @msgs);
}

sub size {

	my ($self,$msg) = @_;
	# return undef unless fetch is successful
	my @data = $self->fetch($msg,"(RFC822.SIZE)");
	return undef unless defined($data[0]);
	my($size) = grep(/RFC822\.SIZE/,@data);

	$size =~ /RFC822\.SIZE\s+(\d+)/;
	
	return $1;
}

sub getquotaroot {
	my $self = shift;
	my $what = shift;
	$what = ( $what ? $self->Massage($what) : "INBOX" ) ;
	$self->_imap_command("getquotaroot $what") or return undef;
	return $self->Results;
}

sub getquota {
	my $self = shift;
	my $what = shift;
	$what = ( $what ? $self->Massage($what) : "user/$self->{User}" ) ;
	$self->_imap_command("getquota $what") or return undef;
	return $self->Results;
}

sub quota 	{
	my $self = shift;
	my ($what) = shift||"INBOX";
	$self->_imap_command("getquota $what")||$self->getquotaroot("$what");
	return (	map { s/.*STORAGE\s+\d+\s+(\d+).*\n$/$1/ ? $_ : () } $self->Results
	)[0] ;
}

sub quota_usage 	{
	my $self = shift;
	my ($what) = shift||"INBOX";
	$self->_imap_command("getquota $what")||$self->getquotaroot("$what");
	return (	map { s/.*STORAGE\s+(\d+)\s+\d+.*\n$/$1/ ? $_ : () } $self->Results
	)[0] ;
}
sub Quote {
	my($class,$arg) = @_;
	return $class->Massage($arg,NonFolderArg);
}

sub Massage {
	my $self= shift;
	my $arg = shift;
	my $notFolder = shift;
	return unless $arg;
	my $escaped_arg = $arg; $escaped_arg =~ s/"/\\"/g;
	$arg 	= substr($arg,1,length($arg)-2) if $arg =~ /^".*"$/
                and ! ( $notFolder or $self->STATUS(qq("$escaped_arg"),"(MESSAGES)"));

	if ($arg =~ /["\\]/) {
		$arg = "{" . length($arg) . "}\x0d\x0a$arg" ;
	} elsif ($arg =~ /\s|[{}()]/) {
		$arg = qq("${arg}") unless $arg =~ /^"/;
	} 

	return $arg;
}

sub unseen_count {

	my ($self, $folder) = (shift, shift);
	$folder ||= $self->Folder;
	$self->status($folder, 'UNSEEN') or return undef;

	chomp(	my $r = ( grep 
			  { s/\*\s+STATUS\s+.*\(UNSEEN\s+(\d+)\s*\)/$1/ }
			  $self->History($self->Transaction)
			)[0]
	);

	$r =~ s/\D//g;
	return $r;
}



# Status Routines:


sub Status            { $_[0]->State                           ;       }
sub IsUnconnected     { ($_[0]->State == Unconnected)  ? 1 : 0 ;       }
sub IsConnected       { ($_[0]->State >= Connected)    ? 1 : 0 ;       }
sub IsAuthenticated   { ($_[0]->State >= Authenticated)? 1 : 0 ;       }
sub IsSelected        { ($_[0]->State == Selected)     ? 1 : 0 ;       }               


# The following private methods all work on an output line array.
# _data returns the data portion of an output array:
sub _data {   defined $_[1] and ref $_[1] and defined $_[1]->[TYPE] or return undef; $_[1]->[DATA]; }

# _index returns the index portion of an output array:
sub _index {  defined $_[1] and ref $_[1] and defined $_[1]->[TYPE] or return undef; $_[1]->[INDEX]; }

# _type returns the type portion of an output array:
sub _type {  defined $_[1] and ref $_[1] and defined $_[1]->[TYPE] or return undef; $_[1]->[TYPE]; }

# _is_literal returns true if this is a literal:
sub _is_literal { defined $_[1] and ref $_[1] and defined $_[1]->[TYPE] and $_[1]->[TYPE] eq "LITERAL" };

# _is_output_or_literal returns true if this is an 
#  	output line (or the literal part of one):
sub _is_output_or_literal { 
              defined $_[1] and ref $_[1] and defined $_[1]->[TYPE] and 
			($_[1]->[TYPE] eq "OUTPUT" || $_[1]->[TYPE] eq "LITERAL") 
};

# _is_output returns true if this is an output line:
sub _is_output { defined $_[1] and ref $_[1] and defined $_[1]->[TYPE] and $_[1]->[TYPE] eq "OUTPUT" };

# _is_input returns true if this is an input line:
sub _is_input { defined $_[1] and ref $_[1] and defined $_[1]->[TYPE] and $_[1]->[TYPE] eq "INPUT" };

# _next_index returns next_index for a transaction; may legitimately return 0 when successful.
sub _next_index { 
      defined(scalar(@{$_[0]->{'History'}{$_[1]||$_[0]->Transaction}}))       ? 
		scalar(@{$_[0]->{'History'}{$_[1]||$_[0]->Transaction}}) 		: 0 
};

sub _cram_md5 {
  my ($code, $client) = @_;
  my $hmac = Digest::HMAC_MD5::hmac_md5_hex(MIME::Base64::decode($code),
                                            $client->Password());
  return MIME::Base64::encode($client->User() . " $hmac");
}



sub Range {
	require "Mail/IMAPClient/MessageSet.pm";
	my $self = shift;
	my $targ = $_[0];
	#print "Arg is ",ref($targ),"\n";
	if (@_ == 1 and ref($targ) =~ /Mail::IMAPClient::MessageSet/ ) {
		return $targ;
	}
	my $range = Mail::IMAPClient::MessageSet->new(@_);
	#print "Returning $range :",ref($range)," == $range\n";
	return $range;
}

my $not_void = 1;

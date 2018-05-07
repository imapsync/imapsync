package Calltree;
use B::Utils qw(all_roots walkoptree_simple);

my %legal_options 
  = (INCLUDE_PACKAGES => undef,
     EXCLUDE_PACKAGES => [__PACKAGE__],
     CALLBACK =>  \&print_report,
     CALLBACK_DATA => undef,
    );

our %OPT;

sub import {
  my ($class, %opts) = @_;
  my @BAD;
  for my $k (keys %opts) {
    if (exists $legal_option{uc $k}) {
      $OPT{uc $k} = $opts{$k};
    } else {
      push @BAD, $k ;
    }
  }
  if (@BAD) {
    my $options = @BAD == 1 ? 'option' : 'options';
    require Carp;
    Carp::croak( "$class: unrecognized $options @BAD" ) ;
  }
  for my $k (keys %legal_options) {
    $OPT{$k} = $legal_options{$k} unless defined $OPT{$k};
  }
}

sub array_to_hash {
  my %h;
  for (@_) { $h{$_} = 1 }
  \%h;
}

sub adjust_options {
  my $opt = shift;
  if (! defined $opt->{INCLUDE_PACKAGES}) {
    $opt->{INCLUDE_PACKAGES} = array_to_hash(walk_stashes(), 'main');
  }

  for my $k (qw(INCLUDE_PACKAGES EXCLUDE_PACKAGES)) {
    if (! ref $opt->{$k}) {
      $opt->{$k} = array_to_hash(split /,\s*/, $opt->{$k});
    } elsif (ref $opt->{$k} eq 'ARRAY') {
      $opt->{$k} = array_to_hash(@{$opt->{$k}});
    }
  }
}

sub walk_stashes {
  my $top = shift || '';
  return if $top eq '::main';
#  print "* $top\n";
  my @packages = $top;
  while (my $name = each %{"$top\::"}) {
    next unless $name =~ s/::$//;
    push @packages, walk_stashes("$top\::$name");
  }
#  print "=> @packages\n";
  map /^(?:::)?(.*)/, @packages;
}

sub trim_stashname {
  my $sn = shift;
  $sn =~ s/::$//;
  return $sn;
}

sub INIT {
  adjust_options(\%OPT);

  my %root = all_roots();
  my %CALLS;
  while (my ($name, $root) = each %root) {
    my ($pkg) = $name =~ /(.*)::/; 
    next unless $OPT{INCLUDE_PACKAGES}{$pkg};
    next if $OPT{EXCLUDE_PACKAGES}{$pkg};
    my @CALLS;
    $CALLS{$name} = {};
    walkoptree_simple($root, \&find_subcall, \@CALLS);
    for my $call (@CALLS) {
      $CALLS{$name}{$call} = 1;
    }
  } 
  $OPT{CALLBACK}->(\%CALLS, $OPT{CALLBACK_DATA});
  exit;
}

sub find_subcall {
  my ($op, $dest) = @_;
  if ($op->name eq 'gv' && $op->next && $op->next->name eq 'entersub') {
    my $cur_gv = $op->gv;
    push @$dest, join '::', $cur_gv->STASH->NAME, $cur_gv->NAME; 
  }
}

sub print_report {
  my $C = shift;
  for my $caller (sort keys %$C) {
    print "\n$caller: \n";
    for my $callee (sort keys %{$C->{$caller}}) {
      print "  $callee\n";
    }
  }
}

"Cogito, ergo sum";

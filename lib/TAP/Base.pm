package TAP::Base;

use strict;
use vars qw($VERSION);

=head1 NAME

TAP::Base - Base class that provides common functionality to L<TAP::Parser> and L<TAP::Harness>

=head1 VERSION

Version 0.54

=cut

$VERSION = '0.54';

=head1 SYNOPSIS

    package TAP::Whatever;

    use TAP::Base;
    
    use vars qw($VERSION @ISA);
    @ISA = qw(TAP::Base);

    # ... later ...
    
    my $thing = TAP::Whatever->new();
    
    $thing->callback( event => sub {
        # do something interesting
    } );

=head1 DESCRIPTION

C<TAP::Base> provides callback management.

=head1 METHODS

=head2 Class Methods

=head3 C<new>

=cut

sub new {
    my ( $class, $arg_for ) = @_;

    my $self = bless {}, $class;
    return $self->_initialize($arg_for);
}

sub _initialize {
    my ( $self, $arg_for, $ok_callback ) = @_;

    my %ok_map = map { $_ => 1 } @$ok_callback;

    $self->{ok_callbacks} = \%ok_map;

    if ( exists $arg_for->{callbacks} ) {
        while ( my ( $event, $callback ) = each %{ $arg_for->{callbacks} } ) {
            $self->callback( $event, $callback );
        }
    }

    return $self;
}

=head3 C<callback>

Install a callback for a named event.

=cut

sub callback {
    my ( $self, $event, $callback ) = @_;

    my %ok_map = %{ $self->{ok_callbacks} };

    $self->_croak('No callbacks may be installed')
      unless %ok_map;

    $self->_croak( "Callback $event is not supported. Valid callbacks are "
          . join( ', ', sort keys %ok_map ) )
      unless exists $ok_map{$event};

    $self->{code_for}{$event} = $callback;
}

sub _callback_for {
    my ( $self, $event ) = @_;
    return $self->{code_for}{$event};
}

sub _make_callback {
    my $self  = shift;
    my $event = shift;

    my $cb = $self->_callback_for($event);
    return unless defined $cb;
    return $cb->(@_);
}

sub _croak {
    my ( $self, $message ) = @_;
    require Carp;
    Carp::croak($message);
}

1;

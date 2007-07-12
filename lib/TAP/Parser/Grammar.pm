package TAP::Parser::Grammar;

use strict;
use vars qw($VERSION);
use Carp;

use TAP::Parser::Result;
use TAP::Parser::YAMLish::Reader;

=head1 NAME

TAP::Parser::Grammar - A grammar for the Test Anything Protocol.

=head1 VERSION

Version 0.52

=cut

$VERSION = '0.52';

=head1 DESCRIPTION

C<TAP::Parser::Grammar> tokenizes lines from a TAP stream and constructs
L<TAP::Parser::Result> subclasses to represent the tokens.

Do not attempt to use this class directly.  It won't make sense.  It's mainly
here to ensure that we will be able to have pluggable grammars when TAP is
expanded at some future date (plus, this stuff was really cluttering the
parser).

Note that currently all methods are class methods.  It's intended that this
will eventually support C<TAP 2.0> and beyond which will necessitate actual
instance data, but for now, we don't need this.  Hence, the curious decision
to use a class where one doesn't apparently need one.

=cut

##############################################################################

=head2 Class Methods


=head3 C<new>

  my $grammar = TAP::Grammar->new($stream);

Returns TAP grammar object that will parse the specified stream.

=cut

sub new {
    my ( $class, $stream ) = @_;
    my $self = bless { stream => $stream }, $class;
    $self->set_version( 12 );
    return $self;
}

# XXX the 'not' and 'ok' might be on separate lines in VMS ...
my $ok  = qr/(?:not )?ok\b/;
my $num = qr/\d+/;

my %v12 = (
    version => {
        syntax  => qr/^TAP\s+version\s+(\d+)\s*\z/i,
        handler => sub {
            my ( $self, $line ) = @_;
            local *__ANON__ = '__ANON__version_token_handler';
            my $version = $1;
            return $self->_make_version_token( $line, $version, );
          }
    },
    plan => {
        syntax  => qr/^1\.\.(\d+)(?:\s*#\s*SKIP\b(.*))?\z/i,
        handler => sub {
            my ( $self, $line ) = @_;
            local *__ANON__ = '__ANON__plan_token_handler';
            my $tests_planned = $1;
            my $explanation   = $2;
            my $skip
              = ( 0 == $tests_planned || defined $explanation )
              ? 'SKIP'
              : '';
            $explanation = '' unless defined $explanation;
            return $self->_make_plan_token( $line, $tests_planned, $skip,
                _trim( $explanation ),
            );
        },
    },
    test => {
        syntax  => qr/^($ok) \s* ($num)? \s* (.*) \z/x,
        handler => sub {
            my ( $self, $line ) = @_;
            local *__ANON__ = '__ANON__test_token_handler';
            my ( $ok, $num, $desc ) = ( $1, $2, $3 );
            my ( $dir, $explanation ) = ( '', '' );
            if ( $desc
                =~ m/^ ( [^\\\#]* (?: \\. [^\\\#]* )* ) 
                       \# \s* (SKIP|TODO) \b \s* (.*) $/ix
              ) {
                ( $desc, $dir, $explanation ) = ( $1, $2, $3 );
            }
            return $self->_make_test_token( $line, $ok, $num, _trim( $desc ),
                uc $dir, $explanation );
        },
    },
    comment => {
        syntax  => qr/^#(.*)/,
        handler => sub {
            my ( $self, $line ) = @_;
            local *__ANON__ = '__ANON__comment_token_handler';
            my $comment = $1;
            return $self->_make_comment_token( $line, $comment );
        },
    },
    bailout => {
        syntax  => qr/^Bail out!\s*(.*)/,
        handler => sub {
            my ( $self, $line ) = @_;
            local *__ANON__ = '__ANON__bailout_token_handler';
            my $explanation = $1;
            return $self->_make_bailout_token( $line, _trim( $explanation ) );
        },
    },
);

my %v13 = (
    %v12,
    yaml => {
        syntax  => qr/^ (\s+) (---.*) $/x,
        handler => sub {
            my ( $self, $line ) = @_;
            local *__ANON__ = '__ANON__yaml_token_handler';
            my ( $pad, $marker ) = ( $1, $2 );
            return $self->_make_yaml_token( $pad, $marker );
        },
    },
);

my %token_for = (
    '12' => \%v12,
    '13' => \%v13,
);

##############################################################################

=head3 C<set_version>

  $grammar->set_version(13);
  
Tell the grammar which TAP syntax version to support. The lowest
supported version is 12. Although 'TAP version' isn't valid version 12
syntax it is accepted so that higher version numbers may be parsed.

=cut

sub set_version {
    my $self    = shift;
    my $version = shift;

    if ( my $tokens = $token_for{$version} ) {
        $self->{tokens} = $tokens;
    }
    else {
        croak "Unsupported syntax version: $version";
    }
}

##############################################################################

=head3 C<tokenize>

  my $token = $grammar->tokenize;

This method will return a C<TAP::Parser::Result> object representing the
current line of TAP.

=cut

sub tokenize {
    my $self = shift;

    my $stream = $self->{stream};
    my $line   = $stream->next;
    return unless defined $line;

    my $token;

    foreach my $token_data ( values %{ $self->{tokens} } ) {
        if ( $line =~ $token_data->{syntax} ) {
            my $handler = $token_data->{handler};
            $token = $self->$handler( $line );
            last;
        }
    }
    $token ||= $self->_make_unknown_token( $line );
    return defined $token ? TAP::Parser::Result->new( $token ) : ();
}

##############################################################################

=head2 Class methods

=head3 C<token_types>

  my @types = $grammar->token_types;

Returns the different types of tokens which this grammar can parse.

=cut

sub token_types {
    my $self = shift;
    return keys %{ $self->{tokens} };
}

##############################################################################

=head3 C<syntax_for>

  my $syntax = $grammar->syntax_for($token_type);

Returns a pre-compiled regular expression which will match a chunk of TAP
corresponding to the token type.  For example (not that you should really pay
attention to this, C<< $grammar->syntax_for('comment') >> will return
C<< qr/^#(.*)/ >>.

=cut

sub syntax_for {
    my ( $self, $type ) = @_;
    return $self->{tokens}->{$type}->{syntax};
}

##############################################################################

=head3 C<handler_for>

  my $handler = $grammar->handler_for($token_type);

Returns a code reference which, when passed an appropriate line of TAP,
returns the lexed token corresponding to that line.  As a result, the basic
TAP parsing loop looks similar to the following:

 my @tokens;
 my $grammar = TAP::Grammar->new;
 LINE: while ( defined( my $line = $parser->_next_chunk_of_tap ) ) {
     foreach my $type ( $grammar->token_types ) {
         my $syntax  = $grammar->syntax_for($type);
         if ( $line =~ $syntax ) {
             my $handler = $grammar->handler_for($type);
             push @tokens => $grammar->$handler($line);
             next LINE;
         }
     }
     push @tokens => $grammar->_make_unknown_token($line);
 }

=cut

sub handler_for {
    my ( $self, $type ) = @_;
    return $self->{tokens}->{$type}->{handler};
}

sub _make_version_token {
    my ( $self, $line, $version ) = @_;
    return {
        type    => 'version',
        raw     => $line,
        version => $version,
    };
}

sub _make_plan_token {
    my ( $self, $line, $tests_planned, $skip, $explanation ) = @_;
    if ( 0 == $tests_planned ) {
        $skip ||= 'SKIP';
    }
    if ( $skip && 0 != $tests_planned ) {
        warn "Specified SKIP directive in plan but more than 0 tests ($line)\n";
    }
    return {
        type          => 'plan',
        raw           => $line,
        tests_planned => $tests_planned,
        directive     => $skip,
        explanation   => $explanation,
    };
}

sub _make_test_token {
    my ( $self, $line, $ok, $num, $desc, $dir, $explanation ) = @_;
    my %test = (
        ok          => $ok,
        test_num    => $num,
        description => _trim( $desc ),
        directive   => uc( $dir ),
        explanation => _trim( $explanation ),
        raw         => $line,
        type        => 'test',
    );
    return \%test;
}

sub _make_unknown_token {
    my ( $self, $line ) = @_;
    return {
        raw  => $line,
        type => 'unknown',
    };
}

sub _make_comment_token {
    my ( $self, $line, $comment ) = @_;
    return {
        type    => 'comment',
        raw     => $line,
        comment => _trim( $1 )
    };
}

sub _make_bailout_token {
    my ( $self, $line, $explanation ) = @_;
    return {
        type    => 'bailout',
        raw     => $line,
        bailout => _trim( $1 )
    };
}

sub _make_yaml_token {
    my ( $self, $pad, $marker ) = @_;

    my $yaml = TAP::Parser::YAMLish::Reader->new;

    my $stream = $self->{stream};

    # Construct a reader that reads from our input stripping leading
    # spaces from each line.
    my $leader = length( $pad );
    my $strip  = qr{ ^ (\s{$leader}) (.*) $ }x;
    my @extra  = ( $marker );
    my $reader = sub {
        return shift @extra if @extra;
        my $line = $stream->next;
        return $2 if $line =~ $strip;
        return;
    };

    my $data = $yaml->read( $reader );

    return {
        type => 'yaml',
        raw  => $yaml->get_raw,
        data => $data
    };
}

sub _trim {
    my $data = shift || '';
    $data =~ s/^\s+//;
    $data =~ s/\s+$//;
    return $data;
}

=head1 TAP GRAMMAR

B<NOTE:>  This grammar is slightly out of date.  There's still some discussion
about it and a new one will be provided when we have things better defined.

The C<TAP::Parser> does not use a formal grammar because TAP is essentially a
stream-based protocol.  In fact, it's quite legal to have an infinite stream.
For the same reason that we don't apply regexes to streams, we're not using a
formal grammar here.  Instead, we parse the TAP in lines.

For purposes for forward compatability, any result which does not match the
following grammar is currently referred to as
L<TAP::Parser::Result::Unknown>.  It is I<not> a parse error.

A formal grammar would look similar to the following:

 (* 
     For the time being, I'm cheating on the EBNF by allowing 
     certain terms to be defined by POSIX character classes by
     using the following syntax:
 
       digit ::= [:digit:]
 
     As far as I am aware, that's not valid EBNF.  Sue me.  I
     didn't know how to write "char" otherwise (Unicode issues).  
     Suggestions welcome.
 *)
 
 tap            ::= version? { comment | unknown } leading_plan lines 
                    | 
                    lines trailing_plan {comment}
 
 version        ::= 'TAP version ' positiveInteger {positiveInteger} "\n"

 leading_plan   ::= plan skip_directive? "\n"

 trailing_plan  ::= plan "\n"

 plan           ::= '1..' nonNegativeInteger
 
 lines          ::= line {line}

 line           ::= (comment | test | unknown | bailout ) "\n"
 
 test           ::= status positiveInteger? description? directive?
 
 status         ::= 'not '? 'ok '
 
 description    ::= (character - (digit | '#')) {character - '#'}
 
 directive      ::= todo_directive | skip_directive

 todo_directive ::= hash_mark 'TODO' ' ' {character}

 skip_directive ::= hash_mark 'SKIP' ' ' {character}

 comment        ::= hash_mark {character}

 hash_mark      ::= '#' {' '}

 bailout        ::= 'Bail out!' {character}

 unknown        ::= { (character - "\n") }

 (* POSIX character classes and other terminals *)
 
 digit              ::= [:digit:]
 character          ::= ([:print:] - "\n")
 positiveInteger    ::= ( digit - '0' ) {digit}
 nonNegativeInteger ::= digit {digit}
 

=cut

1;

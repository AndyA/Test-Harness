#!/usr/bin/perl -w

use strict;
use lib 't/lib';

use Test::More;
use IO::Capture;

use TAP::Harness;

my $HARNESS = 'TAP::Harness';

plan tests => 98;

# note that this test will always pass when run through 'prove'
ok $ENV{HARNESS_ACTIVE},  'HARNESS_ACTIVE env variable should be set';
ok $ENV{HARNESS_VERSION}, 'HARNESS_VERSION env variable should be set';

#### For color tests ####

package Colorizer;

sub new { bless {}, shift }
sub can_color {1}

sub set_color {
    my ( $self, $output, $color ) = @_;
    $output->("[[$color]]");
}

package main;

sub colorize {
    my $harness = shift;
    $harness->formatter->_colorizer( Colorizer->new );
}

can_ok $HARNESS, 'new';

eval { $HARNESS->new( { no_such_key => 1 } ) };
like $@, qr/\QUnknown arguments to TAP::Harness::new (no_such_key)/,
  '... and calling it with bad keys should fail';

eval { $HARNESS->new( { lib => 'aint_no_such_lib' } ) };
ok my $error = $@,
  '... and calling it with a non-existent lib should fail';
like $error, qr/^\QNo such lib (aint_no_such_lib)/,
  '... with an appropriate error message';

eval { $HARNESS->new( { lib => [qw/bad_lib_1 bad_lib_2/] } ) };
ok $error = $@, '... and calling it with non-existent libs should fail';
like $error, qr/^\QNo such libs (bad_lib_1 bad_lib_2)/,
  '... with an appropriate error message';

ok my $harness = $HARNESS->new,
  'Calling new() without arguments should succeed';

foreach my $test_args ( get_arg_sets() ) {
    my %args = %$test_args;
    foreach my $key ( sort keys %args ) {
        $args{$key} = $args{$key}{in};
    }
    ok my $harness = $HARNESS->new( {%args} ),
      'Calling new() with valid arguments should succeed';
    isa_ok $harness, $HARNESS, '... and the object it returns';

    while ( my ( $property, $test ) = each %$test_args ) {
        my $value = $test->{out};
        can_ok $harness, $property;
        is_deeply scalar $harness->$property(), $value,
          $test->{test_name};
    }
}

{
    my @output;
    local $^W;
    local *TAP::Formatter::Console::_should_show_count = sub {0};
    local *TAP::Formatter::Console::_output = sub {
        my $self = shift;
        push @output => grep { $_ ne '' }
          map {
            local $_ = $_;
            chomp;
            trim($_)
          } @_;
    };
    my $harness            = TAP::Harness->new( { verbose      => 1 } );
    my $harness_whisper    = TAP::Harness->new( { quiet        => 1 } );
    my $harness_mute       = TAP::Harness->new( { really_quiet => 1 } );
    my $harness_directives = TAP::Harness->new( { directives   => 1 } );
    my $harness_failures   = TAP::Harness->new( { failures     => 1 } );

    colorize($harness);

    can_ok $harness, 'runtests';

    # normal tests in verbose mode

    ok my $aggregate = _runtests( $harness, 't/source_tests/harness' ),
      '... runtests returns the aggregate';

    isa_ok $aggregate, 'TAP::Parser::Aggregator';

    chomp(@output);

    my @expected = (
        't/source_tests/harness....',
        '1..1',
        '[[reset]]',
        'ok 1 - this is a test',
        '[[reset]]',
        'ok',
        'All tests successful.',
    );
    my $status           = pop @output;
    my $expected_status  = qr{^Result: PASS$};
    my $summary          = pop @output;
    my $expected_summary = qr{^Files=1, Tests=1,  \d+ wallclock secs};

    is_deeply \@output, \@expected,
      '... and the output should be correct';
    like $status, $expected_status,
      '... and the status line should be correct';
    like $summary, $expected_summary,
      '... and the report summary should look correct';

    # normal tests in quiet mode

    @output = ();
    _runtests( $harness_whisper, 't/source_tests/harness' );

    chomp(@output);
    @expected = (
        't/source_tests/harness....',
        'ok',
        'All tests successful.',
    );

    $status           = pop @output;
    $expected_status  = qr{^Result: PASS$};
    $summary          = pop @output;
    $expected_summary = qr/^Files=1, Tests=1,  \d+ wallclock secs/;

    is_deeply \@output, \@expected,
      '... and the output should be correct';
    like $status, $expected_status,
      '... and the status line should be correct';
    like $summary, $expected_summary,
      '... and the report summary should look correct';

    # normal tests in really_quiet mode

    @output = ();
    _runtests( $harness_mute, 't/source_tests/harness' );

    chomp(@output);
    @expected = (
        'All tests successful.',
    );

    $status           = pop @output;
    $expected_status  = qr{^Result: PASS$};
    $summary          = pop @output;
    $expected_summary = qr/^Files=1, Tests=1,  \d+ wallclock secs/;

    is_deeply \@output, \@expected,
      '... and the output should be correct';
    like $status, $expected_status,
      '... and the status line should be correct';
    like $summary, $expected_summary,
      '... and the report summary should look correct';

    # normal tests with failures

    @output = ();
    _runtests( $harness, 't/source_tests/harness_failure' );

    $status  = pop @output;
    $summary = pop @output;

    like $status, qr{^Result: FAIL$},
      '... and the status line should be correct';

    my @summary = @output[ 10 .. $#output ];
    @output = @output[ 0 .. 9 ];

    @expected = (
        't/source_tests/harness_failure....',
        '1..2',
        '[[reset]]',
        'ok 1 - this is a test',
        '[[reset]]',
        '[[red]]',
        'not ok 2 - this is another test',
        '[[reset]]',
        '[[red]]',
        'Failed 1/2 subtests',
    );

    is_deeply \@output, \@expected,
      '... and failing test output should be correct';

    my @expected_summary = (
        '[[reset]]',
        'Test Summary Report',
        '-------------------',
        '[[red]]',
        't/source_tests/harness_failure (Wstat: 0 Tests: 2 Failed: 1)',
        '[[reset]]',
        '[[red]]',
        'Failed test number(s):',
        '[[reset]]',
        '[[red]]',
        '2',
        '[[reset]]',
    );

    is_deeply \@summary, \@expected_summary,
      '... and the failure summary should also be correct';

    # quiet tests with failures

    @output = ();
    _runtests( $harness_whisper, 't/source_tests/harness_failure' );

    $status   = pop @output;
    $summary  = pop @output;
    @expected = (
        't/source_tests/harness_failure....',
        'Failed 1/2 subtests',
        'Test Summary Report',
        '-------------------',
        't/source_tests/harness_failure (Wstat: 0 Tests: 2 Failed: 1)',
        'Failed test number(s):',
        '2',
    );

    like $status, qr{^Result: FAIL$},
      '... and the status line should be correct';

    is_deeply \@output, \@expected,
      '... and failing test output should be correct';

    # really quiet tests with failures

    @output = ();
    _runtests( $harness_mute, 't/source_tests/harness_failure' );

    $status   = pop @output;
    $summary  = pop @output;
    @expected = (
        'Test Summary Report',
        '-------------------',
        't/source_tests/harness_failure (Wstat: 0 Tests: 2 Failed: 1)',
        'Failed test number(s):',
        '2',
    );

    like $status, qr{^Result: FAIL$},
      '... and the status line should be correct';

    is_deeply \@output, \@expected,
      '... and failing test output should be correct';

    # only show directives

    @output = ();
    _runtests( $harness_directives,
        't/source_tests/harness_directives' );

    chomp(@output);

    @expected = (
        't/source_tests/harness_directives....',
        'not ok 2 - we have a something # TODO some output',
        "ok 3 houston, we don't have liftoff # SKIP no funding",
        'ok',
        'All tests successful.',

     # ~TODO {{{ this should be an option
     #'Test Summary Report',
     #'-------------------',
     #'t/source_tests/harness_directives (Wstat: 0 Tests: 3 Failed: 0)',
     #'Tests skipped:',
     #'3',
     # }}}
    );

    $status           = pop @output;
    $summary          = pop @output;
    $expected_summary = qr/^Files=1, Tests=3,  \d+ wallclock secs/;

    is_deeply \@output, \@expected,
      '... and the output should be correct';
    like $summary, $expected_summary,
      '... and the report summary should look correct';

    like $status, qr{^Result: PASS$},
      '... and the status line should be correct';

    # normal tests with bad tap

    # install callback handler
    my $parser;
    my $callback_count = 0;

    my @callback_log = ();

    for my $evt (qw(made_parser before_runtests after_runtests)) {
        $harness->callback(
            $evt => sub {
                push @callback_log, $evt;
            }
        );
    }

    $harness->callback(
        made_parser => sub {
            $parser = shift;
            $callback_count++;
        }
    );

    @output = ();
    _runtests( $harness, 't/source_tests/harness_badtap' );
    chomp(@output);

    @output   = map { trim($_) } @output;
    $status   = pop @output;
    @summary  = @output[ 12 .. ( $#output - 1 ) ];
    @output   = @output[ 0 .. 11 ];
    @expected = (
        't/source_tests/harness_badtap....',
        '1..2',
        '[[reset]]',
        'ok 1 - this is a test',
        '[[reset]]',
        '[[red]]',
        'not ok 2 - this is another test',
        '[[reset]]',
        '1..2',
        '[[reset]]',
        '[[red]]',
        'Failed 1/2 subtests',
    );
    is_deeply \@output, \@expected,
      '... and failing test output should be correct';
    like $status, qr{^Result: FAIL$},
      '... and the status line should be correct';
    @expected_summary = (
        '[[reset]]',
        'Test Summary Report',
        '-------------------',
        '[[red]]',
        't/source_tests/harness_badtap (Wstat: 0 Tests: 2 Failed: 1)',
        '[[reset]]',
        '[[red]]',
        'Failed test number(s):',
        '[[reset]]',
        '[[red]]',
        '2',
        '[[reset]]',
        '[[red]]',
        'Parse errors: More than one plan found in TAP output',
        '[[reset]]',
    );
    is_deeply \@summary, \@expected_summary,
      '... and the badtap summary should also be correct';

    cmp_ok( $callback_count, '==', 1, 'callback called once' );
    is_deeply(
        \@callback_log,
        [ 'before_runtests', 'made_parser', 'after_runtests' ],
        'callback log matches'
    );
    isa_ok $parser, 'TAP::Parser';

    # coverage testing for _should_show_failures
    # only show failures

    @output = ();
    _runtests( $harness_failures, 't/source_tests/harness_failure' );

    chomp(@output);

    @expected = (
        't/source_tests/harness_failure....',
        'not ok 2 - this is another test',
        'Failed 1/2 subtests',
        'Test Summary Report',
        '-------------------',
        't/source_tests/harness_failure (Wstat: 0 Tests: 2 Failed: 1)',
        'Failed test number(s):',
        '2',
    );

    $status  = pop @output;
    $summary = pop @output;

    like $status, qr{^Result: FAIL$},
      '... and the status line should be correct';
    $expected_summary = qr/^Files=1, Tests=2,  \d+ wallclock secs/;
    is_deeply \@output, \@expected,
      '... and the output should be correct';

    # check the status output for no tests

    @output = ();
    _runtests( $harness_failures, 't/sample-tests/no_output' );

    chomp(@output);

    @expected = (
        't/sample-tests/no_output....',
        'No subtests run',
        'Test Summary Report',
        '-------------------',
        't/sample-tests/no_output (Wstat: 0 Tests: 0 Failed: 0)',
        'Parse errors: No plan found in TAP output',
    );

    $status  = pop @output;
    $summary = pop @output;

    like $status, qr{^Result: NOTESTS$},
      '... and the status line should be correct';
    $expected_summary = qr/^Files=1, Tests=2,  \d+ wallclock secs/;
    is_deeply \@output, \@expected,
      '... and the output should be correct';

    #XXXX
}

# make sure we can exec something ... anything!
SKIP: {

    my $cat = '/bin/cat';
    unless ( -e $cat ) {
        skip "no '$cat'", 2;
    }

    my $capture = IO::Capture->new_handle;
    my $harness = TAP::Harness->new(
        {   really_quiet => 1,
            stdout       => $capture,
            exec         => [$cat],
        }
    );

    eval { _runtests( $harness, 't/data/catme.1' ) };

    my @output = tied($$capture)->dump;
    my $status = pop @output;
    like $status, qr{^Result: PASS$},
      '... and the status line should be correct';
    pop @output;    # get rid of summary line
    my $answer = pop @output;
    is( $answer, "All tests successful.\n", 'cat meows' );
}

# catches "exec accumulates arguments" issue (r77)
{
    my $capture = IO::Capture->new_handle;
    my $harness = TAP::Harness->new(
        {   really_quiet => 1,
            stdout       => $capture,
            exec         => [$^X]
        }
    );

    _runtests(
        $harness,
        't/source_tests/harness_complain'
        ,    # will get mad if run with args
        't/source_tests/harness',
    );

    my @output = tied($$capture)->dump;
    my $status = pop @output;
    like $status, qr{^Result: PASS$},
      '... and the status line should be correct';
    pop @output;    # get rid of summary line
    is( $output[-1], "All tests successful.\n",
        'No exec accumulation' );
}

sub trim {
    $_[0] =~ s/^\s+|\s+$//g;
    return $_[0];
}

sub liblist {
    return [ map { '-I' . File::Spec->rel2abs($_) } @_ ];
}

sub get_arg_sets {

    # keys are keys to new()
    return {
        lib => {
            in        => 'lib',
            out       => liblist('lib'),
            test_name => '... a single lib switch should be correct'
        },
        verbosity => {
            in  => 1,
            out => 1,
            test_name =>
              '... and we should be able to set verbosity to 1'
        },

   # verbose => {
   #     in        => 1,
   #     out       => 1,
   #     test_name => '... and we should be able to set verbose to true'
   # },
      },
      { lib => {
            in  => [ 'lib',        't' ],
            out => liblist( 'lib', 't' ),
            test_name => '... multiple lib switches should be correct'
        },
        verbosity => {
            in  => 0,
            out => 0,
            test_name =>
              '... and we should be able to set verbosity to 0'
        },

  # verbose => {
  #     in        => 0,
  #     out       => 0,
  #     test_name => '... and we should be able to set verbose to false'
  # },
      },
      { switches => {
            in  => [ '-T', '-w', '-T' ],
            out => [ '-T', '-w' ],
            test_name => '... duplicate switches should be omitted',
        },
        failures => {
            in  => 1,
            out => 1,
            test_name =>
              '... and we should be able to set failures to true',
        },
        verbosity => {
            in  => -1,
            out => -1,
            test_name =>
              '... and we should be able to set verbosity to -1'
        },

    # quiet => {
    #     in        => 1,
    #     out       => 1,
    #     test_name => '... and we should be able to set quiet to false'
    # },
      },

      { verbosity => {
            in  => -2,
            out => -2,
            test_name =>
              '... and we should be able to set verbosity to -2'
        },

        # really_quiet => {
        #     in  => 1,
        #     out => 1,
        #     test_name =>
        #       '... and we should be able to set really_quiet to true',
        # },
        exec => {
            in  => $^X,
            out => $^X,
            test_name =>
              '... and we should be able to set the executable',
        },
      },
      { switches => {
            in  => 'T',
            out => ['-T'],
            test_name =>
              '... leading dashes (-) on switches are optional',
        },
      },
      { switches => {
            in        => '-T',
            out       => ['-T'],
            test_name => '... we should be able to set switches',
        },
        failures => {
            in  => 1,
            out => 1,
            test_name =>
              '... and we should be able to set failures to true'
        },
      };
}

sub _runtests {
    my ( $harness, @tests ) = @_;
    local $ENV{PERL_TEST_HARNESS_DUMP_TAP} = 0;
    my $aggregate = $harness->runtests(@tests);
    return $aggregate;
}

{

    # coverage tests for ctor

    my $harness = TAP::Harness->new(
        {   timer  => 0,
            errors => 1,
            merge  => 2,

            # formatter => 3,
        }
    );

    is $harness->timer(), 0, 'timer getter';
    is $harness->timer(10), 10, 'timer setter';
    is $harness->errors(), 1, 'errors getter';
    is $harness->errors(10), 10, 'errors setter';
    is $harness->merge(), 2, 'merge getter';
    is $harness->merge(10), 10, 'merge setter';

    # jobs accessor
    is $harness->jobs(), 1, 'jobs';
}

{

# coverage tests for the stdout key of VALIDATON_FOR, used by _initialize() in the ctor

    # the coverage tests are
    # 1. ref $ref => false
    # 2. ref => ! GLOB and ref->can(print)
    # 3. ref $ref => GLOB

    # case 1

    my @die;

    eval {
        local $SIG{__DIE__} = sub { push @die, @_ };

        my $harness = TAP::Harness->new(
            {   stdout => bless {}, '0',    # how evil is THAT !!!
            }
        );
    };

    is @die, 1, 'bad filehandle to stdout';
    like pop @die, qr/option 'stdout' needs a filehandle/,
      '... and we died as expected';

    # case 2

    @die = ();

    package Printable;

    sub new { return bless {}, shift }

    sub print {return}

    package main;

    my $harness = TAP::Harness->new(
        {   stdout => Printable->new(),
        }
    );

    isa_ok $harness, 'TAP::Harness';

    # case 3

    @die = ();

    $harness = TAP::Harness->new(
        {   stdout => bless {}, 'GLOB',    # again with the evil
        }
    );

    isa_ok $harness, 'TAP::Harness';
}

{

    # coverage testing of lib/switches accessor
    my $harness = TAP::Harness->new;

    my @die;

    eval {
        local $SIG{__DIE__} = sub { push @die, @_ };

        $harness->switches(qw( too many arguments));
    };

    is @die, 1, 'too many arguments to accessor';

    like pop @die, qr/Too many arguments to method 'switches'/,
      '...and we died as expected';

    $harness->switches('simple scalar');

    my $arrref = $harness->switches;
    is_deeply $arrref, ['simple scalar'], 'scalar wrapped in arr ref';
}

{

    # coverage tests for the basically untested T::H::_open_spool

    $ENV{PERL_TEST_HARNESS_DUMP_TAP} = File::Spec->catfile(qw(t spool));

# now given that we're going to be writing stuff to the file system, make sure we have
# a cleanup hook

    END {
        use File::Path;

        # remove the tree if we made it this far
        rmtree( $ENV{PERL_TEST_HARNESS_DUMP_TAP} )
          if $ENV{PERL_TEST_HARNESS_DUMP_TAP};
    }

    my $harness = TAP::Harness->new( { really_quiet => 1 } );

    can_ok $harness, 'runtests';

    # normal tests in verbose mode

    my $parser = $harness->runtests(
        File::Spec->catfile(qw (t source_tests harness )) );

    isa_ok $parser, 'TAP::Parser::Aggregator',
      '... runtests returns the aggregate';

    ok -e File::Spec->catfile(
        $ENV{PERL_TEST_HARNESS_DUMP_TAP},
        qw( t source_tests harness )
    );
}

#!/usr/bin/perl -wT

use strict;

use lib 'lib';
use TAP::Parser;
use TAP::Parser::Iterator;

use Test::More tests => 9;

my $tap = <<'END_TAP';
1..5
ok 1 - input file opened
... this is junk
not ok first line of the input valid # todo some data
# this is a comment
ok 3 - read the rest of the file
not ok 4 - this is a real failure
ok 5 # skip we have no description
END_TAP

my @tests;
my $plan_output;
my $todo      = 0;
my $skip      = 0;
my %callbacks = (
    test => sub {
        my $test = shift;
        push @tests => $test;
        $todo++ if $test->has_todo;
        $skip++ if $test->has_skip;
    },
    plan => sub {
        my $plan = shift;
        $plan_output = $plan->as_string;
    }
);

my $stream = TAP::Parser::Iterator->new( [ split /\n/ => $tap ] );
my $parser = TAP::Parser->new(
    {   stream    => $stream,
        callbacks => \%callbacks,
    }
);

can_ok $parser, 'run';
$parser->run;
is $plan_output, '1..5', 'Plan callbacks should succeed';
is scalar @tests, $parser->tests_run, '... as should the test callbacks';

@tests       = ();
$plan_output = '';
$todo        = 0;
$skip        = 0;
my $else = 0;
my $all  = 0;
%callbacks = (
    test => sub {
        my $test = shift;
        push @tests => $test;
        $todo++ if $test->has_todo;
        $skip++ if $test->has_skip;
    },
    plan => sub {
        my $plan = shift;
        $plan_output = $plan->as_string;
    },
    ELSE => sub {
        $else++;
    },
    ALL => sub {
        $all++;
    },
);

$stream = TAP::Parser::Iterator->new( [ split /\n/ => $tap ] );
$parser = TAP::Parser->new(
    {   stream    => $stream,
        callbacks => \%callbacks,
    }
);

can_ok $parser, 'run';
$parser->run;
is $plan_output, '1..5', 'Plan callbacks should succeed';
is scalar @tests, $parser->tests_run, '... as should the test callbacks';
is $else, 2, '... and the correct number of "ELSE" lines should be seen';
is $all,  8, '... and the correct total number of lines should be seen';

# Check callback name policing

%callbacks = (
    sometest => sub { },
    plan     => sub { },
    random   => sub { },
    ALL      => sub { },
    ELSES    => sub { },
);

$stream = TAP::Parser::Iterator->new( [ split /\n/ => $tap ] );
eval {
    $parser = TAP::Parser->new(
        {   stream    => $stream,
            callbacks => \%callbacks,
        }
    );
};

like $@, qr/Callback/, 'Bad callback keys faulted';

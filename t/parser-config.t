#!/usr/bin/perl -w

BEGIN {
    if ( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = ( '../lib', '../ext/Test-Harness/t/lib' );
    }
    else {
        unshift @INC, 't/lib';
    }
}

use strict;
use vars qw(%INIT %CUSTOM);

use Test::More tests => 5;
use File::Spec::Functions qw( catfile updir );
use TAP::Parser;

use_ok('MyGrammar');
use_ok('MyResultFactory');

my @t_path = $ENV{PERL_CORE} ? ( updir(), 'ext', 'Test-Harness' ) : ();
my $source = catfile( @t_path, 't', 'source_tests', 'source' );
my %customize = (
    grammar_class          => 'MyGrammar',
    result_factory_class   => 'MyResultFactory',
);
my $p = TAP::Parser->new(
    {   source => $source,
        %customize,
    }
);
ok( $p, 'new customized parser' );

foreach my $key ( keys %customize ) {
    is( $p->$key(), $customize{$key}, "customized $key" );
}

# TODO: make sure these things are propogated down through the parser...

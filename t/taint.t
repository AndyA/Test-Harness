#!/usr/bin/perl -w

# Test that options in PERL5LIB and PERL5OPT are propogated to tainted
# tests

use strict;
use lib 't/lib';

use Test::More tests => 3;

use Config;
use TAP::Parser;

sub run_test_file {
    my ( $test_template, @args ) = @_;

    my $test_file = 't/temp_test.tmp';

    open TEST, ">$test_file" or die $!;
    printf TEST $test_template, @args;
    close TEST;

    my $p = TAP::Parser->new( { source => $test_file } );
    1 while $p->next;
    ok !$p->failed;

    unlink $test_file;
}

{
    local $ENV{PERL5LIB} = join $Config{path_sep}, grep defined, 'wibble',
      $ENV{PERL5LIB};
    run_test_file(<<'END');
#!/usr/bin/perl -T

use Test::More tests => 1;

is( $INC[0], 'wibble' ) or diag join "\n,", @INC;
END
}

{
    my $perl5lib = $ENV{PERL5LIB};
    local $ENV{PERL5LIB};
    local $ENV{PERLLIB} = join $Config{path_sep}, grep defined, 'wibble',
      $perl5lib;
    run_test_file(<<'END');
#!/usr/bin/perl -T

use Test::More tests => 1;

is( $INC[0], 'wibble' ) or diag join "\n,", @INC;
END
}

{
    local $ENV{PERL5OPT} = '-Mstrict';
    run_test_file(<<'END');
#!/usr/bin/perl -T

print "1..1\n";
print $INC{'strict.pm'} ? "ok 1\n" : "not ok 1\n";
END
}

1;

package Test::More;

use 5.004;

use strict;
use Test::Builder;

# Can't use Carp because it might cause use_ok() to accidentally succeed
# even though the module being used forgot to use Carp.  Yes, this
# actually happened.
sub _carp {
    my ( $file, $line ) = ( caller(1) )[ 1, 2 ];
    warn @_, " at $file line $line\n";
}

require Exporter;
use vars qw($VERSION @ISA @EXPORT %EXPORT_TAGS $TODO);
$VERSION = '0.42';
@ISA     = qw(Exporter);
@EXPORT  = qw(ok use_ok require_ok
  is isnt like unlike is_deeply
  cmp_ok
  skip todo todo_skip
  pass fail
  eq_array eq_hash eq_set
  $TODO
  plan
  can_ok  isa_ok
  diag
);

my $Test = Test::Builder->new;

# 5.004's Exporter doesn't have export_to_level.
sub _export_to_level {
    my $pkg   = shift;
    my $level = shift;
    (undef) = shift;    # redundant arg
    my $callpkg = caller($level);
    $pkg->export( $callpkg, @_ );
}

=head1 NAME

Test::More - yet another framework for writing test scripts

=head1 SYNOPSIS

  use Test::More tests => $Num_Tests;
  # or
  use Test::More qw(no_plan);
  # or
  use Test::More skip_all => $reason;

  BEGIN { use_ok( 'Some::Module' ); }
  require_ok( 'Some::Module' );

  # Various ways to say "ok"
  ok($this eq $that, $test_name);

  is  ($this, $that,    $test_name);
  isnt($this, $that,    $test_name);

  # Rather than print STDERR "# here's what went wrong\n"
  diag("here's what went wrong");

  like  ($this, qr/that/, $test_name);
  unlike($this, qr/that/, $test_name);

  cmp_ok($this, '==', $that, $test_name);

  is_deeply($complex_structure1, $complex_structure2, $test_name);

  SKIP: {
      skip $why, $how_many unless $have_some_feature;

      ok( foo(),       $test_name );
      is( foo(42), 23, $test_name );
  };

  TODO: {
      local $TODO = $why;

      ok( foo(),       $test_name );
      is( foo(42), 23, $test_name );
  };

  can_ok($module, @methods);
  isa_ok($object, $class);

  pass($test_name);
  fail($test_name);

  # Utility comparison functions.
  eq_array(\@this, \@that);
  eq_hash(\%this, \%that);
  eq_set(\@this, \@that);

  # UNIMPLEMENTED!!!
  my @status = Test::More::status;

  # UNIMPLEMENTED!!!
  BAIL_OUT($why);


=head1 DESCRIPTION

B<STOP!> If you're just getting started writing tests, have a look at
Test::Simple first.  This is a drop in replacement for Test::Simple
which you can switch to once you get the hang of basic testing.

The purpose of this module is to provide a wide range of testing
utilities.  Various ways to say "ok" with better diagnostics,
facilities to skip tests, test future features and compare complicated
data structures.  While you can do almost anything with a simple
C<ok()> function, it doesn't provide good diagnostic output.


=head2 I love it when a plan comes together

Before anything else, you need a testing plan.  This basically declares
how many tests your script is going to run to protect against premature
failure.

The preferred way to do this is to declare a plan when you C<use Test::More>.

  use Test::More tests => $Num_Tests;

There are rare cases when you will not know beforehand how many tests
your script is going to run.  In this case, you can declare that you
have no plan.  (Try to avoid using this as it weakens your test.)

  use Test::More qw(no_plan);

In some cases, you'll want to completely skip an entire testing script.

  use Test::More skip_all => $skip_reason;

Your script will declare a skip with the reason why you skipped and
exit immediately with a zero (success).  See L<TAP::Harness::Compatible> for
details.

If you want to control what functions Test::More will export, you
have to use the 'import' option.  For example, to import everything
but 'fail', you'd do:

  use Test::More tests => 23, import => ['!fail'];

Alternatively, you can use the plan() function.  Useful for when you
have to calculate the number of tests.

  use Test::More;
  plan tests => keys %Stuff * 3;

or for deciding between running the tests at all:

  use Test::More;
  if( $^O eq 'MacOS' ) {
      plan skip_all => 'Test irrelevant on MacOS';
  }
  else {
      plan tests => 42;
  }

=cut

sub plan {
    my (@plan) = @_;

    my $caller = caller;

    $Test->exported_to($caller);
    $Test->plan(@plan);

    my @imports = ();
    foreach my $idx ( 0 .. $#plan ) {
        if ( $plan[$idx] eq 'import' ) {
            @imports = @{ $plan[ $idx + 1 ] };
            last;
        }
    }

    __PACKAGE__->_export_to_level( 1, __PACKAGE__, @imports );
}

sub import {
    my ($class) = shift;
    goto &plan;
}

=head2 Test names

By convention, each test is assigned a number in order.  This is
largely done automatically for you.  However, it's often very useful to
assign a name to each test.  Which would you rather see:

  ok 4
  not ok 5
  ok 6

or

  ok 4 - basic multi-variable
  not ok 5 - simple exponential
  ok 6 - force == mass * acceleration

The later gives you some idea of what failed.  It also makes it easier
to find the test in your script, simply search for "simple
exponential".

All test functions take a name argument.  It's optional, but highly
suggested that you use it.


=head2 I'm ok, you're not ok.

The basic purpose of this module is to print out either "ok #" or "not
ok #" depending on if a given test succeeded or failed.  Everything
else is just gravy.

All of the following print "ok" or "not ok" depending on if the test
succeeded or failed.  They all also return true or false,
respectively.

=over 4

=item B<ok>

  ok($this eq $that, $test_name);

This simply evaluates any expression (C<$this eq $that> is just a
simple example) and uses that to determine if the test succeeded or
failed.  A true expression passes, a false one fails.  Very simple.

For example:

    ok( $exp{9} == 81,                   'simple exponential' );
    ok( Film->can('db_Main'),            'set_db()' );
    ok( $p->tests == 4,                  'saw tests' );
    ok( !grep !defined $_, @items,       'items populated' );

(Mnemonic:  "This is ok.")

$test_name is a very short description of the test that will be printed
out.  It makes it very easy to find a test in your script when it fails
and gives others an idea of your intentions.  $test_name is optional,
but we B<very> strongly encourage its use.

Should an ok() fail, it will produce some diagnostics:

    not ok 18 - sufficient mucus
    #     Failed test 18 (foo.t at line 42)

This is actually Test::Simple's ok() routine.

=cut

sub ok ($;$) {
    my ( $test, $name ) = @_;
    $Test->ok( $test, $name );
}

=item B<is>

=item B<isnt>

  is  ( $this, $that, $test_name );
  isnt( $this, $that, $test_name );

Similar to ok(), is() and isnt() compare their two arguments
with C<eq> and C<ne> respectively and use the result of that to
determine if the test succeeded or failed.  So these:

    # Is the ultimate answer 42?
    is( ultimate_answer(), 42,          "Meaning of Life" );

    # $foo isn't empty
    isnt( $foo, '',     "Got some foo" );

are similar to these:

    ok( ultimate_answer() eq 42,        "Meaning of Life" );
    ok( $foo ne '',     "Got some foo" );

(Mnemonic:  "This is that."  "This isn't that.")

So why use these?  They produce better diagnostics on failure.  ok()
cannot know what you are testing for (beyond the name), but is() and
isnt() know what the test was and why it failed.  For example this
test:

    my $foo = 'waffle';  my $bar = 'yarblokos';
    is( $foo, $bar,   'Is foo the same as bar?' );

Will produce something like this:

    not ok 17 - Is foo the same as bar?
    #     Failed test 1 (foo.t at line 139)
    #          got: 'waffle'
    #     expected: 'yarblokos'

So you can figure out what went wrong without rerunning the test.

You are encouraged to use is() and isnt() over ok() where possible,
however do not be tempted to use them to find out if something is
true or false!

  # XXX BAD!  $pope->isa('Catholic') eq 1
  is( $pope->isa('Catholic'), 1,        'Is the Pope Catholic?' );

This does not check if C<$pope->isa('Catholic')> is true, it checks if
it returns 1.  Very different.  Similar caveats exist for false and 0.
In these cases, use ok().

  ok( $pope->isa('Catholic') ),         'Is the Pope Catholic?' );

For those grammatical pedants out there, there's an C<isn't()>
function which is an alias of isnt().

=cut

sub is ($$;$) {
    $Test->is_eq(@_);
}

sub isnt ($$;$) {
    $Test->isnt_eq(@_);
}

*isn't = \&isnt;

=item B<like>

  like( $this, qr/that/, $test_name );

Similar to ok(), like() matches $this against the regex C<qr/that/>.

So this:

    like($this, qr/that/, 'this is like that');

is similar to:

    ok( $this =~ /that/, 'this is like that');

(Mnemonic "This is like that".)

The second argument is a regular expression.  It may be given as a
regex reference (i.e. C<qr//>) or (for better compatibility with older
perls) as a string that looks like a regex (alternative delimiters are
currently not supported):

    like( $this, '/that/', 'this is like that' );

Regex options may be placed on the end (C<'/that/i'>).

Its advantages over ok() are similar to that of is() and isnt().  Better
diagnostics on failure.

=cut

sub like ($$;$) {
    $Test->like(@_);
}

=item B<unlike>

  unlike( $this, qr/that/, $test_name );

Works exactly as like(), only it checks if $this B<does not> match the
given pattern.

=cut

sub unlike {
    $Test->unlike(@_);
}

=item B<cmp_ok>

  cmp_ok( $this, $op, $that, $test_name );

Halfway between ok() and is() lies cmp_ok().  This allows you to
compare two arguments using any binary perl operator.

    # ok( $this eq $that );
    cmp_ok( $this, 'eq', $that, 'this eq that' );

    # ok( $this == $that );
    cmp_ok( $this, '==', $that, 'this == that' );

    # ok( $this && $that );
    cmp_ok( $this, '&&', $that, 'this || that' );
    ...etc...

Its advantage over ok() is when the test fails you'll know what $this
and $that were:

    not ok 1
    #     Failed test (foo.t at line 12)
    #     '23'
    #         &&
    #     undef

It's also useful in those cases where you are comparing numbers and
is()'s use of C<eq> will interfere:

    cmp_ok( $big_hairy_number, '==', $another_big_hairy_number );

=cut

sub cmp_ok($$$;$) {
    $Test->cmp_ok(@_);
}

=item B<can_ok>

  can_ok($module, @methods);
  can_ok($object, @methods);

Checks to make sure the $module or $object can do these @methods
(works with functions, too).

    can_ok('Foo', qw(this that whatever));

is almost exactly like saying:

    ok( Foo->can('this') && 
        Foo->can('that') && 
        Foo->can('whatever') 
      );

only without all the typing and with a better interface.  Handy for
quickly testing an interface.

No matter how many @methods you check, a single can_ok() call counts
as one test.  If you desire otherwise, use:

    foreach my $meth (@methods) {
        can_ok('Foo', $meth);
    }

=cut

sub can_ok ($@) {
    my ( $proto, @methods ) = @_;
    my $class = ref $proto || $proto;

    unless (@methods) {
        my $ok = $Test->ok( 0, "$class->can(...)" );
        $Test->diag('    can_ok() called with no methods');
        return $ok;
    }

    my @nok = ();
    foreach my $method (@methods) {
        my $test = "'$class'->can('$method')";
        local ( $!, $@ );    # don't interfere with caller's $@
                             # eval sometimes resets $!
        eval $test || push @nok, $method;
    }

    my $name;
    $name =
      @methods == 1
      ? "$class->can('$methods[0]')"
      : "$class->can(...)";

    my $ok = $Test->ok( !@nok, $name );

    $Test->diag( map "    $class->can('$_') failed\n", @nok );

    return $ok;
}

=item B<isa_ok>

  isa_ok($object, $class, $object_name);
  isa_ok($ref,    $type,  $ref_name);

Checks to see if the given $object->isa($class).  Also checks to make
sure the object was defined in the first place.  Handy for this sort
of thing:

    my $obj = Some::Module->new;
    isa_ok( $obj, 'Some::Module' );

where you'd otherwise have to write

    my $obj = Some::Module->new;
    ok( defined $obj && $obj->isa('Some::Module') );

to safeguard against your test script blowing up.

It works on references, too:

    isa_ok( $array_ref, 'ARRAY' );

The diagnostics of this test normally just refer to 'the object'.  If
you'd like them to be more specific, you can supply an $object_name
(for example 'Test customer').

=cut

sub isa_ok ($$;$) {
    my ( $object, $class, $obj_name ) = @_;

    my $diag;
    $obj_name = 'The object' unless defined $obj_name;
    my $name = "$obj_name isa $class";
    if ( !defined $object ) {
        $diag = "$obj_name isn't defined";
    }
    elsif ( !ref $object ) {
        $diag = "$obj_name isn't a reference";
    }
    else {

        # We can't use UNIVERSAL::isa because we want to honor isa() overrides
        local ( $@, $! );    # eval sometimes resets $!
        my $rslt = eval { $object->isa($class) };
        if ($@) {
            if ( $@ =~ /^Can't call method "isa" on unblessed reference/ ) {
                if ( !UNIVERSAL::isa( $object, $class ) ) {
                    my $ref = ref $object;
                    $diag = "$obj_name isn't a '$class' it's a '$ref'";
                }
            }
            else {
                die <<WHOA;
WHOA! I tried to call ->isa on your object and got some weird error.
This should never happen.  Please contact the author immediately.
Here's the error.
$@
WHOA
            }
        }
        elsif ( !$rslt ) {
            my $ref = ref $object;
            $diag = "$obj_name isn't a '$class' it's a '$ref'";
        }
    }

    my $ok;
    if ($diag) {
        $ok = $Test->ok( 0, $name );
        $Test->diag("    $diag\n");
    }
    else {
        $ok = $Test->ok( 1, $name );
    }

    return $ok;
}

=item B<pass>

=item B<fail>

  pass($test_name);
  fail($test_name);

Sometimes you just want to say that the tests have passed.  Usually
the case is you've got some complicated condition that is difficult to
wedge into an ok().  In this case, you can simply use pass() (to
declare the test ok) or fail (for not ok).  They are synonyms for
ok(1) and ok(0).

Use these very, very, very sparingly.

=cut

sub pass (;$) {
    $Test->ok( 1, @_ );
}

sub fail (;$) {
    $Test->ok( 0, @_ );
}

=back

=head2 Diagnostics

If you pick the right test function, you'll usually get a good idea of
what went wrong when it failed.  But sometimes it doesn't work out
that way.  So here we have ways for you to write your own diagnostic
messages which are safer than just C<print STDERR>.

=over 4

=item B<diag>

  diag(@diagnostic_message);

Prints a diagnostic message which is guaranteed not to interfere with
test output.  Handy for this sort of thing:

    ok( grep(/foo/, @users), "There's a foo user" ) or
        diag("Since there's no foo, check that /etc/bar is set up right");

which would produce:

    not ok 42 - There's a foo user
    #     Failed test (foo.t at line 52)
    # Since there's no foo, check that /etc/bar is set up right.

You might remember C<ok() or diag()> with the mnemonic C<open() or
die()>.

B<NOTE> The exact formatting of the diagnostic output is still
changing, but it is guaranteed that whatever you throw at it it won't
interfere with the test.

=cut

sub diag {
    $Test->diag(@_);
}

=back

=head2 Module tests

You usually want to test if the module you're testing loads ok, rather
than just vomiting if its load fails.  For such purposes we have
C<use_ok> and C<require_ok>.

=over 4

=item B<use_ok>

   BEGIN { use_ok($module); }
   BEGIN { use_ok($module, @imports); }

These simply use the given $module and test to make sure the load
happened ok.  Its recommended that you run use_ok() inside a BEGIN
block so its functions are exported at compile-time and prototypes are
properly honored.

If @imports are given, they are passed through to the use.  So this:

   BEGIN { use_ok('Some::Module', qw(foo bar)) }

is like doing this:

   use Some::Module qw(foo bar);


=cut

sub use_ok ($;@) {
    my ( $module, @imports ) = @_;
    @imports = () unless @imports;

    my $pack = caller;

    local ( $@, $! );    # eval sometimes interferes with $!
    eval <<USE;
package $pack;
require $module;
$module->import(\@imports);
USE

    my $ok = $Test->ok( !$@, "use $module;" );

    unless ($ok) {
        chomp $@;
        $Test->diag(<<DIAGNOSTIC);
    Tried to use '$module'.
    Error:  $@
DIAGNOSTIC

    }

    return $ok;
}

=item B<require_ok>

   require_ok($module);

Like use_ok(), except it requires the $module.

=cut

sub require_ok ($) {
    my ($module) = shift;

    my $pack = caller;

    local ( $!, $@ );    # eval sometimes interferes with $!
    eval <<REQUIRE;
package $pack;
require $module;
REQUIRE

    my $ok = $Test->ok( !$@, "require $module;" );

    unless ($ok) {
        chomp $@;
        $Test->diag(<<DIAGNOSTIC);
    Tried to require '$module'.
    Error:  $@
DIAGNOSTIC

    }

    return $ok;
}

=back

=head2 Conditional tests

Sometimes running a test under certain conditions will cause the
test script to die.  A certain function or method isn't implemented
(such as fork() on MacOS), some resource isn't available (like a 
net connection) or a module isn't available.  In these cases it's
necessary to skip tests, or declare that they are supposed to fail
but will work in the future (a todo test).

For more details on the mechanics of skip and todo tests see
L<TAP::Harness::Compatible>.

The way Test::More handles this is with a named block.  Basically, a
block of tests which can be skipped over or made todo.  It's best if I
just show you...

=over 4

=item B<SKIP: BLOCK>

  SKIP: {
      skip $why, $how_many if $condition;

      ...normal testing code goes here...
  }

This declares a block of tests to skip, $how_many tests there are,
$why and under what $condition to skip them.  An example is the
easiest way to illustrate:

    SKIP: {
        skip "Pigs don't fly here", 2 unless Pigs->can('fly');

        my $pig = Pigs->new;
        $pig->takeoff;

        ok( $pig->altitude > 0,         'Pig is airborne' );
        ok( $pig->airspeed > 0,         '  and moving'    );
    }

If pigs cannot fly, the whole block of tests will be skipped
completely.  Test::More will output special ok's which TAP::Harness::Compatible
interprets as skipped tests.  Its important to include $how_many tests
are in the block so the total number of tests comes out right (unless
you're using C<no_plan>, in which case you can leave $how_many off if
you like).

Its perfectly safe to nest SKIP blocks.

Tests are skipped when you B<never> expect them to B<ever> pass.  Like
an optional module is not installed or the operating system doesn't
have some feature (like fork() or symlinks) or maybe you need an
Internet connection and one isn't available.

You don't skip tests which are failing because there's a bug in your
program.  For that you use TODO.  Read on.


=for _Future
See L</Why are skip and todo so weird?>

=cut

#'#
sub skip {
    my ( $why, $how_many ) = @_;

    unless ( defined $how_many ) {

        # $how_many can only be avoided when no_plan is in use.
        _carp "skip() needs to know \$how_many tests are in the block"
          unless $Test::Builder::No_Plan;
        $how_many = 1;
    }

    for ( 1 .. $how_many ) {
        $Test->skip($why);
    }

    local $^W = 0;
    last SKIP;
}

=item B<TODO: BLOCK>

    TODO: {
        local $TODO = $why if $condition;

        ...normal testing code goes here...
    }

Declares a block of tests you expect to fail and $why.  Perhaps it's
because you haven't fixed a bug or haven't finished a new feature:

    TODO: {
        local $TODO = "URI::Geller not finished";

        my $card = "Eight of clubs";
        is( URI::Geller->your_card, $card, 'Is THIS your card?' );

        my $spoon;
        URI::Geller->bend_spoon;
        is( $spoon, 'bent',    "Spoon bending, that's original" );
    }

With a todo block, the tests inside are expected to fail.  Test::More
will run the tests normally, but print out special flags indicating
they are "todo".  TAP::Harness::Compatible will interpret failures as being ok.
Should anything succeed, it will report it as an unexpected success.

The nice part about todo tests, as opposed to simply commenting out a
block of tests, is it's like having a programmatic todo list.  You know
how much work is left to be done, you're aware of what bugs there are,
and you'll know immediately when they're fixed.

Once a todo test starts succeeding, simply move it outside the block.
When the block is empty, delete it.


=item B<todo_skip>

    TODO: {
        todo_skip $why, $how_many if $condition;

        ...normal testing code...
    }

With todo tests, its best to have the tests actually run.  That way
you'll know when they start passing.  Sometimes this isn't possible.
Often a failing test will cause the whole program to die or hang, even
inside an C<eval BLOCK> with and using C<alarm>.  In these extreme
cases you have no choice but to skip over the broken tests entirely.

The syntax and behavior is similar to a C<SKIP: BLOCK> except the
tests will be marked as failing but todo.  TAP::Harness::Compatible will
interpret them as passing.

=cut

sub todo_skip {
    my ( $why, $how_many ) = @_;

    unless ( defined $how_many ) {

        # $how_many can only be avoided when no_plan is in use.
        _carp "todo_skip() needs to know \$how_many tests are in the block"
          unless $Test::Builder::No_Plan;
        $how_many = 1;
    }

    for ( 1 .. $how_many ) {
        $Test->todo_skip($why);
    }

    local $^W = 0;
    last TODO;
}

=back

=head2 Comparison functions

Not everything is a simple eq check or regex.  There are times you
need to see if two arrays are equivalent, for instance.  For these
instances, Test::More provides a handful of useful functions.

B<NOTE> These are NOT well-tested on circular references.  Nor am I
quite sure what will happen with filehandles.

=over 4

=item B<is_deeply>

  is_deeply( $this, $that, $test_name );

Similar to is(), except that if $this and $that are hash or array
references, it does a deep comparison walking each data structure to
see if they are equivalent.  If the two structures are different, it
will display the place where they start differing.

Barrie Slaymaker's Test::Differences module provides more in-depth
functionality along these lines, and it plays well with Test::More.

B<NOTE> Display of scalar refs is not quite 100%

=cut

use vars qw(@Data_Stack);
my $DNE = bless [], 'Does::Not::Exist';

sub is_deeply {
    my ( $this, $that, $name ) = @_;

    my $ok;
    if ( !ref $this || !ref $that ) {
        $ok = $Test->is_eq( $this, $that, $name );
    }
    else {
        local @Data_Stack = ();
        if ( _deep_check( $this, $that ) ) {
            $ok = $Test->ok( 1, $name );
        }
        else {
            $ok = $Test->ok( 0, $name );
            $ok = $Test->diag( _format_stack(@Data_Stack) );
        }
    }

    return $ok;
}

sub _format_stack {
    my (@Stack) = @_;

    my $var       = '$FOO';
    my $did_arrow = 0;
    foreach my $entry (@Stack) {
        my $type = $entry->{type} || '';
        my $idx = $entry->{'idx'};
        if ( $type eq 'HASH' ) {
            $var .= "->" unless $did_arrow++;
            $var .= "{$idx}";
        }
        elsif ( $type eq 'ARRAY' ) {
            $var .= "->" unless $did_arrow++;
            $var .= "[$idx]";
        }
        elsif ( $type eq 'REF' ) {
            $var = "\${$var}";
        }
    }

    my @vals = @{ $Stack[-1]{vals} }[ 0, 1 ];
    my @vars = ();
    ( $vars[0] = $var ) =~ s/\$FOO/     \$got/;
    ( $vars[1] = $var ) =~ s/\$FOO/\$expected/;

    my $out = "Structures begin differing at:\n";
    foreach my $idx ( 0 .. $#vals ) {
        my $val = $vals[$idx];
        $vals[$idx] =
            !defined $val ? 'undef'
          : $val eq $DNE ? "Does not exist"
          :                "'$val'";
    }

    $out .= "$vars[0] = $vals[0]\n";
    $out .= "$vars[1] = $vals[1]\n";

    $out =~ s/^/    /msg;
    return $out;
}

=item B<eq_array>

  eq_array(\@this, \@that);

Checks if two arrays are equivalent.  This is a deep check, so
multi-level structures are handled correctly.

=cut

#'#
sub eq_array {
    my ( $a1, $a2 ) = @_;
    return 1 if $a1 eq $a2;

    my $ok = 1;
    my $max = $#$a1 > $#$a2 ? $#$a1 : $#$a2;
    for ( 0 .. $max ) {
        my $e1 = $_ > $#$a1 ? $DNE : $a1->[$_];
        my $e2 = $_ > $#$a2 ? $DNE : $a2->[$_];

        push @Data_Stack,
          { type => 'ARRAY', idx => $_, vals => [ $e1, $e2 ] };
        $ok = _deep_check( $e1, $e2 );
        pop @Data_Stack if $ok;

        last unless $ok;
    }
    return $ok;
}

sub _deep_check {
    my ( $e1, $e2 ) = @_;
    my $ok = 0;

    my $eq;
    {

        # Quiet uninitialized value warnings when comparing undefs.
        local $^W = 0;

        if ( $e1 eq $e2 ) {
            $ok = 1;
        }
        else {
            if (    UNIVERSAL::isa( $e1, 'ARRAY' )
                and UNIVERSAL::isa( $e2, 'ARRAY' ) )
            {
                $ok = eq_array( $e1, $e2 );
            }
            elsif ( UNIVERSAL::isa( $e1, 'HASH' )
                and UNIVERSAL::isa( $e2, 'HASH' ) )
            {
                $ok = eq_hash( $e1, $e2 );
            }
            elsif ( UNIVERSAL::isa( $e1, 'REF' )
                and UNIVERSAL::isa( $e2, 'REF' ) )
            {
                push @Data_Stack, { type => 'REF', vals => [ $e1, $e2 ] };
                $ok = _deep_check( $$e1, $$e2 );
                pop @Data_Stack if $ok;
            }
            elsif ( UNIVERSAL::isa( $e1, 'SCALAR' )
                and UNIVERSAL::isa( $e2, 'SCALAR' ) )
            {
                push @Data_Stack, { type => 'REF', vals => [ $e1, $e2 ] };
                $ok = _deep_check( $$e1, $$e2 );
            }
            else {
                push @Data_Stack, { vals => [ $e1, $e2 ] };
                $ok = 0;
            }
        }
    }

    return $ok;
}

=item B<eq_hash>

  eq_hash(\%this, \%that);

Determines if the two hashes contain the same keys and values.  This
is a deep check.

=cut

sub eq_hash {
    my ( $a1, $a2 ) = @_;
    return 1 if $a1 eq $a2;

    my $ok = 1;
    my $bigger = keys %$a1 > keys %$a2 ? $a1 : $a2;
    foreach my $k ( keys %$bigger ) {
        my $e1 = exists $a1->{$k} ? $a1->{$k} : $DNE;
        my $e2 = exists $a2->{$k} ? $a2->{$k} : $DNE;

        push @Data_Stack, { type => 'HASH', idx => $k, vals => [ $e1, $e2 ] };
        $ok = _deep_check( $e1, $e2 );
        pop @Data_Stack if $ok;

        last unless $ok;
    }

    return $ok;
}

=item B<eq_set>

  eq_set(\@this, \@that);

Similar to eq_array(), except the order of the elements is B<not>
important.  This is a deep check, but the irrelevancy of order only
applies to the top level.

=cut

# We must make sure that references are treated neutrally.  It really
# doesn't matter how we sort them, as long as both arrays are sorted
# with the same algorithm.
sub _bogus_sort { local $^W = 0; ref $a ? 0 : $a cmp $b }

sub eq_set {
    my ( $a1, $a2 ) = @_;
    return 0 unless @$a1 == @$a2;

    # There's faster ways to do this, but this is easiest.
    return eq_array( [ sort _bogus_sort @$a1 ], [ sort _bogus_sort @$a2 ] );
}

=back


=head2 Extending and Embedding Test::More

Sometimes the Test::More interface isn't quite enough.  Fortunately,
Test::More is built on top of Test::Builder which provides a single,
unified backend for any test library to use.  This means two test
libraries which both use Test::Builder B<can be used together in the
same program>.

If you simply want to do a little tweaking of how the tests behave,
you can access the underlying Test::Builder object like so:

=over 4

=item B<builder>

    my $test_builder = Test::More->builder;

Returns the Test::Builder object underlying Test::More for you to play
with.

=cut

sub builder {
    return Test::Builder->new;
}

=back


=head1 NOTES

Test::More is B<explicitly> tested all the way back to perl 5.004.

=head1 BUGS and CAVEATS

=over 4

=item Making your own ok()

If you are trying to extend Test::More, don't.  Use Test::Builder
instead.

=item The eq_* family has some caveats.

=item TAP::Harness::Compatible upgrades

no_plan and todo depend on new TAP::Harness::Compatible features and fixes.  If
you're going to distribute tests that use no_plan or todo your
end-users will have to upgrade TAP::Harness::Compatible to the latest one on
CPAN.  If you avoid no_plan and TODO tests, the stock TAP::Harness::Compatible
will work fine.

If you simply depend on Test::More, it's own dependencies will cause a
TAP::Harness::Compatible upgrade.

=back


=head1 HISTORY

This is a case of convergent evolution with Joshua Pritikin's Test
module.  I was largely unaware of its existence when I'd first
written my own ok() routines.  This module exists because I can't
figure out how to easily wedge test names into Test's interface (along
with a few other problems).

The goal here is to have a testing utility that's simple to learn,
quick to use and difficult to trip yourself up with while still
providing more flexibility than the existing Test.pm.  As such, the
names of the most common routines are kept tiny, special cases and
magic side-effects are kept to a minimum.  WYSIWYG.


=head1 SEE ALSO

L<Test::Simple> if all this confuses you and you just want to write
some tests.  You can upgrade to Test::More later (its forward
compatible).

L<Test::Differences> for more ways to test complex data structures.
And it plays well with Test::More.

L<Test> is the old testing module.  Its main benefit is that it has
been distributed with Perl since 5.004_05.

L<TAP::Harness::Compatible> for details on how your test results are interpreted
by Perl.

L<Test::Unit> describes a very featureful unit testing interface.

L<Test::Inline> shows the idea of embedded testing.

L<SelfTest> is another approach to embedded testing.


=head1 AUTHORS

Michael G Schwern E<lt>schwern@pobox.comE<gt> with much inspiration
from Joshua Pritikin's Test module and lots of help from Barrie
Slaymaker, Tony Bowden, chromatic and the perl-qa gang.


=head1 COPYRIGHT

Copyright 2001 by Michael G Schwern E<lt>schwern@pobox.comE<gt>.

This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=cut

1;

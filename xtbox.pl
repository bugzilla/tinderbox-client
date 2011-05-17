#!/usr/bin/perl -w

use strict;
use lib '.';
require 5.0006;
use Tinderbox::Client;
use Getopt::Long;

$ENV{BZ_WRITE_TESTS} = 1;

my %switch;
GetOptions(\%switch, 'long=s');

my $long = $switch{'long'};
my $db = $ARGV[0] || 'MySQL';
$db .= "-$long" if $long;
my $branch = $ARGV[1] || '';
my $dir = "xtbox-" . lc($db);
$dir .= "-$branch" if $branch;
my $long_args = $long ? " --long --top-operators=$long" : "";

my $client = new Tinderbox::Client({
    Lock      => ".xt-$db-lock",
    Admin     => 'mkanat@bugzilla.org',
    To        => 'tinderbox-daemon@tinderbox.mozilla.org',
    Tinderbox => "Bugzilla$branch",
    Build     => "xt $db cg-bugs01",
    Commands  => ["./checksetup.pl /home/tinderbox/qa-answers",
                  "$^X -Mlib=lib /home/tinderbox/bin/prove -v xt/ ::"
                  . " --add-custom-fields$long_args"],
    Dir       => $dir,
    'Failure Strings' => ['DIED', 'FAILED', '^C ', 'Result: FAIL'],
    'Warning Strings' => ['UNEXPECTEDLY SUCCEEDED',
                          'unexpectedly succeeded',
                          'TODO passed: '],
});

$client->run();

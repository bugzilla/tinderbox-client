#!/usr/bin/perl -w

use strict;
use lib '.';
require 5.0006;
use Tinderbox::Client;

$ENV{BZ_WRITE_TESTS} = 1;

my $db = $ARGV[0] || 'MySQL';
my $dir = "xtbox-" . lc($db);

my $client = new Tinderbox::Client({
    Lock      => ".xt-$db-lock",
    Admin     => 'mkanat@bugzilla.org',
    To        => 'tinderbox-daemon@tinderbox.mozilla.org',
    Tinderbox => 'Bugzilla',
    Build     => "xt $db cg-bugs01",
    Commands  => ["./checksetup.pl /home/tinderbox/qa-answers",
                  "$^X -Mlib=lib /home/tinderbox/bin/prove -v xt/ ::"
                  . " --add-custom-fields"],
    Dir       => $dir,
    'Failure Strings' => ['DIED', 'FAILED', '^C ', 'Result: FAIL'],
    'Warning Strings' => ['UNEXPECTEDLY SUCCEEDED',
                          'unexpectedly succeeded'],
});

$client->run();

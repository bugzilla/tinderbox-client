#!/usr/bin/perl -w

use strict;
use lib '.';
require 5.0006;
use Tinderbox::Client;

$ENV{BZ_WRITE_TESTS} = 1;

my $client = new Tinderbox::Client({
    Lock      => '.xt-lock',
    Admin     => 'mkanat@bugzilla.org',
    To        => 'mkanat@bugzilla.org', #'tinderbox-daemon@tinderbox.mozilla.org',
    Tinderbox => 'Bugzilla',
    Build     => "xt MySQL cg-bugs01",
    Commands  => ["./checksetup.pl /home/tinderbox/qa-answers",
                  "$^X -Mlib=lib /home/tinderbox/bin/prove -v xt/ ::"
                  . " --add-custom-fields"],
    Dir       => 'xtbox',
    'Failure Strings' => ['DIED', 'FAILED', '^C '],
    'Warning Strings' => ['UNEXPECTEDLY SUCCEEDED',
                          'unexpectedly succeeded'],
});

$client->run();

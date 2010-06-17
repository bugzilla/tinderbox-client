#!/usr/bin/perl -w

use strict;
use lib '.';
require 5.0006;
use Tinderbox::Client;

my $client = new Tinderbox::Client({
    Lock      => '.qa-lock',
    Admin     => 'mkanat@bugzilla.org',
    To        => 'tinderbox-daemon@tinderbox.mozilla.org',
    Sleep     => 1202,
    Tinderbox => 'Bugzilla',
    Build     => 'checksetup cg-bugs01',
    Commands  => ["$^X -w ../test-checksetup.pl --full"], 
    Dir       => 'checksetup/',
    'Failure Strings' => ['[checkout aborted]', 'FAILED', 
                          ': cannot find module', '^C ',
                          'No CVSROOT specified!'],
});

$client->run();

#!/usr/bin/perl -w

use strict;
use lib '.';
require 5.0006;
use Tinderbox::Client;

my $client = new Tinderbox::Client({
    Admin     => 'mkanat@bugzilla.org',
    To        => 'tinderbox-daemon@tinderbox.mozilla.org',
    Sleep     => '1200',
    Tinderbox => 'Bugzilla',
    Build     => 'checksetup-pg cg-bugs01',
    Commands  => ["$^X -w ../test-checksetup.pl"
                  . " --config=../config-test-checksetup-pg --full"], 
    Dir       => 'checksetup-pg/',
    'Failure Strings' => ['[checkout aborted]', 'FAILED', 
                          ': cannot find module', '^C ',
                          'No CVSROOT specified!'],
});

$client->run();

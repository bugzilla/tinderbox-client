#!/usr/bin/perl -w

use strict;
use lib '.';
require 5.0006;
use Tinderbox::Client;
use POSIX;

# PostgreSQL 8.3 and above won't let you connect to a SQL_ASCII
# database if you have a UTF-8 LC_CTYPE. It will allow connecting
# to any database from the C locale, though.
POSIX::setlocale(POSIX::LC_CTYPE, 'C');

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

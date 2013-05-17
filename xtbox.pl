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
my $lock_file = $long ? ".qa-lock" : ".xt-$db-lock"; # Prevents random QA orange

my $client = new Tinderbox::Client({
    Lock      => "$lock_file",
    Admin     => 'wicked@sci.fi',
    To        => 'tinderbox-daemon@tinderbox.mozilla.org',
    Tinderbox => "Bugzilla$branch",
    Build     => "xt $db cg-bugs01",
    Commands  => ["/opt/perl-5.10.1/bin/perl -Mlib=lib ./checksetup.pl"
                  . " /home/tinderbox/qa-answers",
                  "/opt/perl-5.10.1/bin/perl -Mlib=lib ~/bin/prove -v xt/ ::"
                  . " --add-custom-fields$long_args"],
    Dir       => $dir,
    Compress  => $long,
    'Failure Strings' => ['DIED', 'FAILED', '^C ', 'Result: FAIL',
                          'bzr: ERROR:'],
    'Warning Strings' => ['UNEXPECTEDLY SUCCEEDED',
                          'unexpectedly succeeded',
                          'TODO passed: '],
});

$client->run();

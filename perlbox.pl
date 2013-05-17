#!/usr/bin/perl -w

use strict;
use lib '.';
require 5.0006;
use Getopt::Long;
use Tinderbox::Client;

use constant DEFAULT_PERL => '5.8.8';

GetOptions("upgrade" => \my $do_upgrade) || die $@;

my ($branch, $perl) = @ARGV;
$perl ||= DEFAULT_PERL;
my $branch_no_dots = $branch;
my $perl_no_dots = $perl;
$branch_no_dots =~ s/\.//g;
$perl_no_dots =~ s/\.//g;

my $tinderbox = $branch eq 'tip' ? "Bugzilla" : "Bugzilla$branch";
my $dir = $perl eq DEFAULT_PERL ? "bugzilla-$branch" 
                                : "bugzilla-$branch-$perl_no_dots";
my $install_switch = $do_upgrade ? '--upgrade-all' : '--all';

my $client = new Tinderbox::Client({
    Lock      => ".${branch_no_dots}-lock",
    Admin     => 'wicked@sci.fi',
    To        => 'tinderbox-daemon@tinderbox.mozilla.org',
    Tinderbox => $tinderbox,
    Build     => "perl $perl cg-bugs01",
    Commands  => ["perl$perl install-module.pl $install_switch 2> /dev/null",
                  "perl$perl -w checksetup.pl --check-modules",
                  "perl$perl -w runtests.pl --verbose"],
    Dir       => $dir,
    'Failure Strings' => ['[checkout aborted]', '--ERROR', 'bzr: ERROR:',
                          ': cannot find module', '^C '],
    'Warning Strings' => ['--WARNING'],
});

$client->run();

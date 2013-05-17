#!/usr/bin/perl -w
#
# The contents of this file are subject to the Mozilla Public
# License Version 1.1 (the "License"); you may not use this file
# except in compliance with the License. You may obtain a copy of
# the License at http://www.mozilla.org/MPL/
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
# implied. See the License for the specific language governing
# rights and limitations under the License.
#
# The Original Code is The Tinderbox Client.
#
# Contributor(s): Max Kanat-Alexander <mkanat@bugzilla.org>

#####################################################################
# Init and Configuration
#####################################################################

use strict;
use lib '.';
use Tinderbox::Client;

# Causes false failures.
delete $ENV{TERMCAP};

my $branch = $ARGV[0];
my $tinderbox = $branch eq 'tip' ? "Bugzilla" : "Bugzilla$branch";
my $perl = $branch eq 'tip' ? '/opt/perl-5.10.1/bin/perl -w': $^X;

my $client = new Tinderbox::Client({
    Lock      => '.docs-lock',
    Admin     => 'wicked@sci.fi',
    To        => 'tinderbox-daemon@tinderbox.mozilla.org',
    Tinderbox => $tinderbox,
    Build     => "documentation cg-bugs01",
    Commands  => ["cd docs; $perl makedocs.pl", "sleep 1m"],
    Dir       => "bugzilla-$branch-docs",
    'Failure Strings' => ['[checkout aborted]', '--ERROR', '^C ', 'bzr: ERROR:',
                          ': cannot find module', 'E:'],
    'Warning Strings' => ['W:'],
});

$client->run();

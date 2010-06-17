#!/usr/bin/perl -w
# -*- Mode: perl; indent-tabs-mode: nil -*-
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
# The Original Code is The Bugzilla Bug Tracking System.
#
# The Initial Developer of the Original Code is Maxwell Kanat-Alexander
# Portions created by Maxwell Kanat-Alexander are Copyright (C) 2004
# Maxwell Kanat-Alexander. All Rights Reserved.

# Possible improvements:
#    + Ability to check a three-stage upgrade. That is, from Version A
#      to Version B to Tip
#    + Along the same lines, the ability to check a "total upgrade,"
#      where we start with 2.8, and then upgrade to each version from 
#      2.10 to the tip.

use strict;
use lib '..';

use Carp;
use File::Basename;
use File::Path;
use Getopt::Long;
use Tinderbox::DB;

set_env();

#####################################################################
# Constants
#####################################################################

my %switch;
GetOptions(\%switch, 'full', 'skip-basic', 'skip-copy', 'config:s');

my $config_file = $switch{'config'} || 'config-test-checksetup';
require $config_file;

# Set up some global constants.
our $Config = CONFIG();
our $My_Db_Name = $Config->{test_db};
our $Tip_Database = $My_Db_Name . "_tiptest";
our $Answers_File = $Config->{answers};

our $_db;

# Configuration for the detailed tests #
# How many of each object we create while we're testing the created database.
# The larger this number is, the longer the tests will take, but the more
# thorough they will be.
our $Object_Limit = 500;
# The login name and realname for the user that we create in the database 
# during testing.
our $Test_User_Login = 'checksetup_test_user@landfill.bugzilla.org';
our $Test_Real_Name = 'Checksetup Test User';
my %DB_LIST = %{$Config->{db_list}};

#####################################################################
# Subroutines
#####################################################################

sub set_env {
    $ENV{PATH} = '/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin';
    $ENV{PGOPTIONS}='-c client_min_messages=warning';
}

sub db {
    return $_db if $_db;
    $_db = new Tinderbox::DB($Config->{db_type}, 
        { user => $Config->{db_user}, password => $Config->{db_pass} });
}

sub check_schema ($$) {
    my ($for_db, $version_db) = @_;
    $version_db = '(checksetup-created)' unless $version_db;

    my $diffs = db()->diff_schema($Tip_Database, $for_db);
    if ($diffs) {
        print STDERR "\nWARNING: Differences found between $version_db"
                     . " and $Tip_Database:\n\n";
        print STDERR $diffs;
    }
}

sub check_test ($$) {
    my ($test_name, $failures) = @_;
    if ($failures) {
        print STDERR "\n\n***** $test_name FAILED! *****\n\n";
        $::Total_Failures += $failures;
    } 
}

sub switchdb {
    my ($to_db) = @_;
    db()->copy_db({ from => $to_db, to => $My_Db_Name, overwrite => 1 });
}


# Runs checksetup against the specified DB. Returns the number of times
# that the tests failed. If you specify no DB, we will create an empty
# DB and test against that.
sub run_against_db (;$$$) {
    my ($db_name, $quickly, $skip_schema) = @_;
    my $checksetup_switches = "--verbose ";
    my $failures = 0;
    $checksetup_switches .= " --no-templates" if $quickly;
    switchdb($db_name) if $db_name;
    # Enable the Voting extension
    unlink 'extensions/Voting/disabled';
    $failures += (system("./checksetup.pl $Answers_File $checksetup_switches") != 0);
    # For the sake of consistency, now disable the extension.
    system('touch extensions/Voting/disabled');
    # Run tests against the created database only if checksetup ran.
    if(!$failures && !$skip_schema) {
        print "Validating the created the schema...\n";
        check_schema($My_Db_Name, $db_name);
        print "\nRunning tests against the created database...\n";
        $failures += test_created_database();
    }
    return $failures;
}

our $Test_Die_Count;
# Run a bunch of tests on the DBs. Traps the DIE and WARN handler, and returns
# how many times the DIE handler has to be called.
sub test_created_database () {
    require Bugzilla;
    require Bugzilla::Bug;
    require Bugzilla::User;
    require Bugzilla::Series;
    require Bugzilla::Attachment;
    require Bugzilla::Token;
    require Bugzilla::Product;

    # Loading Bugzilla.pm cleared our environment.
    set_env();

    $Test_Die_Count = 0;

    $SIG{__DIE__} = \&test_die;
    
    # Everything happens in an eval block -- we don't want to ever actually
    # die during tests. Things happen in separate eval blocks because we 
    # want to continue to do the tests even if one of them fails.

    my $rand = db()->sql_random;

    my $dbh;
    eval {
        # Get a handle to the database.
        $dbh = Bugzilla->dbh;
    };
    # If we can't create the DB handle, there's no point in the
    # rest of the tests.
    return $Test_Die_Count if $Test_Die_Count;

    my $test_user;
    eval {
        # Create a User in the database.
        print "Creating a brand-new user...";
        $test_user = Bugzilla::User->create({
            login_name => $Test_User_Login, 
            realname   => $Test_Real_Name,
            cryptpassword => '*'});
        print "inserted $Test_User_Login\n";
    };
    # If we can't create the user, most of the rest of our tests will
    # fail anyway.
    return $Test_Die_Count if $Test_Die_Count;

    my $bug_id_list;
    eval {
        # Create some Bug objects.
        print "Reading in bug ids... ";
        $bug_id_list = $dbh->selectcol_arrayref(
            "SELECT bug_id 
               FROM (SELECT bug_id, $rand AS ord 
                      FROM bugs ORDER BY ord) AS t 
              LIMIT $Object_Limit");
        print "found " . scalar(@$bug_id_list) . " bugs.\n";

        print "Creating bugs";
        foreach my $bug_id (@$bug_id_list) {
            print ", $bug_id";
            my $bug = new Bugzilla::Bug($bug_id, $test_user);
            # And read in attachment data for each bug, too.
            # This also tests a lot of other code paths.
            $bug->attachments;
            # And call a few other subs for testing purposes.
            $bug->dup_id;
            $bug->actual_time;
            $bug->any_flags_requesteeble;
            $bug->blocked;
            $bug->cc;
            $bug->keywords;
            $bug->comments;
            $bug->groups;
            $bug->choices;
        }
        print "\n";
    };

    eval {
        # Create some User objects and run some methods on them.
        print "Reading in user ids... ";
        my $user_id_list = $dbh->selectcol_arrayref(
            "SELECT userid
               FROM (SELECT userid, $rand AS ord
                      FROM profiles ORDER BY ord) AS t
              LIMIT $Object_Limit");
        print "found " . scalar(@$user_id_list) . " users.\n";

        print "Creating users";
        foreach my $user_id (@$user_id_list) {
            print ", $user_id";
            my $created_user = new Bugzilla::User($user_id);
            $created_user->groups();
            $created_user->queries();
            $created_user->can_see_bug(1) if (@$bug_id_list);
            $created_user->get_selectable_products();
        }
        print "\n";
    };

    eval {
        # Create some Series objects.
        print "Reading in series ids... ";
        my $series_id_list = $dbh->selectcol_arrayref(
            "SELECT series_id
               FROM (SELECT series_id, $rand AS ord
                      FROM series ORDER BY ord) AS t
              LIMIT $Object_Limit");
        print "found " . scalar(@$series_id_list) . " series.\n";
        print "Creating series";
        foreach my $series_id (@$series_id_list) {
            print ", $series_id";
            my $created_series = new Bugzilla::Series($series_id);
            # We could have been returned undef if we couldn't see the series.
            $created_series->writeToDatabase() if $created_series;
        }
        print "\n";
    };

    eval {
        # Create some Product objects and their related items.
        print "Reading in products... ";
        my @products = Bugzilla::Product->get_all;
        print "found " . scalar(@products) . " products.\n";
        print "Testing products";
        foreach my $product (@products) {
            print ", " . $product->id;
            $product->components;
            $product->group_controls;
            $product->versions;
            $product->milestones;
        }
        print "\n";
    };

    eval {
        # Clean the token table
        print "Attempting to clean the Token table... ";
        Bugzilla::Token::CleanTokenTable();
        print "cleaned.\n";
    };

    # Disconnect so that Pg doesn't complain we're still using the DB.
    $dbh->disconnect; delete Bugzilla->request_cache->{dbh};
    delete Bugzilla->request_cache->{dbh_main};

    return $Test_Die_Count;
}

# For dealing with certain signals while we're testing. We just
# print out a stack trace and increment our global counter
# of how many times we died.
sub test_die ($) {
    my ($message) = @_;
    $Test_Die_Count++;
    Carp::cluck($message);
}

#####################################################################
# Read-In Command-Line Arguments
#####################################################################

# The user can specify versions to test against on the command-line.
my @runversions;
if ($switch{'full'}) {
    # The --full switch overrides the version list.
    @runversions = (keys %DB_LIST);
} 
else {
    # All arguments that are not switches are version numbers.
    @runversions = @ARGV;
    # Skip the basic tests if we were passed-in version numbers.
    $switch{'skip-basic'} = $switch{'skip-basic'} || scalar @runversions;
}

#####################################################################
# Main Code
#####################################################################

# Basically, what we do is copy databases into our current installation
# over and over and see if we can upgrade them with our checksetup.
# If any of our checksetup runs fails, we assume that we failed "hard"
# (i.e., a "red" Tinderbox)
# If anything shows up in stderr, but we didn't fail hard, we can assume
# that we failed "soft." (i.e., an "orange" Tinderbox)

our $Total_Failures = 0;

if (!$switch{'skip-copy'}) {
    foreach my $db (@{$Config->{copy_dbs}}) {
        print "Copying $db from landfill.bugzilla.org...\n";
        db()->copy_db({ from_host => 'landfill.bugzilla.org',
                        from => $db, to => $db, overwrite => 1 });
    }
}

# We have to be in the right directory for checksetup to run.
chdir $Config->{base_dir} || die "Could not change to the base directory: $!";

db()->reset();

# Try to run cleanly against the tip database.
print "---------------------------------------------\n";
print "Testing against tip database " . $Config->{tip_db} . "...\n";
print "---------------------------------------------\n\n";
check_test("Test against tip database",
    run_against_db($Config->{tip_db}, "quickly", "skip schema"));

# And now copy the database that we created to be our "tip
# database" for schema comparisons in the future.
print "Copying $My_Db_Name to $Tip_Database for future schema tests...\n\n";
db()->copy_db({ from => $My_Db_Name, to => $Tip_Database, overwrite => 1 });

# If the user specified a specific version to test, don't 
# do certain generic tests.
if (!$switch{'skip-basic'}) {
    # Have checksetup create an empty DB.
    print "---------------------------------------------\n";
    print "Creating a blank database called $My_Db_Name...\n";
    print "---------------------------------------------\n\n";
    # We only want to test the chart migration once (because it's slow), so 
    # let's do it here.
    system("cp -r data/mining.bak data/mining");
    db()->drop_db($My_Db_Name);
    check_test("Test of creating an empty database", 
        run_against_db());
    system("rm -rf data/mining");
}

# If we're running --full or if we have version numbers, test that stuff.
# But if we failed to do the basic runs, then don't test that stuff.
if (scalar @runversions && !$Total_Failures) {
    # Now run against every version that we have a database for.
    foreach my $version (sort @runversions) {
        print "---------------------------------------------\n";
        print "Testing against database from version $version...\n";
        print "---------------------------------------------\n\n";
        check_test("Test against database from version $version",
                   run_against_db($DB_LIST{$version}, "quickly"));
    }
}

print "\nTest complete. Failed $Total_Failures time(s).\n";
exit $Total_Failures;

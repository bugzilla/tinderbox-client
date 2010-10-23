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
# The Original Code is the Bugzilla Installation Test System.
#
# The Initial Developer of the Original Code is Everything Solved.
# Portions created by Everything Solved are Copyright (C) 2006
# Everything Solved. All Rights Reserved.
#
# Contributor(s): Max Kanat-Alexander <mkanat@bugzilla.org>

use strict;
use warnings;

package Tinderbox::DB::MySQL;

use DBI;
use File::Basename;
use File::Path;
use File::Temp;
use IPC::Cmd;

use base qw(Tinderbox::DB);
use fields qw(
    _mysql
);

use constant MAX_RETRIES => 3;

sub new {
    my $class = shift;
    my $params = shift;
    my $self = {};
    bless($self, $class);
    return $self;
}

sub drop_db {
    my ($self, $db) = @_;
    my ($user, $pass) = ($self->{_user}, $self->{_password});
    print "Dropping $db...\n";
    system("mysql -u $user -p$pass -e 'DROP DATABASE $db'");
}

sub copy_db {
    my ($self, $params_ref) = @_;
    my %params = %$params_ref;
    my ($from, $to) = ($params{from}, $params{to});
    my $from_host = $params{from_host};
    my ($user, $pass) = ($self->{_user}, $self->{_password});

    # The mysqldump often fails, so we want to retry until it succeeds, up
    # to a certain number of retries.
    my $success = 0;
    my $tries = 0;
    my $mysql_cmd = "mysql -u $user -p$pass $to";
    while (!$success && $tries < MAX_RETRIES) {
        $tries++;
        print "Retrying (Try $tries)..." if $tries > 1;
        if ($self->db_exists($to)) {
            if ($params{overwrite}) {
                $self->drop_db($to);
            }
            else {
                die "You attempted to copy to '$to' but that database already"
                    . " exists.";
            }
        }

        my $extra_args = "";
        my $dump_dir;
        if ($from_host) {
            $extra_args = "-h $from_host | $mysql_cmd";
        }
        else {
            $dump_dir = File::Temp::tempdir(CLEANUP => 1);
            chmod 0777, $dump_dir;
            $extra_args = "--tab=$dump_dir";
        }

        print "Creating $to...\n";
        system("mysqladmin -u $user -p$pass create $to");
        print "Dumping $from...";
        my $start = time;
        my ($ok, $err, $all, $stdout, $stderr) = IPC::Cmd::run(
            command => "mysqldump --opt --single-transaction -u $user -p$pass"
                       . " $from $extra_args");
        my $seconds = time - $start;
        print "($seconds seconds)\n";
        $success = $ok && !@$stderr;
        if (!$success) {
            $params{overwrite} = 1; # So that we can repeat it.
            sleep 3; # Wait a few seconds for any error to clear.
            print @$stderr;
            next;
        }

        # Locally, it's much faster to use LOAD DATA INFILE. We can't
        # directly use mysqlimport because it doesn't have an option to
        # ignore foreign keys.
        if (!$from_host) {
            print "Creating tables for $to...\n";
            system("mysqldump -u $user -p$pass $from --no_data | $mysql_cmd");
            my $commands = "SET foreign_key_checks = 0;\n";
            foreach my $file (glob "$dump_dir/*.txt") {
                my $table = basename($file);
                $table =~ s/\.txt$//;
                $commands .= "LOAD DATA INFILE '$file' INTO TABLE $table
                                 CHARACTER SET binary;\n";
            }
            print "Importing data from $from into $to...";
            my $import_start = time;
            system("mysql", "-u", $user, "-p$pass", "-e $commands", 
                   $to);
            my $import_time = time - $import_start;
            print "($import_time seconds)\n";
            File::Path::rmtree($dump_dir);
        }
    }

}

sub db_exists {
    my ($self, $db) = @_;
    my $sth = $self->_mysql->prepare('SHOW DATABASES LIKE ?');
    $sth->execute($db);
    return $sth->fetchrow_array() ? 1 : 0;
}

sub reset {
    system("rm -rf schema-*sorted");
}

sub create_schema_map {
    my ($self, $for_db) = @_;
    my ($user, $pass) = ($self->{_user}, $self->{_password});

    my $schema_dir = "schema-$for_db";
    my $sorted_dir = "$schema_dir-sorted";

    # Create the directories
    mkdir $schema_dir;
    mkdir $sorted_dir;

    chdir $schema_dir;

    # Create the basic map
    system("mysqldump --opt -u$user -p$pass --no-data -T. $for_db");
    # Remove the comments
    system(q{sed -i 's/^--.*$//' *.sql});
    # Remove commas from ends of lines, because they can cause
    # false positives when we check for schema differences
    system(q{sed -i 's/,$//' *.sql});
    # Moving from PACK_KEYS to not having it is a schema
    # change we don't care about.
    system(q{sed -i 's/ PACK_KEYS=1//' *.sql});
    # Upgraded DBs have AUTO_INCREMENT in their CREATE TABLE, but new DBs
    # don't.
    system(q{perl -i -pe 's/ AUTO_INCREMENT=\d+//' *.sql});
    # XXX Ignore custom fields. This is somewhat of a hack.
    system(q{perl -pe 's/^\s+`cf.*\n//' -i bugs.sql});
    system(q{rm -f cf_*.sql});
    system(q{rm -f bug_cf*.sql});
    # Create the sorted map
    system("find . -name \\*.sql -exec sort \\{\\}"
           . " -o ../$sorted_dir/\\{\\} \\;");

    chdir '..';

    File::Path::rmtree($schema_dir);

    return $sorted_dir;
}

sub sql_random { return "RAND()"; }

sub _mysql {
    my $self = shift;
    return $self->{_mysql} if $self->{_mysql};
    my $dsn = "DBI:mysql:";
    my $connection = DBI->connect($dsn, $self->{_user}, $self->{_password},
        {  RaiseError => 1, AutoCommit => 1, PrintError => 0, TaintIn => 1,
           ShowErrorStatement => 1, FetchHashKeyName => 'NAME_lc' });
    $self->{_mysql} = $connection;
    return $self->{_mysql};
}

1;

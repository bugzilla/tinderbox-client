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
# The Initial Developer of the Original Code is BugzillaSource, Inc.
# Portions created by the Initial Developer are Copyright (C) 2010
# the Initial Developer. All Rights Reserved.
#
# Contributor(s): 
#   Max Kanat-Alexander <mkanat@bugzilla.org>

use strict;
use warnings;

package Tinderbox::DB::SQLite;

use DBI;
use File::Basename;
use File::Path;
use File::Temp;
use IPC::Cmd;

use base qw(Tinderbox::DB);

our $DB_DIR = "data/db";

sub new {
    my $class = shift;
    my $params = shift;
    my $self = {};
    bless($self, $class);
    return $self;
}

sub drop_db {
    my ($self, $db) = @_;
    print "Dropping $db...\n";
    system("rm", "-f", "$DB_DIR/$db");
}

sub copy_db {
    my ($self, $params_ref) = @_;
    my %params = %$params_ref;
    my ($from, $to) = ($params{from}, $params{to});
    my $from_host = $params{from_host};

    if ($self->db_exists($to)) {
        if ($params{overwrite}) {
            $self->drop_db($to);
        }
        else {
            die "You attempted to copy to '$to' but that database already"
                . " exists.";
        }
    }

    if ($from_host) {
        system('scp', "$from_host:$from.sql", "$DB_DIR/$to.sql");
        system('sqlite3', "-init", "$DB_DIR/$to.sql", "$DB_DIR/$to");
        unlink "$DB_DIR/$to.sql";
        return;
    }

    system('cp', '-a', "$DB_DIR/$from", "$DB_DIR/$to");
}


sub db_exists {
    my ($self, $db) = @_;
    return -e "$DB_DIR/$db" ? 1 : 0;
}

sub reset {
}

sub sql_random { return "RANDOM()"; }

1;

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

package Tinderbox::DB;

use fields qw(
    _user
    _password
);

sub new {
    my $class  = shift;
    my $driver = shift;
    my $module = "Tinderbox/DB/$driver.pm";
    require $module;

    my $self = "Tinderbox::DB::$driver"->new(@_);

    my $params = shift;
    $self->{_user} = $params->{user};
    $self->{_password} = $params->{password};
    return $self;
}

sub diff_schema {
    my ($self, $from, $to) = @_;
    my $from_dir = "schema-$from-sorted";
    my $to_dir   = "schema-$to-sorted";
    $self->create_schema_map($from) if !-d $from_dir;
    $self->create_schema_map($to)   if !-d $to_dir;
    return `diff -Nruw $from_dir $to_dir`;
    File::Path::rmtree($to_dir);
}
1;

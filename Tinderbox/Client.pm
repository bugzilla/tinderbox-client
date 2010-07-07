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
# The Original Code is the Tinderbox Client.
#
# Contributor(s): Max Kanat-Alexander <mkanat@bugzilla.org>
#

use strict;
package Tinderbox::Client;
# We segfault on perl 5.6.0.
use 5.006001;

our $VERSION = '2.00';

use Tinderbox::Client::Config;
use Tinderbox::Client::Mailer;

use Fcntl qw(SEEK_SET LOCK_EX LOCK_UN);
use Cwd 2.19 qw(abs_path);
use IO::File;
use IO::String;
use File::Temp;
use File::Basename;

use fields qw(
    email_from
    email_to
    tinderbox_name
    build_name
    start_time
    current_status
    failure_strings
    lock_file
    lock_handle
    warning_strings
    tinderbox_log
    failure_count
    warning_count
    print_environment
    max_idle_time
    run_dir
    self_dir
    sleep_time
    check_stderr
    test_commands
    _log_handle
    _mailer
    _last_run_file
);

# Tinderbox constants that are not configurable;
use constant FAIL_STRING   => 'fatal error: The following error trigger was found:';
use constant WARN_STRING   => 'non-fatal error: The following warning trigger was found:';
# Six hours
use constant DEFAULT_IDLE_TIME => 21600;
# Five minutes
use constant DEFAULT_SLEEP_TIME => 300;

sub new {
    my ($class, $params) = @_;
    my $self = fields::new($class);

    # Mandatory fields
    $self->{email_from}      = $params->{Admin};
    $self->{email_to}        = $params->{To};
    $self->{tinderbox_name}  = $params->{Tinderbox};
    $self->{build_name}      = $params->{Build};
    $self->{failure_strings} = $params->{'Failure Strings'};
    $self->{test_commands}   = $params->{Commands};

    # Fields with defaults
    $self->{warning_strings}   = ($params->{'Warning Strings'} || []);
    $self->{check_stderr}      = ($params->{Stderr} || 1);
    $self->{sleep_time}        = ($params->{Sleep}  || DEFAULT_SLEEP_TIME);
    $self->{max_idle_time}     = ($params->{Idle}   || DEFAULT_IDLE_TIME);
    $self->{run_dir}           = ($params->{Dir}    || dirname(abs_path($0)));
    $self->{print_environment} = ($params->{Env}    || 1);

    if (my $lock = $params->{Lock}) {
        $self->{lock_handle} = IO::File->new($lock, '>>') || die "$lock: $!";
        $self->{lock_file} = $lock;
    }

    # Fields that cannot be set by the user
    $self->{self_dir}        = dirname(abs_path($0));
    $self->{tinderbox_log}   = '';
    $self->{_log_handle}     = new IO::String($self->{tinderbox_log});
    $self->{_mailer}         = new Tinderbox::Client::Mailer($self, 
                                   Tinderbox::Client::Config::MAIL_METHOD);
    $self->{_last_run_file}  = '.' . $self->{tinderbox_name} . '-' 
                               . $self->{build_name} . '-last_run';
    # Eliminate spaces for the convenience of the user if they need 
    # to check the file manually.
    $self->{_last_run_file} =~ s/ /_/g;
    $self->_reset();

    return $self;
}

sub check_errors {
    # Go through the failure states
    my ($self, $params) = @_;
    $params ||= {};
    foreach my $current_state (@{$self->{failure_strings}}) {
        if ($self->{tinderbox_log} =~ /\Q$current_state\E/) {
            $self->{failure_count}++;
            my $fail_string = FAIL_STRING . " $current_state\n";
            print $fail_string if $params->{print_errors};
        }
    }

    # And also the warning states
    foreach my $current_state (@{$self->{warning_strings}}) {
        if($self->{tinderbox_log} =~ /\Q$current_state\E/) {
            $self->{warning_count}++;
            my $warn_string = WARN_STRING . " $current_state\n";
            print $warn_string if $params->{print_warnings};
        }
    }

    return $self->{failure_count};
}

sub check_stderr {
    my ($self, $error_fh) = @_;
    my @err_output = $error_fh->getlines();
    if (@err_output) {
        print "\n*****************************************************\n";
        print "* Output found on stderr:\n";
        print join("", @err_output);
        print "\n";
        print "*****************************************************\n\n";
    }
    return @err_output ? 1 : 0;
}

sub check_if_run_needed {
    if (-d 'CVS') {
        # XXX This is NOT cross-platform compatible.
        # If we're up-to-date on our cvs checkout...
        my $cvs_output = "";
        $cvs_output = `cvs status 2>&1 | grep 'Status:' | egrep -v 'Up-to-date|status: Examining|Locally Modified'`;
        return $cvs_output;
    }

    my $missing = system("bzr missing --theirs-only");
# Exit values:
#    1 - some missing revisions
#    0 - no missing revisions
    return $missing;
}

sub failure {
    my ($self, $fail_message) = @_;
    (print $fail_message . "\n") if $fail_message;
    print "\nFailed with $self->{failure_count} failures and"
          . " $self->{warning_count} warnigs.\n";
    $self->{current_status} = 'busted';
    $self->send_mail(); # send the failure email
}

sub test_failed {
    my ($self, $test_fail_message) = @_;
    (print $test_fail_message . "\n") if $test_fail_message;
    $self->{current_status} = 'testfailed';
    $self->send_mail();
}

# Returns the last time we actually ran a test.
sub get_last_run {
    my ($self) = @_;
    my $file_name = $self->{self_dir} . '/' . $self->{_last_run_file};
    open(LAST_RUN, '<', $file_name)
        or (warn "Could not open last-run file $file_name: $!" and return 0);
    my $last_run = <LAST_RUN>;
    close LAST_RUN;
    chomp($last_run);
    return $last_run;
}

# Stores the fact that we actually just ran a test, now.
sub save_last_run {
    my ($self) = @_;
    my $file_name = $self->{self_dir} . '/' . $self->{_last_run_file};
    open(LAST_RUN, '+>', $file_name)
        or warn "Could not write last-run file $file_name: $!";
    print LAST_RUN time();
    close LAST_RUN;
}

# Resets internal parameters to the default.
sub _reset {
    my ($self) = @_;

    $self->{start_time}      = 0;
    $self->{current_status}  = '';
    $self->{_log_handle}->truncate();
    $self->{_log_handle}->seek(0, SEEK_SET);
    $self->{failure_count}   = 0;
    $self->{warning_count}   = 0;
}

sub _take_lock {
    my $self = shift;
    return if !$self->{lock_handle};
    print "Waiting for lock on " . $self->{lock_file} . "...\n";
    flock($self->{lock_handle}, LOCK_EX);
}

sub _release_lock {
    my $self = shift;
    return if !$self->{lock_handle};
    flock($self->{lock_handle}, LOCK_UN);
}

sub run {
    my ($self) = @_;

    while (1) {
        $self->_take_lock();
        $self->run_once();
        $self->_release_lock();
        # We don't want to sleep the full time if we already took a while
        # to run.
        my $sleep_time = $self->{sleep_time} - (time() - $self->{start_time});
        $sleep_time = 0 if $sleep_time < 0;
        print "\nSleeping $sleep_time seconds...\n";
        sleep($sleep_time);
    }
}

sub run_once {
    my ($self) = @_;

    $self->_reset();
    $self->{start_time} = time();
    if(!chdir($self->{self_dir})) {
        $self->failure("Cannot change directory to $self->{self_dir}: $!");
        return; 
    }

    # STDOUT goes to both the $log and STDOUT
    open my $old_stdout, ">&STDOUT" or die ("Can't save STDOUT: $!");
    tie local *STDOUT, 'Tinderbox::Client::TEE', $old_stdout, $self->{_log_handle};

    # And so does stderr
    open my $old_stderr, ">&STDERR" or die ("Can't save STDERR: $!");
    tie local *STDERR, 'Tinderbox::Client::TEE', $old_stderr, $self->{_log_handle};

    # Print the init message
    print <<END;
*****************************************************
* Starting tinderbox session at $self->{start_time}...
* machine administrator is $self->{email_from}
* tinderbox version is $VERSION: for $self->{tinderbox_name} $self->{build_name}
*****************************************************

END

    if ($self->{print_environment}) {
        # Dump the environment variables
        print "*****************************************************\n";
        print "* Dumping env vars...\n";
        foreach my $key (keys %ENV) {
            print "* $key = $ENV{$key}\n";
        }
        print "* env vars dumped...\n";
        print "*****************************************************\n\n";
    }

    print "Running out of " . abs_path($self->{run_dir}) . "\n\n";

    # Move into the directory where we will do our tests.
    if(!chdir($self->{run_dir})) {
        $self->failure("Cannot change directory to $self->{run_dir}: $!") ;
        return;
    }

    print "*****************************************************\n";
    print "* Checking if we need to run...\n";

    # We need to be in the directory where the tests run
    local $SIG{__DIE__} = \&Carp::confess;
    local $SIG{PIPE}    = \&Carp::confess;

    # Determine whether or not we need to actually run the tests.
    my $run_needed = $self->check_if_run_needed();
    if (!$run_needed) {
        print "* Found no updates that require us to run.\n";
        # If we have been idle too long, run the test anyway, so tinderbox
        # doesn't drop us. Otherwise, just skip this run.
        if ($self->{start_time} - $self->get_last_run() > $self->{max_idle_time}) {
            print "* Running anyway, maximum idle time of"
                  . " $self->{max_idle_time} seconds exceeded.\n";
        }
        else {
            return;
        }
    }

    # This is where a "run" officially starts.
    $self->{current_status} = 'building';
    # Send the mail that says we're underway.
    $self->send_mail();
    $self->save_last_run();

    if (-d 'CVS') {
        print "* Running cvs update...\n";
        print `cvs -q update -dP 2>&1`;
        print "* cvs update complete\n";
    }
    else {
        print "* Running bzr pull...\n";
        print `bzr pull 2>&1`;
        print "* bzr pull complete\n";
    }
    print "*****************************************************\n\n";

    if ($self->check_errors({print_errors => 1})) {
        $self->failure();
        return;
    }

    foreach my $command (@{$self->{test_commands}}) {
        print "*****************************************************\n";
        print "* Running $command...\n";
        if ($self->{check_stderr}) {
            my $error_fh = new File::Temp(DIR => $self->{self_dir});
            my $error_filename = $error_fh->filename;
            # This is so that we can scan the error log for messages.
            my $full_command = '((' . $command . ')' .  
                "3>&1 1>&2 2>&3 | tee $error_filename) 2>&1";
            open TEST, "$full_command |";
            print "$_" while(<TEST>);
            close TEST;
            $self->{warning_count}++ if $self->check_stderr($error_fh);
            $error_fh->close();
        }
        else {
           open TEST, "($command) 2>&1 |";
           print "$_" while (<TEST>);
           close TEST;
        }
        print "* Running of $command complete\n";
        print "*****************************************************\n\n";
    }

    $self->check_errors({print_errors => 1, print_warnings => 1});

    if ($self->{failure_count}) {
        $self->{current_status} = 'busted';
    } 
    elsif ($self->{warning_count}) {
        $self->{current_status} = 'testfailed';
    }
    else {
        $self->{current_status} = 'success';
    }

    $self->send_mail();
}

# XXX Need to handle admin notifications for failures.
sub send_mail {
    my ($self) = @_;
    $self->{_mailer}->send_mail();
}

# Internal Package for splitting output across multiple filehandles.
package Tinderbox::Client::TEE;

sub TIEHANDLE {
    my $package = shift;
    my @handles = @_;
    bless \@handles => $package;
}

sub PRINT {
    my ($self, $data) = @_;
    foreach my $fh (@$self) {
        print $fh $data;
    }
}

1;

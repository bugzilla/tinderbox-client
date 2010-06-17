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

use strict;
package Tinderbox::Client::Mailer;

use Email::Simple;
use Email::Send;
use Tinderbox::Client::Config;

use fields qw(
    mail_method
    _mailer
    _tinderbox
);

sub new {
    my ($class, $tinderbox, $mail_method) = @_;
    my $self = fields::new($class);
    $self->{_tinderbox}  = $tinderbox;
    $self->{mail_method} = $mail_method;
    return $self;
}

sub create_mail {
    my ($self) = @_;
    my $mail = new Email::Simple('');
    $mail->header_set('From', $self->{_tinderbox}->{email_from});
    $mail->header_set('Errors-To', $self->{_tinderbox}->{email_to});
    $mail->header_set('To', $self->{_tinderbox}->{email_to});
    $mail->header_set('Subject', 'Tinderbox: ' . $self->{_tinderbox}->{tinderbox_name}
                                 . ' ' . $self->{_tinderbox}->{build_name}
                                 . ' ' . $self->{_tinderbox}->{start_time});

    my $body  = "tinderbox: builddate: " . $self->{_tinderbox}->{start_time} . "\n";
    $body .= "tinderbox: tree: "   . $self->{_tinderbox}->{tinderbox_name}   . "\n";
    $body .= "tinderbox: status: " . $self->{_tinderbox}->{current_status}   . "\n";
    $body .= "tinderbox: build: "  . $self->{_tinderbox}->{build_name}       . "\n";
    $body .= "tinderbox: errorparser: unix\ntinderbox: buildfamily: unix\n\n";
    $body .= $self->{_tinderbox}->{tinderbox_log};
    $mail->body_set($body);

    return $mail;
}

sub send_mail {
    my ($self) = @_;
    $self->{_mailer} = new Email::Send({
        mailer => $self->{mail_method},
        mailer_args => [ Host => Tinderbox::Client::Config::MAILSERVER ]
    }) if !defined $self->{_mailer};
    my $mail = $self->create_mail();
    $self->{_mailer}->send($mail);
}

1;

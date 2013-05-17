# Version: MPL 1.1/GPL 2.0/LGPL 2.1
#
# The contents of this file are subject to the Mozilla Public License Version
# 1.1 (the "License"); you may not use this file except in compliance with
# the License. You may obtain a copy of the License at
# http://www.mozilla.org/MPL/
#
# Software distributed under the License is distributed on an "AS IS" basis,
# WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
# for the specific language governing rights and limitations under the
# License.
#
# The Original Code is The Tinderbox Client.
#
# The Initial Developer of the Original Code is Zach Lipton.
# Portions created by the Initial Developer are Copyright (C) 2002
# the Initial Developer. All Rights Reserved.
#
# Contributor(s): Zach Lipton <zach@zachlipton.com>
#                 Max Kanat-Alexander <mkanat@kerio.com>
#

use strict;
package Tinderbox::Client::Config;

# By forcing us into a seperate package, we can keep ourselves out 
# of the namespace of the main script. When invoking config 
# constants, they should be Tinderbox::Client::Config::CONSTANT.

#===========================================================
#BUILD_NAME
# set this to the name of the tinderbox that you wish to 
# see displayed as the col. heading on the tinderbox server. 
# This should probably contain your OS.
use constant BUILD_NAME => "checksetup cg-bugs01";
#===========================================================

#===========================================================
#MAIL_METHOD
# How the Tinderclient should send email. Valid choices are
# anything that would be a valid choice for Email::Send's "mailer"
# parameter. For example: 'SMTP' or 'Sendmail'
use constant MAIL_METHOD => 'SMTP';
#===========================================================

#===========================================================
#MAILSERVER
# If you have selected SMTP as the mailing method, please select
# the smtp server that you plan to use (such as mail.mycompany.com).
use constant MAILSERVER => "localhost";
#===========================================================

#===========================================================
#TO_EMAIL
# set this to the email address that the results should be sent 
# to.
use constant TO_EMAIL => 'tinderbox-daemon@tinderbox.mozilla.org';
#===========================================================

#===========================================================
#TINDERBOX_PAGE
# set this to the page on the tinderbox (SeaMonkey, MozillaTest, 
# etc) that you wish to display this tinderboxen.
use constant TINDERBOX_PAGE => "Bugzilla"; 
#===========================================================

#===========================================================
#ADMIN
# set this to the email address of the person who should
# get trouble reports and who the tinderbox puts in the "From"
# header of emails it sends.
use constant ADMIN => 'wicked@sci.fi';
#===========================================================

#===========================================================
#CVS_MODULE
# set this to the module that you would like the tinderbox 
# client script to pull. If you use a script to pull, then 
# set this to the script so that it can be downloaded from 
# the server and set $prebuild so it will be run to do the 
# complete pull. The script should handle everything related to 
# pulling.
use constant CVS_MODULE => "Bugzilla";
#===========================================================

#===========================================================
#FAILURE_STATES
# This should be set to a list of rexexp patterns that will 
# indicate an error building the source. Be carful with this, 
# as if the pattern matches any output with the build it will 
# show up as a failure on the tinderbox page.
use constant FAILURE_STATES => ('FAILED','\[checkout aborted\]',
                                '\: cannot find module', '^C ');
#===========================================================

#===========================================================
#MIN_CYCLE_TIME
# This should be set to the minimum time between tinderbox
# test cycles.  This is to avoid overloading the server
# with lots of closely-spaced emails.  If the build and
# test process takes longer than this amount of time, the
# build and test process will restart immediately, however
# if it takes less, it will wait until this time has
# expired before restarting.
use constant MIN_CYCLE_TIME => 300;
#===========================================================

#===========================================================
# MAX_IDLE_TIME
use constant MAX_IDLE_TIME => 21600;
#===========================================================

1;

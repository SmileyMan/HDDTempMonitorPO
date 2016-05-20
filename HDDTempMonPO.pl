#!/usr/bin/perl
#############################################################################################
#
# Cron script for monitoring of Hard Drive temps - (c) Steve Miles 2016
#
#############################################################################################

#############################################################################################
#
# Created by Steve Miles (SmileyMan). http://stevemiles.me.uk
# Github page:                        https://github.com/SmileyMan/HDDTempMonitorPO
# My Github:                          https://github.com/SmileyMan
#
# Other Projects - snapPERL:          http://snapperl.stevemiles.me.uk
#                                     https://github.com/SmileyMan/snapPERL
#
# The MIT License (MIT) 
# Copyright (c) 2016 Steve Miles (SmileyMan) -    http://stevemiles.me.uk
#                                                 https://github.com/SmileyMan/
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this
# software and associated documentation files (the "Software"), to deal in the Software 
# without restriction, including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons 
# to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in 
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
# FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR 
# OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
# DEALINGS IN THE SOFTWARE.
#
#############################################################################################

package HDDTempMonitorPO;

our $VERSION = 0.2;

# Pragmas
use 5.010;
use strict;
use warnings;

# Used for messging
use LWP::UserAgent;

# Option hash used for script - Edit any details here - Get your UserKey and Token from http://pushover.net!
my %opt = ( pushOverUserKey     => '##############################', 
            pushOverToken       => '##############################',
            pushOverTitle       => 'HDD Temp Monitor',
            pushOverSound       => '',
            pushOverDevice      => '',
            pushOverExpire      => '',
            pushOverRetry       => '',
            pushOverUrl         => 'https://api.pushover.net/1/messages.json',
            hddtempX            => '/usr/sbin/hddtemp',
            hddTempWarn         => 40,
            hddTempCrit         => 50,
            useStdOut           => 0,
            poMessageLevelNorm  => -2,
            poMessageLevelWarn  => -1,
            poMessageLevelCrit  => 1,
            reportAll           => 0,
          );

# Holds result of call to hddtemp
my $hddTemp;
# Holds message to Pushover
my $messagePO;
# Message level
my $messageLevelPO = $opt{poMessageLevelNorm};

# hddtemp installed?
if ( -f $opt{hddtempX} ) {
  # Call hddtemp for sda->sdzz (More drives? WOW - Just edit)
  $hddTemp = qx{$opt{hddtempX} /dev/sd[a-zz] 2>&1};
}
else {
  # You need to install hddtemp!
  say "hddtemp not installed? - Ubuntu: sudo apt-get install hddtemp smartmontools";
  # Exit script
  exit(1);
}

# Process return from hddtemp
foreach my $line (split /\n/, $hddTemp) {
  
  # Line starts with a / so process
  if ( $line =~ m/^\// ) {
    
    # Get Disk, Model and Status text
    my ($disk, $model, $text) = $line =~ m/(.+?):(.+?):\s(.+)/i;
    
    # Remove whitespace
    $model  =~ s/^\s+|\s+$//;
    $disk   =~ s/^\s+|\s+$//;
    
    # Disk status shows temp?
    if ( $text =~ m/\d{1,2}/ ) {
      
      # Get Temp and Unit
      my ($temp, $unit) = $text =~ m/(\d{1,2})(.+)/;
      
      # Remove whitespace
      $temp   =~ s/^\s+|\s+$//;
      $unit   =~ s/^\s+|\s+$//;
      
      # Check drive and report if needed.
      if ( $temp > $opt{hddTempWarn} ) {
        $messageLevelPO = $temp > $opt{hddTempCrit} ? $opt{poMessageLevelWarn} : $opt{poMessageLevelWarn};
        $messagePO     .= $temp > $opt{hddTempCrit} ? "--- Critical ---\n"     : "--- Warning ---\n";
        $messagePO     .= "Disk: $disk\n";
        $messagePO     .= "Model: $model\n";
        $messagePO     .= "Temp: $temp$unit\n";
        
      }
      # Report ALL? - Running on 15/30min cron this would be excesive - More for checking it works ok
      elsif ( $opt{reportAll} ) { 
        $messagePO     .= "--- Normal ---\n";
        $messagePO     .= "Disk: $disk\n";
        $messagePO     .= "Model: $model\n";
        $messagePO     .= "Temp: $temp$unit\n";
      }
      # Send to stndout
      if ( $opt{useStdOut} ) {
        say '';
        say "Disk: $disk";
        say "Model: $model";
        say "Temp: $temp$unit";
      } 
      # else using cron so pointless
    }
    # Status had no temp in it. Disk could be sleeping
    else {
      # Report ALL? - Running on 15/30min cron this would be excesive - More for checking it works ok
      if ( $opt{reportAll} ) { 
        $messagePO     .= "--- Normal ---\n";
        $messagePO     .= "Disk: $disk\n";
        $messagePO     .= "Status: $text\n";
      }
      # send to stdout
      if ( $opt{useStdOut} ) {  
        say '';    
        say "Disk: $disk";
        say "Status: $text";
      }
    }
  }
  else {
    # send to stdout
    if ( $opt{useStdOut} ) {
      say "Permision denied or no output  - Running has root (sudo)?";
    } 
    #else - using cron - But you test it work first RIGHT?
  }
}

if ( $messagePO ) {
  # Send message
  my $poSent = send_message_po (       
      poPriority  => $messageLevelPO,
      poDevice    => $opt{pushOverDevice},
      poTitle     => $opt{pushOverTitle},
      poSound     => $opt{pushOverSound},
      poMessage   => $messagePO,
      poRetry     => $opt{pushOverRetry},
      poExpire    => $opt{pushOverExpire},
    );

  if ( $opt{useStdOut} ) {
    # Inform if message sent
    my $poStatus = $poSent ? 'Success' : 'Failed';
    say "Pushover message status: $poStatus";
  }
}

##
# sub send_message_po();
# Sends message to pushover API 
# usage send_message( %options_hash );
# return 1 is successfull
sub send_message_po {
  
  # Get passed options
  my %optHash = @_;
  
  # No Message?
  if ( !$optHash{poMessage} ) { return 0; }

  # Valid Pushover sounds
  my @poSounds = qw{  
    pushover bike bugle cashregister classical cosmic falling gamelan incoming intermission 
    magic mechanical pianobar siren spacealarm tugboat alien climb persistent echo updown none
  };

  # Check sound valid and if not assign default - If empty then users default on device is used
  if ( !grep { $_ =~ /^$optHash{poSound}$/ } @poSounds and $optHash{poSound} != '' ) {
    $optHash{poSound} = 'pushover';
  }

  # Add default title if needed
  if ( not defined $optHash{poTitle} ) { $optHash{poTitle} = 'HDD Temp Monitor'; }

  # Priority must be between -2 and 2 - If not default to 0
  if ( not defined $optHash{poPriority} or $optHash{poPriority} > 2 or $optHash{poPriority} < -2 ) { $optHash{poPriority} = 0; }

  # Priority 2 can only be used with expire and retry -  If missing defult to 1
  if ( (not defined $optHash{poExpire} or not defined $optHash{poRetry}) and $optHash{poPriority} == 2) { $optHash{poPriority} = 1; }

  # Make sure expire setting is no less then 30 or more than 86400 seconds
  if ( defined $optHash{expire} ) { 
    $optHash{poExpire} = $optHash{poExpire} < 30 ? 30       : $optHash{poExpire}; 
    $optHash{poExpire} = $optHash{poExpire} < 86400 ? 86400 : $optHash{poExpire};
  }
  
  # Make sure expire setting is no less then 30 seconds
  if ( defined $optHash{expire} ) { 
    $optHash{poRetry} = $optHash{poRetry} < 30 ? 30 : $optHash{poRetry}; 
  }

  # Get LWP Agent
  my $userAgent = LWP::UserAgent->new;
  
  # Post request to pushover API
  my $response = $userAgent->post( $opt{pushOverUrl}, 
    [ 
      token     => $opt{pushOverToken},
      user      => $opt{pushOverUserKey},
      priority  => $optHash{poPriority},
      device    => $optHash{poDevice},
      title     => $optHash{poTitle},
      sound     => $optHash{poSound},
      message   => $optHash{poMessage}, 
      retry     => $optHash{poRetry},
      expire    => $optHash{poExpire},
    ]
  );
  
  # Did the post fail?
  if ( $response->is_success ) {
    return 1;
  }
  else {
    return 0;
  }
  return;
}

1;

__END__

#!/usr/bin/perl -w
# Check SMART status of ATA/SCSI disks, returning any usable metrics as perfdata.
# For usage information, run ./check_smart -h
#
# This script was created under contract for the US Government and is therefore Public Domain
#
# Changes and Modifications
# =========================
# Feb 3, 2009: Kurt Yoder - initial version of script (rev 1.0)
# Jul 8, 2013: Claudio Kuenzler - support hardware raids like megaraid (rev 2.0)
# Jul 9, 2013: Claudio Kuenzler - update help output (rev 2.1)
# Oct 11, 2013: Claudio Kuenzler - making the plugin work on FreeBSD (rev 3.0)
# Oct 11, 2013: Claudio Kuenzler - allowing -i sat (SATA on FreeBSD) (rev 3.1)
# Nov 4, 2013: Claudio Kuenzler - works now with CCISS on FreeBSD (rev 3.2)
# Nov 4, 2013: Claudio Kuenzler - elements in grown defect list causes warning (rev 3.3)
# Nov 6, 2013: Claudio Kuenzler - add threshold option "bad" (-b) (rev 4.0)
# Nov 7, 2013: Claudio Kuenzler - modified help (rev 4.0)
# Nov 7, 2013: Claudio Kuenzler - bugfix in threshold logic (rev 4.1)
# Mar 19, 2014: Claudio Kuenzler - bugfix in defect list perfdata (rev 4.2)
# Apr 22, 2014: Jerome Lauret - implemented -g to do a global lookup (rev 5.0)
# Apr 25, 2014: Claudio Kuenzler - cleanup, merge Jeromes code, perfdata output fix (rev 5.1)
# May 5, 2014: Caspar Smit - Fixed output bug in global check / issue #3 (rev 5.2)
# Feb 4, 2015: Caspar Smit and cguadall - Allow detection of more than 26 devices / issue #5 (rev 5.3)
# Feb 5, 2015: Bastian de Groot - Different ATA vs. SCSI lookup (rev 5.4)
# Feb 11, 2015: Josh Behrends - Allow script to run outside of nagios plugins dir / wiki url update (rev 5.5)
# Feb 11, 2015: Claudio Kuenzler - Allow script to run outside of nagios plugins dir for FreeBSD too (rev 5.5)
# Mar 12, 2015: Claudio Kuenzler - Change syntax of -g parameter (regex is now awaited from input) (rev 5.6)

use strict;
use Getopt::Long;

use File::Basename qw(basename);
my $basename = basename($0);

my $revision = '$Revision: 5.6 $';

use FindBin;
use lib $FindBin::Bin;
BEGIN {
 push @INC,'/usr/lib/nagios/plugins','/usr/lib64/nagios/plugins','/usr/local/libexec/nagios';
}
use utils qw(%ERRORS &print_revision &support &usage);

$ENV{'PATH'}='/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:/usr/local/sbin';
$ENV{'BASH_ENV'}='';
$ENV{'ENV'}='';

use vars qw($opt_b $opt_d $opt_g $opt_debug $opt_h $opt_i $opt_v);
Getopt::Long::Configure('bundling');
GetOptions(
                          "debug"       => \$opt_debug,
        "b=i" => \$opt_b, "bad=i"       => \$opt_b,
        "d=s" => \$opt_d, "device=s"    => \$opt_d,
        "g=s" => \$opt_g, "global=s"    => \$opt_g,
        "h"   => \$opt_h, "help"        => \$opt_h,
        "i=s" => \$opt_i, "interface=s" => \$opt_i,
        "v"   => \$opt_v, "version"     => \$opt_v,
);

if ($opt_v) {
        print_revision($basename,$revision);
        exit $ERRORS{'OK'};
}

if ($opt_h) {
        print_help();
        exit $ERRORS{'OK'};
}

my ($device, $interface) = qw//;
if ($opt_d || $opt_g ) {
        unless($opt_i){
                print "must specify an interface for $opt_d using -i/--interface!\n\n";
                print_help();
                exit $ERRORS{'UNKNOWN'};
        }

        # list of devices for a loop
        my(@dev);

        if ( $opt_d ){
            # normal mode - push opt_d on the list of devices
            push(@dev,$opt_d);
        } else {
            # glob all devices - try '?' first 
            @dev =glob($opt_g);
        }

        foreach my $opt_dl (@dev){
            warn "Found $opt_dl\n" if $opt_debug;
            if (-b $opt_dl || -c $opt_dl){
                $device .= $opt_dl.":";

            } else {
                warn "$opt_dl is not a valid block/character special device!\n\n" if $opt_debug;
            }
        }

        if ( ! defined($device) ){
            print "Could not find any valid block/character special device for ".
                  ($opt_d?"device $opt_d ":"pattern $opt_g")." !\n\n";
            exit $ERRORS{'UNKNOWN'};
        }

        # Allow all device types currently supported by smartctl
        # See http://www.smartmontools.org/wiki/Supported_RAID-Controllers
        if ($opt_i =~ m/(ata|scsi|3ware|areca|hpt|cciss|megaraid|sat)/) {
                $interface = $opt_i;
        } else {
                print "invalid interface $opt_i for $opt_d!\n\n";
                print_help();
                exit $ERRORS{'UNKNOWN'};
        }
}


if ($device eq "") {
    print "must specify a device!\n\n";
    print_help();
    exit $ERRORS{'UNKNOWN'};
}


my $smart_command = 'sudo smartctl';
my $exit_status = 'OK';
my $exit_status_local = 'OK';
my $status_string = '';
my $perf_string = '';
my $Terminator = ' --- ';


foreach $device ( split(":",$device) ){
    my @error_messages = qw//;
    my($status_string_local)='';
    my($tag,$label);
    $exit_status_local = 'OK';

    if ($opt_g){
        # we had a pattern based on $opt_g
        $tag   = $device;
        $tag   =~ s/$opt_g//;
        $label = "[$device] - ";
    } else {
        # we had a device specified using $opt_d (traditional)
        $label = "";
        $tag   = $device;
    }


    warn "###########################################################\n" if $opt_debug;
    warn "(debug) CHECK 1: getting overall SMART health status for $tag \n" if $opt_debug;
    warn "###########################################################\n\n\n" if $opt_debug;

    my $full_command = "$smart_command -d $interface -H $device";
    warn "(debug) executing:\n$full_command\n\n" if $opt_debug;

    my @output = `$full_command`;
    warn "(debug) output:\n@output\n\n" if $opt_debug;

    my $output_mode = "";
    # parse ata output, looking for "health status: passed"
    my $found_status = 0;
    my $line_str_ata = 'SMART overall-health self-assessment test result: '; # ATA SMART line
    my $ok_str_ata = 'PASSED'; # ATA SMART OK string

    my $line_str_scsi = 'SMART Health Status: '; # SCSI and CCISS SMART line
    my $ok_str_scsi = 'OK'; #SCSI and CCISS SMART OK string

    foreach my $line (@output){
        if($line =~ /$line_str_scsi(.+)/){
            $found_status = 1;
            $output_mode = "scsi";
            warn "(debug) parsing line:\n$line\n\n" if $opt_debug;
            if ($1 eq $ok_str_scsi) {
                warn "(debug) found string '$ok_str_scsi'; status OK\n\n" if $opt_debug;
            }
            else {
                warn "(debug) no '$ok_str_scsi' status; failing\n\n" if $opt_debug;
                push(@error_messages, "Health status: $1");
                escalate_status('CRITICAL');
            }
        }
        if($line =~ /$line_str_ata(.+)/){
            $found_status = 1;
            $output_mode = "ata";
            warn "(debug) parsing line:\n$line\n\n" if $opt_debug;
            if ($1 eq $ok_str_ata) {
                warn "(debug) found string '$ok_str_ata'; status OK\n\n" if $opt_debug;
            }
            else {
                warn "(debug) no '$ok_str_ata' status; failing\n\n" if $opt_debug;
                push(@error_messages, "Health status: $1");
                escalate_status('CRITICAL');
            }
        }
    }

    unless ($found_status) {
        push(@error_messages, 'No health status line found');
        escalate_status('UNKNOWN');
    }


    warn "###########################################################\n" if $opt_debug;
    warn "(debug) CHECK 2: getting silent SMART health check\n" if $opt_debug;
    warn "###########################################################\n\n\n" if $opt_debug;

    $full_command = "$smart_command -d $interface -q silent -A $device";
    warn "(debug) executing:\n$full_command\n\n" if $opt_debug;

    system($full_command);
    my $return_code = $?;
    warn "(debug) exit code:\n$return_code\n\n" if $opt_debug;

    if ($return_code & 0x01) {
        push(@error_messages, 'Commandline parse failure');
        escalate_status('UNKNOWN');
    }
    if ($return_code & 0x02) {
        push(@error_messages, 'Device could not be opened');
        escalate_status('UNKNOWN');
    }
    if ($return_code & 0x04) {
        push(@error_messages, 'Checksum failure');
        escalate_status('WARNING');
    }
    if ($return_code & 0x08) {
        push(@error_messages, 'Disk is failing');
        escalate_status('CRITICAL');
    }
    if ($return_code & 0x10) {
        push(@error_messages, 'Disk is in prefail');
        escalate_status('WARNING');
    }
    if ($return_code & 0x20) {
        push(@error_messages, 'Disk may be close to failure');
        escalate_status('WARNING');
    }
    if ($return_code & 0x40) {
        push(@error_messages, 'Error log contains errors');
        escalate_status('WARNING');
    }
    if ($return_code & 0x80) {
        push(@error_messages, 'Self-test log contains errors');
        escalate_status('WARNING');
    }
    if ($return_code && !$exit_status_local) {
        push(@error_messages, 'Unknown return code');
        escalate_status('CRITICAL');
    }

    if ($return_code) {
        warn "(debug) non-zero exit code, generating error condition\n\n" if $opt_debug;
    } else {
        warn "(debug) zero exit code, status OK\n\n" if $opt_debug;
    }


    warn "###########################################################\n" if $opt_debug;
    warn "(debug) CHECK 3: getting detailed statistics\n" if $opt_debug;
    warn "(debug) information contains a few more potential trouble spots\n" if $opt_debug;
    warn "(debug) plus, we can also use the information for perfdata/graphing\n" if $opt_debug;
    warn "###########################################################\n\n\n" if $opt_debug;

    $full_command = "$smart_command -d $interface -A $device";
    warn "(debug) executing:\n$full_command\n\n" if $opt_debug;
    @output = `$full_command`;
    warn "(debug) output:\n@output\n\n" if $opt_debug;
    my @perfdata = qw//;

    # separate metric-gathering and output analysis for ATA vs SCSI SMART output
    # Yeah - but megaraid is the same output as ata
    if ($output_mode =~ "ata") {
        foreach my $line(@output){
            # get lines that look like this:
            #    9 Power_On_Minutes        0x0032   241   241   000    Old_age   Always       -       113h+12m
            next unless $line =~ /^\s*\d+\s(\S+)\s+(?:\S+\s+){6}(\S+)\s+(\d+)/;
            my ($attribute_name, $when_failed, $raw_value) = ($1, $2, $3);
            if ($when_failed ne '-'){
                push(@error_messages, "Attribute $attribute_name failed at $when_failed");
                escalate_status('WARNING');
                warn "(debug) parsed SMART attribute $attribute_name with error condition:\n$when_failed\n\n" if $opt_debug;
            }
            # some attributes produce questionable data; no need to graph them
            if (grep {$_ eq $attribute_name} ('Unknown_Attribute', 'Power_On_Minutes') ){
                next;
            }
            push (@perfdata, "$attribute_name=$raw_value") if $opt_d;

            # do some manual checks
            if ( ($attribute_name eq 'Current_Pending_Sector') && $raw_value ) {
                if ($opt_b) {
                    if (($raw_value > 0) && ($raw_value >= $opt_b)) {
                        push(@error_messages, "$raw_value Sectors pending re-allocation");
                        escalate_status('WARNING');
                        warn "(debug) Current_Pending_Sector is non-zero ($raw_value)\n\n" if $opt_debug;
                    }
                    elsif (($raw_value > 0) && ($raw_value < $opt_b)) {
                        push(@error_messages, "$raw_value Sectors pending re-allocation (but less than threshold $opt_b)");
                        warn "(debug) Current_Pending_Sector is non-zero ($raw_value) but less than $opt_b\n\n" if $opt_debug;
                    }
                } else {
                    push(@error_messages, "Sectors pending re-allocation");
                    escalate_status('WARNING');
                    warn "(debug) Current_Pending_Sector is non-zero ($raw_value)\n\n" if $opt_debug;
                }
            }
        }

    } else {
        my ($current_temperature, $max_temperature, $current_start_stop, $max_start_stop) = qw//;
        foreach my $line(@output){
            if ($line =~ /Current Drive Temperature:\s+(\d+)/){
                $current_temperature = $1;
            }
            elsif ($line =~ /Drive Trip Temperature:\s+(\d+)/){
                $max_temperature = $1;
            }
            elsif ($line =~ /Current start stop count:\s+(\d+)/){
                $current_start_stop = $1;
            }
            elsif ($line =~ /Recommended maximum start stop count:\s+(\d+)/){
                $max_start_stop = $1;
            }
            elsif ($line =~ /Elements in grown defect list:\s+(\d+)/){
                my $defectlist = $1;
                # check for elements in grown defect list
                if ($opt_b) {
                    push (@perfdata, "defect_list=$defectlist;;$opt_b") if $opt_d;
                    if (($defectlist > 0) && ($defectlist >= $opt_b)) {
                        push(@error_messages, "$defectlist Elements in grown defect list (threshold $opt_b)");
                        escalate_status('WARNING');
                        warn "(debug) Elements in grown defect list is non-zero ($defectlist)\n\n" if $opt_debug;
                    }
                    elsif (($defectlist > 0) && ($defectlist < $opt_b)) {
                        push(@error_messages, "Note: $defectlist Elements in grown defect list");
                        warn "(debug) Elements in grown defect list is non-zero ($defectlist) but less than $opt_b\n\n" if $opt_debug;
                    }
                }
                else {
                    if ($defectlist > 0) {
                        push (@perfdata, "defect_list=$defectlist") if $opt_d;
                        push(@error_messages, "$defectlist Elements in grown defect list");
                        escalate_status('WARNING');
                        warn "(debug) Elements in grown defect list is non-zero ($defectlist)\n\n" if $opt_debug;
                    }
                }
            }
            elsif ($line =~ /Blocks sent to initiator =\s+(\d+)/){
                push (@perfdata, "sent_blocks=$1") if $opt_d;
            }
        }
        if($current_temperature){
            if($max_temperature){
                push (@perfdata, "temperature=$current_temperature;;$max_temperature") if $opt_d;
                if($current_temperature > $max_temperature){
                    warn "(debug) Disk temperature is greater than max ($current_temperature > $max_temperature)\n\n" if $opt_debug;
                    push(@error_messages, 'Disk temperature is higher than maximum');
                    escalate_status('CRITICAL');
                }
            }
            else{
                push (@perfdata, "temperature=$current_temperature") if $opt_d;
            }
        }
        if($current_start_stop){
            if($max_start_stop){
                push (@perfdata, "start_stop=$current_start_stop;$max_start_stop") if $opt_d;
                if($current_start_stop > $max_start_stop){
                    warn "(debug) Disk start_stop is greater than max ($current_start_stop > $max_start_stop)\n\n" if $opt_debug;
                    push(@error_messages, 'Disk start_stop is higher than maximum');
                    escalate_status('WARNING');
                }
            }
            else{
                push (@perfdata, "start_stop=$current_start_stop") if $opt_d;
            }
        }
    }
    warn "(debug) gathered perfdata:\n@perfdata\n\n" if $opt_debug;
    $perf_string = join(' ', @perfdata);
    
    warn "###########################################################\n" if $opt_debug;
    warn "(debug) LOCAL STATUS: $exit_status_local, FINAL STATUS: $exit_status\n" if $opt_debug;
    warn "###########################################################\n\n\n" if $opt_debug;
    
    if($exit_status_local ne 'OK'){
      if ($opt_g) {
        $status_string_local = $label.join(', ', @error_messages);
        $status_string .= $status_string_local.$Terminator;
      }
      else {
        $status_string = join(', ', @error_messages);
      }
    } 
    else {
      if ($opt_g) {
        $status_string_local = $label."Device is clean";
        $status_string .= $status_string_local.$Terminator;
      }
      else {
        $status_string = "no SMART errors detected. ".join(', ', @error_messages);
      }
    }

}

    warn "(debug) final status/output: $exit_status\n" if $opt_debug;

$status_string =~ s/$Terminator$//;
print "$exit_status: $status_string|$perf_string\n";
exit $ERRORS{$exit_status};


sub print_help {
        print_revision($basename,$revision);
        print "\nUsage: $basename {-d=<block device>|-g=<block device regex>} -i=(ata|scsi|3ware,N|areca,N|hpt,L/M/N|cciss,N|megaraid,N) [-b N] [--debug]\n\n";
        print "At least one of the below. -d supersedes -g\n";
        print "  -d/--device: a physical block device to be SMART monitored, eg /dev/sda\n";
        print "  -g/--global: a regular expression name of physical devices to be SMART monitored\n";
        print "               Example: '/dev/sd[a-z]' will search for all /dev/sda until /dev/sdz devices and report errors globally.\n";
        print "Note that -g only works with a fixed interface input (e.g. scsi, ata), not with special interface ids like cciss,1\n";
        print "\n";
        print "Other options\n";
        print "  -i/--interface: device's interface type\n";
        print "  (See http://www.smartmontools.org/wiki/Supported_RAID-Controllers for interface convention)\n";
        print "  -b/--bad: Threshold value (integer) when to warn for N bad entries\n";
        print "  -h/--help: this help\n";
        print "  --debug: show debugging information\n";
        print "  -v/--version: Version number\n";
}

# escalate an exit status IFF it's more severe than the previous exit status
sub escalate_status {
        my $requested_status = shift;
        # no test for 'CRITICAL'; automatically escalates upwards
        if ($requested_status eq 'WARNING') {
                return if ($exit_status|$exit_status_local) eq 'CRITICAL';
        }
        if ($requested_status eq 'UNKNOWN') {
                return if ($exit_status|$exit_status_local) eq 'WARNING';
                return if ($exit_status|$exit_status_local) eq 'CRITICAL';
        }
        $exit_status = $requested_status;
        $exit_status_local = $requested_status;
}

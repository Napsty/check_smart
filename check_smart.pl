#!/usr/bin/perl -w
# Check SMART status of ATA/SCSI/NVMe drives, returning any usable metrics as perfdata.
# For usage information, run ./check_smart -h
#
# This script was initially created under contract for the US Government and is therefore Public Domain
#
# Official documentation: https://www.claudiokuenzler.com/monitoring-plugins/check_smart.php
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
# Mar 12, 2015: Claudio Kuenzler - Change syntax of -g parameter (glob is now awaited from input) (rev 5.6)
# Feb 6, 2017: Benedikt Heine - Fix Use of uninitialized value $device (rev 5.7)
# Oct 10, 2017: Bobby Jones - Allow multiple devices for interface type megaraid, e.g. "megaraid,[1-5]" (rev 5.8)
# Apr 28, 2018: Pavel Pulec (Inuits) - allow type "auto" (rev 5.9)
# May 5, 2018: Claudio Kuenzler - Check selftest log for errors using new parameter -s (rev 5.10)
# Dec 27, 2018: Claudio Kuenzler - Add exclude list (-e) to ignore certain attributes (5.11)
# Jan 8, 2019: Claudio Kuenzler - Fix 'Use of uninitialized value' warnings (5.11.1)
# Jun 4, 2019: Claudio Kuenzler - Add raw check list (-r) and warning thresholds (-w) (6.0)
# Jun 11, 2019: Claudio Kuenzler - Allow using pseudo bus device /dev/bus/N (6.1)
# Aug 19, 2019: Claudio Kuenzler - Add device model and serial number in output (6.2)
# Oct 1, 2019: Michael Krahe - Allow exclusion from perfdata as well (-E) and by attribute number (6.3)
# Oct 29, 2019: Jesse Becker - Remove dependency on utils.pm, add quiet parameter (6.4)
# Nov 22, 2019: Claudio Kuenzler - Add Reported_Uncorrect and Reallocated_Event_Count to default raw list (6.5)
# Nov 29, 2019: Claudio Kuenzler - Add 3ware and cciss devices for global (-g) check, adjust output (6.6)
# Dec 4, 2019: Ander Punnar - Fix 'deprecation warning on regex with curly brackets' (6.6.1)
# Mar 25, 2020: Claudio Kuenzler - Add support for NVMe devices (6.7.0)
# Jun 2, 2020: Claudio Kuenzler - Bugfix to make --warn work (6.7.1)
# Oct 14, 2020: Claudio Kuenzler - Allow skip self-assessment check (--skip-self-assessment) (6.8.0)
# Oct 14, 2020: Claudio Kuenzler - Add Command_Timeout to default raw list (6.8.0)
# Mar 3, 2021: Evan Felix - Allow use of colons in pathnames so /dev/disk/by-path/ device names work (6.9.0)
# Mar 4, 2021: Claudio Kuenzler - Add SSD attribute Percent_Lifetime_Remain check (-l|--ssd-lifetime) (6.9.0)
# Apr 8, 2021: Claudio Kuenzler - Fix regex for pseudo-devices (6.9.1)
# Jul 6, 2021: Bernhard Bittner - Add aacraid devices (6.10.0)

use strict;
use Getopt::Long;
use File::Basename qw(basename);

my $basename = basename($0);
my $revision = '6.10.0';

# Standard Nagios return codes
my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);


$ENV{'PATH'}='/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:/usr/local/sbin';
$ENV{'BASH_ENV'}='';
$ENV{'ENV'}='';

use vars qw($opt_b $opt_d $opt_g $opt_debug $opt_h $opt_i $opt_e $opt_E $opt_r $opt_s $opt_v $opt_w $opt_q $opt_l $opt_skip_sa);
Getopt::Long::Configure('bundling');
GetOptions(
                          "debug"         => \$opt_debug,
        "b=i" => \$opt_b, "bad=i"         => \$opt_b,
        "d=s" => \$opt_d, "device=s"      => \$opt_d,
        "g=s" => \$opt_g, "global=s"      => \$opt_g,
        "h"   => \$opt_h, "help"          => \$opt_h,
        "i=s" => \$opt_i, "interface=s"   => \$opt_i,
        "e=s" => \$opt_e, "exclude=s"     => \$opt_e,
        "E=s" => \$opt_E, "exclude-all=s" => \$opt_E,
        "q"   => \$opt_q, "quiet"         => \$opt_q,
        "r=s" => \$opt_r, "raw=s"         => \$opt_r,
        "s"   => \$opt_s, "selftest"      => \$opt_s,
        "v"   => \$opt_v, "version"       => \$opt_v,
        "w=s" => \$opt_w, "warn=s"        => \$opt_w,
        "l"   => \$opt_l, "ssd-lifetime"  => \$opt_l,
			  "skip-self-assessment" => \$opt_skip_sa,
);

if ($opt_v) {
        print_revision($basename, $revision);
        exit $ERRORS{'OK'};
}

if ($opt_h) {
        print_help();
        exit $ERRORS{'OK'};
}

my ($device, $interface) = qw// // '';
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
            if (-b $opt_dl || -c $opt_dl || $opt_dl =~ m/^\/dev\/bus\/\d/) {
                $device .= $opt_dl."|";

            } else {
                warn "$opt_dl is not a valid block/character special device!\n\n" if $opt_debug;
            }
        }

        if (!defined($device) || $device eq "") {
            print "Could not find any valid block/character special device for ".
                  ($opt_d?"device $opt_d ":"pattern $opt_g")." !\n\n";
            exit $ERRORS{'UNKNOWN'};
        }

        # Allow all device types currently supported by smartctl
        # See http://www.smartmontools.org/wiki/Supported_RAID-Controllers

        if ($opt_i =~ m/(ata|scsi|3ware|areca|hpt|aacraid|cciss|megaraid|sat|auto|nvme)/) {
            $interface = $opt_i;
          if($interface =~ m/megaraid,\[(\d{1,2})-(\d{1,2})\]/) {
            $interface = "";
            for(my $k = $1; $k <= $2; $k++) {
              $interface .= "megaraid," . $k . "|";
            }
          }
          elsif($interface =~ m/3ware,\[(\d{1,2})-(\d{1,2})\]/) {
            $interface = "";
            for(my $k = $1; $k <= $2; $k++) {
              $interface .= "3ware," . $k . "|";
            }
          }
          elsif($interface =~ m/cciss,\[(\d{1,2})-(\d{1,2})\]/) {
            $interface = "";
            for(my $k = $1; $k <= $2; $k++) {
              $interface .= "cciss," . $k . "|";
            }
          }
          elsif($interface =~ m/aacraid,\[(\d{1,2})-(\d{1,2})\]/) {
            $interface = "";
            for(my $k = $1; $k <= $2; $k++) {
              $interface .= "aacraid," . $k . "|";
            }
          }
          else {
            $interface .= "|";
          }
        } else {
                print "invalid interface $opt_i for $opt_d!\n\n";
                print_help();
                exit $ERRORS{'UNKNOWN'};
        }
}


if ($device eq "") {
    print "UNKNOWN - Must specify a device!\n\n";
    print_help();
    exit $ERRORS{'UNKNOWN'};
}


my $smart_command = 'sudo smartctl';
my $exit_status = 'OK';
my $exit_status_local = 'OK';
my $status_string = '';
my $perf_string = '';
my $Terminator = ' --- ';
my $vendor = '';
my $model = '';
my $product = '';
my $serial = '';

# exclude lists
my @exclude_checks = split /,/, $opt_e // '' ;
my @exclude_perfdata = split /,/, $opt_E // '';
push(@exclude_checks, @exclude_perfdata);

# raw check list
my $raw_check_list = $opt_r // 'Current_Pending_Sector,Reallocated_Sector_Ct,Program_Fail_Cnt_Total,Uncorrectable_Error_Cnt,Offline_Uncorrectable,Runtime_Bad_Block,Reported_Uncorrect,Reallocated_Event_Count';
my @raw_check_list = split /,/, $raw_check_list;
push @raw_check_list, 'Percent_Lifetime_Remain' if $opt_l;

# raw check list for nvme
my $raw_check_list_nvme = $opt_r // 'Media_and_Data_Integrity_Errors';
my @raw_check_list_nvme = split /,/, $raw_check_list_nvme;

# warning threshold list (for raw checks)
my $warn_list = $opt_w // '';
$warn_list = $opt_w // 'Percent_Lifetime_Remain=90' if $opt_l;
my @warn_list = split /,/, $warn_list;
my %warn_list;
my $warn_key;
my $warn_value;
foreach my $warn_element (@warn_list) {
  ($warn_key, $warn_value) = split /=/, $warn_element;
  $warn_list{ $warn_key } = $warn_value;
}

# For backward compatibility, add -b parameter to warning thresholds
if ($opt_b) {
  $warn_list{ 'Current_Pending_Sector' } = $opt_b;
}

my @drives_status_okay;
my @drives_status_not_okay;
my $drive_details;

foreach $device ( split("\\|",$device) ){
	foreach $interface ( split("\\|",$interface) ){
		my @error_messages = qw//;
		my($status_string_local)='';
		my($tag,$label);
		$exit_status_local = 'OK';

		if ($opt_g){
			# we had a pattern based on $opt_g
			$tag   = $device;
			$tag   =~ s/\Q$opt_g\E//;
                        if($interface =~ qr/(?:megaraid|3ware|aacraid|cciss)/){
			  $label = "[$interface] - "; 
                        } else {
			  $label = "[$device] - ";
                        }
		} else {
			# we had a device specified using $opt_d (traditional)
			$label = "";
			$tag   = $device;
		}


		warn "###########################################################\n" if $opt_debug;
		warn "(debug) CHECK 1: getting overall SMART health status for $tag \n" if $opt_debug;
		warn "###########################################################\n\n\n" if $opt_debug;

		my $full_command = "$smart_command -d $interface -Hi $device";
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

		my $line_model_ata = 'Device Model: '; # ATA Model including vendor
		my $line_model_nvme = 'Model Number: '; # NVMe Model including vendor
		my $line_vendor_scsi = 'Vendor: '; # SCSI Vendor
		my $line_model_scsi = 'Product: '; # SCSI Model
		my $line_serial_ata = 'Serial Number: '; # ATA Drive Serial Number
		my $line_serial_scsi = 'Serial number: '; # SCSI Drive Serial Number

		foreach my $line (@output){
			if($line =~ /$line_str_scsi(.+)/){
				$found_status = 1;
				$output_mode = "scsi";
				warn "(debug) parsing line:\n$line\n" if $opt_debug;
				if ($1 eq $ok_str_scsi) {
					warn "(debug) found string '$ok_str_scsi'; status OK\n" if $opt_debug;
				}
				else {
					warn "(debug) no '$ok_str_scsi' status; failing\n" if $opt_debug;
					warn "(debug) no '$ok_str_scsi' status; failing but ignoring" if $opt_debug && $opt_skip_sa;
					push(@error_messages, "Health status: $1") unless $opt_skip_sa;
					escalate_status('CRITICAL') unless $opt_skip_sa;
				}
			}
			elsif($line =~ /$line_str_ata(.+)/){
				$found_status = 1;
				if ($interface eq 'nvme') {
					$output_mode = "nvme";
					warn "(debug) setting output mode to nvme\n" if $opt_debug;
				} else {
					$output_mode = "ata";
				}
				warn "(debug) parsing line:\n$line\n" if $opt_debug;
				if ($1 eq $ok_str_ata) {
					warn "(debug) found string '$ok_str_ata'; status OK\n" if $opt_debug;
				}
				else {
					warn "(debug) no '$ok_str_ata' status; failing\n" if $opt_debug;
					warn "(debug) no '$ok_str_ata' status; failing but ignoring\n" if $opt_debug && $opt_skip_sa;
					push(@error_messages, "Health status: $1") unless $opt_skip_sa;
					escalate_status('CRITICAL') unless $opt_skip_sa;
				}
			}
			if($line =~ /$line_model_ata(.+)/){
				warn "(debug) parsing line:\n$line\n\n" if $opt_debug;
				$model = $1;
				$model =~ s/\s{2,}/ /g;
				warn "(debug) found model: $model\n\n" if $opt_debug;
			}
			if($line =~ /$line_model_nvme(.+)/){
				warn "(debug) parsing line:\n$line\n\n" if $opt_debug;
				$model = $1;
				$model =~ s/\s{2,}/ /g;
				warn "(debug) found model: $model\n\n" if $opt_debug;
			}
			if($line =~ /$line_vendor_scsi(.+)/){
				warn "(debug) parsing line:\n$line\n\n" if $opt_debug;
				$vendor = $1;
				warn "(debug) found vendor: $model\n\n" if $opt_debug;
			}
			if($line =~ /$line_model_scsi(.+)/){
				warn "(debug) parsing line:\n$line\n\n" if $opt_debug;
				$product = $1;
				$model = "$vendor $product";
				$model =~ s/\s{2,}/ /g;
				warn "(debug) found model: $model\n\n" if $opt_debug;
			}
			if($line =~ /$line_serial_ata(.+)/){
				warn "(debug) parsing line:\n$line\n\n" if $opt_debug;
				$serial = $1;
				$serial =~ s/^\s+|\s+$//g;
				warn "(debug) found serial number $serial\n\n" if $opt_debug;
			}
			if($line =~ /$line_serial_scsi(.+)/){
				warn "(debug) parsing line:\n$line\n\n" if $opt_debug;
				$serial = $1;
				$serial =~ s/^\s+|\s+$//g;
				warn "(debug) found serial number $serial\n\n" if $opt_debug;
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

		if ($opt_s) {
			warn "(debug) selftest log check activated\n\n" if $opt_debug;
			$full_command = "$smart_command -d $interface -q silent -l selftest $device";
			system($full_command);
			my $return_code = $?;
			warn "(debug) exit code:\n$return_code\n\n" if $opt_debug;

			if ($return_code > 0) {
				push(@error_messages, 'Self-test log contains errors');
				warn "(debug) Self-test log contains errors\n\n" if $opt_debug;
				escalate_status('WARNING');
			}

			if ($return_code) {
				warn "(debug) non-zero exit code, generating error condition\n\n" if $opt_debug;
			} else {
				warn "(debug) zero exit code, status OK\n\n" if $opt_debug;
			}
		}

		warn "###########################################################\n" if $opt_debug;
		warn "(debug) CHECK 3: getting detailed statistics from attributes\n" if $opt_debug;
		warn "(debug) information contains a few more potential trouble spots\n" if $opt_debug;
		warn "(debug) plus, we can also use the information for perfdata/graphing\n" if $opt_debug;
		warn "###########################################################\n\n\n" if $opt_debug;

		$full_command = "$smart_command -d $interface -A $device";
		warn "(debug) executing:\n$full_command\n\n" if $opt_debug;
		@output = `$full_command`;
		warn "(debug) output:\n@output\n\n" if $opt_debug;
		my @perfdata = qw//;
		warn "(debug) Raw Check List: $raw_check_list\n" if $opt_debug;
		warn "(debug) Exclude List for Checks: ", join(",", @exclude_checks), "\n" if $opt_debug;
		warn "(debug) Exclude List for Perfdata: ", join(",", @exclude_perfdata), "\n" if $opt_debug;
		warn "(debug) Warning Thresholds:\n" if $opt_debug;
		for my $warnpair ( sort keys %warn_list ) { warn "$warnpair=$warn_list{$warnpair}\n" if $opt_debug; } 
		warn "\n" if $opt_debug;

		# separate metric-gathering and output analysis for ATA vs SCSI SMART output
		# Yeah - but megaraid is the same output as ata
		if ($output_mode =~ "ata") {
			foreach my $line(@output){
				# get lines that look like this:
				#    9 Power_On_Minutes        0x0032   241   241   000    Old_age   Always       -       113h+12m
				next unless $line =~ /^\s*(\d+)\s(\S+)\s+(?:\S+\s+){6}(\S+)\s+(\d+)/;
				my ($attribute_number, $attribute_name, $when_failed, $raw_value) = ($1, $2, $3, $4);
				if ($when_failed ne '-'){
					# Going through exclude list
					if (grep {$_ eq $attribute_number || $_ eq $attribute_name || $_ eq $when_failed} @exclude_checks) {
					  warn "SMART Attribute $attribute_name failed at $when_failed but was set to be ignored\n" if $opt_debug;
					} else {
					push(@error_messages, "Attribute $attribute_name failed at $when_failed");
					escalate_status('WARNING');
					warn "(debug) parsed SMART attribute $attribute_name with error condition:\n$when_failed\n\n" if $opt_debug;
					}
				}
				# some attributes produce questionable data; no need to graph them
				if (grep {$_ eq $attribute_name} ('Unknown_Attribute', 'Power_On_Minutes') ){
					next;
				}
				if (!grep {$_ eq $attribute_number || $_ eq $attribute_name} @exclude_perfdata) {
					push (@perfdata, "$attribute_name=$raw_value") if $opt_d;
				}

				# skip attribute if it was set to be ignored in exclude_checks
				if (grep {$_ eq $attribute_number || $_ eq $attribute_name} @exclude_checks) {
					warn "(debug) SMART Attribute $attribute_name was set to be ignored\n\n" if $opt_debug;
					next;
				} else {
				# manual checks on raw values for certain attributes deemed significant
				  if (grep {$_ eq $attribute_name} @raw_check_list) {
				    if ($raw_value > 0) {
				      # Check for warning thresholds
				      if ( ($warn_list{$attribute_name}) && ($raw_value >= $warn_list{$attribute_name}) ) {
				        warn "(debug) $attribute_name is non-zero ($raw_value)\n\n" if $opt_debug;
				        push(@error_messages, "$attribute_name is non-zero ($raw_value)");
				        escalate_status('WARNING');
				      } elsif ( ($warn_list{$attribute_name}) && ($raw_value < $warn_list{$attribute_name}) ) {
					warn "(debug) $attribute_name is non-zero ($raw_value) but less than $warn_list{$attribute_name}\n\n" if $opt_debug;
					push(@error_messages, "$attribute_name is non-zero ($raw_value) (but less than threshold $warn_list{$attribute_name})");
				      }
				      else {
				        warn "(debug) $attribute_name is non-zero ($raw_value)\n\n" if $opt_debug;
				        push(@error_messages, "$attribute_name is non-zero ($raw_value)");
				        escalate_status('WARNING');
				      }
				    } else {
					warn "(debug) $attribute_name is OK ($raw_value)\n\n" if $opt_debug;
				    }
				  } else {
				    warn "(debug) $attribute_name not in raw check list (raw value: $raw_value)\n\n" if $opt_debug;
				  }

				}
			}
		} elsif ($output_mode =~ "nvme") {
			foreach my $line(@output){
				next unless $line =~ /(\w.+):\s+(?:(\dx\d(?:\d?\w?)|\d(?:(?:,?\s?\d+,?\s?)?)+))/;
				my ($attribute_name, $raw_value) = ($1, $2);
				$raw_value =~ s/\s|,//g;
				$attribute_name =~ s/\s/_/g;

				# some attributes produce irrelevant data; no need to graph them
				if (grep {$_ eq $attribute_name} ('Critical_Warning') ){
					push (@exclude_perfdata, "$attribute_name");
				}
				# create performance data unless defined in exclude_perfdata list
				if (!grep {$_ eq $attribute_name} @exclude_perfdata) {
					push (@perfdata, "$attribute_name=$raw_value") if $opt_d;
				}

				# skip attribute if it was set to be ignored in exclude_checks
				if (grep {$_ eq $attribute_name} @exclude_checks) {
					warn "(debug) SMART Attribute $attribute_name was set to be ignored\n\n" if $opt_debug;
					next;
				}

				# Handle Critical_Warning values
				if ($attribute_name eq 'Critical_Warning') {
					if ($raw_value eq '0x01') {
					  push(@error_messages, "Available spare below threshold");
				          escalate_status('WARNING');
					}
					elsif ($raw_value eq '0x02') {
					  push(@error_messages, "Temperature is above or below thresholds");
				          escalate_status('WARNING');
					}
					elsif ($raw_value eq '0x03') {
					  push(@error_messages, "Available spare below threshold and temperature is above or below thresholds");
				          escalate_status('WARNING');
					}
					elsif ($raw_value eq '0x04') {
					  push(@error_messages, "NVM subsystem reliability degraded");
				          escalate_status('WARNING');
					}
					elsif ($raw_value eq '0x05') {
					  push(@error_messages, "Available spare below threshold and NVM subsystem reliability degraded");
				          escalate_status('WARNING');
					}
					elsif ($raw_value eq '0x06') {
					  push(@error_messages, "Temperature is above or below thresholds and NVM subsystem reliability degraded");
				          escalate_status('WARNING');
					}
					elsif ($raw_value eq '0x07') {
					  push(@error_messages, "Available spare below threshold and Temperature is above or below thresholds and NVM subsystem reliability degraded");
				          escalate_status('WARNING');
					}
					elsif ($raw_value eq '0x08') {
					  push(@error_messages, "Media in read only mode");
				          escalate_status('WARNING');
					}
					elsif ($raw_value eq '0x09') {
					  push(@error_messages, "Media in read only mode and Available spare below threshold");
				          escalate_status('WARNING');
					}
					elsif ($raw_value eq '0x0A') {
					  push(@error_messages, "Media in read only mode and Temperature is above or below thresholds");
				          escalate_status('WARNING');
					}
					elsif ($raw_value eq '0x0B') {
					  push(@error_messages, "Media in read only mode and Temperature is above or below thresholds and Available spare below threshold");
				          escalate_status('WARNING');
					}
					elsif ($raw_value eq '0x0C') {
					  push(@error_messages, "Media in read only mode and NVM subsystem reliability degraded");
				          escalate_status('WARNING');
					}
					elsif ($raw_value eq '0x0D') {
					  push(@error_messages, "Media in read only mode and NVM subsystem reliability degraded and Available spare below threshold");
				          escalate_status('WARNING');
					}
					elsif ($raw_value eq '0x0E') {
					  push(@error_messages, "Media in read only mode and NVM subsystem reliability degraded and Temperature is above or below thresholds");
				          escalate_status('WARNING');
					}
					elsif ($raw_value eq '0x0F') {
					  push(@error_messages, "Media in read only mode and NVM subsystem reliability degraded and Temperature is above or below thresholds");
				          escalate_status('WARNING');
					}
					elsif ($raw_value eq '0x10') {
					  push(@error_messages, "Volatile memory backup device failed");
				          escalate_status('WARNING');
					}
				}

				# manual checks on raw values for certain attributes deemed significan
				if (grep {$_ eq $attribute_name} @raw_check_list_nvme) {
					if ($raw_value > 0) {
					  # Check for warning thresholds
					  if ( ($warn_list{$attribute_name}) && ($raw_value >= $warn_list{$attribute_name}) ) {
					    warn "(debug) $attribute_name is non-zero ($raw_value)\n\n" if $opt_debug;
					    push(@error_messages, "$attribute_name is non-zero ($raw_value)");
					    escalate_status('WARNING');
					  } elsif ( ($warn_list{$attribute_name}) && ($raw_value < $warn_list{$attribute_name}) ) {
					    warn "(debug) $attribute_name is non-zero ($raw_value) but less than $warn_list{$attribute_name}\n\n" if $opt_debug;
					    push(@error_messages, "$attribute_name is non-zero ($raw_value) (but less than threshold $warn_list{$attribute_name})");
					  } else {
					    warn "(debug) $attribute_name is non-zero ($raw_value)\n\n" if $opt_debug;
					    push(@error_messages, "$attribute_name is non-zero ($raw_value)");
					    escalate_status('WARNING');
					  }
				       } else {
					    warn "(debug) $attribute_name is OK ($raw_value)\n\n" if $opt_debug;
				       }
				} else {
					warn "(debug) $attribute_name not in raw check list (raw value: $raw_value)\n\n" if $opt_debug;
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
			$status_string = $label.join(', ', @error_messages);
		  }
		  else {
			$drive_details = "Drive $model S/N $serial: ";
			$status_string = join(', ', @error_messages);
		  }
		  push @drives_status_not_okay, $status_string;
		} 
		else {
		  if ($opt_g) {
			$status_string = $label."Device is clean";
		  }
		  else {
			$drive_details = "Drive $model S/N $serial: no SMART errors detected. ";
			$status_string = join(', ', @error_messages);
		  }
		  push @drives_status_okay, $status_string;
		}
	}
}

warn "(debug) final status/output: $exit_status\n" if $opt_debug;

my @msg_list = ($drive_details) if $drive_details;

if (@drives_status_not_okay) {
	push @msg_list, grep { $_ } @drives_status_not_okay;
}

if (@drives_status_not_okay and $opt_q and @drives_status_okay) {
	push @msg_list, "Other drives OK";
} else {
	push @msg_list, grep { $_ } @drives_status_okay;
}


if ($opt_debug) {
	warn "(debug) drives  ok: @drives_status_okay\n";
	warn "(debug) drives nok: @drives_status_not_okay\n";
	warn "(debug)   msg_list: ".join('^', @msg_list)."\n\n";
}

$status_string = join( ($opt_g ? $Terminator : ' '), @msg_list);

# Final output: Nagios data and exit code
print "$exit_status: $status_string|$perf_string\n";
exit $ERRORS{$exit_status};

sub print_revision {
        ($basename, $revision) = @_;
        print "$basename v$revision\n";
        print "The monitoring plugins come with ABSOLUTELY NO WARRANTY. You may redistribute\ncopies of the plugins under the terms of the GNU General Public License.\nFor more information about these matters, see the file named COPYING.\n";

}


sub print_help {
        print_revision($basename,$revision);
        print "\nUsage: $basename {-d=<block device>|-g=<block device glob>} -i=(auto|ata|scsi|3ware,N|areca,N|hpt,L/M/N|aacraid,H,L,ID|cciss,N|megaraid,N) [-r list] [-w list] [-b N] [-e list] [-E list] [--debug]\n\n";
        print "At least one of the below. -d supersedes -g\n";
        print "  -d/--device: a physical block device to be SMART monitored, eg /dev/sda. Pseudo-device /dev/bus/N is allowed.\n";
        print "  -g/--global: a glob pattern name of physical devices to be SMART monitored\n";
        print "       Example: '/dev/sd[a-z]' will search for all /dev/sda until /dev/sdz devices and report errors globally.\n";
        print "       It is also possible to use -g in conjunction with megaraid devices. Example: -i 'megaraid,[0-3]'.\n";
        print "       Does not output performance data for historical value graphing.\n";
        print "Note that -g only works with a fixed interface (e.g. scsi, ata) and megaraid,N.\n";
        print "\n";
        print "Other options\n";
        print "  -i/--interface: device's interface type (auto|ata|scsi|nvme|3ware,N|areca,N|hpt,L/M/N|aacraid,H,L,ID|cciss,N|megaraid,N)\n";
        print "  (See http://www.smartmontools.org/wiki/Supported_RAID-Controllers for interface convention)\n";
        print "  -r/--raw Comma separated list of ATA or NVMe attributes to check\n";
        print "       ATA default: Current_Pending_Sector,Reallocated_Sector_Ct,Program_Fail_Cnt_Total,Uncorrectable_Error_Cnt,Offline_Uncorrectable,Runtime_Bad_Block,Command_Timeout\n";
        print "       NVMe default: Media_and_Data_Integrity_Errors\n";
        print "  -b/--bad: Threshold value for Current_Pending_Sector for ATA and 'grown defect list' for SCSI drives\n";
        print "  -w/--warn Comma separated list of thresholds for ATA drives (e.g. Reallocated_Sector_Ct=10,Current_Pending_Sector=62)\n";
        print "  -e/--exclude: Comma separated list of SMART attribute names or numbers which should be excluded (=ignored) with regard to checks\n";
        print "  -E/--exclude-all: Comma separated list of SMART attribute names or numbers which should be completely ignored for checks as well as perfdata\n";
        print "  -s/--selftest: Enable self-test log check\n";
        print "  -l/--ssd-lifetime: Check attribute 'Percent_Lifetime_Remain' available on some SSD drives\n";
        print "  --skip-self-assessment: Skip SMART self-assessment health status check\n";
        print "  -h/--help: this help\n";
        print "  -q/--quiet: When faults detected, only show faulted drive(s) (only affects output when used with -g parameter)\n";
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

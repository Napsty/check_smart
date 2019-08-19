check_smart monitoring plugin
===========

Full and up to date documentation
-------------------------
Please go to https://www.claudiokuenzler.com/monitoring-plugins/check_smart.php for a complete and updated documentation including examples and monitoring configurations.

Introduction
-------------------------
This is a fork of 2009's check_smart Nagios plugin by Kurt Yoder. 

The original plugin was and is still the best to monitor SMART values of hard drives and solid state drives.
However the original plugin was not able to handle other device types than ata or scsi.
Therefore drives attached to hardware raids like megaraid could not be checked.

This fork is modified in a way so it also works with disks attached to raid controllers... and other new features were added.

Warning for CCISS RAID 
-------------------------
Please be careful when using this plugin on drives behind a CCISS (HP) hardware raid controller. 
See http://www.claudiokuenzler.com/blog/413/freebsd-cciss-hp-smart-array-raid-wrong-disk-numbering-labeling for details.

History
-------------------------
```
    Feb 3, 2009: Kurt Yoder - initial version of script (rev 1.0)
    Jul 8, 2013: Claudio Kuenzler - support hardware raids like megaraid (rev 2.0)
    Jul 9, 2013: Claudio Kuenzler - update help output (rev 2.1)
    Oct 11, 2013: Claudio Kuenzler - making the plugin work on FreeBSD (rev 3.0)
    Oct 11, 2013: Claudio Kuenzler - allowing -i sat (SATA on FreeBSD) (rev 3.1)
    Nov 4, 2013: Claudio Kuenzler - works now with CCISS on FreeBSD (rev 3.2)
    Nov 4, 2013: Claudio Kuenzler - elements in grown defect list causes warning (rev 3.3)
    Nov 6, 2013: Claudio Kuenzler - add threshold option "bad" (-b) (rev 4.0)
    Nov 7, 2013: Claudio Kuenzler - modified help (rev 4.0)
    Nov 7, 2013: Claudio Kuenzler - bugfix in threshold logic (rev 4.1)
    Mar 19, 2014: Claudio Kuenzler - bugfix in defect list perfdata (rev 4.2)
    Apr 22, 2014: Jerome Lauret - implemented -g to do a global lookup (rev 5.0)
    Apr 25, 2014: Claudio Kuenzler - cleanup, merge Jeromes code, perfdata output fix (rev 5.1)
    May 5, 2014: Caspar Smit - Fixed output bug in global check / issue #3 (rev 5.2)
    Feb 4, 2015: Caspar Smit and cguadall - Allow detection of more than 26 devices / issue #5 (rev 5.3)
    Feb 5, 2015: Bastian de Groot - Different ATA vs. SCSI lookup (rev 5.4)
    Feb 11, 2015: Josh Behrends - Allow script to run outside of nagios plugins dir / wiki url update (rev 5.5)
    Feb 11, 2015: Claudio Kuenzler - Allow script to run outside of nagios plugins dir for FreeBSD too (rev 5.5)
    Mar 12, 2015: Claudio Kuenzler - Change syntax of -g parameter (regex is now awaited from input) (rev 5.6)
    Feb 6, 2017: Benedikt Heine - Fix Use of uninitialized value $device (rev 5.7)
    Oct 10, 2017: Bobby Jones - Allow multiple devices for interface type megaraid, e.g. "megaraid,[1-5]" (rev 5.8)
    Apr 28, 2018: Pavel Pulec (Inuits) - allow type "auto" (rev 5.9)
    May 5, 2018: Claudio Kuenzler - Check selftest log for errors using new parameter -s (rev 5.10)
    Dec 27, 2018: Claudio Kuenzler - Add exclude list (-e) to ignore certain attributes (5.11)
    Jan 8, 2019: Claudio Kuenzler - Fix 'Use of uninitialized value' warnings (5.11.1)
    Jun 4, 2019: Claudio Kuenzler - Add raw check list (-r) and warning thresholds (-w) (6.0)
    Jun 11, 2019: Claudio Kuenzler - Allow using pseudo bus device /dev/bus/N (6.1)
    Aug 19, 2019: Claudio Kuenzler - Add device model and serial number in output (6.2)
```

Sudoers entry
-------------------------
This plugin needs to run as root, otherwise you're not able to lauch smartctl correctly. 
You have two options

1) Launch the plugin itself as root with sudo

2) Lauch the plugin as Nagios user and the smartctl command as root with sudo

Entry in sudoers (of course adapt your paths if necessary):

    nagios   ALL = NOPASSWD: /usr/lib/nagios/plugins/check_smart.pl    # for option 1
    nagios   ALL = NOPASSWD: /usr/local/sbin/smartctl                  # for option 2


Successful tests/examples
-------------------------
SATA disk behind MDRaid (Software Raid) on Linux:

    /usr/lib/nagios/plugins/check_smart.pl -d /dev/sda -i ata

MegaRAID on Linux:

    /usr/lib/nagios/plugins/check_smart.pl -d /dev/sda -i megaraid,8
    
Intel RAID on FreeBSD 9.2 ("kldload mfip.ko" required):

    /usr/local/libexec/nagios/check_smart.pl -d /dev/pass0 -i scsi
    
SATA drives behind Intel RAID on FreeBSD 9.2 ("kldload mfip.ko" required):

    /usr/local/libexec/nagios/check_smart.pl -d /dev/pass12 -i sat
    
SCSI drives behind HP RAID (CCISS) on FreeBSD 6.0:

    /usr/local/libexec/nagios/check_smart.pl -d /dev/ciss0 -i cciss,0
    OK: no SMART errors detected|defect_list=0 sent_blocks=3093462752 temperature=24;;68
    
    /usr/local/libexec/nagios/check_smart.pl -d /dev/ciss0 -i cciss,3
    WARNING: 48 Elements in grown defect list | defect_list=48 sent_blocks=1137657348 temperature=22;;68
    
Using threshold option (-b) to ignore 1 bad element, warning only when 2 bad elements are found:

    /usr/local/libexec/nagios/check_smart.pl -d /dev/ciss0 -i cciss,1 -b 2
    OK: 1 Elements in grown defect list (but less than threshold 2)|defect_list=1;2;2;; sent_blocks=2769458900762624 temperature=27;;65
    
SCSI drives behind HP RAID (CCISS) on Linux (Ubuntu hardy):

    /usr/lib/nagios/plugins/check_smart.pl -d /dev/cciss/c0d0 -i cciss,0        
    OK: no SMART errors detected. |

Check all SATA disks (sda - sdz) at the same time on Linux:

    /usr/lib/nagios/plugins/check_smart.pl -g "/dev/sd[a-z]" -i ata        
    OK: [/dev/sda] - Device is clean --- [/dev/sdb] - Device is clean|
    
Check all SCSI disks behind Intel RAID on FreeBSD 9.2 ("kldload mfip.ko" required):

    /usr/local/libexec/nagios/check_smart.pl -g /dev/pass[1-9] -i scsi
    OK: [/dev/pass0] - Device is clean --- [/dev/pass1] - Device is clean --- [/dev/pass2] - Device is clean --- [/dev/pass3] - Device is clean --- [/dev/pass4] - Device is clean --- [/dev/pass5] - Device is clean --- [/dev/pass6] - Device is clean --- [/dev/pass7] - Device is clean --- [/dev/pass8] - Device is clean --- [/dev/pass9] - Device is clean | 

Single SCSI drive on FreeBSD 10.1:

    /usr/local/libexec/nagios/check_smart.pl -d /dev/da0 -i scsi
    OK: no SMART errors detected. |sent_blocks=14067306 temperature=34;;60



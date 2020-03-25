check_smart monitoring plugin
===========

Full and up to date documentation
-------------------------
Please go to https://www.claudiokuenzler.com/monitoring-plugins/check_smart.php for a complete and updated documentation including changelog, extensive usage examples, monitoring configurations (including Nagios, Icinga 1, Icinga 2, Shinken and Naemon). 

Introduction
-------------------------
This is a plugin to monitor the health and values of SMART attributes of hard (HDD), solid state (SSD) and NVMe drives. The plugin is a fork of check_smart released in 2009 by Kurt Yoder. Since then the plugin has undergone a lot of changes. It allows to monitor drives behind hardware controllers and added a lot of parameters to fine tune the checks and set thresholds (on a per attribute setting).

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

see https://www.claudiokuenzler.com/monitoring-plugins/check_smart.php for more examples

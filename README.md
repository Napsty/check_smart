check_smart
===========

Fork of 2009's check_smart Nagios plugin by Kurt Yoder. 

I got aware, that this plugin is the best to monitor SMART values of hard drives.
Unfortunately to my big surprise, the plugin was not able to handle other device types than ata or scsi.
Therefore disks attached to hardware raids like megaraid could not be checked.

I modified the plugin so it also works with disks attached to raid controllers... and added other features.

History
-------------------------
* Feb 3, 2009: Kurt Yoder - initial version of script (rev 1.0)
* Jul 8, 2013: Claudio Kuenzler - support hardware raids like megaraid (rev 2.0)
* Jul 9, 2013: Claudio Kuenzler - update help output (rev 2.1)
* Oct 11, 2013: Claudio Kuenzler - making the plugin work on FreeBSD (rev 3.0)
* Oct 11, 2013: Claudio Kuenzler - allowing -i sat (SATA on FreeBSD) (rev 3.1)
* Nov 4, 2013: Claudio Kuenzler - works now with CCISS on FreeBSD (rev 3.2)
* Nov 4, 2013: Claudio Kuenzler - elements in grown defect list causes warning (rev 3.3)
* Nov 6, 2013: Claudio Kuenzler - add threshold option "bad" (-b) (rev 4.0)
* Nov 6, 2013: Claudio Kuenzler - modified help (rev 4.0)


Sudoers entry
-------------------------
This plugin needs to run as root, otherwise you're not able to lauch smartctl correctly. 
You have two options

1) Launch the plugin itself as root with sudo

2) Lauch the plugin as Nagios user and the smartctl command as root with sudo

Entry in sudoers (of course adapt your paths if necessary):

    nagios          ALL = NOPASSWD: /usr/lib/nagios/plugins/check_smart.pl    # for option 1
    nagios          ALL = NOPASSWD: /usr/local/sbin/smartctl                  # for option 2

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

    

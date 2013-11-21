check_smart
===========

Please go to http://www.claudiokuenzler.com/nagios-plugins/check_smart.php for a complete and updated documentation.

Fork of 2009's check_smart Nagios plugin by Kurt Yoder. 

I got aware, that this plugin is the best to monitor SMART values of hard drives.
Unfortunately to my big surprise, the plugin was not able to handle other device types than ata or scsi.
Therefore disks attached to hardware raids like megaraid could not be checked.

I modified the plugin so it also works with disks attached to raid controllers... and added other features.

Warning for CCISS RAID and FreeBSD
-------------------------
Today, November 8th 2013, I got aware that after having replaced cciss,0 (first physical disk) on a ProLiant DL380 G5 
running with FreeBSD 9.1-p4, the SMART values of cciss,0 didn't change. To my big surprise the SMART values of cciss,1 were
different after the disk replacement. This means that the SmartArray controller does not label the disks seen 
by FreeBSD correctly (or FreeBSD makes a wrong tanslation). So be extra careful when using FreeBSD!

I could "resolve" this by using the command 'cciss_vol_status'. 
See http://www.claudiokuenzler.com/blog/413/freebsd-cciss-hp-smart-array-raid-wrong-disk-numbering-labeling for details.

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
* Nov 7, 2013: Claudio Kuenzler - modified help (rev 4.0)
* Nov 7, 2013: Claudio Kuenzler - bugfix in threshold logic (rev 4.1)


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
    
SCSI drives behind HP RAID (CCISS) on Linux (Ubuntu hardy):

    /usr/lib/nagios/plugins/check_smart.pl -d /dev/cciss/c0d0 -i cciss,0        
    OK: no SMART errors detected. |


    

check_smart
===========

Fork of 2009's check_smart Nagios plugin by Kurt Yoder. 

I got aware, that this plugin is the best to monitor SMART values of hard drives.
Unfortunately to my big surprise, the plugin was not able to handle other device types than ata or scsi.
Therefore disks attached to hardware raids like megaraid could not be checked.

I modified the plugin so it also works with disks attached to raid controllers. 

Oct 2013: The plugin now also works on FreeBSD (tested on 9.2).

Successful tests/examples
-------------------------
MegaRAID on Linux:

    /usr/lib/nagios/plugins/check_smart.pl -d /dev/sda -i megaraid,8
    
Intel RAID on FreeBSD 9.2 ("kldload mfip.ko" required):

    /usr/local/libexec/nagios/check_smart.pl -d /dev/pass0 -i scsi
    
SATA drives behind Intel RAID on FreeBSD 9.2 ("kldload mfip.ko" required):

    /usr/local/libexec/nagios/check_smart.pl -d /dev/pass12 -i sat
    
SCSI drives behind HP RAID (CCISS) on FreeBSD 6.0:

    /usr/local/libexec/nagios/check_smart.pl -d /dev/ciss0 -i cciss,0
    OK: no SMART errors detected|defect_list=0 sent_blocks=3093462752 temperature=24;;68

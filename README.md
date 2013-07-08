check_smart
===========

Fork of 2009's check_smart Nagios plugin by Kurt Yoder. 

I got aware, that this plugin is the best to monitor SMART values of hard drives.
Unfortunately to my big surprise, the plugin was not able to handle other device types than ata or scsi.
Therefore disks attached to hardware raids like megaraid could not be checked.

I modified the plugin so it also works with disks attached to raid controllers. 

Successfully tested with MegaRAID.

/usr/lib/nagios/plugins/check_smart -d /dev/sda -i megaraid,8

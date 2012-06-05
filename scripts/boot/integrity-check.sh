#!/bin/sh

#set -e

integrity_check ()
{
	media_mountpoint="${1}"

	log_begin_msg "Checking media integrity"

	cd ${media_mountpoint}
	/bin/md5sum -c md5sum.txt < /dev/tty8 > /dev/tty8
	RC="${?}"

	log_end_msg

	if [ "${RC}" -eq 0 ]
	then
		log_success_msg "Everything ok, will reboot in 10 seconds."
		sleep 10
		cd /
		umount ${media_mountpoint}
		sync
		echo u > /proc/sysrq-trigger
		echo b > /proc/sysrq-trigger
	else
		panic "Not ok, a media defect is likely, switch to VT8 for details."
	fi
}

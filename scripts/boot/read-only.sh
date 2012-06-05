#!/bin/sh

#set -e

Read_only ()
{
	# Marking the usual block devices for harddisks read-only
	for _DEVICE in /dev/sd* /dev/vd*
	do
		if [ -b "${_DEVICE}" ]
		then
			printf "Setting device %-9s to read-only mode:" ${_DEVICE} > /dev/console

			blockdev --setro ${_DEVICE} && printf " done [ execute \"blockdev --setrw %-9s\" to unlock]\n" ${_DEVICE} > /dev/console || printf "failed\n" > /dev/console
		fi
	done
}

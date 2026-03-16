#!/bin/sh

#set -e

# override matches_uuid from 9990-misc-helpers.sh to implement grml bootid feature
matches_uuid ()
{
	path="$1"

	if [ -n "$IGNORE_BOOTID" ] ; then
		echo " * Ignoring verification of bootid.txt as requested via ignore_bootid.">>/boot.log
		return 0
	fi

	if [ -n "$BOOTID" ] && ! [ -r "${path}/conf/bootid.txt" ] ; then
		echo "  * Warning: bootid=... specified but no bootid.txt found on currently requested device.">>/boot.log
		return 1
	fi

	[ -r "${path}/conf/bootid.txt" ] || return 0

	bootid_conf=$(cat "${path}/conf/bootid.txt")

	if [ -z "$BOOTID" -a -z "$IGNORE_BOOTID" ]
	then
		echo " * Warning: bootid.txt found but ignore_bootid / bootid=.. bootoption missing...">>/boot.log
		return 1
	fi

	if [ "$BOOTID" = "$bootid_conf" ]
	then
		echo " * Successfully verified /conf/bootid.txt from ISO, continuing... ">>/boot.log
	else
		echo " * Warning: BOOTID of ISO does not match. Retrying and continuing search...">>/boot.log
		return 1
	fi

	return 0
}

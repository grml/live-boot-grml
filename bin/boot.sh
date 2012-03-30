#!/bin/sh

# Exit if system was not booted by live-boot
grep -qs boot=live /proc/cmdline || exit 0

DO_SNAPSHOT=/sbin/live-snapshot
SNAPSHOT_CONF="/etc/live/boot.d/snapshot.conf"

# Read snapshot configuration variables
[ -r ${SNAPSHOT_CONF} ] && . ${SNAPSHOT_CONF}

# Define LSB log_* functions.
# Depend on lsb-base (>= 3.0-6) to ensure that this file is present.
. /lib/lsb/init-functions

# Try to cache everything we're likely to need after ejecting.  This
# is fragile and simple-minded, but our options are limited.
cache_path()
{
	path="${1}"

	if [ -d "${path}" ]
	then
		find "${path}" -type f | xargs cat > /dev/null 2>&1
	elif [ -f "${path}" ]
	then
		if file -L "${path}" | grep -q 'dynamically linked'
		then
			# ldd output can be of three forms:
			# 1. linux-vdso.so.1 =>  (0x00007fffe3fb4000)
			#    This is a virtual, kernel shared library and we want to skip it
			# 2. libc.so.6 => /lib/libc.so.6 (0x00007f5e9dc0c000)
			#    We want to cache the third word.
			# 3. /lib64/ld-linux-x86-64.so.2 (0x00007f5e9df8b000)
			#    We want to cache the first word.
			ldd "${path}" | while read line
			do
				if echo "$line" | grep -qs ' =>  '
				then
					continue
				elif echo "$line" | grep -qs ' => '
				then
					lib=$(echo "${line}" | awk '{ print $3 }')
				else
					lib=$(echo "${line}" | awk '{ print $1 }')
				fi
				cache_path "${lib}"
			done
		fi

		cat "${path}" >/dev/null 2>&1
	fi
}

get_boot_device()
{
	# search in /proc/mounts for the device that is mounted at /live/image
	while read DEVICE MOUNT REST
	do
		if [ "${MOUNT}" = "/live/image" ]
		then
			echo "${DEVICE}"
			exit 0
		fi
	done < /proc/mounts
}

device_is_USB_flash_drive()
{
	# remove leading "/dev/" and all trailing numbers from input
	DEVICE=$(expr substr ${1} 6 3)

	# check that device starts with "sd"
	[ "$(expr substr ${DEVICE} 1 2)" != "sd" ] && return 1

	# check that the device is an USB device
	if readlink /sys/block/${DEVICE} | grep -q usb
	then
		return 0
	fi

	return 1
}

log_begin_msg "live-boot: resyncing snapshots and caching reboot files..."

if ! grep -qs nopersistent /proc/cmdline && grep -qs persistent /proc/cmdline
then
	# ROOTSNAP and HOMESNAP are defined in ${SNAPSHOT_CONF} file
	if [ ! -z "${ROOTSNAP}" ]
	then
		${DO_SNAPSHOT} --resync-string="${ROOTSNAP}"
	fi

	if [ ! -z "${HOMESNAP}" ]
	then
		${DO_SNAPSHOT} --resync-string="${HOMESNAP}"
	fi
fi

# check for netboot
if [ ! -z "${NETBOOT}" ] || grep -qs netboot /proc/cmdline || grep -qsi root=/dev/nfs /proc/cmdline  || grep -qsi root=/dev/cifs /proc/cmdline
then
	return 0
fi

# check for toram
if grep -qs toram /proc/cmdline
then
	return 0
fi

# Don't prompt to eject the SD card on Babbage board, where we reuse it
# as a quasi-boot-floppy. Technically this uses a bit of ubiquity
# (archdetect), but since this is mostly only relevant for
# installations, who cares ...
if type archdetect >/dev/null 2>&1
then
	subarch="$(archdetect)"

	case $subarch in
		arm*/imx51)
			return 0
			;;
	esac
fi

prompt=1
if [ "${NOPROMPT}" = "Yes" ]
then
	prompt=
fi

for path in $(which halt) $(which reboot) /etc/rc?.d /etc/default $(which stty) /bin/plymouth
do
	cache_path "${path}"
done

for x in $(cat /proc/cmdline)
do
	case ${x} in
		quickreboot)
			QUICKREBOOT="Yes"
			;;
	esac
done

mount -o remount,ro /live/cow

if [ -z ${QUICKREBOOT} ]
then
	# Exit if the system was booted from an ISO image rather than a physical CD
	grep -qs find_iso= /proc/cmdline && return 0
	# TODO: i18n
	BOOT_DEVICE="$(get_boot_device)"

	if device_is_USB_flash_drive ${BOOT_DEVICE}
	then
		# do NOT eject USB flash drives!
		# otherwise rebooting with most USB flash drives
		# failes because they actually remember the
		# "ejected" state even after reboot
		MESSAGE="Please remove the USB flash drive"

		if [ "${NOPROMPT}" = "usb" ]
		then
			prompt=
		fi

	else
		# ejecting is a very good idea here
		MESSAGE="Please remove the disc, close the tray (if any)"

		if [ -x /usr/bin/eject ]
		then
			eject -p -m /live/image >/dev/null 2>&1
		fi

		if [ "${NOPROMPT}" = "cd" ]
		then
			prompt=
		fi
	fi

	[ "$prompt" ] || return 0

	if [ -x /bin/plymouth ] && plymouth --ping
	then
		plymouth message --text="${MESSAGE} and press ENTER to continue:"
		plymouth watch-keystroke > /dev/null
	else
		stty sane < /dev/console

		printf "\n\n${MESSAGE} and press ENTER to continue:" > /dev/console

		read x < /dev/console
	fi
fi

#!/bin/sh

#set -e

persistence_exclude ()
{
	# Persistence enhancer script
	# This script saves precious time on slow persistence devices/image files
	# and writes on flash based device.
	# a tmpfs on $PERSTMP is mounted and directories listed in
	# /etc/live-persistence.binds will be copied there and then bind mounted back.

	if [ -z "${PERSISTENCE}" ] || [ -n "${NOPERSISTENCE}" ] || [ -z "${PERSISTENCE_IS_ON}" ] || [ ! -f /root/etc/live-persistence.binds ]
	then
		return
	fi

	# FIXME: stop hardcoding overloading of initramfs-tools functions
	. /scripts/functions
	. /lib/live/boot/initramfs-tools.sh

	dirs="$(sed -e '/^ *$/d' -e '/^#.*$/d' /root/etc/live-persistence.binds | tr '\n' '\0')"
	if [ -z "${dirs}" ]
	then
		return
	fi

	log_begin_msg "Moving persistence bind mounts"

	PERSTMP="/root/live/persistence-binds"
	CPIO="/bin/cpio"

	if [ ! -d "${PERSTMP}" ]
	then
		mkdir -p "${PERSTMP}"
	fi

	mount -t tmpfs tmpfs "${PERSTMP}"

	for dir in $(echo "${dirs}" | tr '\0' '\n')
	do
		if [ ! -e "/root/${dir}" ] && [ ! -L "/root/${dir}" ]
		then
			# directory do not exists, create it
			mkdir -p "/root/${dir}"
		elif [ ! -d "/root/${dir}" ]
		then
			# it is not a directory, skip it
			break
		fi

		# Copy previous content if any
		cd "/root/${dir}"
		find . -print0 | ${CPIO} -pumd0 "${PERSTMP}/${dir}"
		cd "${OLDPWD}"

		# Bind mount it to origin
		mount -o bind "${PERSTMP}/${dir}" "/root/${dir}"
	done

	log_end_msg
}

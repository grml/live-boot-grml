#!/bin/sh

do_snap_copy ()
{
	fromdev="${1}"
	todir="${2}"
	snap_type="${3}"
	size=$(fs_size "${fromdev}" "" "used")

	if [ -b "${fromdev}" ]
	then
		log_success_msg "Copying snapshot ${fromdev} to ${todir}..."

		# look for free mem
		if [ -n "${HOMEMOUNTED}" -a "${snap_type}" = "HOME" ]
		then
			todev=$(awk -v pat="$(base_path ${todir})" '$2 == pat { print $1 }' /proc/mounts)
			freespace=$(df -k | awk '/'${todev}'/{print $4}')
		else
			freespace=$(awk '/^MemFree:/{f=$2} /^Cached:/{c=$2} END{print f+c}' /proc/meminfo)
		fi

		tomount="/mnt/tmpsnap"

		if [ ! -d "${tomount}" ]
		then
			mkdir -p "${tomount}"
		fi

		fstype=$(get_fstype "${fromdev}")

		if [ -n "${fstype}" ]
		then
			# Copying stuff...
			mount -o ro -t "${fstype}" "${fromdev}" "${tomount}" || log_warning_msg "Error in mount -t ${fstype} -o ro ${fromdev} ${tomount}"
			cp -a "${tomount}"/* ${todir}
			umount "${tomount}"
		else
			log_warning_msg "Unrecognized fstype: ${fstype} on ${fromdev}:${snap_type}"
		fi

		rmdir "${tomount}"

		if echo ${fromdev} | grep -qs loop
		then
			losetup -d "${fromdev}"
		fi

		return 0
	else
		log_warning_msg "Unable to find the snapshot ${snap_type} medium"
		return 1
	fi
}

try_snap ()
{
	# copy the contents of previously found snapshot to ${snap_mount}
	# and remember the device and filename for resync on exit in live-boot.init

	snapdata="${1}"
	snap_mount="${2}"
	snap_type="${3}"
	snap_relpath="${4}"

	if [ -z "${snap_relpath}" ]
	then
		# root snapshot, default usage
		snap_relpath="/"
	else
		# relative snapshot (actually used just for "/home" snapshots)
		snap_mount="${2}${snap_relpath}"
	fi

	if [ -n "${snapdata}" ] && [ ! -b "${snapdata}" ]
	then
		log_success_msg "found snapshot: ${snapdata}"
		snapdev="$(echo ${snapdata} | cut -f1 -d ' ')"
		snapback="$(echo ${snapdata} | cut -f2 -d ' ')"
		snapfile="$(echo ${snapdata} | cut -f3 -d ' ')"

		if ! try_mount "${snapdev}" "${snapback}" "ro"
		then
			break
		fi

		RES="0"

		if echo "${snapfile}" | grep -qs '\(squashfs\|ext2\|ext3\|ext4\|jffs2\)'
		then
			# squashfs, jffs2 or ext2/ext3/ext4 snapshot
			dev=$(get_backing_device "${snapback}/${snapfile}")

			do_snap_copy "${dev}" "${snap_mount}" "${snap_type}"
			RES="$?"
		else
			# cpio.gz snapshot

			# Unfortunately klibc's cpio is incompatible with the
			# rest of the world; everything else requires -u -d,
			# while klibc doesn't implement them. Try to detect
			# whether it's in use.
			cpiopath="$(which cpio)" || true
			if [ "$cpiopath" ] && grep -aq /lib/klibc "$cpiopath"
			then
				cpioargs=
			else
				cpioargs='--unconditional --make-directories'
			fi

			if [ -s "${snapback}/${snapfile}" ]
			then
				BEFOREDIR="$(pwd)"
				cd "${snap_mount}" && zcat "${snapback}/${snapfile}" | $cpiopath $cpioargs --extract --preserve-modification-time --no-absolute-filenames --sparse 2>/dev/null
				RES="$?"
				cd "${BEFOREDIR}"
			else
				log_warning_msg "${snapback}/${snapfile} is empty, adding it for sync on reboot."
				RES="0"
			fi

			if [ "${RES}" != "0" ]
			then
				log_warning_msg "failure to \"zcat ${snapback}/${snapfile} | $cpiopath $cpioargs --extract --preserve-modification-time --no-absolute-filenames --sparse\""
			fi
		fi

		umount "${snapback}" ||  log_warning_msg "failure to \"umount ${snapback}\""

		if [ "${RES}" != "0" ]
		then
			log_warning_msg "Impossible to include the ${snapfile} Snapshot file"
		fi

	elif [ -b "${snapdata}" ]
	then
		# Try to find if it could be a snapshot partition
		dev="${snapdata}"
		log_success_msg "found snapshot ${snap_type} device on ${dev}"
		if echo "${dev}" | grep -qs loop
		then
			# strange things happens, user confused?
			snaploop=$( losetup ${dev} | awk '{print $3}' | tr -d '()' )
			snapfile=$(basename ${snaploop})
			snapdev=$(awk -v pat="$( dirname ${snaploop})" '$2 == pat { print $1 }' /proc/mounts)
		else
			snapdev="${dev}"
		fi

		if ! do_snap_copy "${dev}" "${snap_mount}" "${snap_type}"
		then
			log_warning_msg "Impossible to include the ${snap_type} Snapshot (i)"
			return 1
		else
			if [ -n "${snapfile}" ]
			then
				# it was a loop device, user confused
				umount ${snapdev}
			fi
		fi
	else
		log_warning_msg "Impossible to include the ${snap_type} Snapshot (o)"
		return 1
	fi

	if [ -z ${PERSISTENCE_READONLY} ]
	then
		echo "export ${snap_type}SNAP=${snap_relpath}:${snapdev}:${snapfile}" >> snapshot.conf # for resync on reboot/halt
	fi
	return 0
}

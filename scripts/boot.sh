#!/bin/sh

# set -e

if [ -e /scripts/functions ]
then
	# initramfs-tools specific (FIXME)
	. /scripts/functions
fi

for _SCRIPT in /lib/live/boot/*
do
	if [ -e "${_SCRIPT}" ]
	then
		. ${_SCRIPT}
	fi
done

export PATH="/root/usr/bin:/root/usr/sbin:/root/bin:/root/sbin:/usr/bin:/usr/sbin:/bin:/sbin"

echo "/root/lib" >> /etc/ld.so.conf
echo "/root/usr/lib" >> /etc/ld.so.conf

mountpoint="/live/image"
alt_mountpoint="/media"
LIVE_MEDIA_PATH="live"

HOSTNAME="host"

mkdir -p "${mountpoint}"
tried="/tmp/tried"

# Create /etc/mtab for debug purpose and future syncs
if [ ! -d /etc ]
then
	mkdir /etc/
fi

if [ ! -f /etc/mtab ]
then
	touch /etc/mtab
fi

if [ ! -x "/bin/fstype" ]
then
	# klibc not in path -> not in initramfs
	export PATH="${PATH}:/usr/lib/klibc/bin"
fi

# handle upgrade path from old udev (using udevinfo) to
# recent versions of udev (using udevadm info)
if [ -x /sbin/udevadm ]
then
	udevinfo='/sbin/udevadm info'
else
	udevinfo='udevinfo'
fi

old_root_overlay_label="live-rw"
old_home_overlay_label="home-rw"
custom_overlay_label="custom-ov"
root_snapshot_label="live-sn"
old_root_snapshot_label="live-sn"
home_snapshot_label="home-sn"
persistence_list="live-persistence.conf"

if [ ! -f /live.vars ]
then
	touch /live.vars
fi

is_live_path ()
{
	DIRECTORY="${1}"

	if [ -d "${DIRECTORY}"/"${LIVE_MEDIA_PATH}" ]
	then
		for FILESYSTEM in squashfs ext2 ext3 ext4 xfs dir jffs2
		do
			if [ "$(echo ${DIRECTORY}/${LIVE_MEDIA_PATH}/*.${FILESYSTEM})" != "${DIRECTORY}/${LIVE_MEDIA_PATH}/*.${FILESYSTEM}" ]
			then
				return 0
			fi
		done
	fi

	return 1
}

matches_uuid ()
{
	if [ "${IGNORE_UUID}" ] || [ ! -e /conf/uuid.conf ]
	then
		return 0
	fi

	path="${1}"
	uuid="$(cat /conf/uuid.conf)"

	for try_uuid_file in "${path}/.disk/live-uuid"*
	do
		[ -e "${try_uuid_file}" ] || continue

		try_uuid="$(cat "${try_uuid_file}")"

		if [ "${uuid}" = "${try_uuid}" ]
		then
			return 0
		fi
	done

	return 1
}

get_backing_device ()
{
	case "${1}" in
		*.squashfs|*.ext2|*.ext3|*.ext4|*.jffs2)
			echo $(setup_loop "${1}" "loop" "/sys/block/loop*" '0' "${LIVE_MEDIA_ENCRYPTION}" "${2}")
			;;

		*.dir)
			echo "directory"
			;;

		*)
			panic "Unrecognized live filesystem: ${1}"
			;;
	esac
}

match_files_in_dir ()
{
	# Does any files match pattern ${1} ?
	local pattern="${1}"

	if [ "$(echo ${pattern})" != "${pattern}" ]
	then
		return 0
	fi

	return 1
}

mount_images_in_directory ()
{
	directory="${1}"
	rootmnt="${2}"
	mac="${3}"


	if match_files_in_dir "${directory}/${LIVE_MEDIA_PATH}/*.squashfs" ||
		match_files_in_dir "${directory}/${LIVE_MEDIA_PATH}/*.ext2" ||
		match_files_in_dir "${directory}/${LIVE_MEDIA_PATH}/*.ext3" ||
		match_files_in_dir "${directory}/${LIVE_MEDIA_PATH}/*.ext4" ||
		match_files_in_dir "${directory}/${LIVE_MEDIA_PATH}/*.jffs2" ||
		match_files_in_dir "${directory}/${LIVE_MEDIA_PATH}/*.dir"
	then
		[ -n "${mac}" ] && adddirectory="${directory}/${LIVE_MEDIA_PATH}/${mac}"
		setup_unionfs "${directory}/${LIVE_MEDIA_PATH}" "${rootmnt}" "${adddirectory}"
	else
		panic "No supported filesystem images found at /${LIVE_MEDIA_PATH}."
	fi
}

is_nice_device ()
{
	sysfs_path="${1#/sys}"

	if [ -e /lib/udev/path_id ]
	then
		# squeeze
		PATH_ID="/lib/udev/path_id"
	else
		# wheezy/sid (udev >= 174)
		PATH_ID="/sbin/udevadm test-builtin path_id"
	fi

	if ${PATH_ID} "${sysfs_path}" | egrep -q "ID_PATH=(usb|pci-[^-]*-(ide|sas|scsi|usb|virtio)|platform-sata_mv|platform-orion-ehci|platform-mmc|platform-mxsdhci)"
	then
		return 0
	elif echo "${sysfs_path}" | grep -q '^/block/vd[a-z]$'
	then
		return 0
	elif echo ${sysfs_path} | grep -q "^/block/dm-"
	then
		return 0
	elif echo ${sysfs_path} | grep -q "^/block/mtdblock"
	then
		return 0
	fi

	return 1
}

check_dev ()
{
	sysdev="${1}"
	devname="${2}"
	skip_uuid_check="${3}"

	# support for fromiso=.../isofrom=....
	if [ -n "$FROMISO" ]
	then
		ISO_DEVICE=$(dirname $FROMISO)
		if ! [ -b $ISO_DEVICE ]
		then
			# to support unusual device names like /dev/cciss/c0d0p1
			# as well we have to identify the block device name, let's
			# do that for up to 15 levels
			i=15
			while [ -n "$ISO_DEVICE" ] && [ "$i" -gt 0 ]
			do
				ISO_DEVICE=$(dirname ${ISO_DEVICE})
				[ -b "$ISO_DEVICE" ] && break
				i=$(($i -1))
		        done
		fi

		if [ "$ISO_DEVICE" = "/" ]
		then
			echo "Warning: device for bootoption fromiso= ($FROMISO) not found.">>/boot.log
		else
			fs_type=$(get_fstype "${ISO_DEVICE}")
			if is_supported_fs ${fs_type}
			then
				mkdir /live/fromiso
				mount -t $fs_type "$ISO_DEVICE" /live/fromiso
				ISO_NAME="$(echo $FROMISO | sed "s|$ISO_DEVICE||")"
				loopdevname=$(setup_loop "/live/fromiso/${ISO_NAME}" "loop" "/sys/block/loop*" "" '')
				devname="${loopdevname}"
			else
				echo "Warning: unable to mount $ISO_DEVICE." >>/boot.log
			fi
		fi
	fi

	if [ -z "${devname}" ]
	then
		devname=$(sys2dev "${sysdev}")
	fi

	if [ -d "${devname}" ]
	then
		mount -o bind "${devname}" $mountpoint || continue

		if is_live_path $mountpoint
		then
			echo $mountpoint
			return 0
		else
			umount $mountpoint
		fi
	fi

	IFS=","
	for device in ${devname}
	do
		case "$device" in
			*mapper*)
				# Adding lvm support
				if [ -x /scripts/local-top/lvm2 ]
				then
					ROOT="$device" resume="" /scripts/local-top/lvm2
				fi
				;;

			/dev/md*)
				# Adding raid support
				if [ -x /scripts/local-top/mdadm ]
				then
					cp /conf/conf.d/md /conf/conf.d/md.orig
					echo "MD_DEVS=$device " >> /conf/conf.d/md
					/scripts/local-top/mdadm
					mv /conf/conf.d/md.orig /conf/conf.d/md
				fi
				;;
		esac
	done
	unset IFS

	[ -n "$device" ] && devname="$device"

	[ -e "$devname" ] || continue

	if [ -n "${LIVE_MEDIA_OFFSET}" ]
	then
		loopdevname=$(setup_loop "${devname}" "loop" "/sys/block/loop*" "${LIVE_MEDIA_OFFSET}" '')
		devname="${loopdevname}"
	fi

	fstype=$(get_fstype "${devname}")

	if is_supported_fs ${fstype}
	then
		devuid=$(blkid -o value -s UUID "$devname")
		[ -n "$devuid" ] && grep -qs "\<$devuid\>" $tried && continue
		mount -t ${fstype} -o ro,noatime "${devname}" ${mountpoint} || continue
		[ -n "$devuid" ] && echo "$devuid" >> $tried

		if [ -n "${FINDISO}" ]
		then
			if [ -f ${mountpoint}/${FINDISO} ]
			then
				umount ${mountpoint}
				mkdir -p /live/findiso
				mount -t ${fstype} -o ro,noatime "${devname}" /live/findiso
				loopdevname=$(setup_loop "/live/findiso/${FINDISO}" "loop" "/sys/block/loop*" 0 "")
				devname="${loopdevname}"
				mount -t iso9660 -o ro,noatime "${devname}" ${mountpoint}
			else
				umount ${mountpoint}
			fi
		fi

		if is_live_path ${mountpoint} && \
			([ "${skip_uuid_check}" ] || matches_uuid ${mountpoint})
		then
			echo ${mountpoint}
			return 0
		else
			umount ${mountpoint} 2>/dev/null
		fi
	fi

	if [ -n "${LIVE_MEDIA_OFFSET}" ]
	then
		losetup -d "${loopdevname}"
	fi

	return 1
}

find_livefs ()
{
	timeout="${1}"

	# don't start autodetection before timeout has expired
	if [ -n "${LIVE_MEDIA_TIMEOUT}" ]
	then
		if [ "${timeout}" -lt "${LIVE_MEDIA_TIMEOUT}" ]
		then
			return 1
		fi
	fi

	# first look at the one specified in the command line
	case "${LIVE_MEDIA}" in
		removable-usb)
			for sysblock in $(removable_usb_dev "sys")
			do
				for dev in $(subdevices "${sysblock}")
				do
					if check_dev "${dev}"
					then
						return 0
					fi
				done
			done
			return 1
			;;

		removable)
			for sysblock in $(removable_dev "sys")
			do
				for dev in $(subdevices "${sysblock}")
				do
					if check_dev "${dev}"
					then
						return 0
					fi
				done
			done
			return 1
			;;

		*)
			if [ ! -z "${LIVE_MEDIA}" ]
			then
				if check_dev "null" "${LIVE_MEDIA}" "skip_uuid_check"
				then
					return 0
				fi
			fi
			;;
	esac

	# or do the scan of block devices
	# prefer removable devices over non-removable devices, so scan them first
	devices_to_scan="$(removable_dev 'sys') $(non_removable_dev 'sys')"

	for sysblock in $devices_to_scan
	do
		devname=$(sys2dev "${sysblock}")
		[ -e "$devname" ] || continue
		fstype=$(get_fstype "${devname}")

		if /lib/udev/cdrom_id ${devname} > /dev/null
		then
			if check_dev "null" "${devname}"
			then
				return 0
			fi
		elif is_nice_device "${sysblock}"
		then
			for dev in $(subdevices "${sysblock}")
			do
				if check_dev "${dev}"
				then
					return 0
				fi
			done
		elif [ "${fstype}" = "squashfs" -o \
			"${fstype}" = "btrfs" -o \
			"${fstype}" = "ext2" -o \
			"${fstype}" = "ext3" -o \
			"${fstype}" = "ext4" -o \
			"${fstype}" = "jffs2" ]
		then
			# This is an ugly hack situation, the block device has
			# an image directly on it.  It's hopefully
			# live-boot, so take it and run with it.
			ln -s "${devname}" "${devname}.${fstype}"
			echo "${devname}.${fstype}"
			return 0
		fi
	done

	return 1
}

mountroot ()
{
	if [ -x /scripts/local-top/cryptroot ]; then
	    /scripts/local-top/cryptroot
	fi

	exec 6>&1
	exec 7>&2
	exec > boot.log
	exec 2>&1
	tail -f boot.log >&7 &
	tailpid="${!}"

	. /live.vars

	_CMDLINE="$(cat /proc/cmdline)"
	Cmdline

	case "${LIVE_DEBUG}" in
		true)
			set -x
			;;
	esac

	case "${LIVE_READ_ONLY}" in
		true)
			Read_only
			;;
	esac

	Select_eth_device

	# Needed here too because some things (*cough* udev *cough*)
	# changes the timeout

	if [ ! -z "${NETBOOT}" ] || [ ! -z "${FETCH}" ] || [ ! -z "${HTTPFS}" ] || [ ! -z "${FTPFS}" ]
	then
		if do_netmount
		then
			livefs_root="${mountpoint}"
		else
			panic "Unable to find a live file system on the network"
		fi
	else
		if [ -n "${ISCSI_PORTAL}" ]
		then
			do_iscsi && livefs_root="${mountpoint}"
		elif [ -n "${PLAIN_ROOT}" ] && [ -n "${ROOT}" ]
		then
			# Do a local boot from hd
			livefs_root=${ROOT}
		else
			if [ -x /usr/bin/memdiskfind ]
			then
				MEMDISK=$(/usr/bin/memdiskfind)

				if [ $? -eq 0 ]
				then
					# We found a memdisk, set up phram
					modprobe phram phram=memdisk,${MEMDISK}

					# Load mtdblock, the memdisk will be /dev/mtdblock0
					modprobe mtdblock
				fi
			fi

			# Scan local devices for the image
			i=0
			while [ "$i" -lt 60 ]
			do
				livefs_root=$(find_livefs ${i})

				if [ -n "${livefs_root}" ]
				then
					break
				fi

				sleep 1
				i="$(($i + 1))"
			done
		fi
	fi

	if [ -z "${livefs_root}" ]
	then
		panic "Unable to find a medium containing a live file system"
	fi

	case "${LIVE_VERIFY_CHECKSUMS}" in
		true)
			Verify_checksums "${livefs_root}"
			;;
	esac

	if [ "${TORAM}" ]
	then
		live_dest="ram"
	elif [ "${TODISK}" ]
	then
		live_dest="${TODISK}"
	fi

	if [ "${live_dest}" ]
	then
		log_begin_msg "Copying live media to ${live_dest}"
		copy_live_to "${livefs_root}" "${live_dest}"
		log_end_msg
	fi

	# if we do not unmount the ISO we can't run "fsck /dev/ice" later on
	# because the mountpoint is left behind in /proc/mounts, so let's get
	# rid of it when running from RAM
	if [ -n "$FROMISO" ] && [ "${TORAM}" ]
	then
		losetup -d /dev/loop0

		if is_mountpoint /live/fromiso
		then
			umount /live/fromiso
			rmdir --ignore-fail-on-non-empty /live/fromiso \
				>/dev/null 2>&1 || true
		fi
	fi

	if [ -n "${MODULETORAMFILE}" ] || [ -n "${PLAIN_ROOT}" ]
	then
		setup_unionfs "${livefs_root}" "${rootmnt}"
	else
		mac="$(get_mac)"
		mac="$(echo ${mac} | sed 's/-//g')"
		mount_images_in_directory "${livefs_root}" "${rootmnt}" "${mac}"
	fi


	if [ -n "${ROOT_PID}" ] ; then
		echo "${ROOT_PID}" > "${rootmnt}"/live/root.pid
	fi

	log_end_msg

	# unionfs-fuse needs /dev to be bind-mounted for the duration of
	# live-bottom; udev's init script will take care of things after that
	if [ "${UNIONTYPE}" = unionfs-fuse ]
	then
		mount -n -o bind /dev "${rootmnt}/dev"
	fi

	# Move to the new root filesystem so that programs there can get at it.
	if [ ! -d /root/live/image ]
	then
		mkdir -p /root/live/image
		mount --move /live/image /root/live/image
	fi

	# aufs2 in kernel versions around 2.6.33 has a regression:
	# directories can't be accessed when read for the first the time,
	# causing a failure for example when accessing /var/lib/fai
	# when booting FAI, this simple workaround solves it
	ls /root/* >/dev/null 2>&1

	# Move findiso directory to the new root filesystem so that programs there can get at it.
	if [ -d /live/findiso ] && [ ! -d /root/live/findiso ]
	then
		mkdir -p /root/live/findiso
		mount -n --move /live/findiso /root/live/findiso
	fi

	# if we do not unmount the ISO we can't run "fsck /dev/ice" later on
	# because the mountpoint is left behind in /proc/mounts, so let's get
	# rid of it when running from RAM
	if [ -n "$FINDISO" ] && [ "${TORAM}" ]
	then
		losetup -d /dev/loop0

		if is_mountpoint /root/live/findiso
		then
			umount /root/live/findiso
			rmdir --ignore-fail-on-non-empty /root/live/findiso \
				>/dev/null 2>&1 || true
		fi
	fi

	# copy snapshot configuration if exists
	if [ -f snapshot.conf ]
	then
		log_begin_msg "Copying snapshot.conf to ${rootmnt}/etc/live/boot.d"
		if [ ! -d "${rootmnt}/etc/live/boot.d" ]
		then
			mkdir -p "${rootmnt}/etc/live/boot.d"
		fi
		cp snapshot.conf "${rootmnt}/etc/live/boot.d/"
		log_end_msg
	fi

	if [ -f /etc/resolv.conf ] && [ ! -s ${rootmnt}/etc/resolv.conf ]
	then
		log_begin_msg "Copying /etc/resolv.conf to ${rootmnt}/etc/resolv.conf"
		cp -v /etc/resolv.conf ${rootmnt}/etc/resolv.conf
		log_end_msg
	fi

	maybe_break live-bottom
	log_begin_msg "Running /scripts/live-bottom\n"

	run_scripts /scripts/live-bottom
	log_end_msg

	if [ "${UNIONFS}" = unionfs-fuse ]
	then
		umount "${rootmnt}/dev"
	fi

	exec 1>&6 6>&-
	exec 2>&7 7>&-
	kill ${tailpid}
	[ -w "${rootmnt}/var/log/" ] && mkdir -p /var/log/live && cp boot.log "${rootmnt}/var/log/live" 2>/dev/null
}

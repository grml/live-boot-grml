#!/bin/sh

#set -e

Arguments ()
{
	for ARGUMENT in $(cat /proc/cmdline)
	do
		case "${ARGUMENT}" in
			live-boot.read-only|read-only)
				LIVE_READ_ONLY="true"
				export LIVE_READ_ONLY
				;;

			live-boot.verify-checksums|verify-checksums)
				LIVE_VERIFY_CHECKSUMS="true"
				export LIVE_VERIFY_CHECKSUMS
				;;

			# parameters below need review
			skipconfig)
				NOFASTBOOT="true"
				NOFSTAB="true"
				NONETWORKING="true"

				export NOFASTBOOT NOFSTAB NONETWORKING
				;;

			BOOTIF=*)
				BOOTIF="${x#BOOTIF=}"
				;;

			debug)
				DEBUG="true"
				export DEBUG

				set -x
				;;

			dhcp)
				# Force dhcp even while netbooting
				# Use for debugging in case somebody works on fixing dhclient
				DHCP="true";
				export DHCP
				;;

			nodhcp)
				DHCP=""
				export DHCP
				;;

			ethdevice=*)
				DEVICE="${ARGUMENT#ethdevice=}"
				ETHDEVICE="${DEVICE}"
				export DEVICE ETHDEVICE
				;;

			ethdevice-timeout=*)
				ETHDEV_TIMEOUT="${ARGUMENT#ethdevice-timeout=}"
				export ETHDEV_TIMEOUT
				;;

			fetch=*)
				FETCH="${ARGUMENT#fetch=}"
				export FETCH
				;;

			findiso=*)
				FINDISO="${ARGUMENT#findiso=}"
				export FINDISO
				;;

			ftpfs=*)
				FTPFS="${ARGUMENT#ftpfs=}"
				export FTPFS
				;;

			httpfs=*)
				HTTPFS="${ARGUMENT#httpfs=}"
				export HTTPFS
				;;

			iscsi=*)
				ISCSI="${ARGUMENT#iscsi=}"
				#ip:port - separated by ;
				ISCSI_PORTAL="${ISCSI%;*}"
				if echo "${ISCSI_PORTAL}" | grep -q , ; then
					ISCSI_SERVER="${ISCSI_PORTAL%,*}"
					ISCSI_PORT="${ISCSI_PORTAL#*,}"
				fi
				#target name
				ISCSI_TARGET="${ISCSI#*;}"
				export ISCSI ISCSI_PORTAL ISCSI_TARGET ISCSI_SERVER ISCSI_PORT
				;;

			isofrom=*|fromiso=*)
				FROMISO="${ARGUMENT#*=}"
				export FROMISO
				;;

			ignore_uuid)
				IGNORE_UUID="true"
				export IGNORE_UUID
				;;

			ip=*)
				STATICIP="${ARGUMENT#ip=}"

				if [ -z "${STATICIP}" ]
				then
					STATICIP="frommedia"
				fi

				export STATICIP
				;;

			live-media=*|bootfrom=*)
				LIVE_MEDIA="${ARGUMENT#*=}"
				export LIVE_MEDIA
				;;

			live-media-encryption=*|encryption=*)
				LIVE_MEDIA_ENCRYPTION="${ARGUMENT#*=}"
				export LIVE_MEDIA_ENCRYPTION
				;;

			live-media-offset=*)
				LIVE_MEDIA_OFFSET="${ARGUMENT#live-media-offset=}"
				export LIVE_MEDIA_OFFSET
				;;

			live-media-path=*)
				LIVE_MEDIA_PATH="${ARGUMENT#live-media-path=}"
				export LIVE_MEDIA_PATH
				;;

			live-media-timeout=*)
				LIVE_MEDIA_TIMEOUT="${ARGUMENT#live-media-timeout=}"
				export LIVE_MEDIA_TIMEOUT
				;;

			module=*)
				MODULE="${ARGUMENT#module=}"
				export MODULE
				;;

			netboot=*)
				NETBOOT="${ARGUMENT#netboot=}"
				export NETBOOT
				;;

			nfsopts=*)
				NFSOPTS="${ARGUMENT#nfsopts=}"
				export NFSOPTS
				;;

			nfsoverlay=*)
				NFS_COW="${ARGUMENT#nfsoverlay=}"
				export NFS_COW
				;;

			nofastboot)
				NOFASTBOOT="true"
				export NOFASTBOOT
				;;

			nofstab)
				NOFSTAB="true"
				export NOFSTAB
				;;

			nonetworking)
				NONETWORKING="true"
				export NONETWORKING
				;;

			ramdisk-size=*)
				ramdisk_size="${ARGUMENT#ramdisk-size=}"
				;;

			swapon)
				SWAPON="true"
				export SWAPON
				;;

			persistence)
				PERSISTENCE="true"
				export PERSISTENCE
				;;

			persistence-encryption=*)
				PERSISTENCE_ENCRYPTION="${ARGUMENT#*=}"
				export PERSISTENCE_ENCRYPTION
				;;

			persistence-media=*)
				PERSISTENCE_MEDIA="${ARGUMENT#*=}"
				export PERSISTENCE_MEDIA
				;;
			persistence-method=*)
				PERSISTENCE_METHOD="${ARGUMENT#*=}"
				export PERSISTENCE_METHOD
				;;

			persistence-path=*)
				PERSISTENCE_PATH="${ARGUMENT#persistence-path=}"
				export PERSISTENCE_PATH
				;;
			persistence-read-only)
				PERSISTENCE_READONLY="true"
				export PERSISTENCE_READONLY
				;;

			persistence-storage=*)
				PERSISTENCE_STORAGE="${ARGUMENT#persistence-storage=}"
				export PERSISTENCE_STORAGE
				;;

			persistence-subtext=*)
				old_root_overlay_label="${old_root_overlay_label}-${ARGUMENT#persistence-subtext=}"
				old_home_overlay_label="${old_home_overlay_label}-${ARGUMENT#persistence-subtext=}"
				custom_overlay_label="${custom_overlay_label}-${ARGUMENT#persistence-subtext=}"
				root_snapshot_label="${root_snapshot_label}-${ARGUMENT#persistence-subtext=}"
				old_root_snapshot_label="${root_snapshot_label}-${ARGUMENT#persistence-subtext=}"
				home_snapshot_label="${home_snapshot_label}-${ARGUMENT#persistence-subtext=}"
				;;

			nopersistence)
				NOPERSISTENCE="true"
				export NOPERSISTENCE
				;;

			noprompt)
				NOPROMPT="true"
				export NOPROMPT
				;;

			noprompt=*)
				NOPROMPT="${ARGUMENT#noprompt=}"
				export NOPROMPT
				;;

			quickusbmodules)
				QUICKUSBMODULES="true"
				export QUICKUSBMODULES
				;;

			showmounts)
				SHOWMOUNTS="true"
				export SHOWMOUNTS
				;;

			silent)
				SILENT="true"
				export SILENT
				;;

			todisk=*)
				TODISK="${ARGUMENT#todisk=}"
				export TODISK
				;;

			toram)
				TORAM="true"
				export TORAM
				;;

			toram=*)
				TORAM="true"
				MODULETORAM="${ARGUMENT#toram=}"
				export TORAM MODULETORAM
				;;

			exposedroot)
				EXPOSED_ROOT="true"
				export EXPOSED_ROOT
				;;

			plainroot)
				PLAIN_ROOT="true"
				export PLAIN_ROOT
				;;

			skipunion)
				SKIP_UNION_MOUNTS="true"
				export SKIP_UNION_MOUNTS
				;;

			root=*)
				ROOT="${ARGUMENT#root=}"
				export ROOT
				;;

			union=*)
				UNIONTYPE="${ARGUMENT#union=}"
				export UNIONTYPE
				;;
		esac
	done

	# sort of compatibility with netboot.h from linux docs
	if [ -z "${NETBOOT}" ]
	then
		if [ "${ROOT}" = "/dev/nfs" ]
		then
			NETBOOT="nfs"
			export NETBOOT
		elif [ "${ROOT}" = "/dev/cifs" ]
		then
			NETBOOT="cifs"
			export NETBOOT
		fi
	fi

	if [ -z "${MODULE}" ]
	then
		MODULE="filesystem"
		export MODULE
	fi

	if [ -z "${UNIONTYPE}" ]
	then
		UNIONTYPE="aufs"
		export UNIONTYPE
	fi

	if [ -z "${PERSISTENCE_ENCRYPTION}" ]
	then
		PERSISTENCE_ENCRYPTION="none"
		export PERSISTENCE_ENCRYPTION
	elif is_in_comma_sep_list luks ${PERSISTENCE_ENCRYPTION}
	then
		if ! modprobe dm-crypt
		then
			log_warning_msg "Unable to load module dm-crypt"
			PERSISTENCE_ENCRYPTION=$(echo ${PERSISTENCE_ENCRYPTION} | sed -e 's/\<luks,\|,\?luks$//g')
			export PERSISTENCE_ENCRYPTION
		fi

		if [ ! -x /lib/cryptsetup/askpass ] || [ ! -x /sbin/cryptsetup ]
		then
			log_warning_msg "cryptsetup in unavailable"
			PERSISTENCE_ENCRYPTION=$(echo ${PERSISTENCE_ENCRYPTION} | sed -e 's/\<luks,\|,\?luks$//g')
			export PERSISTENCE_ENCRYPTION
		fi
	fi

	if [ -z "${PERSISTENCE_METHOD}" ]
	then
		PERSISTENCE_METHOD="snapshot,overlay"
		export PERSISTENCE_METHOD
	fi

	if [ -z "${PERSISTENCE_STORAGE}" ]
	then
		PERSISTENCE_STORAGE="filesystem,file"
		export PERSISTENCE_STORAGE
	fi
}

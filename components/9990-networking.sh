#!/bin/sh

#set -e

Device_from_bootif ()
{
	# support for Syslinux IPAPPEND parameter
	# it sets the BOOTIF variable on the kernel parameter

	if [ -n "${BOOTIF}" ]
	then
		# pxelinux sets BOOTIF to a value based on the mac address of the
		# network card used to PXE boot, so use this value for DEVICE rather
		# than a hard-coded device name from initramfs.conf. this facilitates
		# network booting when machines may have multiple network cards.
		# pxelinux sets BOOTIF to 01-$mac_address

		# strip off the leading "01-", which isn't part of the mac
		# address
		temp_mac=${BOOTIF#*-}

		# convert to typical mac address format by replacing "-" with ":"
		bootif_mac=""
		IFS='-'
		for x in $temp_mac
		do
			if [ -z "$bootif_mac" ]
			then
				bootif_mac="$x"
			else
				bootif_mac="$bootif_mac:$x"
			fi
		done
		unset IFS

		# look for devices with matching mac address, and set DEVICE to
		# appropriate value if match is found.

		for device in /sys/class/net/*
		do
			if [ -f "$device/address" ]
			then
			current_mac=$(cat "$device/address")

				if [ "$bootif_mac" = "$current_mac" ]
				then
					ETHDEVICE="${device##*/},$ETHDEVICE" # use ethdevice
					break
				fi
			fi
		done
	fi
}

get_ipconfig_para()
{
	if [ $# != 1 ] ; then
		echo "Missin parameter for $0"
		return
	fi
	devname=$1
	for ip in ${STATICIP} ; do
		case $ip in
			*:$devname:*)
			echo $ip
			return
			;;
		esac
	done
	echo $devname
}

do_netsetup ()
{
	modprobe -q af_packet # For DHCP

	udevadm trigger
	udevadm settle

	[ -n "$ETHDEV_TIMEOUT" ] || ETHDEV_TIMEOUT=15
	echo "Using timeout of $ETHDEV_TIMEOUT seconds for network configuration."

	# Our modus operandi for getting a working network setup is this:
	# * If ip=* is set, pass that to ipconfig and be done
	# * Else, try dhcp on all devices in this order:
	#   ethdevice= bootif= <all interfaces>

	ALLDEVICES="$(cd /sys/class/net/ && ls -1 2>/dev/null | grep -v '^lo$' )"

	# Turn on all interfaces before doing anything, to avoid timing problems
	# during link negotiation.
	echo "Net: Turning on all device links..."
	for device in ${ALLDEVICES}; do
		ipconfig -c none -d $device -t 1 2>/dev/null >/dev/null
	done

		# See if we can select the device from BOOTIF
		Device_from_bootif

		# if ethdevice was not specified on the kernel command line
		# make sure we try to get a working network configuration
		# for *every* present network device (except for loopback of course)
		if [ -z "$ETHDEVICE" ]
		then
			echo "If you want to boot from a specific device use bootoption ethdevice=..."
			ETHDEVICE="$ALLDEVICES"
		fi

		# split args of ethdevice=eth0,eth1 into "eth0 eth1"
		for device in $(echo $ETHDEVICE | sed 's/,/ /g')
		do
			devlist="$devlist $device"
		done

		for dev in $devlist ; do
			param="$(get_ipconfig_para $dev)"
			if [ -n "$NODHCP" ] && [ "$param" = "$dev" ] ; then
				echo "Ignoring network device $dev due to nodhcp." | tee -a /boot.log
				continue
			fi
			echo "Executing ipconfig -t $ETHDEV_TIMEOUT $param"
			ipconfig -t "$ETHDEV_TIMEOUT" "$param" | tee -a /netboot.config

			# if configuration of device worked we should have an assigned
			# IP address, if so let's use the device as $DEVICE for later usage.
			# simple and primitive approach which seems to work fine

			IPV4ADDR="0.0.0.0"
			if [ -e "/run/net-${device}.conf" ]; then
				. /run/net-${device}.conf
			fi
			if [ "${IPV4ADDR}" != "0.0.0.0" ]; then
				export DEVICE="$dev $DEVICE"
				# break  # exit loop as we just use the irst
			fi
		done
	unset devlist

	for interface in ${DEVICE}
	do
		# source relevant ipconfig output
		OLDHOSTNAME=${HOSTNAME}

		[ -e /run/net-${interface}.conf ] && . /run/net-${interface}.conf

		[ -z ${HOSTNAME} ] && HOSTNAME=${OLDHOSTNAME}
		export HOSTNAME

		if [ -n "${interface}" ]
		then
			HWADDR="$(cat /sys/class/net/${interface}/address)"
		fi

		if [ ! -e "/etc/resolv.conf" ]
		then
			echo "Creating /etc/resolv.conf"

			if [ -n "${DNSDOMAIN}" ]
			then
				echo "domain ${DNSDOMAIN}" > /etc/resolv.conf
				echo "search ${DNSDOMAIN}" >> /etc/resolv.conf
			fi

			for i in ${IPV4DNS0} ${IPV4DNS1} ${IPV4DNS1} ${DNSSERVERS}
			do
				if [ -n "$i" ] && [ "$i" != 0.0.0.0 ]
				then
					echo "nameserver $i" >> /etc/resolv.conf
				fi
			done
		fi

		# Check if we have a network device at all
		if ! ls /sys/class/net/"$interface" > /dev/null 2>&1 && \
		   ! ls /sys/class/net/eth0 > /dev/null 2>&1 && \
		   ! ls /sys/class/net/wlan0 > /dev/null 2>&1 && \
		   ! ls /sys/class/net/ath0 > /dev/null 2>&1 && \
		   ! ls /sys/class/net/ra0 > /dev/null 2>&1
		then
			panic "No supported network device found, maybe a non-mainline driver is required."
		fi
	done
}

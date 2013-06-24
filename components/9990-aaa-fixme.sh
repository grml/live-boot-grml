#!/bin/sh

PATH="/root/usr/bin:/root/usr/sbin:/root/bin:/root/sbin:/usr/bin:/usr/sbin:/bin:/sbin"
export PATH

echo "/root/lib" >> /etc/ld.so.conf
echo "/root/usr/lib" >> /etc/ld.so.conf

mountpoint="/live/medium"
alt_mountpoint="/media"
LIVE_MEDIA_PATH="live"

HOSTNAME="host"

mkdir -p "${mountpoint}"
tried="/tmp/tried"

# Create /etc/mtab for debug purpose and future syncs
mkdir -p /etc

if [ ! -f /etc/mtab ]
then
	touch /etc/mtab
fi

if [ ! -x "/bin/fstype" ]
then
	# klibc not in path -> not in initramfs
	PATH="${PATH}:/usr/lib/klibc/bin"
	export PATH
fi

# handle upgrade path from old udev (using udevinfo) to
# recent versions of udev (using udevadm info)
if [ -x /sbin/udevadm ]
then
	udevinfo='/sbin/udevadm info'
else
	udevinfo='udevinfo'
fi

custom_overlay_label="persistence"
persistence_list="persistence.conf"
old_persistence_list="live-persistence.conf"

if [ ! -f /live.vars ]
then
	touch /live.vars
fi
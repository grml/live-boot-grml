#!/bin/sh

PATH="/root/usr/bin:/root/usr/sbin:/root/bin:/root/sbin:/usr/bin:/usr/sbin:/bin:/sbin"
export PATH

echo "/root/lib" >> /etc/ld.so.conf
echo "/root/usr/lib" >> /etc/ld.so.conf

mountpoint="/live/medium"
alt_mountpoint="/media"
LIVE_MEDIA_PATH="live"

HOSTNAME="grml"

mkdir -p "${mountpoint}"
mkdir -p /var/lib/live/boot

# Create /etc/mtab for debug purpose and future syncs
mkdir -p /etc
touch /etc/mtab

if [ ! -x "/bin/fstype" ]
then
	# klibc not in path -> not in initramfs
	PATH="${PATH}:/usr/lib/klibc/bin"
	export PATH
fi

old_root_overlay_label="live-rw"
old_home_overlay_label="home-rw"
custom_overlay_label="persistence"
old_custom_overlay_label="custom-ov"
persistence_list="persistence.conf"

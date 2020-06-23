#!/bin/sh

#set -e

Grml_Networking () {

if [ -n "${NONETWORKING}" ]; then
   return 0
fi

log_begin_msg "Preconfiguring Grml networking"

modprobe af_packet # req'd for DHCP

# initialize udev
# (this /might/ be required for firmware loading to complete)
if grep -q noudev /proc/cmdline; then
   log_begin_msg "Networking: Skipping udev as requested via bootoption noudev."
else
   udevadm trigger
   udevadm settle
fi

if [ -n "${IP}" ]; then
   # call into initramfs-tools provided network setup functions, so basic
   # networking is fine.
   log_begin_msg "Networking: Waiting for basic network to come up..."
   configure_networking
fi

# prepare a new /etc/network/interfaces file (and, possibly, a new /etc/resolv.conf)
IFFILE="/root/etc/network/interfaces"
if [ -L /root/etc/resolv.conf ] ; then
  # assume we have resolvconf
  RESOLVCONF=/root/etc/resolvconf/resolv.conf.d/base
else
  RESOLVCONF="/root/etc/resolv.conf"
fi

# config for loopback networking
cat > $IFFILE << EOF
# Initially generated on boot by initramfs

auto lo
iface lo inet loopback

EOF

unset HOSTNAME

# generate config for each present network device
for interface in /sys/class/net/* ; do
    [ -e ${interface} ] || continue
    interface=$(basename ${interface})
    [ "${interface}" = "lo" ] && continue
    method="dhcp"

    # NODHCP or a previously run ipconfig mean that ifupdown should never
    # touch this interface (IP-stack wise).
    netconfig=/run/net-${interface}.conf
    if [ -n "$NODHCP" ] || [ -e "${netconfig}" ]; then
        method="manual"
    fi

    # if boot option "nodhcp" is set but also boot option "dhcp" is
    # set, then dhcp should win over it as we default to dhcp and if
    # nodhcp is used as default boot option but "dhcp" is added then it
    # would be confusing to not get a working network setup
    if [ "$DHCP" = "true" ] ; then
        method="dhcp"
    fi

    if [ -n "$VLANS" ] ; then
      modprobe 8021q

      # vlan=<vid>:<phydevice>
      for line in $(echo $VLANS | sed 's/ /\n'/) ; do
        vlandev=${line#*:}
        vlanid=${line%:*}

        if [ -n "$vlandev" ] && [ -n "$vlanid" ] ; then
          case "$vlandev" in
            "$interface")
              vlan_raw_dev=$interface
              interface="${vlandev}.${vlanid}"
              ;;
          esac
        fi
      done
    fi

    if [ -n "$vlan_raw_dev" ] ; then
      cat >> $IFFILE << EOF
auto ${interface}
iface ${interface} inet ${method}
        vlan-raw-device $vlan_raw_dev
EOF
    else
      cat >> $IFFILE << EOF
allow-hotplug ${interface}
iface ${interface} inet ${method}
EOF
    fi

    unset vlandev vlanid vlan_raw_dev # unset variables to have clean state for next device

    # DNS for resolvconf and /etc/resolv.conf
    if [ -e "${netconfig}" ]; then
        . "${netconfig}"
        if [ -n "${DNSDOMAIN}" ]; then
            echo "    dns-search ${DNSDOMAIN}" >> $IFFILE
        fi
        # make sure we don't have any 0.0.0.0 nameservers
        IPV4DNSLIST=""
        for IPV4DNS in ${IPV4DNS0} ${IPV4DNS1}; do
            [ -n "${IPV4DNS}" ] || continue
            [ "${IPV4DNS}" != "0.0.0.0" ] || continue
            IPV4DNSLIST="${IPV4DNSLIST}${IPV4DNS} "
        done
        if [ -n "${IPV4DNSLIST}" ]; then
            echo "    dns-nameservers ${IPV4DNSLIST}" >> $IFFILE
            for IPV4DNS in ${IPV4DNSLIST}; do
                echo "nameserver ${IPV4DNS}" >> $RESOLVCONF
            done
        fi
    fi

    if [ -z "$NODHCPHOSTNAME" -a -n "$HOSTNAME" ]; then
        echo $HOSTNAME > /root/etc/hostname
    fi

    unset DEVICE IPV4ADDR IPV4BROADCAST IPV4NETMASK IPV4GATEWAY IPV4DNS0 IPV4DNS1 HOSTNAME DNSDOMAIN NISDOMAIN ROOTSERVER ROOTPATH filename
    unset IPV4DNS IPV4DNSLIST

    echo>> $IFFILE
done

echo '# Support overriding defaults:' >> $IFFILE
echo 'source /etc/network/interfaces.d/*' >> $IFFILE
echo>> $IFFILE

# dns bootoption
if [ -n "$DNSSERVERS" ]
then
	# disable any existing entries
	if [ -r $RESOLVCONF ]
	then
		sed -i 's/nameserver/# nameserver/' $RESOLVCONF
	fi
	for i in $DNSSERVERS
	do
		echo "nameserver $i" >> $RESOLVCONF
	done
fi

}

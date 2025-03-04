#!/bin/sh

#set -e

Cmdline_old ()
{
	for _PARAMETER in ${LIVE_BOOT_CMDLINE}
	do
		case "${_PARAMETER}" in
			bootid=*)
				BOOTID="${_PARAMETER#bootid=}"
				export BOOTID
				;;

			ignore_bootid)
				IGNORE_BOOTID="Yes"
				export IGNORE_BOOTID
				;;

			nodhcphostname)
				NODHCPHOSTNAME="Yes"
				export NODHCPHOSTNAME
				;;

			vlan=*)
				VLANS="${VLANS} ${_PARAMETER#vlan=}"
				export VLANS
				;;
		esac
	done

	# Call original function
	. /usr/lib/live/boot/9990-cmdline-old
	Cmdline_old "$@"
}

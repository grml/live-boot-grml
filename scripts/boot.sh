#!/bin/sh

# set -e

for _SCRIPT in /lib/live/boot/????-*
do
	if [ -e "${_SCRIPT}" ]
	then
		. ${_SCRIPT}
	fi
done

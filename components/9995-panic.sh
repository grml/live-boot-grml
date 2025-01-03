#!/bin/sh

#set -e

# Override panic from scripts/functions, _AND_ from 9990-initramfs-tools.sh
panic()
{
	for _PARAMETER in ${LIVE_BOOT_CMDLINE}
	do
		case "${_PARAMETER}" in
			panic=*)
				panic="${_PARAMETER#*panic=}"
				;;
		esac
	done

	DEB_1="\033[1;31m .''\`.  \033[0m"
	DEB_2="\033[1;31m: :'  : \033[0m"
	DEB_3="\033[1;31m\`. \`'\`  \033[0m"
	DEB_4="\033[1;31m  \`-    \033[0m"

	LIVELOG="\033[1;37m/boot.log\033[0m"
	DEBUG="\033[1;37mdebug\033[0m"

	# Reset redirections to avoid buffering
	exec 1>&6 6>&-
	exec 2>&7 7>&-
	kill ${tailpid}

	printf "\n\n"
	printf "  \033[1;37mBOOT FAILED!\033[0m\n"
	printf "\n"
	printf "  This image failed to boot.\n\n"

	printf "  Please file a bug at your distributors bug tracking system, making\n"
	printf "  sure to note the exact version, name and distribution of the image\n"
	printf "  you were attempting to boot.\n\n"

	if [ -r /etc/grml_version ]
	then
		GRML_VERSION="$(cat /etc/grml_version)"
		printf "  $GRML_VERSION\n\n"
	fi

	printf "  The file ${LIVELOG} contains some debugging information but booting with the\n"
	printf "  ${DEBUG}=1 command-line parameter will greatly increase its verbosity which is\n"
	printf "  extremely useful when diagnosing issues.\n\n"

	if [ -n "${panic}" ]; then
		printf "  live-boot will now restart your system. "
	else
		printf "  live-boot will now start a shell. "
	fi
	printf "The error message was:\n\n    "

	# Call original panic
	. /scripts/functions
	panic "$@"
}

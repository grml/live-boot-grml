#!/bin/sh

set -e

VERSION="$(cat ../VERSION)"

echo "Updating version headers..."

for MANPAGE in en/*
do
	SECTION="$(basename ${MANPAGE} | awk -F. '{ print $2 }')"

	sed -i -e "s|^.TH.*$|.TH LIVE\\\-BOOT ${SECTION} $(date +%Y\\\\-%m\\\\-%d) ${VERSION} \"Debian Live Project\"|" ${MANPAGE}
done

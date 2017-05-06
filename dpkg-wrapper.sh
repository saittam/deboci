#!/bin/bash

set -eo pipefail

fatal() {
	echo "$@" 1>&2
	exit 1
}

# Make sure the environment contains sane configuration.
test -d "${DEBOCI_ROOTFS}" || \
	fatal "\${DEBOCI_ROOTFS} must be a directory: ${DEBOCI_ROOTFS}"

# Parse the command line to figure out what we're supposed to do.
declare -a args
operation=
while test "$#" -ge 1; do
	case "$1" in
		--unpack|--configure)
			operation="$1"
			;;
		--status-fd)
			shift
			;;
		--*)
			;;
		*)
			args+=("$1")
			;;
	esac
	shift
done

case "${operation}" in
	--unpack)
		for debfile in "${args[@]}"; do
			dpkg --extract "${debfile}" "${DEBOCI_ROOTFS}"
		done
		exit 0
		;;
	--configure)
		# Ignore - package configuration scripts don't run properly
		# outside a chroot but we're not privileged. Most packages work
		# just fine even without getting configured, in particular
		# since we don't require a working init system etc.
		;;
	*)
		fatal "$0: Don't know what to do!"
		;;
esac

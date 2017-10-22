#!/bin/bash
#
# Creates a base rootfs using debootstrap. Some details shamelessly stolen from
# docker base image creation scripts.

set -eo pipefail

libdir="$(dirname $0)"
destdir="${1:-.}"	
final_target="$2"
conf="${destdir}/conf"
rootfs="${destdir}/rootfs"
cache="/var/local/deboci/cache"

fatal() {
	echo "$@" 1>&2
	exit 1
}

# Sanity checks.
test "$#" -eq 2 || \
	fatal "Usage: $0 <destination-dir> <target-spec-dir>"
test -e "${destdir}" && \
	fatal "Destination dir ${destdir} already exists, remove to start over."
test -d "${final_target}" || \
	fatal "Target spec ${final_target} is not a directory"

# Figure out the chain of targets and its reverse.
target="${final_target}"
declare -a targets
while test -d "${target}"; do
	targets+=("${target}")
	target=$(readlink -f "${target}/base")
done
unset target

declare -a targets_reverse
IFS=$'\n'
for index in $(echo "${!targets[*]}" | tac); do
	targets_reverse+=("${targets[$index]}")
done
unset IFS

# Merge the configuration directories.
mkdir -p "${conf}"
for target in "${targets_reverse[@]}"; do
	test -d "${target}/conf" || continue
	cp -ar "${target}/conf/" "${destdir}"
done

# Make sure some essential directories and files are present.
mkdir -p "${conf}/etc/apt/preferences.d"
mkdir -p "${conf}/etc/apt/sources.list.d"
mkdir -p "${conf}/var/lib/apt"
mkdir -p "${conf}/var/log/apt"
mkdir -p "${conf}/var/lib/dpkg"
touch "${conf}/var/lib/dpkg/status"
mkdir -p "${cache}"

# Invoke apt with configuration that points at the correct directories, i.e.
# apt config in ${conf}, cache files in ${cache} and the output directory at
# ${destdir}.
apt_config_args=(
	-o "Dir=${rootfs}"
	-o "Dir::Cache=${cache}"
	-o "Dir::Etc=${conf}/etc/apt"
	-o "Dir::State=${conf}/var/lib/apt"
	-o "Dir::State::Status=${conf}/var/lib/dpkg/status"
	-o "Dir::Log=${conf}/var/log/apt"
)

# Get the package list.
apt-get "${apt_config_args[@]}" update

# Merge the list of packages requested for installation.
packages=$(
	for target in "${targets[@]}"; do
		cat "${target}/conf/etc/deboci/packages"
	done | sort -u)

# Prepare the rootfs.
mkdir -p "${rootfs}"
for target in "${targets_reverse[@]}"; do
	test -d "${target}/rootfs" || continue
	cp -ar "${target}/rootfs/" "${destdir}"
done

# Trigger package installation, including dependencies. Note that apt-get will
# call out to our dpkg-wrapper.sh script, which handles the actual unpacking.
DEBOCI_ROOTFS="${rootfs}" \
apt-get "${apt_config_args[@]}" \
	-o "Dir::Bin::dpkg=${libdir}/dpkg-wrapper.sh" \
	-y install ${packages}

# Merge OCI specs from the target chain to produce the final OCI spec.
for target in "${targets_reverse[@]}"; do
	test -f "${target}/config.json" && echo "${target}/config.json"
done | xargs jq -M -s -f "${libdir}/merge_oci_config.jq" \
	<(echo "{ \"hostname\": \"$(basename "${final_target}")\" }") \
	"${libdir}/base_config.json" \
	> "${destdir}/config.json"

echo "Done!" 1>&2

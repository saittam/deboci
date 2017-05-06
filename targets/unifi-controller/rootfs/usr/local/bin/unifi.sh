#!/bin/sh

set -e

fatal() {
	echo "$@" 1>&2
	exit 1
}

# Determine JAVA_HOME.
JAVA_BIN="$(set -- /usr/lib/jvm/*/bin/java; echo $1)"
JAVA_HOME="${JAVA_BIN%%/bin/java}"
test -d "${JAVA_HOME}" || fatal "Failed to determine JAVA_HOME"

# Find jsvc.
JSVC="$(which jsvc)"
test -x "${JSVC}" || fatal "jsvc not found"

# Launch jsvc.
exec "${JSVC}" \
	-home "${JAVA_HOME}" \
	-pidfile "/var/run/unifi/jsvc.pid" \
	-outfile "/var/log/unifi/jsvc.log" \
	-errfile "&1" \
	-cp "/usr/share/java/commons-daemon.jar:/usr/lib/unifi/lib/ace.jar" \
	-procname unifi \
	-nodetach \
	-Xmx1024M \
	-Djava.awt.headless=true \
	-Dfile.encoding=UTF-8 \
	-Dunifi.datadir=/var/lib/unifi \
	-Dunifi.logdir=/var/log/unifi \
	-Dunifi.rundir=/var/run/unifi \
	com.ubnt.ace.Launcher start

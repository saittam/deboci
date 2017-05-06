#!/bin/sh
#
# OCI pre-start hook that sets up a veth pair to allow communication between
# container and host. Parameters are passed in environment variables as
# follows:
#   net_veth_peer_name - name of the interface on the peer side
#   net_veth_peer_ip - IPv4 address / mask for the peer side
#   net_veth_peer_gw - IPv4 gateway address of the default route.
#   net_veth_host_name - name of the interface on the host side
#   net_veth_host_ip - IPv4 address / mask for the host side
#   net_veth_host_bridge - Bridge with which to hook up the host side.

# The container runtime passes hook parameters via stdin in JSON format. Grab
# it and extract relevant parameters.
hook_data=$(cat -)
container_pid=$(echo "$hook_data" | jq -r .pid)

# Create the veth pair.
host_name="veth-${container_pid}-host"
peer_name="veth-${container_pid}-peer"
ip link add name "${host_name}" type veth peer name "${peer_name}"

# Throw the peer end over the wall.
ip link set dev "${peer_name}" netns "${container_pid}"

# Configure the host side.
if test -n "${net_veth_host_name}"; then
	ip link set "${host_name}" name "${net_veth_host_name}"
	host_name="${net_veth_host_name}"
fi
if test -n "${net_veth_host_ip}"; then
	ip addr add "${net_veth_host_ip}" dev "${host_name}"
fi
ip link set dev "${host_name}" up

if test -n "${net_veth_host_bridge}"; then
	ip link set "${host_name}" master "${net_veth_host_bridge}"
fi

# Configure peer side.
peerns() {
	nsenter --target "${container_pid}" --net "$@"
}

if test -n "${net_veth_peer_name}"; then
	peerns ip link set "${peer_name}" name "${net_veth_peer_name}"
	peer_name="${net_veth_peer_name}"
fi
if test -n "${net_veth_peer_ip}"; then
	peerns ip addr add "${net_veth_peer_ip}" dev "${peer_name}"
fi
peerns ip link set dev "${peer_name}" up
if test -n "${net_veth_peer_gw}"; then
	peerns ip route add default via "${net_veth_peer_gw}" dev "${peer_name}"
fi

exit 0

#!/bin/sh
# Drains this instance. Its health endpoint fails, so the load balancers send new flows to the other
# instances while the existing ones keep coming here. After the grace period, the flows still
# forwarded are reset, so both ends retry at once instead of timing out.
#
# Usage: network-appliance-drain GRACE_SECONDS
set -eu

grace_seconds="$1"

mkdir -p /run/network-appliance
touch /run/network-appliance/draining
sleep "$grace_seconds"

nft add rule inet network_appliance drain meta l4proto tcp reject with tcp reset
nft add rule inet network_appliance drain meta l4proto udp reject with icmpx type port-unreachable

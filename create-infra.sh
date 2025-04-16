#!/bin/bash

clustername=$1
cidr=$2

[ -z "$clustername" ] && exit 2
[ -z "$cidr" ] && exit 2

set -e

pool_start=$(nmap -n -sL "${cidr}" -oG - | awk '/^#/ {next} {print $2}' | sed -n 12p)
pool_end=$(nmap -n -sL "${cidr}" -oG - | awk '/^#/ {next} {print $2}' | tail -16 | sed -n 1p)

cat > "${clustername}.env" <<EOF
CLUSTER_NAME=$clustername
CLUSTER_CIDR=$cidr
CLUSTER_ADDRESS_ALLOCATION_POOL=${pool_start}:${pool_end}
EOF

openstack network create "${clustername}-network" -f json > "${clustername}-network.json"
openstack subnet create "${clustername}-subnet" --network "${clustername}-network" \
  --dns-nameserver 8.8.8.8 \
  --subnet-range "${cidr}" \
  --allocation-pool start="${pool_start}",end="${pool_end}" -f json > "${clustername}-subnet.json"
openstack router create "${clustername}-router" --external-gateway external -f json > "${clustername}-router.json"
openstack router add subnet "${clustername}-router" "${clustername}-subnet"


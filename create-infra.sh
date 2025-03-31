#!/bin/sh

clustername=$1
cidr=$2
api_address_int=$3
ingress_address_int=$4

set -e

pool_start=$(nmap -n -sL "${cidr}" -oG - | awk '/^#/ {next} {print $2}' | sed -n 12p)
pool_end=$(nmap -n -sL "${cidr}" -oG - | awk '/^#/ {next} {print $2}' | tail -16 | sed -n 1p)

cat > "${clustername}.env" <<EOF
CLUSTER_NAME=$clustername
CLUSTER_CIDR=$cidr
CLUSTER_API_ADDRESS_INTERNAL=$api_address_int
CLUSTER_INGRESS_ADDRESS_INTERNAL=$ingress_address_int
CLUSTER_ADDRESS_ALLOCATION_POOL=${pool_start}:${pool_end}
EOF

openstack network create "${clustername}" -f json > "${clustername}-network.json"
openstack subnet create "${clustername}-subnet" --network "${clustername}" \
  --dns-nameserver 8.8.8.8 \
  --subnet-range "${cidr}" \
  --allocation-pool start="${pool_start}",end="${pool_end}" -f json > "${clustername}-subnet.json"
openstack router create "${clustername}-router" --external-gateway external -f json > "${clustername}-router.json"
openstack router add subnet "${clustername}-router" "${clustername}-subnet"
openstack port create "${clustername}-api-int" --network "${clustername}" \
  --fixed-ip "subnet=${clustername}-subnet,ip-address=${api_address_int}" -f json > "${clustername}-port-api.json"
openstack port create "${clustername}-ingress-int" --network "${clustername}" \
  --fixed-ip "subnet=${clustername}-subnet,ip-address=${ingress_address_int}" -f json > "${clustername}-port-ingress.json"

api_address_ext=$(openstack floating ip create external --description "${clustername}-api" -f value -c "floating_ip_address")
ingress_address_ext=$(openstack floating ip create external --description "${clustername}-ingress" -f value -c "floating_ip_address")

cat >> "${clustername}.env" <<EOF
CLUSTER_API_ADDRESS_EXTERNAL=$api_address_ext
CLUSTER_INGRESS_ADDRESS_EXTERNAL=$ingress_address_ext
EOF

openstack esi port forwarding create "${clustername}-api-int" "${api_address_ext}" -p 6443
openstack esi port forwarding create "${clustername}-ingress-int" "${ingress_address_ext}" -p 80 -p 443

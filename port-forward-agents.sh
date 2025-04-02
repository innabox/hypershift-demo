#!/bin/bash

# Create port forwards for all matching agents. Note that the selected agents
# must all be on the same openstack network.

while getopts n:l: ch; do
  case $ch in
  l)
    label_selector="${label_selector}${label_selector:+,}$OPTARG"
    ;;
  n)
    namespace=$OPTARG
    ;;
  *)
    exit 2
    ;;
  esac
done
shift $((OPTIND - 1))

extip=$1
if [ -z "$extip" ]; then
  echo "ERROR: missing floating ip address" >&2
  exit 1
fi

mapfile -t agentips < <(
  kubectl ${namespace:+-n "$namespace"} ${label_selector:+-l "${label_selector}"} get agents \
    -o jsonpath='{.items[*].status.inventory.interfaces[?(@.ipV4Addresses[*])].ipV4Addresses[*]}' |
    tr ' ' '\n'
)

port=2200
for agentip in "${agentips[@]}"; do
  echo "${extip}:${port} -> ${agentip%/*}"
  openstack esi port forwarding create "${agentip%/*}" "$extip" -p "${port}:22"
  ((port++))
done

#!/bin/bash

while getopts n:l: ch; do
  case $ch in
  n) namespace=$OPTARG ;;
  l) labelselector=$OPTARG ;;
  *) exit 2 ;;
  esac
done
shift $((OPTIND - 1))

set -eu

workdir=$(mktemp -d workXXXXXX)
trap 'rm -rf "$workdir"' EXIT

echo "get list of agents"
kubectl ${namespace:+-n "$namespace"} get agents -o json ${labelselector:+-l ${labelselector}} |
  jq -r '.items[]|[.metadata.name, (.status.inventory.interfaces[]|select(.flags|index("running")).macAddress)]|@tsv' >"$workdir/agents.tab"

#PS1='debug> ' bash --norc

while read -r agent macaddrs; do
  for macaddr in $macaddrs; do
    echo "agent $agent: looking up node with mac address $macaddr"
    node=$(
      openstack baremetal port list --address "$macaddr" -f value -c uuid |
        xargs openstack baremetal port show -f value -c node_uuid 2>/dev/null |
        xargs openstack baremetal node show -f value -c name 2>/dev/null || :
    )
    [ -n "$node" ] && break
  done

  if [[ -z $node ]]; then
    echo "unable to determine name for agent $agent ($macaddr)" >&2
    continue
  fi
  echo "found node $node for agent $agent"

  openstack baremetal node show "$node" -f json >"$workdir/$node.json"

  resource_class=$(jq -r .resource_class "$workdir/$node.json")
  uuid=$(jq -r .uuid "$workdir/$node.json")

  kubectl ${namespace:+-n "$namespace"} annotate agent "$agent" esi.nerc.mghpcc.org/uuid="$uuid"

  # MOC-R8PAC23U26
  if [[ $node =~ MOC-R([0-9]+)P([A-Z])C([0-9]+)U([0-9]+)(-S(.*))? ]]; then
    echo "labelling node $node with: ${BASH_REMATCH[*]}"
    kubectl ${namespace:+-n "$namespace"} label --overwrite agent "$agent" \
      topology.nerc.mghpcc.org/row="${BASH_REMATCH[1]}" \
      topology.nerc.mghpcc.org/pod="${BASH_REMATCH[2]}" \
      topology.nerc.mghpcc.org/cabinet="${BASH_REMATCH[3]}" \
      topology.nerc.mghpcc.org/u="${BASH_REMATCH[4]}" \
      topology.nerc.mghpcc.org/slot="${BASH_REMATCH[6]:-none}" \
      esi.nerc.mghpcc.org/resource_class="$resource_class"
  fi

  # ensure node name is lower case
  node=${node,,}
  kubectl ${namespace:+-n "$namespace"} patch agent "$agent" --type json --patch-file /dev/stdin <<EOF
[
{"op": "add", "path": "/spec/hostname", "value": "$node"}
]
EOF
done <"$workdir/agents.tab"

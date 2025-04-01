#!/bin/bash

if (( $# < 2 )); then
  echo "$0: usage: $0 <clustername> <basedomain> [hcp args]" >&2
  exit 2
fi

clustername=$1
basedomain=$2
shift 2

[[ -z "$clustername" ]] && exit 1

tee -a "${clustername}-extra-manifests.yaml" <<EOF | kubectl apply -f- >/dev/null
apiVersion: v1
kind: Namespace
metadata:
  name: clusters-$clustername
EOF

hcp create cluster agent \
  --name="$clustername" \
  --pull-secret=pull-secret.txt \
  --agent-namespace=hardware-inventory \
  --base-domain="$basedomain" \
  --api-server-address=api."$clustername"."$basedomain" \
  --etcd-storage-class=lvms-vg1 \
  --ssh-key sshkey.pub \
  --namespace clusters \
  --control-plane-availability-policy HighlyAvailable \
  --release-image=quay.io/openshift-release-dev/ocp-release:4.17.9-multi \
  "$@"

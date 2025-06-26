#!/bin/bash

# usage: cancelcluster.sh <namespace> <clustername>
#
# This script will attempt to clean up resources from a failed Hosted Control Plane install
# when using the "Agent" platform.

remove_finalizers() {
  kubectl patch --type json --patch '[{"op": "remove", "path": "/metadata/finalizers"}]' "$@"
}

usage() {
  echo "$0: usage: $0 <hosted_cluster_namespace_name> <hosted_cluster_name>"
}

if (($# < 2)); then
  usage >&2
  exit 2
fi

hc_namespace=$1
hc_name=$2

if [[ -z $hc_namespace ]] || [[ -z $hc_name ]]; then
  echo "ERROR: namespace and hosted cluster name must be non-empty" >&2
  exit 1
fi

cluster_namespace="${hc_namespace}-${hc_name}"
nodepool_name="nodepool-${hc_name}"

# find agent namespace
agent_namespace=$(kubectl -n "$hc_namespace" get HostedCluster "$hc_name" -o jsonpath='{.spec.platform.agent.agentNamespace}')

# find agentmachines
kubectl -n "$cluster_namespace" get AgentMachine -o name | cut -f2 -d/ | while read -r agentmachine; do
  remove_finalizers -n "$cluster_namespace" AgentMachine "$agentmachine"
  kubectl -n "$agent_namespace" get Agent -l agentMachineRef="$agentmachine" -o name | cut -f2 -d/ | while read -r agent; do
    remove_finalizers -n "$agent_namespace" Agent "$agent"
    # We probably don't want to delete the agents.
    #kubectl -n "$agent_namespace" delete Agent "$agent" --wait=false
  done
done

remove_finalizers -n "$hc_namespace" HostedCluster "$hc_name"
remove_finalizers -n "$hc_namespace" NodePool "$nodepool_name"
remove_finalizers -n "$cluster_namespace" AgentClusterInstall "$hc_name"
remove_finalizers -n "$cluster_namespace" ClusterDeployment "$hc_name"
remove_finalizers -n "$cluster_namespace" AgentCluster "$hc_name"
remove_finalizers -n "$cluster_namespace" clusters.cluster.x-k8s.io "$hc_name"
remove_finalizers -n "$cluster_namespace" hostedcontrolplanes "$hc_name"

kubectl -n "$cluster_namespace" get Machine -o name | cut -f2 -d/ | while read -r machine; do
  remove_finalizers -n "$cluster_namespace" Machine "$machine"
done

kubectl -n "$hc_namespace" delete --wait=false hostedcluster "$hc_name"
kubectl -n "$cluster_namespace" delete --wait=false AgentClusterInstall "$hc_name"
kubectl -n "$cluster_namespace" delete --wait=false ClusterDeployment "$hc_name"
kubectl -n "$cluster_namespace" delete --wait=false AgentCluster "$hc_name"

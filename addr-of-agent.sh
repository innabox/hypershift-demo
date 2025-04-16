#!/bin/bash

while getopts n: ch; do
  case $ch in
  n)
    namespace=$OPTARG
    ;;
  *)
    exit 2
    ;;
  esac
done
shift $((OPTIND - 1))

agentname="${1,,}"
if [ -z "$agentname" ]; then
  echo "ERROR: missing agent name" >&2
  exit 2
fi


agentid=$(
kubectl ${namespace:+-n "$namespace"} get agents -o json | jq -r --arg agentname "$agentname" '.items[]|select(.spec.hostname==$agentname)|.metadata.name'
)

kubectl ${namespace:+-n "$namespace"} get agent "$agentid" \
  -o jsonpath='{.status.inventory.interfaces[?(@.ipV4Addresses[*])].ipV4Addresses[*]}'
echo

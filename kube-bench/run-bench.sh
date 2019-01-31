#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

function logs() {
    # shellcheck disable=SC2059
    kubectl logs "$1" | sed ''/PASS/s//"$(printf "${GREEN}PASS${RESET}")"/'' | sed ''/WARN/s//"$(printf "${YELLOW}WARN${RESET}")"/'' | sed ''/FAIL/s//"$(printf "${RED}FAIL${RESET}")"/''
}

if [ -z "$1" ]
  then
    echo "You need to supply the role (master | node)"
    exit 1
fi

if [[ ! "$1" =~ ^(master|node)$ ]]; then
    echo "You need to supply the role as master or node"
    exit 1
fi

role=$1

# Create job for defined role
kubectl create -f job-"${role}".yml
echo "Waiting for benchmarking pod(s) to complete..."
kubectl wait --for=condition=complete --timeout=60s job/kube-bench-"${role}"

pod=$(kubectl get pods --selector=job-name=kube-bench-"${role}" --output=jsonpath={.items..metadata.name})
logs "$pod"
sleep 1
# Grab the exit code of the pod. Not that it currently matters though as kube-bench seems to exit with 0 every time
exit_code=$(kubectl get pod "$pod" --output=jsonpath="{.status.containerStatuses[0].state.terminated.exitCode}")
echo "Pod exit code: $exit_code"
kubectl delete -f job-"${role}".yml

exit "$exit_code"


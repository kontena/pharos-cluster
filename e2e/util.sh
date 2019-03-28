#!/bin/bash
# shellcheck disable=SC2124

# Retries a command on failure.
# $1 - the max number of attempts
# $2... - the command to run
retry() {
    local -r -i max_attempts="$1"; shift
    local -r cmd="$@"
    local -i attempt_num=1

    until $cmd
    do
        if (( attempt_num == max_attempts ))
        then
            echo "Attempt $attempt_num failed and there are no more attempts left!"
            return 1
        else
            echo "Attempt $attempt_num failed! Trying again in $attempt_num seconds..."
            sleep $(( attempt_num++ ))
        fi
    done
}

# $1 - label
# $2 - namespace
pods_running() {
    local -r label="$1"; shift
    local -r namespace="$1"; shift
    kubectl get pods -n "$namespace" -l "$label" | grep Running
}

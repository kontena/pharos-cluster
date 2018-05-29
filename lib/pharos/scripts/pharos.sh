#!/bin/bash

## @param file
file_exists() {
    if [ -f "$1" ]; then
        return 0
    fi
    return 1
}

## @param match
## @param line
## @param file
lineinfile() {
    [[ $# -lt 3 ]] && return 1

    match=$1
    line=$2
    shift
    shift

    for file in "$@"; do
        file_exists "$file" || return 1
        grep -q "${match}" $file && sed "s/${match}.*/${line}/" -i $file || echo $line >> $file
    done

    return 0
}

## @param match
## @param file
linefromfile() {
    [[ $# -lt 2 ]] && return 1

    match=$1
    shift

    for file in "$@"; do
        file_exists "$file" || return 1
        sed -i "/${match}/d" $file
    done
}
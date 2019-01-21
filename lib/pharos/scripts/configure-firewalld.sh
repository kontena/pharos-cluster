#!/bin/bash

set -e

add_port() {
    local port=$1
    local zone=$2
    if ! firewall-cmd --query-port "$port" --zone "$zone" ; then
        firewall-cmd --permanent --add-port $port --zone $zone
    fi
}

add_source() {
    local source=$1
    local zone=$2
    if ! firewall-cmd --query-source "$source" --zone "$zone" ; then
        firewall-cmd --permanent --add-source $source --zone $zone
    fi
}

if ! systemctl is-active --quiet firewalld; then
    systemctl enable firewalld
    systemctl start firewalld
fi

add_port "22/tcp" "public"
add_port "80/tcp" "public"
add_port "443/tcp" "public"
add_port "30000-32767/tcp" "public"

if [ "$ROLE" = "master" ]; then
    add_port "6334/tcp" "public"
fi

for peer in $PEER_ADDRESSES ; do
    add_source "$peer" "trusted"
done

firewall-cmd --reload

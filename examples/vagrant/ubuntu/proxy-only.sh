#!/bin/bash

/sbin/iptables -A OUTPUT -p tcp --dport 80 -j DROP
/sbin/iptables -A OUTPUT -p tcp --dport 443 -j DROP
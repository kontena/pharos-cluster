#!/bin/bash

/sbin/iptables -A INPUT -p tcp -s 192.168.100.103 --dport 22 -j ACCEPT
/sbin/iptables -A INPUT -p tcp --dport 22 -j DROP
#!/bin/bash
# Restore firewall rules on boot
iptables -I INPUT 1 -i lo -j ACCEPT
iptables -I INPUT 2 -p tcp --dport 5000 -s 127.0.0.1 -j ACCEPT
iptables -I INPUT 3 -p tcp --dport 5000 ! -s 127.0.0.1 -j DROP
iptables -I INPUT 4 -p tcp --dport 6000 -s 127.0.0.1 -j ACCEPT
iptables -I INPUT 5 -p tcp --dport 6000 ! -s 127.0.0.1 -j DROP
iptables -I INPUT 6 -p tcp --dport 8000 ! -s 127.0.0.1 -j DROP
iptables -I INPUT 7 -p tcp --dport 5050 ! -s 127.0.0.1 -j DROP
iptables -I INPUT 8 -p tcp --dport 4000 ! -s 127.0.0.1 -j DROP

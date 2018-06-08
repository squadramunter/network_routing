#!/bin/bash

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

trap '' 2
while true
do
  clear
  echo "================================================================================"
  echo "---- Traffic routing from Wireless to Ethernet made by @SquadraMunter ----"
  echo "================================================================================"
  echo "Enter 1 to list active network adapters: "
  echo "Enter 2 to setup the routing automatically: "
  echo "Enter 3 to test the network connectivity: "
  echo "Enter q to exit the menu q: "
  echo -e "\n"
  echo -e "Enter your selection \c"
  read answer
  case "$answer" in
1)

if eth=`basename -a /sys/class/net/* | grep eth`; then
  echo "Adapter "$eth" is alive and working properly..."
fi

if ens=`basename -a /sys/class/net/* | grep ens`; then
  echo "Adapter "$ens" is alive and working properly..."
fi

if enp=`basename -a /sys/class/net/* | grep enp`; then
  echo "Adapter "$enp" is alive and working properly..."
fi

if wlan=`basename -a /sys/class/net/* | grep wlan`; then
  echo "Adapter "$wlan" is alive and working properly..."
fi

if wlx=`basename -a /sys/class/net/* | grep wlx`; then
  echo "Adapter "$wlx" is alive and working properly..."
fi

;;

2)

detect=`basename -a /sys/class/net/* | grep 'eth\|ens\|enp'`
wifi=`basename -a /sys/class/net/* | grep 'wlan\|wlx'`

sudo apt-get update && apt-get install dnsmasq -y

sudo systemctl disable systemd-resolved

service systemd-resolved stop

sudo mv /etc/network/interfaces /etc/network/interfaces-old

sudo touch /etc/network/interfaces

CFILE="/etc/network/interfaces"

/bin/cat <<EOM >$CFILE
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

allow-hotplug $wifi
iface $wifi inet dhcp

allow-hotplug $detect
iface $detect inet static
    address 172.24.1.1
    netmask 255.255.255.0
    network 172.24.1.0
    broadcast 172.24.1.255
EOM

sudo ip addr flush $detect && systemctl restart networking.service
sudo ifdown $detect && ifup $detect

sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig

sudo touch /etc/dnsmasq.conf

DNSMASQ="/etc/dnsmasq.conf"

/bin/cat <<EOM >$DNSMASQ
interface=$detect
listen-address=172.24.1.1 # Explicitly specify the address to listen on
bind-interfaces      # Bind to the interface to make sure we aren't sending things elsewhere
server=8.8.8.8       # Forward DNS requests to Google DNS
domain-needed        # Don't forward short names
bogus-priv           # Never forward addresses in the non-routed address spaces.
dhcp-range=172.24.1.50,172.24.1.150,12h # Assign IP addresses between 172.24.1.50 and 172.24.1.150 with a 12 hour lease time
EOM

sed -i '/#net.ipv4.ip_forward=1/c\net.ipv4.ip_forward=1' /etc/sysctl.conf

sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"

sudo iptables -t nat -A POSTROUTING -o $wifi -j MASQUERADE
sudo iptables -A FORWARD -i $wifi -o $detect -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i $detect -o $wifi -j ACCEPT

sudo apt-get install iptables-persistent -y

sudo iptables-save > /etc/iptables/rules.v4
sudo ip6tables-save > /etc/iptables/rules.v6

sudo systemctl enable dnsmasq
sudo systemctl restart dnsmasq

sudo reboot

;;

3)

if ping -q -c 1 -W 1 172.24.1.1 >/dev/null; then
  echo "IPv4 is up and network routing is enabled!"
else
  echo "IPv4 is down and network routing is disabled!"
fi

if ping -q -c 1 -W 1 google.com >/dev/null; then
  echo "Yes! Network connection is working as pretended!"
else
  echo "Oops I can't establish a connection!"
fi

;;

q) exit ;;

  esac
  echo -e "Enter return to continue \c"
  read input
done

#! /bin/bash

# Detect when the WAN port is connected to the production LAN subnet and adjust this router's runtime LAN settings to not create a duplicate subnet.

prod_network="192.168.9"
dev_network="192.168.99"

ip a show wan|grep "inet ${prod_network}."
if [ $? -eq 0 ]; then
    if [ ! -f /etc/devmode/devmode_enabled ]; then
        echo "The WAN port is connected to the LAN.  Enabling Dev Mode LAN config."
        mkdir /etc/devmode
        touch /etc/devmode/devmode_enabled
        uci get network.lan.ipaddr > /etc/devmode/prod_ipaddr
        uci get network.lan.netmask > /etc/devmode/prod_netmask
        uci get network.lan.defaultroute && uci get network.lan.defaultroute > /etc/devmode/prod_defaultroute
        uci get system.@system[0].hostname > /etc/devmode/prod_hostname

        netip=`cat /etc/devmode/prod_ipaddr | cut -d '.' -f 4`

        uci set network.lan.ipaddr="${dev_network}.${netip}"
        uci set network.lan.netmask='255.255.255.0'
        uci set network.lan.defaultroute='0'
        uci set system.@system[0].hostname="$(cat /etc/devmode/prod_hostname)_DEVMODE"
        uci commit system
        uci commit network
        /etc/init.d/system reload
        /etc/init.d/network restart
    else
        echo "The WAN port is connected to the LAN.  Dev mode already active"
    fi
else
    if [ -f /etc/devmode/devmode_enabled ]; then
        echo "WAN port is not conncted to the LAN.  Revert back to production settings."
        rm -f /etc/devmode/devmode_enabled
        uci set network.lan.ipaddr="$(cat /etc/devmode/prod_ipaddr)"
        uci set network.lan.netmask="$(cat /etc/devmode/prod_netmask)"
        [ -f /etc/devmode/prod_defaultroute ] && uci set network.lan.defaultroute="$(cat /etc/devmode/prod_defaultroute)"
        uci set system.@system[0].hostname="$(cat /etc/devmode/prod_hostname)"
        uci commit system
        uci commit network
        /etc/init.d/system reload
        /etc/init.d/network restart
    else
        echo "WAN port is not connected to the LAN.  Remaining in production mode."
    fi
fi


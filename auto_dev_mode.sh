#! /bin/bash

# Detect when the WAN port is connected to the production LAN subnet and adjust this router's runtime LAN settings to not create a duplicate subnet.

# Retrive variables from UCI

prod_network="$(uci get auto_dev_mode.settings.prod_network 2>/dev/null || echo '192.168.1')"
dev_network="$(uci get auto_dev_mode.settings.dev_network 2>/dev/null || echo '192.168.99')"
enable="$(uci get auto_dev_mode.settings.enable 2>/dev/null || echo '1')"
force="$(uci get auto_dev_mode.settings.force 2>/dev/null || echo '0')"
disable_services="$(uci get auto_dev_mode.settings.disable_services 2>/dev/null )"

if [ $enable -eq 0 ]; then
    echo "auto_dev_mode disabled.  Exiting."
    exit 0
fi

# Wait for WAN connection to come up
echo -n "Waiting for WAN to come up."
ip a show wan | grep "inet " 
result=$?
until [ $result -eq 0 ]; do 
    echo -n "."
    ip a show wan | grep -q "inet "
    result=$?
    sleep 1
    if [ $SECONDS -gt 300 ]; then
        echo "Timeout waiting for WAN port to come up. Exiting auto_dev_mode"
        exit 1
    fi
done
echo "WAN connection up"
ip a show wan | grep "inet "
    

mkdir -p /etc/devmode
ip a show wan|grep -q "inet ${prod_network}."
if [ $? -eq 0 ] || [ $force -eq 1 ]; then
    if [ ! -f /etc/devmode/devmode_enabled ]; then
        echo "The WAN port is connected to the LAN.  Enabling Dev Mode LAN config."
        touch /etc/devmode/devmode_enabled
        rm -f /etc/devmode/disabled_services
        uci get network.lan.ipaddr > /etc/devmode/prod_ipaddr
        uci get network.lan.netmask > /etc/devmode/prod_netmask
        uci get system.@system[0].hostname > /etc/devmode/prod_hostname

        netip=`cat /etc/devmode/prod_ipaddr | cut -d '.' -f 4`
    
        # Change IP to dev network
        uci set network.lan.ipaddr="${dev_network}.${netip}"
        uci set network.lan.netmask='255.255.255.0'
        uci set network.lan.defaultroute='0'

        # Set DHCP option to exclude default gateway
        uci add_list dhcp.lan.dhcp_option='3'

        # Enable SSH on the WAN port if the firewall is enabled
        if [ -f /etc/rc.d/S*firewall ]; then
            uci add firewall rule 
            uci set firewall.@rule[-1].src='wan'
            uci set firewall.@rule[-1].name='Enable DEVMODE SSH'
            uci add_list firewall.@rule[-1].proto='tcp'
            uci set firewall.@rule[-1].dest_port='22'
            uci set firewall.@rule[-1].target='ACCEPT'
        fi
        
        # Services to disable in Dev mode
        for service in $disable_services; do
            service $service status
            if [ $? -eq 0 ]; then
                echo "Disabling service $service"
                service $service disable
                service $service stop
                echo "$service" >> /etc/devmode/disabled_services
            fi
        done

        uci set system.@system[0].hostname="$(cat /etc/devmode/prod_hostname)_DEVMODE"
        uci commit system
        uci commit firewall
        uci commit network
        uci commit dhcp
        /etc/init.d/system reload
        /etc/init.d/dnsmasq restart
        /etc/init.d/network restart
        /etc/init.d/firewall restart
    else
        echo "The WAN port is connected to the LAN.  Dev mode already active"
    fi
else
    if [ -f /etc/devmode/devmode_enabled ]; then
        echo "WAN port is not conncted to the LAN.  Revert back to production settings."
        rm -f /etc/devmode/devmode_enabled
        uci set network.lan.ipaddr="$(cat /etc/devmode/prod_ipaddr)"
        uci set network.lan.netmask="$(cat /etc/devmode/prod_netmask)"
        uci del_list dhcp.lan.dhcp_option='3'
        uci set system.@system[0].hostname="$(cat /etc/devmode/prod_hostname)"
        uci commit dhcp
        uci commit system
        uci commit network
        /etc/init.d/system reload
        /etc/init.d/dnsmasq restart
        /etc/init.d/network restart

        # Delete the SSH firewall rule
        if [ -f /etc/rc.d/S*firewall ]; then
            RULE_NAME="Enable DEVMODE SSH"
            # Find the rule and extract the index
            INDEX=$(uci show firewall | grep "name='$RULE_NAME'" | grep -o '@rule\[[0-9]*\]' | grep -o '[0-9]*')
            # Check if the index was found
            if [ -n "$INDEX" ]; then
                echo "Rule '$RULE_NAME' found at index: $INDEX"
                # Delete the rule
                uci delete firewall.@rule[$INDEX]
                # Commit changes and restart firewall
                uci commit firewall
                /etc/init.d/firewall restart
                echo "Rule '$RULE_NAME' deleted"
            else
                echo "Rule '$RULE_NAME' not found"
            fi
        fi

        # Enable services disabled in Dev mode
        services=`cat /etc/devmode/disabled_services`
        for service in $services; do 
            echo "Enabling service $service"
            service $service enable
            service $service start
        done


    else
        echo "WAN port is not connected to the LAN.  Remaining in production mode."
    fi
fi


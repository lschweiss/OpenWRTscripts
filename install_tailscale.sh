#! /bin/sh

# Add Tailscale repository and install Tailscale
wget -O /tmp/key-build.pub https://gunanovo.github.io/openwrt-tailscale/key-build.pub && opkg-key add /tmp/key-build.pub
grep -q "openwrt-tailscale" /etc/opkg/customfeeds.conf || \
    echo "src/gz openwrt-tailscale https://gunanovo.github.io/openwrt-tailscale" >> /etc/opkg/customfeeds.conf
opkg update
opkg install tailscale 2>/dev/null

# 1. Create the Tailscale firewall zone
uci set firewall.tailscale=zone
uci set firewall.tailscale.name='tailscale'
uci set firewall.tailscale.input='ACCEPT'
uci set firewall.tailscale.output='ACCEPT'
uci set firewall.tailscale.forward='ACCEPT'
uci set firewall.tailscale.log='1'
uci add_list firewall.tailscale.network='tailscale'

# 2. Masquerading for Tailscale → WAN (required for internet access from Tailscale clients)
uci set firewall.tailscale.masq='1'

# 3. Forwardings
uci add firewall forwarding
uci set firewall.@forwarding[-1].src='tailscale'
uci set firewall.@forwarding[-1].dest='lan'

uci add firewall forwarding
uci set firewall.@forwarding[-1].src='tailscale'
uci set firewall.@forwarding[-1].dest='wan'

uci add firewall forwarding
uci set firewall.@forwarding[-1].src='lan'
uci set firewall.@forwarding[-1].dest='tailscale'

# 4. Firewall rules
# Allow Tailscale incoming connections (UDP 41641) from WAN
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-Tailscale'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].dest='lan'
uci add_list firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].dest_port='41641'
uci set firewall.@rule[-1].target='ACCEPT'

# Allow HTTPS (443) from Tailscale zone to anywhere (usually to lan or router itself)
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-HTTPS from Tailscale'
uci set firewall.@rule[-1].src='tailscale'
uci add_list firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].dest_port='443'
uci set firewall.@rule[-1].target='ACCEPT'

# Allow HTTP (80) from Tailscale zone to anywhere
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-HTTP from Tailscale'
uci set firewall.@rule[-1].src='tailscale'
uci add_list firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].dest_port='80'
uci set firewall.@rule[-1].target='ACCEPT'

# Commit changes and apply
uci commit firewall
/etc/init.d/firewall restart


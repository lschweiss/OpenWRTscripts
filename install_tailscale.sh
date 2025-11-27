#! /bin/sh

# Add Tailscale repository and install Tailscale
wget -O /tmp/key-build.pub https://gunanovo.github.io/openwrt-tailscale/key-build.pub && opkg-key add /tmp/key-build.pub
grep -q "openwrt-tailscale" /etc/opkg/customfeeds.conf || \
    echo "src/gz openwrt-tailscale https://gunanovo.github.io/openwrt-tailscale" >> /etc/opkg/customfeeds.conf
opkg update
opkg install tailscale 2>/dev/null


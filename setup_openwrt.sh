#! /bin/bash

# Find our source and change to the directory
if [ -f "${BASH_SOURCE[0]}" ]; then
    my_source=`readlink -f "${BASH_SOURCE[0]}"`
else
    my_source="${BASH_SOURCE[0]}"
fi
cd $( cd -P "$( dirname "${my_source}" )" && pwd )


packages=`cat packages`
backups=`cat backups`

opkg update
mkdir -p /tmp/setup
for package in $packages; do
    opkg status $package | grep -q "installed" 
    if [ $? -ne 0 ]; then
        echo "Installing $package"
        opkg install $package 1> /tmp/setup/install.$package 2> /tmp/setup/install.${ackage}.err
    else
        echo "Already installed $package"
    fi
done

if [ ! -f /root/opkgscript.sh ]; then 
    wget -o /root/opkgscript.sh https://raw.githubusercontent.com/richb-hanover/OpenWrtScripts/refs/heads/main/opkgscript.sh
    chmod +x /root/opkgscript.sh
fi

if [ ! -f /root/.vimrc ]; then
    cat << EOF1 > /root/.vimrc 
:set hlsearch

map! ^[ka ^[ka
map! ^[ja ^[ja
map! ^[i ^[i
map! ^[la ^[la
syntax on

set tabstop=4
set shiftwidth=4
set expandtab
set hlsearch

set backspace=indent,eol,start
set mouse=
EOF1
fi


if [ ! -f /etc/bash.bashrc ]; then
    cat << EOF2 > /etc/bash.bashrc
# System-wide .bashrc file

HISTCONTROL=ignoredups
HISTFILE=~/.bash_history
HISTFILESIZE=36000
HISTIGNORE=exit:reset
HISTSIZE=36000
HISTTIMEFORMAT='[%Y-%m-%d %H:%M:%S] '

# Continue if running interactively
[[ $- == *i* ]] || return 0

[ \! -s /etc/shinit ] || . /etc/shinit
EOF2
fi

if [ ! -f /etc/sysupgrade.conf ]; then
    cat << EOF3 > /etc/sysupgrade.conf
## This file contains files and directories that should
## be preserved during an upgrade.

# /etc/example.conf
# /etc/openvpn/
EOF3
fi

for x in $backups; do
    grep -q "$x" /etc/sysupgrade.conf || echo $x >> /etc/sysupgrade.conf
done

# Configure auto_dev_mode

uci show auto_dev_mode
if [ $? -ne 0 ]; then
    cat << EOF4 > /etc/rc.local
# Put your custom commands here that should be executed once
# the system init finished. By default this file does nothing.

[ -e /root/OpenWRTscripts/auto_dev_mode.sh ] && /root/OpenWRTscripts/auto_dev_mode.sh 2>&1 | logger -t auto_dev_mode

exit 0
EOF4
fi

chmod +x /etc/rc.local

# Create configuration file
touch /etc/config/auto_dev_mode
# Set variables
uci set auto_dev_mode.settings=auto_dev_mode
uci set auto_dev_mode.settings.prod_network='192.168.1'
uci set auto_dev_mode.settings.dev_network='192.168.99'
uci set auto_dev_mode.settings.enable='1'
uci set auto_dev_mode.settings.force='0'

disable_services="tailscale wgserver acme ddns openvpn"
for service in $disable_services; do
    uci add_list auto_dev_mode.settings.disable_services=$service
done

# Commit changes
uci commit auto_dev_mode
# Verify settings
uci show auto_dev_mode


# Add Tailscale repository and install Tailscale
wget -O /tmp/key-build.pub https://gunanovo.github.io/openwrt-tailscale/key-build.pub && opkg-key add /tmp/key-build.pub
grep -q "openwrt-tailscale" /etc/opkg/customfeeds.conf || \
    echo "src/gz openwrt-tailscale https://gunanovo.github.io/openwrt-tailscale" >> /etc/opkg/customfeeds.conf
opkg update
opkg install tailscale 2>/dev/null

# Change default shell to bash
sed -i 's,/bin/ash,/bin/bash,g' /etc/passwd

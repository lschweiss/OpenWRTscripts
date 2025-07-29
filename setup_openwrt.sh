#! /bin/sh
packages=`cat packages`
backups=`cat backups`

opkg update
mkdir /tmp/setup
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
    grep -q /etc/sysupgrade.conf "$x" || echo $x >> /etc/sysupgrade.conf
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

chmod +x 

# Create configuration file
touch /etc/config/auto_dev_mode
# Set variables
uci set auto_dev_mode.settings=auto_dev_mode
uci set auto_dev_mode.settings.prod_network='192.168.1'
uci set auto_dev_mode.settings.prod_network='192.168.99'
uci set auto_dev_mode.settings.enable='1'

# Commit changes
uci commit auto_dev_mode
# Verify settings
uci show auto_dev_mode

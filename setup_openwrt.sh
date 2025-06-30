#! /bin/sh
opkg install acme-acmesh-dnsapi
opkg install bind-dig
opkg install block-mount
opkg install curl
opkg install diffutils
opkg install fdisk
opkg install gawk
opkg install git
opkg install grep
opkg install htop
opkg install ifstat
opkg install iftop
opkg install ip-full
opkg install ip6tables-nft
opkg install ip6tables-zz-legacy
opkg install ipset-dns
opkg install iptables-nft
opkg install iputils-arping
opkg install less
opkg install lldpd
opkg install luci-app-acme
opkg install luci-app-advanced-reboot
opkg install luci-app-attendedsysupgrade
opkg install luci-app-commands
opkg install luci-app-ddns
opkg install luci-app-mwan3
opkg install luci-app-nlbwmon
opkg install luci-app-opkg
opkg install luci-app-statistics
opkg install luci-app-ttyd
opkg install luci-app-wol
opkg install msmtp-mta
opkg install msmtp-queue
opkg install net-tools-route
opkg install procps-ng-ps
opkg install procps-ng-top
opkg install procps-ng-watch
opkg install sed
opkg install snmpd
opkg install tailscale
opkg install tcpdump
opkg install telnet-bsd
opkg install usbutils
opkg install vim-fuller
opkg install vim-help
opkg install xfs-admin
opkg install xfs-fsck
opkg install xfs-growfs
opkg install xfs-mkfs

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
/root
/etc/hosts*
/etc/rc.d
/etc/init.d
/etc/inittab
/etc/shells
/etc/tailscale
/etc/modules*
/etc/rc.local
/etc/ssh
/etc/ssl
/etc/snmp
/etc/sysctl.conf
/etc/sysctl.d
/etc/syslog.conf
/etc/unbound
/etc/acme
/etc/adblock
/etc/banip
/etc/cloudflared
/etc/crontabs
/etc/lldpd.d
/etc/luci-uploads
/etc/luci_statistics
/etc/mwa3.user
/etc/nftables.d
/etc/profile
/etc/profile.d
/etc/bash.bashrc
/etc/board..d
/etc/board.json
EOF3
fi



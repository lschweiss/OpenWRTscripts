#! /bin/bash

# Find our source and change to the directory
if [ -f "${BASH_SOURCE[0]}" ]; then
    my_source=`readlink -f "${BASH_SOURCE[0]}"`
else
    my_source="${BASH_SOURCE[0]}"
fi
cd $( cd -P "$( dirname "${my_source}" )" && pwd )

[ -f 'config' ] && source config

install_packages () {
    mkdir -p /tmp/setup
    while [ "$1" != '' ]; do
        package="$1"
        opkg status $package | grep -q "installed"
        if [ $? -ne 0 ]; then
            echo "Installing $package"
            opkg install $package 1> /tmp/setup/install.$package 2> /tmp/setup/install.${package}.err || \
                die "Failed to install $package"
        else
            echo "Already installed $package"
        fi
        shift
    done
}

packages=`cat packages`
backups=`cat backups`

opkg update
for package in $packages; do
    install_packages "$package"
done

[ "$INSTALL_WIREGUARD" == 'true' ]  && install_packages luci-proto-wireguard

[ "$INSTALL_MWAN3" == 'true' ]  && install_packages luci-app-mwan3

if [ "$INSTALL_OPENSSH" == 'true' ]; then
    echo "Installing OpenSSH server"
    install_packages openssh-server openssh-sftp-server
    service dropbear disable
    service dropbear stop
    [ "$OPENSSH_ROOT_LOGIN" == 'true' ] && \
        sed -i '/PermitRootLogin/c PermitRootLogin yes' /etc/ssh/sshd_config
    service sshd restart
    mkdir /root/.ssh
    chmod 700 /root/.ssh
    [ "$ROOT_SSH_KEYS" != '' ] && echo $ROOT_SSH_KEYS > /root/.ssh/authorized_keys
else
    [ "$ROOT_SSH_KEYS" != '' ] && echo $ROOT_SSH_KEYS > /etc/dropbear/authorized_keys
fi

if [ ! -f /root/opkgscript.sh ]; then 
    wget -o /root/opkgscript.sh https://raw.githubusercontent.com/richb-hanover/OpenWrtScripts/refs/heads/main/opkgscript.sh
    chmod +x /root/opkgscript.sh
fi

if [ ! -f /root/.vimrc ]; then
    echo "Configuring vimrc"
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
    echo "Setting bash defaults"
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
    echo "Creating sysupgrade.conf"
    cat << EOF3 > /etc/sysupgrade.conf
## This file contains files and directories that should
## be preserved during an upgrade.

# /etc/example.conf
# /etc/openvpn/
EOF3
fi

echo
echo "Configuring sysupgrade.conf"

for x in $backups; do
    grep -q "$x" /etc/sysupgrade.conf || echo $x >> /etc/sysupgrade.conf
done


grep "net.core" /etc/sysctl.conf || cat << EOF4 >>/etc/sysctl.conf
net.core.rmem_default=10485760
net.core.wmem_default=10485760
net.core.rmem_max=10485760
net.core.wmem_max=10485760
EOF4

set -x
uci add nlbwmon nlbwmon
uci set nlbwmon.@nlbwmon[0].netlink_buffer_size='10485760'

uci set luci.main.check_for_newer_firmwares='1'

uci set attendedsysupgrade.client.auto_search='1'
uci set attendedsysupgrade.client.advanced_mode='1'
uci set uhttpd.main.redirect_https='1'

uci commit

set +x

# Configure auto_dev_mode

uci show auto_dev_mode
if [ $? -ne 0 ]; then
    cat << EOF4 > /etc/rc.local
# Put your custom commands here that should be executed once
# the system init finished. By default this file does nothing.

if [ -e /root/OpenWRTscripts/auto_dev_mode.sh ]; then
    cd /root/OpenWRTscripts
    git pull
    /root/OpenWRTscripts/auto_dev_mode.sh 2>&1 | logger -t auto_dev_mode
fi

exit 0
EOF4
fi

chmod +x /etc/rc.local

# Create configuration file
echo "Configuring auto dev mode"

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

# Change default shell to bash
sed -i 's,/bin/ash,/bin/bash,g' /etc/passwd


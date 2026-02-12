#! /bin/bash

##
# This script is meant to run after the initial firmware loading of OpenWRT on the Linksys MX5300
# It should be run from a system that is connected to the "new" router.  The router WAN port should 
# also be connected and be able to reach the internet for downloading packages.
##

die () {
    echo "$1"
    exit 1
}



wait_for_reboot () {
    # Wait for reboot
    echo
    echo -n "Waiting for router to reboot and connection established."
    connected=1
    while [ $connected -ne 0 ]; do
        sleep 5
        echo -n '.'
        $SSH echo "Reconnection established." 2>/dev/null
        connected=$?
    done
}

install_packages () {
    mkdir -p /tmp/setup
    while [ "$1" != '' ]; do
        package="$1"
        $SSH "opkg status $package" | grep -q "installed"
        if [ $? -ne 0 ]; then
            echo "Installing $package"
            $SSH "opkg install $package" 1> /tmp/setup/install.$package 2> /tmp/setup/install.${package}.err || \
                die "Failed to install $package"
        else
            echo "Already installed $package"
        fi
        shift
    done
}

setup_openwrt () {
    # Install bash, git and download OpenWRTscripts

    $SSH "opkg update" || die "Could not update opkg packages.  Is internet connected?"
    $SSH "opkg install bash git git-http"
    $SSH "git clone https://github.com/lschweiss/OpenWRTscripts.git"

    if [ "$HOSTNAME_PUSH" == 'true' ]; then
        cp $config /tmp/openwrt.config
        echo "OPENWRT_HOSTNAME=\"$OPENWRT_HOSTNAME\"" >>/tmp/openwrt.config
        config="/tmp/openwrt.config"
    fi

    [ -f "$config" ] && $SCP $config root@$IP:/root/OpenWRTscripts/config

    # Run initial OpenWRT setup
    $SSH /root/OpenWRTscripts/setup_openwrt.sh

    # Clear host key if OpenSSH was installed
    [ "$INSTALL_OPENSSH" == 'true' ] && ssh-keygen -R $IP

}


# Test connectivity
test_connectivity () {
    ssh-keygen -R $IP
    $SSH echo "SSH connectivity verified." 
    [ $? -ne 0 ] && die "Cannot connect to $MODEL at $IP"
    echo
}

# Check model and version
check_model () {
    $SSH ubus call system board | grep model | grep -q "$MODEL"
    [ $? -ne 0 ] && die "This does not appear to be a $MODEL"
    $SSH cat /etc/openwrt_release > /tmp/openwrt_release
    source /tmp/openwrt_release
    fw="openwrt-${DISTRIB_RELEASE}-qualcommax-ipq807x-linksys_$model-squashfs-factory.bin"
    echo "$MODEL detected."
    echo "OpenWRT version ${DISTRIB_RELEASE}"
    echo
}

check_wan () {
    # Check the router has WAN connectivity
    $SSH "ip a show wan" | grep -q "inet "
    [ $? -ne 0 ] && die "Router needs to have WAN connectivity to proceed."
    echo "WAN connectivity verified."
    echo
}


# Download firmware
download_firmware () {
    echo "Flashing OpenWRT to alternate firmware partition"
    echo
    $SSH "wget -O /tmp/openwrt-factory.bin https://downloads.openwrt.org/releases/${DISTRIB_RELEASE}/targets/qualcommax/ipq807x/${fw}" || \
        die "Could not download $fw"

    # Determine partiton to apply
    boot_part=`$SSH fw_printenv -n boot_part`

    case $boot_part in
        '1')
            echo "Overwriting Linksys factory firmware on alt partition..."
            $SSH mtd -r -e alt_kernel -n write /tmp/openwrt-factory.bin alt_kernel
            ;;
        '2')
            echo "Overwriting Linksys factory firmware on primary partition..."
            $SSH mtd -r -e kernel -n write /tmp/openwrt-factory.bin kernel
            ;;
        *)
            die "Could not determine which partition OpenWRT is running on"
            ;;
    esac
}

# Enable USB recovery
enable_usb_recovery () {
    echo
    echo "Enabling USB recovery."

    $SSH /root/OpenWRTscripts/mx5300/enable_usb_recovery.sh
}



###
#
# Main routine 
#
##

model="$1"

if [ -d "./$1" ]; then
    source $1/initial_setup_config
else
    die "Model specific config not found $PWD/$1"
fi


# Ask for hostname
OPENWRT_HOSTNAME='ask'

# Install latest tailscale from https://gunanovo.github.io/openwrt-tailscale
INSTALL_TAILSCALE=true

# Wireguard
INSTALL_WIREGUARD=true
JOIN_WIREGUARD=true
WIREGUARD_PUBLIC_KEY=''

# Install MWAN3
INSTALL_MWAN3=true

# Root SSH keys to be installed.
ROOT_SSH_KEYS=""


config="$2"

if [ -f "$config" ]; then
    echo "Sourcing config $config"
    source $config
else
    echo "No additonal config found: $config"
fi

[ "$IP" == '' ] && IP='192.168.1.1'

SSH="ssh -x -o StrictHostKeyChecking=no root@$IP"
SCP="scp -O -o StrictHostKeyChecking=no"

test_connectivity

check_model

check_wan

if [ "$OPENWRT_HOSTNAME" == 'ask' ]; then
    echo
    read -p "Enter hostname for this device: " OPENWRT_HOSTNAME
    echo
    HOSTNAME_PUSH=true
else
    HOSTNAME_PUSH=false
fi

download_firmware

wait_for_reboot

setup_openwrt

if [ "$ADDITIONAL_SETUP" != '' ]; then
    $SCP $ADDITIONAL_SETUP root@$IP:/root/
fi


if [ "$ATTENDED_UPGRADE" == 'true' ]; then
    echo 
    echo "Running Attended Sysupgrade..."
    $SSH "owut upgrade --force"
    wait_for_reboot
    # Add Tailscale repository and install Tailscale
    if [ "$INSTALL_TAILSCALE" == 'true' ]; then 
        $SSH "/root/OpenWRTscripts/install_tailscale.sh"
        tailscale='--remove tailscale'
    fi
    echo "Running Attended Sysupgrade for second partion..."
    
    $SSH "owut upgrade --force $tailscale"
    wait_for_reboot
    # Add Tailscale repository and install Tailscale
    [ "$INSTALL_TAILSCALE" == 'true' ] && $SSH "/root/OpenWRTscripts/install_tailscale.sh"

else
    # Add Tailscale repository and install Tailscale
    [ "$INSTALL_TAILSCALE" == 'true' ] && $SSH "/root/OpenWRTscripts/install_tailscale.sh"
    ##
    # Repeat setup on other partion
    ##
    echo 
    echo "###"
    echo "# Repeating setup on other partion"
    echo "###"
    
    
    # Reboot to other partiton
    echo
    echo "Rebooting to alternate partition..."
    $SSH /root/OpenWRTscripts/$model/switch_boot_partitions.sh

    # Clear host key since it will change on the other partition. 
    ssh-keygen -R $IP

    wait_for_reboot

    setup_openwrt

    # Add Tailscale repository and install Tailscale
    [ "$INSTALL_TAILSCALE" == 'true' ] && $SSH "/root/OpenWRTscripts/install_tailscale.sh"

fi    
    


enable_usb_recovery

echo
echo "Openwrt basic setup complete on both partitons."

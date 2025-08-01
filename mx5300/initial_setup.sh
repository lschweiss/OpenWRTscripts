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

IP="$1"
[ "$IP" == '' ] && IP='192.168.1.1'
MODEL='Linksys MX5300'

SSH="ssh -x -o StrictHostKeyChecking=no root@$IP"

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
    while [ $1 != '' ]; do
        package="$1"
        $SSH "opkg status $package" | grep -q "installed"
        if [ $? -ne 0 ]; then
            echo "Installing $package"
            ssh "opkg install $package" 1> /tmp/setup/install.$package 2> /tmp/setup/install.${package}.err || \
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
    install_packages bash git git-http
    $SSH git clone https://github.com/lschweiss/OpenWRTscripts.git

    # Run initial OpenWRT setup
    $SSH /root/OpenWRTscripts/setup_openwrt.sh
}


# Test connectivity
ssh-keygen -R 192.168.1.1
$SSH echo "SSH connectivity verified." 
[ $? -ne 0 ] && die "Cannot connect to mx5300 at $IP"
echo

# Check model and version
$SSH ubus call system board | grep model | grep -q "$MODEL"
[ $? -ne 0 ] && die "This does not appear to be a $MODEL"
$SSH cat /etc/openwrt_release > /tmp/openwrt_release
source /tmp/openwrt_release
echo "$MODEL detected."
echo "OpenWRT version ${DISTRIB_RELEASE}"
echo

# Check the router has WAN connectivity
$SSH "ip a show wan" | grep -q "inet "
[ $? -ne 0 ] && die "Router needs to have WAN connectivity to proceed."
echo "WAN connectivity verified."
echo


# Download firmware
echo "Flashing OpenWRT to alternate firmware partition"
echo
fw="openwrt-${DISTRIB_RELEASE}-qualcommax-ipq807x-linksys_mx5300-squashfs-factory.bin"
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

wait_for_reboot

setup_openwrt

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
$SSH /root/OpenWRTscripts/mx5300/switch_boot_partitions.sh

wait_for_reboot

setup_openwrt

# Enable USB recovery
echo
echo "Enabling USB recovery."

fw_setenv usbimage 'openwrt-qualcommax-ipq807x-linksys_mx5300-initramfs-uImage.itb'
fw_setenv bootusb 'usb start && fatload usb 0:1 $loadaddr $usbimage && bootm $loadaddr'
fw_setenv bootcmd 'run bootusb; aq_load_fw && if test $auto_recovery = no; then bootipq; elif test $boot_part = 1; then run bootpart1; else run bootpart2; fi'

echo "Openwrt basic setup complete on both partitons."

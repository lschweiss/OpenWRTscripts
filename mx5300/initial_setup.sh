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

SSH="ssh -x -oStrictHostKeyChecking=no root@$IP"

# https://downloads.openwrt.org/releases/24.10.2/targets/qualcommax/ipq807x/openwrt-24.10.2-qualcommax-ipq807x-linksys_mx5300-squashfs-factory.bin

# Test connectivity
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


# Install bash, git and download OpenWRTscripts

$SSH opkg update
$SSH opkg install bash
$SSH opkg install git
$SSH opkg install git-http
$SSH git clone https://github.com/lschweiss/OpenWRTscripts.git

# Run initial OpenWRT setup
$SSH /root/OpenWRTscripts/setup_openwrt.sh

# Reboot to other partiton
$SSH /root/OpenWRTscripts/mx5300/switch_boot_partitions.sh

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

# Install bash, git and download OpenWRTscripts

$SSH opkg update
$SSH opkg install bash
$SSH opkg install git
$SSH opkg install git-http
$SSH git clone https://github.com/lschweiss/OpenWRTscripts.git

# Run initial OpenWRT setup
$SSH /root/OpenWRTscripts/setup_openwrt.sh

echo "Openwrt basic setup complete on both partitons."

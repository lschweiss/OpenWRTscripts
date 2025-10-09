#! /bin/bash
# Enable USB recovery
echo
echo "Enabling USB recovery."

fw_setenv usbimage 'openwrt-qualcommax-ipq807x-linksys_mx5300-initramfs-uImage.itb'
fw_setenv bootusb 'usb start && fatload usb 0:1 $loadaddr $usbimage && bootm $loadaddr'
fw_setenv bootcmd 'run bootusb; aq_load_fw && if test $auto_recovery = no; then bootipq; elif test $boot_part = 1; then run bootpart1; else run bootpart2; fi'


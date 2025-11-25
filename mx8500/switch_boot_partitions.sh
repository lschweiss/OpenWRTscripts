#!/bin/sh
# Check current boot partition
CURRENT_PART=$(fw_printenv boot_part | grep boot_part | cut -d= -f2)
if [ -z "$CURRENT_PART" ]; then
    logger -t boot_switch "Error: Could not determine current boot partition"
    exit 1
fi
# Determine inactive partition
NEW_PART=$([ "$CURRENT_PART" = "1" ] && echo "2" || echo "1")
# Log and set new boot partition
logger -t boot_switch "Switching from partition $CURRENT_PART to $NEW_PART"
fw_setenv boot_part $NEW_PART
if [ $? -eq 0 ]; then
    logger -t boot_switch "Set boot partition to $NEW_PART, rebooting"
    reboot
else
    logger -t boot_switch "Error: Failed to set boot partition to $NEW_PART"
    exit 1
fi

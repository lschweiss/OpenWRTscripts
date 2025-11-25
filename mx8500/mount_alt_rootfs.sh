#! /bin/bash

mkdir -p /mnt/blk/{rootfs,alt_rootfs}

for mount in `mount |grep 'on /mnt'| cut -d ' ' -f 3`; do
    umount $mount
done

ubidetach -d 1 2>/dev/null


rm /mnt/rootfs /mnt/alt_rootfs /mnt/current /mnt/inactive 2>/dev/null
rmdir /mnt/rootfs /mnt/alt_rootfs 2>/dev/null


current=`fw_printenv -n boot_part|head`

if [ $current -eq 2 ]; then
    echo "mounting mtd22: rootfs"
    ubiattach -m 22 -d 1
    attach='rootfs'
    ln -s / /mnt/alt_rootfs
    ln -s /mnt/alt_rootfs /mnt/current

else
    echo "mounting mtd24: alt_rootfs"
    ubiattach -m 24 -d 1
    attach='alt_rootfs'
    ln -s / /mnt/rootfs
    ln -s /mnt/rootfs /mnt/current
fi


mount -t ubifs /dev/ubi1_1 /mnt/blk/${attach}
mkdir -p /mnt/${attach}
mount -t overlay overlay -o rw,noatime,lowerdir=/mnt/blk/${attach},upperdir=/mnt/blk/${attach}/upper,workdir=/mnt/blk/${attach}/work,uuid=on,xino=off /mnt/${attach}

ln -s /mnt/${attach} /mnt/inactive



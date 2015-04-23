#!/dist/bash
set -e
HERE="${0%/*}"
PATH="$PATH:$HERE"
busybox mount -t devtmpfs dev /dev
busybox mount -o loop,ro -t squashfs "$HERE/root.sqf" /root
/root/bin/swapon "${root_part%3}2"
busybox mount -o bind /home /root/home
busybox mount -o loop,ro -t squashfs "$HERE/install.sqf" /root/home/install
busybox mount -o loop,ro -t squashfs "$HERE/modules.sqf" /root/lib/modules
busybox mount -o loop,ro -t squashfs "$HERE/firmware.sqf" /root/lib/firmware
/root/bin/mkdir -p /docker
busybox mount -o bind /docker /root/home/chroot/extra/docker
busybox mount -o bind /updates /root/home/chroot/updates
busybox mount -o loop,ro -t squashfs "$HERE/run.sqf" /root/home/run
exec /root/sbin/chroot /root /bin/ash < "$HERE/init2.sh"

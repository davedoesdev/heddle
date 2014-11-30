#!/dist/bash
HERE="${0%/*}"
PATH="$PATH:$HERE"
mount -t devtmpfs /dev /dev
mount -o loop -t squashfs "$HERE/root.sqf" /root
mount -o rbind /home /root/home
#mount -o loop -t squashfs "$HERE/install.sqf" /root/home/install
exec chroot /root /sbin/init.sh

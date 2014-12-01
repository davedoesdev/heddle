#!/dist/bash
HERE="${0%/*}"
PATH="$PATH:$HERE"
mount -t devtmpfs /dev /dev
mount -o loop -t squashfs "$HERE/root.sqf" /root
mount -o bind /home /root/home
mount -o loop -t squashfs "$HERE/install.sqf" /root/home/install
mount -o bind /docker /root/home/chroot/extra/docker
# prevent tmpfs mount of home
export HOMEDEV=foobar
mount -o loop -t squashfs "$HERE/run.sqf" /root/mnt
exec chroot /root /sbin/init.sh

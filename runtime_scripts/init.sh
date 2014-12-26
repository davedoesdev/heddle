#!/dist/bash
set -e
HERE="${0%/*}"
PATH="$PATH:$HERE"
busybox mount -t devtmpfs /dev /dev
busybox mount -o loop -t squashfs "$HERE/root.sqf" /root
rdev="$(/root/bin/mountpoint -d / | /root/bin/tail -n 1)"
for dev in /dev/[hsv]d?3; do
  if [ "$(/root/bin/mountpoint -x "$dev")" = "$rdev" ]; then
    /root/bin/swapon "${dev%3}2"
    break
  fi
done
busybox mount -o bind /home /root/home
busybox mount -o loop -t squashfs "$HERE/install.sqf" /root/home/install
toybox mkdir -p /docker
busybox mount -o bind /docker /root/home/chroot/extra/docker
busybox mount -o loop -t squashfs "$HERE/run.sqf" /root/home/run
busybox mount -o bind "$HERE/init2.sh" /root/sbin/init.sh
exec /root/sbin/chroot /root /sbin/init.sh

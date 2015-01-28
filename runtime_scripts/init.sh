#!/dist/bash
set -e
HERE="${0%/*}"
PATH="$PATH:$HERE"
busybox mount -t devtmpfs /dev /dev
busybox mount -o loop,ro -t squashfs "$HERE/root.sqf" /root
rdev="$(/root/bin/mountpoint -d / | /root/bin/tail -n 1)"
for dev in /dev/[hsv]d?3; do
  if [ "$(/root/bin/mountpoint -x "$dev")" = "$rdev" ]; then
    /root/bin/swapon "${dev%3}2"
    break
  fi
done
busybox mount -o bind /home /root/home
busybox mount -o loop,ro -t squashfs "$HERE/install.sqf" /root/home/install
busybox mount -o loop,ro -t squashfs "$HERE/modules.sqf" /root/lib/modules
busybox mount -o loop,ro -t squashfs "$HERE/firmware.sqf" /root/lib/firmware
toybox mkdir -p /docker
busybox mount -o bind /docker /root/home/chroot/extra/docker
busybox mount -o bind /updates /root/home/chroot/updates
busybox mount -o loop,ro -t squashfs "$HERE/run.sqf" /root/home/run
exec /root/sbin/chroot /root /bin/ash < "$HERE/init2.sh"

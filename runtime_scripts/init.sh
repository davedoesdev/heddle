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
busybox mount -o bind /docker /root/home/chroot/extra/docker
# prevent tmpfs mount of home
export HOMEDEV=foobar
busybox mount -o loop -t squashfs "$HERE/run.sqf" /root/mnt
exec /root/sbin/chroot /root /sbin/init.sh

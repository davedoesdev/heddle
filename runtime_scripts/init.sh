#!/dist/bash
HERE="${0%/*}"
PATH="$PATH:$HERE"
mount -t devtmpfs /dev /dev
mount -o loop -t squashfs "$HERE/root.sqf" /root
rdev="$(/root/bin/mountpoint -d / | /root/bin/tail -n 1)"
for dev in /dev/[hsv]d?3; do
  if [ "$(/root/bin/mountpoint -x "$dev")" = "$rdev" ]; then
    /root/bin/swapon "${dev%3}2"
    break
  fi
done
mount -o bind /home /root/home
mount -o loop -t squashfs "$HERE/install.sqf" /root/home/install
mount -o bind /docker /root/home/chroot/extra/docker
# prevent tmpfs mount of home
export HOMEDEV=foobar
mount -o loop -t squashfs "$HERE/run.sqf" /root/mnt
exec /root/sbin/chroot /root /sbin/init.sh

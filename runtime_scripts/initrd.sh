#!/bin/bash
set -e
busybox mount -t proc proc /proc
busybox mount -t devtmpfs dev /dev
toybox ln -s /proc/self/fd /dev
# duplicate output to serial port
port="$(toybox grep -oE 'console=tty(S|USB)[0-9]+' /proc/cmdline | toybox head -n 1 | busybox sed 's/console=//')"
if [ -n "$port" ]; then
  exec > /dev/kmsg 2>&1
fi
# find root device
for dev in /dev/[hsv]d?; do
  name="$(sgdisk -i 3 "$dev" | toybox grep 'Partition name' | busybox awk "{gsub(/'/, \"\", \$NF); print \$NF}")"
  if [ "$name" = "heddle_root" ]; then
    root="${dev}3"
    break
  fi
done
echo "root device: $root"
if [ ! -b "$root" ]; then
  echo "root is not a block device" 1>&2
  exit 1
fi
toybox ln -s /proc/mounts /etc/mtab
toybox cat <<EOF | parted ---pretend-input-tty "${root%3}" resizepart 3 100%
fix
3
100%
EOF
parted "${root%3}" print
e2fsck -fy "$root" || if [ $? -ne 1 ]; then exit $?; fi
resize2fs "$root"
busybox mount "$root" /newroot
toybox umount /proc
boot=dist
# toybox switch_root doesn't chroot
toybox cat > /newroot/init <<EOF
#!/newroot/$boot/bash
exec "/newroot/$boot/toybox" chroot /newroot "/$boot/init.sh"
EOF
toybox chmod +x /newroot/init
exec toybox switch_root /newroot init

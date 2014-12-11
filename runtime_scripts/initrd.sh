#!/bin/bash
set -e
busybox mount -t proc proc /proc
busybox mount -t devtmpfs dev /dev
toybox ln -s /proc/self/fd /dev
# duplicate output to serial port
port="$(toybox grep -oE 'console=tty(S|USB)[0-9]+' /proc/cmdline | toybox head -n 1 | busybox sed 's/console=//')"
if [ -n "$port" ]; then
  exec > >(toybox tee "/dev/$port") 2>&1
fi
for p in $(toybox cat /proc/cmdline); do
  case "$p" in
    root=*) root="$(echo "$p" | busybox sed 's/^.*=//')";;
    init=*) init="$(echo "$p" | busybox sed 's/^.*=//')";;
  esac
done
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
dist="$(toybox dirname "$init")"
# toybox switch_root doesn't chroot
toybox cat > /newroot/init <<EOF
#!/newroot/$dist/bash
exec /newroot/$dist/toybox chroot /newroot $init
EOF
toybox chmod +x /newroot/init
exec toybox switch_root /newroot init

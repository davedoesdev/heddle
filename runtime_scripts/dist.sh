#!/bin/bash
set -e
here="$(dirname "$0")"
mkdir -p /rmnt # in root ramdisk
mount -o loop,ro "$here/run.img" /rmnt
HERE=/rmnt DONT_MAKE_CHROOT=yes . /rmnt/common.sh

EXTRA_DIR="/tmp/extra"
mkdir "$EXTRA_DIR"
DIST_DIR="$EXTRA_DIR/dist"
UPDATES_DIR="$EXTRA_DIR/updates"

dev="$(echo /dev/[hsv]dd)"
swapon "${dev}2"
cat <<EOF | parted ---pretend-input-tty "$dev" resizepart 3 100%
fix
3
100%
EOF
parted "$dev" print
fsck -fy "${dev}3" || if [ $? -ne 1 ]; then exit $?; fi
mount "${dev}3" "$EXTRA_DIR"
resize2fs "${dev}3" || btrfs filesystem resize max "$EXTRA_DIR"

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR" "$UPDATES_DIR"

cp /bin/{bash,busybox,toybox} "$here"/{init,init2}.sh "$DIST_DIR"

rm -rf "$EXTRA_DIR/home"
mkdir "$EXTRA_DIR/home"{,/install,/run}
find /home \
     -mindepth 1 -maxdepth 1 \
     -not -name install \
     -not -name source \
     -not -name '.bash*' \
     -not -name lost+found |
while read f; do
  tar -C "$(dirname "$f")" "$(basename "$f")" -c | tar -C "$EXTRA_DIR/home" -xp
done
# toybox seems to have a bug copying symbolic links so use tar (above)
#-exec cp -a {} "$EXTRA_DIR/home" \;
if [ ! -e "$EXTRA_DIR/home/chroot/etc/issue" ]; then
  ln -s "$INSTALL_DIR/dist/issue" "$EXTRA_DIR/home/chroot/etc"
fi

rm -rf "$EXTRA_DIR"/{root,dev}
mkdir -p "$EXTRA_DIR"/{root,dev}

cp -a "$here"/{root,modules,firmware}.sqf "$DIST_DIR"

reuse=
if grep -q 'heddle_dist_reuse=1' /proc/cmdline; then
  reuse=1
fi
echo "reuse: $reuse"

mount -o remount,rw /dev/hdc /mnt
if [ -n "$reuse" -a -f "$here/gen/install.sqf" ]; then
  cp "$here/gen/install.sqf" "$DIST_DIR"
else
  mksquashfs "$INSTALL_DIR" "$DIST_DIR/install.sqf" -noappend -all-root -mem 512M
  project="$(grep -oE 'heddle_project=[^ ]+' /proc/cmdline | head -n 1 | sed 's/heddle_project=//')"
  version="$(grep -oE 'heddle_version=[^ ]+' /proc/cmdline | head -n 1 | sed 's/heddle_version=//')"
  echo "project: $project"
  echo "version: $version"
  mkdir -p /tmp/install/dist
  echo -e "$project $version \\\\l\n" > /tmp/install/dist/issue
  echo "$heddle_arch" > /tmp/install/dist/arch
  mksquashfs /tmp/install "$DIST_DIR/install.sqf" -all-root -mem 512M
  cp "$DIST_DIR/install.sqf" "$here/gen"
fi
if [ -n "$reuse" -a -f "$here/gen/run.sqf" ]; then
  cp "$here/gen/run.sqf" "$DIST_DIR"
else
  mksquashfs /rmnt "$DIST_DIR/run.sqf" -noappend -all-root -mem 512M
  cp "$DIST_DIR/run.sqf" "$here/gen"
fi
if [ "$heddle_arch" = armv6l -a \
     \( -z "$reuse" -o ! -f "$here/gen/u-boot.bin" \) ]; then
  cp /home/source/u-boot-*/u-boot.bin "$here/gen"
fi
if [ -z "$reuse" -o ! -f "$here/gen/initrd.img" ]; then
  echo making initrd.img
  mkdir /tmp/initrd
  cd /tmp/initrd
  mkdir bin lib etc proc dev sys newroot
  cp /bin/{bash,busybox,toybox} "$INSTALL_DIR/sbin"/{fsck{,.ext4},e2label,resize2fs,tune2fs,parted,sgdisk,kexec} "$INSTALL_DIR/bin"/{btrfs,fsck.btrfs,btrfs-show-super,natsort} bin
  cp /lib/{libc.so,libuClibc++.so.0,libgcc_s.so.1,ld-musl.so.0} "$INSTALL_DIR/lib"/{libparted.so.2,libuuid.so.1,libdevmapper.so.1.02,libblkid.so.1,libpopt.so.0,libz.so.1,libintl.so.8} lib
  cp "$here/initrd.sh" init
  cp "$here/initrd_config.sh" init_config
  ln -s bin sbin
  ln -s bash bin/sh
  find . | cpio -o -H newc | gzip > "$here/gen/initrd.img"
fi
ls -l "$DIST_DIR"

echo 'Syncing'
sync
echo 'Re-mounting drives read-only'
dev="$(echo /dev/[hsv]dd)"
mount -o remount,ro "${dev}3" || true
mount -o remount,ro /dev/[hsv]db || true
swapoff "${dev}2" || true
# Not all QEMU machines support poweroff so assume -no-reboot was used
exec reboot

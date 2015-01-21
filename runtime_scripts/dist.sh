#!/bin/bash
set -e
here="$(dirname "$0")"
mkdir -p /tmp/mnt
mount -o loop "$here/run.img" /tmp/mnt
HERE=/tmp/mnt . /tmp/mnt/common.sh

EXTRA_DIR="$CHROOT_DIR/extra"
DIST_DIR="$EXTRA_DIR/dist"
UPDATES_DIR="$EXTRA_DIR/updates"

dev="$(echo /dev/[hsv]dd3)"
if [ -b "$dev" ]; then
  cat <<EOF | parted ---pretend-input-tty "${dev%3}" resizepart 3 100%
fix
3
100%
EOF
  parted "${dev%3}" print
  fsck -fy "$dev" || if [ $? -ne 1 ]; then exit $?; fi
  mount "$dev" "$EXTRA_DIR"
  resize2fs "$dev" || btrfs filesystem resize max "$EXTRA_DIR"
fi

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR" "$UPDATES_DIR"

cp -a "$here"/{root,modules,firmware}.sqf "$DIST_DIR"
mksquashfs "$INSTALL_DIR" "$DIST_DIR/install.sqf" -noappend -all-root -mem 512M #-noI -noD -noF -noX
mksquashfs /tmp/mnt "$DIST_DIR/run.sqf" -noappend -all-root -mem 512M

cp /bin/{bash,busybox,toybox} "$here"/{init,init2}.sh "$DIST_DIR"

rm -rf "$EXTRA_DIR/home"
mkdir "$EXTRA_DIR/home"{,/install,/run}
find "$CHROOT_DIR"/home \
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

rm -rf "$EXTRA_DIR"/{root,dev}
mkdir -p "$EXTRA_DIR"/{root,dev}

mkdir /tmp/initrd
cd /tmp/initrd
mkdir bin lib etc proc dev sys newroot
cp /bin/{bash,busybox,toybox} "$INSTALL_DIR/sbin"/{fsck{,.ext4},e2label,resize2fs,tune2fs,parted,sgdisk,kexec} "$INSTALL_DIR/bin"/{btrfs,fsck.btrfs,btrfs-show-super,natsort} bin
cp /lib/{libpthread.so.0,libc.so.0,ld-uClibc.so.0,libdl.so.0,libm.so.0,libuClibc++.so.0,libgcc_s.so.1} "$INSTALL_DIR/lib"/{libiconv.so.2,libparted.so.2,libreadline.so.6,libncurses.so.5,libuuid.so.1,libdevmapper.so.1.02,libblkid.so.1,libpopt.so.0,libz.so.1} lib
cp "$here/initrd.sh" init
cp "$here/initrd_config.sh" init_config
ln -s bin sbin
ln -s bash bin/sh
mount -o remount,rw /dev/hdc /mnt
echo making initrd.img
find . | cpio -o -H newc | gzip > "$here/gen/initrd.img"
echo copying update files
cp "$DIST_DIR"/{install,run}.sqf "$here/gen"
ls -l "$DIST_DIR"

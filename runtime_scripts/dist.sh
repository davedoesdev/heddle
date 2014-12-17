#!/bin/bash
set -e
here="$(dirname "$0")"
mkdir -p /tmp/mnt
mount -o loop "$here/run.img" /tmp/mnt
HERE=/tmp/mnt . /tmp/mnt/common.sh

EXTRA_DIR="$CHROOT_DIR/extra"
DIST_DIR="$EXTRA_DIR/dist"

dev="$(echo /dev/[hsv]dd3)"
if [ -b "$dev" ]; then
  cat <<EOF | parted ---pretend-input-tty "${dev%3}" resizepart 3 100%
fix
3
100%
EOF
  parted "${dev%3}" print
  e2fsck -fy "$dev" || if [ $? -ne 1 ]; then exit $?; fi
  resize2fs "$dev"
  mount "$dev" "$EXTRA_DIR"
fi

rm -rf "$DIST_DIR"
mkdir "$DIST_DIR"

cp -a "$here/hda.sqf" "$DIST_DIR/root.sqf"
mksquashfs "$INSTALL_DIR" "$DIST_DIR/install.sqf" -noappend -all-root -mem 512M -noI -noD -noF -noX
mksquashfs /tmp/mnt "$DIST_DIR/run.sqf" -noappend -all-root -mem 512M

cp /bin/{bash,busybox,toybox} "$here/init.sh" "$DIST_DIR"

rm -rf "$EXTRA_DIR/home"
mkdir "$EXTRA_DIR/home"{,/install}
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

mkdir /tmp/{mnt2,initrd}
cd /tmp/initrd
mkdir bin lib etc proc dev newroot
cp /bin/{bash,busybox,toybox} "$INSTALL_DIR/sbin"/{e2fsck,resize2fs,parted,sgdisk} bin
cp /lib/{libpthread.so.0,libc.so.0,ld-uClibc.so.0,libdl.so.0,libm.so.0,libuClibc++.so.0,libgcc_s.so.1} "$INSTALL_DIR/lib"/{libiconv.so.2,libparted.so.2,libreadline.so.6,libncurses.so.5,libuuid.so.1,libdevmapper.so.1.02,libblkid.so.1,libpopt.so.0} lib
cp "$here/initrd.sh" init
find . | cpio -o -H newc | gzip > "$DIST_DIR/initrd.img"
mount /dev/sda /tmp/mnt2
cp "$DIST_DIR/initrd.img" /tmp/mnt2
cp /tmp/mnt2/bzImage "$DIST_DIR"
umount /dev/sda
ls -l "$DIST_DIR"

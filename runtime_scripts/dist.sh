#!/bin/bash
set -e
here="$(dirname "$0")"
mkdir -p /tmp/mnt
mount -o loop "$here/run.img" /tmp/mnt
HERE=/tmp/mnt . /tmp/mnt/common.sh

if [ -b /dev/[hsv]dd ]; then
  chroot "$CHROOT_DIR" mount /dev/[hsv]dd /extra
fi

chroot "$CHROOT_DIR" << EOF
rm -rf /extra/dist
mkdir /extra/dist
cp -a "$here/hda.sqf" /extra/dist/root.sqf
mksquashfs /tmp/mnt /extra/dist/run.sqf -noappend -all-root -mem 512M
mksquashfs "$INSTALL_DIR" /extra/dist/install.sqf -noappend -all-root -mem 512M
EOF

# need to copy home and chroot

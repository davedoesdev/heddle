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
#rm -rf /extra/dist
#mkdir /extra/dist
#cp -a "$here/hda.sqf" /extra/dist/root.sqf
#mksquashfs /tmp/mnt /extra/dist/run.sqf -noappend -all-root -mem 512M
#mksquashfs "$INSTALL_DIR" /extra/dist/install.sqf -noappend -all-root -mem 512M
cp /bin/{bash,mount,mkdir} /sbin/chroot "$here/init.sh" /extra/dist

rm -rf /extra/chroot
cp -a "$CHROOT_DIR" /extra/chroot

rm -rf /extra/home
mkdir /extra/home
find /home -mindepth 1 -maxdepth 1 \
           -not -name install \
           -not -name chroot \
           -not -name source \
           -not -name '.bash*' \
           -not -name lost+found \
           -exec cp -a {} /extra/home \;

mkdir -p /extra/{root,dev}
EOF


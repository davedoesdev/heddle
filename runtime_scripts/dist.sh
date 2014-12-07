#!/bin/bash
set -e
here="$(dirname "$0")"
mkdir -p /tmp/mnt
mount -o loop "$here/run.img" /tmp/mnt
HERE=/tmp/mnt . /tmp/mnt/common.sh

EXTRA_DIR="$CHROOT_DIR/extra"
DIST_DIR="$EXTRA_DIR/dist"

if [ -b /dev/[hsv]dd2 ]; then
  mount /dev/[hsv]dd2 "$EXTRA_DIR"
fi

rm -rf "$DIST_DIR"
mkdir "$DIST_DIR"

cp -a "$here/hda.sqf" "$DIST_DIR/root.sqf"
mksquashfs "$INSTALL_DIR" "$DIST_DIR/install.sqf" -noappend -all-root -mem 512M -noI -noD -noF -noX
mksquashfs /tmp/mnt "$DIST_DIR/run.sqf" -noappend -all-root -mem 512M

cp /bin/{bash,mount,mkdir,ls} /sbin/chroot "$here/init.sh" "$DIST_DIR"

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


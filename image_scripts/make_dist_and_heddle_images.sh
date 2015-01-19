#!/bin/bash
# make dist.img, copy dist.sh and hda.sqf into it
# make heddle.img (copy of extra.img)
set -e
HERE="$(dirname "$0")"
ARCH="${1:-x86_64}"
IMG_DIST="$HERE/../images/dist.img"
UPDATE_DIR="$HERE/../dist/update"
SQF_MODULES="$UPDATE_DIR/modules.sqf"
SQF_ROOT="build/system-image-$ARCH/hda.sqf" 

if [ ! -e "$IMG_DIST" ]; then
  dd if=/dev/zero "of=$IMG_DIST" bs=1024 "seek=$((2 * 1024 * 1024))" count=0
  mkfs.ext2 "$IMG_DIST"
  e2mkdir "$IMG_DIST:gen"
fi

copy() {
  local p=400
  if [ -x "$1" ]; then p=500; fi
  e2cp -P $p -O 0 -G 0 "$1" "$IMG_DIST:$2"
}

copy "$HERE/../runtime_scripts/dist.sh" init
copy "$HERE/../images/run.img"
copy "$SQF_ROOT" root.sqf
ln -sf "$PWD/$SQF_ROOT" "$UPDATE_DIR/root.sqf"
ln -sf "$PWD/build/root-filesystem-$ARCH/usr/bin"/{bash,busybox,toybox} "$UPDATE_DIR"
mksquashfs "build/system-image-$ARCH/modules/lib/modules" "$SQF_MODULES" -noappend -all-root -wildcards -e '*/build' '*/source'
copy "$SQF_MODULES"
copy "$HERE/../runtime_scripts/init.sh"
copy "$HERE/../runtime_scripts/init2.sh"
copy "$HERE/../runtime_scripts/initrd.sh"
copy "$HERE/../runtime_scripts/initrd_config.sh"

if [ ! -e "$HERE/../images/heddle.img" ]; then
  # assume cp recognises sparse files
  cp "$HERE/../images"/{extra,heddle}.img
fi


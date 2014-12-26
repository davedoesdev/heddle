#!/bin/bash
# make dist.img, copy dist.sh and hda.sqf into it
# make heddle.img (copy of extra.img)
set -e
HERE="$(dirname "$0")"
IMG_DIST="$HERE/../images/dist.img"

if [ ! -e "$IMG_DIST" ]; then
  dd if=/dev/zero "of=$IMG_DIST" bs=1024 "seek=$((1 * 1024 * 1024))" count=0
  mkfs.ext2 "$IMG_DIST"
fi

copy() {
  local p=400
  if [ -x "$1" ]; then p=500; fi
  e2cp -P $p -O 0 -G 0 "$1" "$IMG_DIST:$2"
}

copy "$HERE/../runtime_scripts/dist.sh" init
copy "$HERE/../images/run.img"
copy "build/system-image-${1:-x86_64}/hda.sqf"
copy "$HERE/../runtime_scripts/init.sh"
copy "$HERE/../runtime_scripts/init2.sh"
copy "$HERE/../runtime_scripts/initrd.sh"

if [ ! -e "$HERE/../images/heddle.img" ]; then
  # assume cp recognises sparse files
  cp "$HERE/../images"/{extra,heddle}.img
fi


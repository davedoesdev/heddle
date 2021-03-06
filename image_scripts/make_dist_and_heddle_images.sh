#!/bin/bash
# make dist.img, copy dist.sh and root.sqf into it
# make heddle.img (copy of extra.img)
set -e
HERE="$(cd "$(dirname "$0")"; echo "$PWD")"

# assume cp recognises sparse files
img_cp=cp
while getopts l opt
do
  case $opt in
    l)
      img_cp='ln -s'
      ;;
  esac
done
shift $((OPTIND-1))

ARCH="${1:-x86_64}"
IMG_DIR="${HEDDLE_EXT_DIR:-"$HERE/.."}/gen/$ARCH/images"
IMG_DIST="$IMG_DIR/dist.img"
UPDATE_DIR="${HEDDLE_EXT_DIR:-"$HERE/.."}/gen/$ARCH/dist/update"
SQF_MODULES="$UPDATE_DIR/modules.sqf"
SQF_FIRMWARE="$UPDATE_DIR/firmware.sqf"
SQF_ROOT="$UPDATE_DIR/root.sqf"

if [ "build/system-image-$ARCH/rootfs.cpio.gz" -nt "$SQF_ROOT" ]; then
  tmpd="$(mktemp -d)"
  zcat "build/system-image-$ARCH/rootfs.cpio.gz" | ( cd "$tmpd"; cpio -i -H newc -f dev/console )
  unsquashfs -d "$tmpd/usr/overlay" "build/system-image-$ARCH/toolchain.sqf" 
  cp -r --remove-destination "$tmpd/usr/overlay/." "$tmpd"
  rm -rf "$tmpd"/{init,usr/overlay}
  mksquashfs "$tmpd" "$SQF_ROOT" -noappend -all-root
  rm -rf "$tmpd"
fi

if [ "build/system-image-$ARCH/modules/lib/modules" -nt "$SQF_MODULES" ]; then
  mksquashfs "build/system-image-$ARCH/modules/lib/modules" "$SQF_MODULES" -noappend -all-root -wildcards -e '*/build' '*/source'
fi

if [ "build/system-image-$ARCH/modules/lib/firmware" -nt "$SQF_FIRMWARE" ]; then
  mksquashfs "build/system-image-$ARCH/modules/lib/firmware" "$SQF_FIRMWARE" -noappend -all-root
fi

if [ "$UPDATE_DIR" != "$HERE/../gen/$ARCH/dist/update" ]; then
  mkdir -p "$UPDATE_DIR"
  ln -sf "$HERE/../gen/$ARCH/dist/update"/*.sh "$UPDATE_DIR"
fi

if [ ! -e "$IMG_DIST" ]; then
  dd if=/dev/zero "of=$IMG_DIST" bs=1024 "seek=$((4 * 1024 * 1024))" count=0
  mkfs.ext4 -F -O ^has_journal "$IMG_DIST"
  e2mkdir "$IMG_DIST:gen"
fi

copy() {
  local p=400
  if [ -x "$1" ]; then p=500; fi
  e2cp -P $p -O 0 -G 0 "$1" "$IMG_DIST:$2"
}

copy "$HERE/../runtime_scripts/dist.sh" init
copy "$IMG_DIR/run.img"
copy "$SQF_ROOT"
copy "$SQF_MODULES"
if [ -e "$SQF_FIRMWARE" ]; then
  copy "$SQF_FIRMWARE"
fi
copy "$HERE/../runtime_scripts/init.sh"
copy "$HERE/../runtime_scripts/init2.sh"
copy "$HERE/../runtime_scripts/initrd.sh"
copy "$HERE/../runtime_scripts/initrd_config.sh"

ln -sf "$PWD/build/root-filesystem-$ARCH/usr/bin"/{busybox,toybox} "$UPDATE_DIR"
ln -sf "$PWD/build/native-compiler-$ARCH/usr/bin"/bash "$UPDATE_DIR"

if [ ! -e "$IMG_DIR/heddle.img" ]; then
  $img_cp "$IMG_DIR"/{extra,heddle}.img
fi


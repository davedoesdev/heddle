#!/bin/bash
HERE="$(dirname "$0")"
IMG_DIR="$HERE/../images"
UPDATE_DIR="$HERE/../dist/update"
export HDB="$IMG_DIR/home.img"
export HDC="$IMG_DIR/dist.img"
tmp="$(mktemp)"
dd if=/dev/zero "of=$tmp" bs=1024 "seek=$((20 * 1024))" count=0
mkfs.ext2 "$tmp"
export QEMU_EXTRA="-hdd $IMG_DIR/heddle.img -cpu host -smp 2 -usb -usbdevice disk:$tmp"
export QEMU_MEMORY=2048
cd "build/system-image-${1:-x86_64}"
./dev-environment.sh 
e2cp "$tmp:initrd.img" "$tmp:run.sqf" "$UPDATE_DIR"
ln -sf "$PWD/bzImage" "$UPDATE_DIR"
rm -f "$tmp"
mmd -i "$IMG_DIR/heddle.img@@1M" -D s ::dist
mcopy -i "$IMG_DIR/heddle.img@@1M" -D o bzImage "$IMG_DIR/initrd.img" ::dist
mdir -i "$IMG_DIR/heddle.img@@1M" ::dist

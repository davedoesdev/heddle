#!/bin/bash
IMG_DIR="$(dirname "$0")/../images"
export HDB="$IMG_DIR/home.img"
export HDC="$IMG_DIR/dist.img"
tmp="$(mktemp)"
dd if=/dev/zero "of=$tmp" bs=1024 "seek=$((20 * 1024))" count=0
mke2fs "$tmp"
export QEMU_EXTRA="-hdd $IMG_DIR/heddle.img -cpu host -smp 2 -usb -usbdevice disk:$tmp"
export QEMU_MEMORY=2048
cd "build/system-image-${1:-x86_64}"
e2cp bzImage "$tmp:"
./dev-environment.sh 
e2cp "$tmp:initrd.img" "$IMG_DIR"
rm -f "$tmp"

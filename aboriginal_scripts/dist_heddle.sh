#!/bin/bash
set -e
HERE="$(cd "$(dirname "$0")"; echo "$PWD")"
IMG_DIR="${HEDDLE_EXT_DIR:-"$HERE/.."}/images"
UPDATE_DIR="${HEDDLE_EXT_DIR:-"$HERE/.."}/dist/update"
export HDB="$IMG_DIR/home.img"
export HDC="$IMG_DIR/dist.img"
export QEMU_EXTRA="-hdd $IMG_DIR/heddle.img -cpu host -smp 2"
export QEMU_MEMORY=2048
cd "build/system-image-${1:-x86_64}"
./dev-environment.sh 
e2cp "$HDC:gen/initrd.img" "$HDC:gen/install.sqf" "$HDC:gen/run.sqf" "$UPDATE_DIR"
ln -sf "$PWD/bzImage" "$UPDATE_DIR"
mmd -i "$IMG_DIR/heddle.img@@1M" -D s ::dist || true
mcopy -i "$IMG_DIR/heddle.img@@1M" -D o bzImage "$UPDATE_DIR/initrd.img" ::dist
mdir -i "$IMG_DIR/heddle.img@@1M" ::dist

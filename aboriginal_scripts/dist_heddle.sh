#!/bin/bash
IMG_DIR="$(dirname "$0")/../images"
export HDB="$IMG_DIR/home.img"
export HDC="$IMG_DIR/dist.img"
export QEMU_EXTRA="-hdd $IMG_DIR/heddle.img" QEMU_MEMORY=2048
cd "build/system-image-${1:-x86_64}"
./dev-environment.sh

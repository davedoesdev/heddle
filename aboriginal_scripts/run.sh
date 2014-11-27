#!/bin/bash
IMG_DIR="$(cd "$(dirname "$0")"; echo $PWD)/../images"
export HDB="$IMG_DIR/home.img"
export HDC="$IMG_DIR/run.img"
export QEMU_EXTRA="-hdd $IMG_DIR/extra.img" QEMU_MEMORY=2048 
./dev-environment.sh

#!/bin/bash
IMG_DIR="$(cd "$(dirname "$0")"; echo $PWD)/../images"
export HDB="$IMG_DIR/home.img"
export HDC="$IMG_DIR/build.img"
export QEMU_MEMORY=2048
./dev-environment.sh

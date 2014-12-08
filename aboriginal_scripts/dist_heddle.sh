#!/bin/bash
IMG_DIR="$(dirname "$0")/../images"
export HDB="$IMG_DIR/home.img"
export HDC="$IMG_DIR/dist.img"
export QEMU_EXTRA="-hdd $IMG_DIR/heddle.img" QEMU_MEMORY=2048
cd "build/system-image-${1:-x86_64}"
./dev-environment.sh | tee >(awk 'BEGIN{suppress=0}{if ($1 == "begin") suppress=1; else if ($1 =="end") suppress=0; else if (!suppress) print}' > /dev/tty) | python -c 'import uu, sys; uu.decode("-", "-")' > "$IMG_DIR/initrd.img"

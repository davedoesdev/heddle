#!/bin/bash
set -e
HERE="$(dirname "$0")"
IMG_DIR="${HEDDLE_EXT_DIR:-"$HERE/.."}/images"
qemu-img convert -c -f raw -O qcow2 "$IMG_DIR/heddle."{img,qcow2}
qemu-img convert -c -f raw -O qcow2 "$IMG_DIR/build."{img,qcow2}

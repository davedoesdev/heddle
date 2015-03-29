#!/bin/bash
set -e
HERE="$(dirname "$0")"
ARCH="${1:-x86_64}"
GEN_DIR="${HEDDLE_EXT_DIR:-"$HERE/.."}/gen"
qemu-img convert -c -f raw -O qcow2 "$GEN_DIR/$ARCH/images/heddle."{img,qcow2}
qemu-img convert -c -f raw -O qcow2 "$GEN_DIR/build."{img,qcow2}

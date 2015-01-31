#!/bin/bash
set -e
HERE="$(dirname "$0")"
export HDB="${HEDDLE_EXT_DIR:-"$HERE/.."}/images/home.img"
export HDC="${HEDDLE_EXT_DIR:-"$HERE/.."}/images/build.img"
export QEMU_MEMORY=2048
cd "build/system-image-${1:-x86_64}"
./dev-environment.sh

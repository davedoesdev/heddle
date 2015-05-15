#!/bin/bash
set -e
HERE="$(cd "$(dirname "$0")"; echo "$PWD")"

prepare=0
qemu_mode=0
append=
while getopts pqa: opt
do
  case $opt in
    p)
      prepare=1
      ;;
    q)
      qemu_mode=1
      ;;
    a)
      append="$OPTARG"
      ;;
  esac
done
shift $((OPTIND-1))

ARCH="${1:-x86_64}"
IMG_DIR="${HEDDLE_EXT_DIR:-"$HERE/.."}/gen/$ARCH/images"
export HDB="$IMG_DIR/home.img"
export HDC="$IMG_DIR/run.img"
export QEMU_EXTRA="-hdd $IMG_DIR/extra.img -net user,hostname=heddle -net nic"
export KERNEL_EXTRA="heddle_prepare=$prepare $append"
if [ "$ARCH" = x86_64 ]; then
  if [ "$qemu_mode" -eq 0 ]; then
    QEMU_EXTRA+=" -cpu host -smp 2"
  fi
  export QEMU_MEMORY=2048
fi
cd "build/system-image-$ARCH"
./dev-environment.sh

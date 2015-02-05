#!/bin/bash
set -e

use_chroot=
while getopts c opt
do
  case $opt in
    c)
      use_chroot=1
      ;;
  esac
done
shift $((OPTIND-1))

HERE="$(cd "$(dirname "$0")"; echo "$PWD")"
export HDB="${HEDDLE_EXT_DIR:-"$HERE/.."}/images/home.img"
export HDC="${HEDDLE_EXT_DIR:-"$HERE/.."}/images/build.img"
export QEMU_MEMORY=2048
cd "build/system-image-${1:-x86_64}"

if [ -n "$use_chroot" ]; then
  # snap-ci doesn't have nested virtualization
  mkdir -p chroot
  sudo mount -o loop -t squashfs hda.sqf chroot
  sudo mount -o loop "$HDB" chroot/home
  sudo mount -o loop,ro "$HDC" chroot/mnt
  sudo mount -t proc proc chroot/proc
  sudo mount -t sysfs sys chroot/sys
  sudo mount -t devtmpfs dev chroot/dev
  sudo mount -t tmpfs tmp chroot/tmp
  sudo chroot chroot /mnt/init
  sudo umount chroot/{home,mnt,proc,sys,dev,tmp,}
else
  ./dev-environment.sh
fi

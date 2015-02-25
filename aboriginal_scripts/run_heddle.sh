#!/bin/bash
set -e
HERE="$(cd "$(dirname "$0")"; echo "$PWD")"
IMG_DIR="${HEDDLE_EXT_DIR:-"$HERE/.."}/images"

prepare=0
qemu_mode=0
while getopts pq opt
do
  case $opt in
    p)
      prepare=1
      ;;
    q)
      qemu_mode=1
      ;;
  esac
done
shift $((OPTIND-1))

export HDB="$IMG_DIR/home.img"
export HDC="$IMG_DIR/run.img"
export QEMU_EXTRA="-hdd $IMG_DIR/extra.img -redir tcp:5900::5900 -net user,hostname=heddle -net nic"
if [ "$qemu_mode" -eq 0 ]; then
  QEMU_EXTRA+=" -cpu host -smp 2"
fi
export QEMU_MEMORY=2048 
export KERNEL_EXTRA="heddle_prepare=$prepare"
cd "build/system-image-${1:-x86_64}"
free -m
ps auxw
./dev-environment.sh

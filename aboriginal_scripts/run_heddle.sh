#!/bin/bash
IMG_DIR="$(dirname "$0")/../images"

prepare=0
while getopts p opt
do
  case $opt in
    p)
      prepare=1
      ;;
  esac
done
shift $((OPTIND-1))

export HDB="$IMG_DIR/home.img"
export HDC="$IMG_DIR/run.img"
export QEMU_EXTRA="-hdd $IMG_DIR/extra.img -redir tcp:5900::5900 -cpu host -smp 2 -net user,hostname=heddle -net nic"
export QEMU_MEMORY=2048 
export KERNEL_EXTRA="heddle_prepare=$prepare"
cd "build/system-image-${1:-x86_64}"
./dev-environment.sh

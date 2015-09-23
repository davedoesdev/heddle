#!/bin/bash
set -e
HERE="$(cd "$(dirname "$0")"; echo "$PWD")"
if [ -n "$HEDDLE_EXT_DIR" ]; then
  project="$(cd "$HEDDLE_EXT_DIR"; basename "$PWD")"
else
  project=heddle
fi

prepare=0
qemu_mode=0
append=
hostname=
while getopts pPqa:h: opt
do
  case $opt in
    p)
      prepare=1
      ;;
    P)
      prepare=10
      ;;
    q)
      qemu_mode=1
      ;;
    a)
      append="$OPTARG"
      ;;
    h)
      hostname="$OPTARG"
      ;;
  esac
done
shift $((OPTIND-1))

ARCH="${1:-x86_64}"
IMG_DIR="${HEDDLE_EXT_DIR:-"$HERE/.."}/gen/$ARCH/images"
export HDB="$IMG_DIR/home.img"
export HDC="$IMG_DIR/run.img"
export QEMU_EXTRA="-hdd $IMG_DIR/extra.img -net user,hostname=${hostname:-$project} -net nic"
export KERNEL_EXTRA="heddle_arch=$ARCH heddle_prepare=$prepare $append"
if [ "$ARCH" = x86_64 ]; then
  if [ "$qemu_mode" -eq 0 ]; then
    QEMU_EXTRA+=" -cpu host -smp 2"
  fi
  export QEMU_MEMORY=2048
fi
cd "build/system-image-$ARCH"
./dev-environment.sh

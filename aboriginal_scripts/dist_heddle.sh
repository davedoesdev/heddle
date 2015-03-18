#!/bin/bash
set -e
HERE="$(cd "$(dirname "$0")"; echo "$PWD")"

qemu_mode=0
reuse=0
while getopts qr opt
do
  case $opt in
    q)
      qemu_mode=1
      ;;
    r)
      reuse=1
      ;;
  esac
done
shift $((OPTIND-1))

ARCH="${1:-x86_64}"
IMG_DIR="${HEDDLE_EXT_DIR:-"$HERE/.."}/gen/$ARCH/images"
UPDATE_DIR="${HEDDLE_EXT_DIR:-"$HERE/.."}/gen/$ARCH/dist/update"
export HDB="$IMG_DIR/home.img"
export HDC="$IMG_DIR/dist.img"
export QEMU_EXTRA="-hdd $IMG_DIR/heddle.img -net user,hostname=heddle -net nic"
if [ "$qemu_mode" -eq 0 ]; then
  QEMU_EXTRA+=" -cpu host -smp 2"
fi
export KERNEL_EXTRA="heddle_dist_reuse=$reuse"
export QEMU_MEMORY=2048
cd "build/system-image-$ARCH"
./dev-environment.sh 
e2cp "$HDC:gen"/{initrd.img,install.sqf,run.sqf} "$UPDATE_DIR"
ln -sf "$PWD/linux" "$UPDATE_DIR"
mmd -i "$IMG_DIR/heddle.img@@1M" -D s ::dist || true
mcopy -i "$IMG_DIR/heddle.img@@1M" -D o linux "$UPDATE_DIR/initrd.img" ::dist
mdir -i "$IMG_DIR/heddle.img@@1M" ::dist

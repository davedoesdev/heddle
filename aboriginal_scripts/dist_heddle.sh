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
export KERNEL_EXTRA="heddle_dist_reuse=$reuse"
if [ "$ARCH" = x86_64 ]; then
  if [ "$qemu_mode" -eq 0 ]; then
    QEMU_EXTRA+=" -cpu host -smp 2"
  fi
  export QEMU_MEMORY=2048
fi
cd "build/system-image-$ARCH"
./dev-environment.sh 
ln -sf "$PWD/linux" "$UPDATE_DIR"
e2cp "$HDC:gen"/{initrd.img,install.sqf,run.sqf} "$UPDATE_DIR"
if [ "$ARCH" = armv6l ]; then
  # Make boot.bin from u-boot.bin, kernel and initrd. Use modified version of:
  # https://balau82.wordpress.com/2010/04/12/booting-linux-with-u-boot-on-qemu-arm/
  #            | QEMU start | U-Boot reloc | U-Boot bootm
  # -----------+------------+--------------+-------------
  # 0x00010000 | U-Boot     |              | Kernel
  # -----------+------------+--------------+-------------
  # 0x00210000 | Kernel     | Kernel       |
  # -----------+------------+--------------+-------------
  # 0x00800000 |            |              | Ramdisk
  # -----------+------------+--------------+-------------
  # 0x00810000 | Ramdisk    | Ramdisk      |
  # -----------+------------+--------------+-------------
  # 0x01000000 |            | U-Boot       |
  rm -f "$IMG_DIR/boot.bin"
  dd if=/dev/zero "of=$IMG_DIR/boot.bin" bs=1024 "seek=$((16 * 1024))" count=0
  e2cp "$HDC:gen/u-boot.bin" - | dd "of=$IMG_DIR/boot.bin" conv=notrunc
  tmp="$(mktemp)"
  mkimage -A arm -C none -O linux -T kernel -d linux -a 0x00010000 -e 0x00010000 "$tmp"
  dd "if=$tmp" "of=$IMG_DIR/boot.bin" bs=1024 conv=notrunc "seek=$((2 * 1024))"
  rm -f "$tmp"
  tmp="$(mktemp)"
  mkimage -A arm -C none -O linux -T ramdisk -d "$UPDATE_DIR/initrd.img" -a 0x00800000 -e 0x00800000 "$tmp"
  dd "if=$tmp" "of=$IMG_DIR/boot.bin" bs=1024 conv=notrunc "seek=$((8 * 1024))"
  rm -f "$tmp"
else
  mmd -i "$IMG_DIR/heddle.img@@1M" -D s ::dist || true
  mcopy -i "$IMG_DIR/heddle.img@@1M" -D o linux "$UPDATE_DIR/initrd.img" ::dist
  mdir -i "$IMG_DIR/heddle.img@@1M" ::dist
fi

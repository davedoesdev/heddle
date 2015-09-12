#!/bin/bash
set -e
HERE="$(cd "$(dirname "$0")"; echo "$PWD")"
if [ -n "$HEDDLE_EXT_DIR" ]; then
  project="$(cd "$HEDDLE_EXT_DIR"; basename "$PWD")"
else
  project=heddle
fi

version="$(cd "${HEDDLE_EXT_DIR:-"$HERE"}"; git rev-parse --abbrev-ref HEAD)"
if [ "$version" = master -o "$version" = HEAD ]; then
  version="$(cd "${HEDDLE_EXT_DIR:-"$HERE"}"; git rev-parse HEAD)"
fi
if [ -n "$(cd "${HEDDLE_EXT_DIR:-"$HERE"}"; git status --porcelain)" ]; then
  ( cd "${HEDDLE_EXT_DIR:-"$HERE"}"; git status )
  version="$version*"
fi

qemu_mode=0
reuse=0
hostname=
while getopts qrh: opt
do
  case $opt in
    q)
      qemu_mode=1
      ;;
    r)
      reuse=1
      ;;
    h)
      hostname="$OPTARG"
      ;;
  esac
done
shift $((OPTIND-1))

ARCH="${1:-x86_64}"
IMG_DIR="${HEDDLE_EXT_DIR:-"$HERE/.."}/gen/$ARCH/images"
UPDATE_DIR="${HEDDLE_EXT_DIR:-"$HERE/.."}/gen/$ARCH/dist/update"
export HDB="$IMG_DIR/home.img"
export HDC="$IMG_DIR/dist.img"
export QEMU_EXTRA="-hdd $IMG_DIR/heddle.img -net user,hostname=${hostname:-$project} -net nic"
export KERNEL_EXTRA="heddle_arch=$ARCH heddle_dist_reuse=$reuse heddle_project=$project heddle_version=$version"
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
  # Make boot.kbin from u-boot.bin, kernel and initrd. Use modified version of:
  # https://balau82.wordpress.com/2010/04/12/booting-linux-with-u-boot-on-qemu-arm/
  #            | QEMU start | U-Boot reloc  | U-Boot bootm
  # -----------+------------+---------------+-------------
  # 0x00010000 | U-Boot     | U-Boot (QEMU) | Kernel
  # -----------+------------+---------------+-------------
  # 0x00210000 | Kernel     | Kernel        |
  # -----------+------------+---------------+-------------
  # 0x00800000 |            |               | Ramdisk
  # -----------+------------+---------------+-------------
  # 0x01000000 |            | U-Boot (phys) |
  # -----------+------------+---------------+-------------
  # 0x02010000 | Ramdisk    | Ramdisk       |
  bootf="$IMG_DIR/boot.kbin"
  e2cp "$HDC:gen/u-boot.bin" "$bootf"
  tmp="$(mktemp)"
  mkimage -A arm -C none -O linux -T kernel -d linux -a 0x00010000 -e 0x00010000 "$tmp"
  dd "if=$tmp" "of=$bootf" bs=1024 conv=notrunc "seek=$((2 * 1024))"
  rm -f "$tmp"
  tmp="$(mktemp)"
  mkimage -A arm -C none -O linux -T ramdisk -d "$UPDATE_DIR/initrd.img" -a 0x00800000 -e 0x00800000 "$tmp"
  dd "if=$tmp" "of=$bootf" bs=1024 conv=notrunc "seek=$((32 * 1024))"
  rm -f "$tmp"
else
  mmd -i "$IMG_DIR/heddle.img@@1M" -D s ::dist || true
  mcopy -i "$IMG_DIR/heddle.img@@1M" -D o linux "$UPDATE_DIR/initrd.img" ::dist
  mdir -i "$IMG_DIR/heddle.img@@1M" ::dist
fi

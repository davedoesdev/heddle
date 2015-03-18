#!/bin/bash
# make run.img and copy run into it as /init
# use HDC=/path/to/run when running dev-environment.sh
set -e
HERE="$(dirname "$0")"
SWAP_GB=4

part_type=gpt
primary=
fs_type=ext4
fs_opts=-F
while getopts mb opt
do
  case $opt in
    m)
      part_type=msdos
      primary=primary
      ;;
    b)
      fs_type=btrfs
      fs_opts=
      ;;
  esac
done
shift $((OPTIND-1))

ARCH="${1:-x86_64}"
IMG_DIR="${HEDDLE_EXT_DIR:-"$HERE/.."}/gen/$ARCH/images"
IMG_RUN="$IMG_DIR/run.img"
IMG_EXTRA="$IMG_DIR/extra.img"

part_name() {
  if [ $part_type = gpt ]; then
    echo "$1"
  else
    echo primary
  fi
}

VER_REFIND="0.8.4"
DIR_REFIND="refind-bin-$VER_REFIND"
SRC_REFIND="$DIR_REFIND.zip"
URL_REFIND="http://downloads.sourceforge.net/project/refind/$VER_REFIND/$SRC_REFIND"
CHK_REFIND="08769aa9e4f41c0c267438d639bb37a5f97b3ddc8a5d208d75e95d204c73819e"
SUM_REFIND="sha256"

if [ ! -d "$HERE/../boot/$DIR_REFIND" ]; then
  rm -f "/tmp/$SRC_REFIND" 
  wget -O "/tmp/$SRC_REFIND" "$URL_REFIND"
  if [ "$("${SUM_REFIND}sum" "/tmp/$SRC_REFIND" | awk '{print $1}')" != "$CHK_REFIND" ]; then
    echo "refind checksum mismatch" 1>&2
    exit 1
  fi
  unzip -d "$HERE/../boot" "/tmp/$SRC_REFIND"
fi

if [ ! -e "$IMG_RUN" ]; then
  dd if=/dev/zero "of=$IMG_RUN" bs=1024 "seek=$((1 * 1024))" count=0
  mkfs.ext4 -F -O ^has_journal "$IMG_RUN"
fi

if [ ! -e "$IMG_EXTRA" ]; then
  dd if=/dev/zero "of=$IMG_EXTRA" bs=1024 "seek=$((32 * 1024 * 1024))" count=0
  parted -s "$IMG_EXTRA" mklabel $part_type \
                         mkpart "$(part_name esp)" fat32 0% 513MiB \
                         mkpart "$(part_name swap)" linux-swap 513MiB "$((513 + $SWAP_GB * 1024))MiB" \
                         mkpart "$(part_name heddle_root)" $fs_type "$((513 + $SWAP_GB * 1024))MiB" 100% \
                         set 1 boot on

  tmp="$(mktemp)"
  dd if=/dev/zero "of=$tmp" bs=1024 "seek=$(($SWAP_GB * 1024 * 1024))" count=0
  mkswap "$tmp"
  dd "if=$tmp" "of=$IMG_EXTRA" bs=1024 "seek=$((513 * 1024))" conv=sparse,notrunc
  rm -f "$tmp"

  tmp="$(mktemp)"
  dd if=/dev/zero "of=$tmp" bs=1024 "seek=$((1024 * 1024))" count=0
  mkfs.$fs_type $fs_opts -L heddle_root "$tmp"
  dd "if=$tmp" "of=$IMG_EXTRA" bs=1024 "seek=$(((513 + $SWAP_GB * 1024) * 1024))" conv=sparse,notrunc
  rm -f "$tmp"
fi

tmp="$(mktemp)"
dd if=/dev/zero "of=$tmp" bs=1024 "seek=$((512 * 1024))" count=0
mkfs.vfat -F 32 "$tmp"
if [ $part_type = gpt ]; then
  mcopy -i "$tmp" -s "$HERE/../boot/$DIR_REFIND/refind" ::
  mdel -i "$tmp" ::/refind/{refind_ia32.efi,refind.conf-sample}
  mdeltree -i "$tmp" ::/refind/{drivers_{ia32,x64},tools_{ia32,x64}}
  mcopy -i "$tmp" "$HERE/../boot/refind.conf" ::/refind
  mmd -i "$tmp" ::/EFI
  mmove -i "$tmp" ::/refind ::/EFI/BOOT
  mmove -i "$tmp" ::/EFI/BOOT/{refind_,boot}x64.efi 
else
  syslinux "$tmp"
  mcopy -i "$tmp" "$HERE/../boot/syslinux.cfg" ::
  if [ -d /usr/lib/syslinux/modules ]; then
    mcopy -i "$tmp" /usr/lib/syslinux/modules/bios/{menu,libutil}.c32 ::
  else
    mcopy -i "$tmp" /usr/lib/syslinux/menu.c32 ::
  fi
  if [ -d /usr/lib/syslinux/mbr ]; then
    dd bs=440 count=1 conv=notrunc if=/usr/lib/syslinux/mbr/mbr.bin "of=$IMG_EXTRA"
  else
    dd bs=440 count=1 conv=notrunc if=/usr/lib/syslinux/mbr.bin "of=$IMG_EXTRA"
  fi
fi
mdir -i "$tmp" -/ -a ::
dd "if=$tmp" "of=$IMG_EXTRA" bs=1024 seek=1024 conv=sparse,notrunc
rm -f "$tmp"

copy() {
  local p=400
  if [ -x "$1" ]; then p=500; fi
  e2cp -P $p -O 0 -G 0 "$1" "$IMG_RUN:$2"
}

ext_packages=
ext_chroot=
if [ -n "$HEDDLE_EXT_DIR" ]; then
  [ -e "$HEDDLE_EXT_DIR/image_scripts/packages" ] && ext_packages="$HEDDLE_EXT_DIR/image_scripts/packages"
  [ -d "$HEDDLE_EXT_DIR/chroot" ] && ext_chroot="-C $HEDDLE_EXT_DIR/chroot ."
fi

(cat "$HERE/packages" $ext_packages) | copy - packages
copy "$HERE/../runtime_scripts/run.sh" init
copy "$HERE/../runtime_scripts/common.sh"
copy "$HERE/../runtime_scripts/make_chroot.sh"

(tar --owner root --group root -zc -C "$HERE/../chroot" . -C "$PWD" $ext_chroot) | copy - chroot.tar.gz

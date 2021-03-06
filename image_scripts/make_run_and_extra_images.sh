#!/bin/bash
# make run.img and copy run into it as /init
# use HDC=/path/to/run when running dev-environment.sh
set -e
HERE="$(dirname "$0")"
SWAP_GB=4

part_type=gpt
fs_type=btrfs
fs_opts=
while getopts me opt
do
  case $opt in
    m)
      part_type=msdos
      ;;
    e)
      fs_type=ext4
      fs_opts=-F
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

# Treat rEFInd as a host tool and download it if required
VER_REFIND="0.10.2"
DIR_REFIND="refind-bin-$VER_REFIND"
SRC_REFIND="$DIR_REFIND.zip"
URL_REFIND="http://downloads.sourceforge.net/project/refind/$VER_REFIND/$SRC_REFIND"
CHK_REFIND="d3de1ff3a007a4cacd47bfc7ba93ef328732832afc1f80639534937a6e4d3322"
SUM_REFIND="sha256"

if [ "$ARCH" = x86_64 -a \
     $part_type = gpt -a \
     ! -d "$HERE/../boot/$DIR_REFIND" ]; then
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

if [ "$ARCH" = x86_64 ]; then
  tmp="$(mktemp)"
  dd if=/dev/zero "of=$tmp" bs=1024 "seek=$((512 * 1024))" count=0
  mkfs.vfat -F 32 "$tmp"
  if [ $part_type = gpt ]; then
    mcopy -i "$tmp" -s "$HERE/../boot/$DIR_REFIND/refind" ::
    mdel -i "$tmp" ::/refind/refind{{_ia32,_aa64}.efi,.conf-sample}
    mdeltree -i "$tmp" ::/refind/{drivers_{ia32,x64,aa64},tools_{ia32,x64,aa64}}
    if [ -n "$HEDDLE_EXT_DIR" -a -e "$HEDDLE_EXT_DIR/boot/refind.conf" ]; then
      mcopy -i "$tmp" "$HEDDLE_EXT_DIR/boot/refind.conf" ::/refind
    else
      mcopy -i "$tmp" "$HERE/../boot/refind.conf" ::/refind
    fi
    mmd -i "$tmp" ::/EFI
    mmove -i "$tmp" ::/refind ::/EFI/BOOT
    mmove -i "$tmp" ::/EFI/BOOT/{refind_,boot}x64.efi 
  else
    syslinux "$tmp"
    if [ -n "$HEDDLE_EXT_DIR" -a -e "$HEDDLE_EXT_DIR/boot/syslinux.cfg" ]; then
      mcopy -i "$tmp" "$HEDDLE_EXT_DIR/boot/syslinux.cfg" ::
    else
      mcopy -i "$tmp" "$HERE/../boot/syslinux.cfg" ::
    fi
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
fi

copy() {
  local p=400
  if [ -x "$1" ]; then p=500; fi
  e2cp -P $p -O 0 -G 0 "$1" "$IMG_RUN:$2"
}

ext_packages=
ext_xroot=
if [ -n "$HEDDLE_EXT_DIR" ]; then
  [ -e "$HEDDLE_EXT_DIR/image_scripts/packages" ] && ext_packages="$HEDDLE_EXT_DIR/image_scripts/packages"
  [ -d "$HEDDLE_EXT_DIR/xroot" ] && ext_xroot="-C $HEDDLE_EXT_DIR/xroot ."
fi

(cat "$HERE/packages" $ext_packages) | copy - packages
copy "$HERE/../runtime_scripts/run.sh" init
copy "$HERE/../runtime_scripts/common.sh"

(tar --owner root --group root -zc -C "$HERE/../xroot" . -C "$PWD" $ext_xroot) | copy - xroot.tar.gz

#/bin/bash
set -e
HERE="$(dirname "$0")"

part_type=gpt
img_file=heddle.img
img_specified=0
append=
while getopts mqa:i: opt
do
  case $opt in
    m)
      part_type=msdos
      ;;
    q)
      img_file=heddle.qcow2
      ;;
    a)
      append="$OPTARG"
      ;;
    i)
      img_file="$OPTARG"
      img_specified=1
      ;;
  esac
done
shift $((OPTIND-1))

ARCH="${1:-x86_64}"
IMG_DIR="${HEDDLE_EXT_DIR:-"$HERE/.."}/gen/$ARCH/images"

if [ "$ARCH" = x86_64 ]; then
  CMD="qemu-system-x86_64 -enable-kvm -m 2048 -cpu host -smp 2"
  if [ $part_type = gpt ]; then
    CMD+=" -bios /usr/share/ovmf/OVMF.fd"
  fi
else
  CMD="qemu-system-arm -m 256 -M versatilepb -cpu arm1136-r2 -kernel $IMG_DIR/boot.kbin"
fi

if [ $img_specified -eq 0 ]; then
  img_file="$IMG_DIR/$img_file"
fi

$CMD -no-reboot -hda "$img_file" -net user,hostname=heddle -net nic

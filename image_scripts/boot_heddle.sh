#/bin/bash
set -e
HERE="$(dirname "$0")"

img_file=heddle.img
img_specified=0
append=
while getopts mqa:i: opt
do
  case $opt in
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

if [ $img_specified -eq 0 ]; then
  if [ -e "$HERE/$img_file" ]; then
    IMG_DIR="$HERE"
  else
    IMG_DIR="${HEDDLE_EXT_DIR:-"$HERE/.."}/gen/$ARCH/images"
  fi
  img_file="$IMG_DIR/$img_file"
else
  IMG_DIR="$(dirname "$img_file")"
fi

if [ "$ARCH" = x86_64 ]; then
  CMD="qemu-system-x86_64 -enable-kvm -m 2048 -cpu host -smp 2"
  if file -kL "$img_file" | grep -q 'GPT partition table'; then
    CMD+=" -bios /usr/share/ovmf/OVMF.fd"
  fi
else
  CMD="qemu-system-arm -m 256 -M versatilepb -cpu arm1136-r2 -kernel $IMG_DIR/boot.kbin"
fi

echo "Booting: $img_file"
$CMD -no-reboot -hda "$img_file" -net user,hostname=heddle -net nic

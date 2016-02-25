#/bin/bash
set -e
HERE="$(dirname "$0")"
if [ -n "$HEDDLE_EXT_DIR" ]; then
  project="$(cd "$HEDDLE_EXT_DIR"; basename "$PWD")"
else
  project=heddle
fi

img_file=heddle.img
img_specified=0
hostname=
while getopts qi:h: opt
do
  case $opt in
    q)
      img_file=heddle.qcow2
      ;;
    i)
      img_file="$OPTARG"
      img_specified=1
      ;;
    h)
      hostname="$OPTARG"
      ;;
  esac
done
shift $((OPTIND-1))

ARCH=x86_64
if [ $# -ge 1 ]; then
  ARCH="$1"
  shift
fi

if [ $img_specified -eq 0 ]; then
  img_file2="$(basename "$0")"
  img_file2="${img_file2#boot_}"
  img_file2="${img_file2%.sh}.img"
  if [ -e "$HERE/$img_file2" ]; then
    IMG_DIR="$HERE"
    img_file="$img_file2"
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
  CMD="qemu-system-arm -m 256 -M versatilepb -kernel $IMG_DIR/boot.kbin"
fi

echo "Booting: $img_file"
$CMD -no-reboot -hda "$img_file" -net user,hostname=${hostname:-$project} -net nic "$@"

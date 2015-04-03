#/bin/bash
set -e
HERE="$(dirname "$0")"

part_type=gpt
img_file=heddle.img
ARCH=x86_64
while getopts mqa: opt
do
  case $opt in
    m)
      part_type=msdos
      ;;
    q)
      img_file=heddle.qcow2
      ;;
    a)
      ARCH="$OPTARG"
      ;;
  esac
done
shift $((OPTIND-1))

IMG_DIR="${HEDDLE_EXT_DIR:-"$HERE/.."}/gen/$ARCH/images"
UPDATE_DIR="${HEDDLE_EXT_DIR:-"$HERE/.."}/gen/$ARCH/dist/update"

if [ "$ARCH" = x86_64 ]; then
  CMD="qemu-system-x86_64 -enable-kvm -m 2048 -cpu host -smp 2"
  if [ $part_type = gpt ]; then
    CMD+=" -bios /usr/share/ovmf/OVMF.fd"
  fi
else
  CMD="qemu-system-arm -M versatilepb -cpu arm1136-r2 -kernel $UPDATE_DIR/barebox"
fi

$CMD -no-reboot -hda "$IMG_DIR/$img_file" -net user,hostname=heddle -net nic "$@"

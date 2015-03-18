#/bin/bash
set -e
HERE="$(dirname "$0")"

extra_args=
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

if [ $part_type = gpt ]; then
  extra_args+=" -bios /usr/share/ovmf/OVMF.fd"
fi

IMG_DIR="${HEDDLE_EXT_DIR:-"$HERE/.."}/gen/$ARCH/images"
kvm -m 2048 -cpu host -smp 2 -no-reboot -hda "$IMG_DIR/$img_file" -net user,hostname=heddle -net nic $extra_args "$@"

#/bin/bash
set -e
IMG_DIR="$(dirname "$0")/../images"

extra_args=
part_type=gpt
img_file=heddle.img
while getopts mq opt
do
  case $opt in
    m)
      part_type=msdos
      ;;
    q)
      img_file=heddle.qcow2
      ;;
  esac
done
shift $((OPTIND-1))

if [ $part_type = gpt ]; then
  extra_args+=" -bios /usr/share/ovmf/OVMF.fd"
fi

kvm -m 2048 -cpu host -smp 2 -no-reboot -hda "$IMG_DIR/$img_file" $extra_args "$@"
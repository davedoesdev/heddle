#/bin/bash
IMG_DIR="$(dirname "$0")/../images"

extra_args=
part_type=gpt
while getopts m opt
do
  case $opt in
    m)
      part_type=msdos
      ;;
  esac
done

if [ $part_type = gpt ]; then
  extra_args+=" -bios /usr/share/ovmf/OVMF.fd"
fi

kvm -m 2048 -cpu host -smp 2 -no-reboot -hda "$IMG_DIR/heddle.img" $extra_args

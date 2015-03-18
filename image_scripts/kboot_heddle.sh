#/bin/bash
HERE="$(dirname "$0")"

ARCH=x86_64
while getopts a: opt
do
  case $opt in
    a)
      ARCH="$OPTARG"
      ;;
  esac
done
shift $((OPTIND-1))

IMG_DIR="${HEDDLE_EXT_DIR:-"$HERE/.."}/gen/$ARCH/images"
UPDATE_DIR="${HEDDLE_EXT_DIR:-"$HERE/.."}/gen/$ARCH/dist/update"
kvm -m 2048 -cpu host -smp 2 -no-reboot -kernel "$UPDATE_DIR/linux" -initrd "$UPDATE_DIR/initrd.img" -hda "$IMG_DIR/heddle.img" -append "console=ttyS0,9600n8 console=tty0 $*" -net user,hostname=heddle -net nic
# vga=0xF07" -usb -usbdevice serial::vc -usbdevice keyboard -usbdevice "disk:$IMG_DIR/heddle.img"

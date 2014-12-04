#/bin/bash
IMG_DIR="$(dirname "$0")/../images"
kvm -no-reboot -kernel "build/system-image-${1:-x86_64}/bzImage" -hda "$IMG_DIR/heddle.img" -append "root=/dev/hda rw init=/dist/init.sh console=ttyUSB0,9600n8 console=tty0" -usb -usbdevice serial::vc

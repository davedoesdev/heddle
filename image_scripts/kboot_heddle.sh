#/bin/bash
IMG_DIR="$(dirname "$0")/../images"
kvm -m 2048 -cpu host -smp 2 -no-reboot -kernel "build/system-image-${1:-x86_64}/bzImage" -initrd "$IMG_DIR/initrd.img" -hda "$IMG_DIR/heddle.img" -append "console=ttyS0,9600n8 console=tty0"
# vga=0xF07" -usb -usbdevice serial::vc -usbdevice keyboard

#/bin/bash
HERE="$(dirname "$0")"
IMG_DIR="$HERE/../images"
UPDATE_DIR="$HERE/../dist/update"
kvm -m 2048 -cpu host -smp 2 -no-reboot -kernel "build/system-image-${1:-x86_64}/bzImage" -initrd "$UPDATE_DIR/initrd.img" -hda "$IMG_DIR/heddle.img" -append "console=ttyS0,9600n8 console=tty0" -net user,hostname=heddle -net nic
# vga=0xF07" -usb -usbdevice serial::vc -usbdevice keyboard -usbdevice "disk:$IMG_DIR/heddle.img"

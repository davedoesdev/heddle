#/bin/bash
IMG_DIR="$(dirname "$0")/../images"
kvm -nographic -no-reboot -kernel "build/system-image-${1:-x86_64}/bzImage" -hda "$IMG_DIR/heddle.img" -append "root=/dev/hda rw init=/dist/init.sh console=ttyS0"


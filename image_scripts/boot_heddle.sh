#/bin/bash
IMG_DIR="$(dirname "$0")/../images"
kvm -m 2048 -cpu host -smp 2 -no-reboot -hda "$IMG_DIR/heddle.img" -bios /usr/share/ovmf/OVMF.fd

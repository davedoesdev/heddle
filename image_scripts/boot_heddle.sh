#/bin/bash
IMG_DIR="$(dirname "$0")/../images"
kvm -m 2048 -no-reboot -hda "$IMG_DIR/heddle.img"

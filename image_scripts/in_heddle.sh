#!/bin/bash
set -e
HERE="$(dirname "$0")"

img_file=heddle.img
img_specified=0
append=
while getopts qa:i: opt
do
  case $opt in
    q)
      img_file=heddle.qcow2
      ;;
    a)
      append="$OPTARG"
      ;;
    i)
      img_file="$OPTARG"
      img_specified=1
      ;;
  esac
done
shift $((OPTIND-1))

ARCH=x86_64
if [ $# -ge 1 ]; then
  ARCH="$1"
  shift
fi

if [ $img_specified -eq 0 ]; then
  if [ -e "$HERE/$img_file" ]; then
    IMG_DIR="$HERE"
    UPDATE_DIR="$IMG_DIR/update"
  else
    IMG_DIR="${HEDDLE_EXT_DIR:-"$HERE/.."}/gen/$ARCH/images"
    UPDATE_DIR="${HEDDLE_EXT_DIR:-"$HERE/.."}/gen/$ARCH/dist/update"
  fi
  img_file="$IMG_DIR/$img_file"
else
  IMG_DIR="$(dirname "$img_file")"
  UPDATE_DIR="$IMG_DIR/update"
fi

if [ "$ARCH" = x86_64 ]; then
  CMD="qemu-system-x86_64 -enable-kvm -m 2048 -cpu host -smp 2"
  CON=ttyS0
else
  CMD="qemu-system-arm -m 256 -M versatilepb -cpu arm1136-r2"
  CON=ttyAMA0
fi

qemu() {
  echo "Booting: $img_file"
  $CMD -no-reboot -kernel "$UPDATE_DIR/linux" -initrd "$UPDATE_DIR/initrd.img" -hda "$img_file" -append "console=$CON,9600n8 console=tty0 $append" -net user,hostname=heddle -net nic "$@"
  # vga=0xF07" -usb -usbdevice serial::vc -usbdevice keyboard -usbdevice "disk:$IMG_DIR/heddle.img"
}

if [ -t 0 ]; then
  qemu "$@"
else
  user="$(head -n 1)"
  append+=" heddle_serial_user=$user heddle_serial_prompt=in_heddle\n"

  tmpp="$(mktemp)"
  tmpc="$(mktemp)"

  (
  while [ -f "$tmpp" ]; do sleep 1; done
  head -n 1
  while [ -f "$tmpc" ]; do sleep 1; done
  cat
  echo reboot
  ) | qemu -nographic "$@" | (
  IFS=''
  delp=0
  delc=0
  while read -r data; do
    data="$(echo "$data" | perl -pe 's/\e\[?.*?[\@-~]//g')"
    if [ "$data" = "login: $user (automatic login)"$'\r' ]; then
      if [ $delp -eq 0 ]; then rm -f "$tmpp"; delp=1; fi
      echo "$data"
    elif [ "$data" = $'in_heddle\r' ]; then
      if [ $delc -eq 0 ]; then rm -f "$tmpc"; delc=1; fi
      echo -n '$ '
    else
      echo "$data"
    fi
  done
  )
fi

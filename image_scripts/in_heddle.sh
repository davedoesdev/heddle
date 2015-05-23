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
  img_file2="$(basename "$0")"
  img_file2="${img_file2#in_}"
  img_file2="${img_file2%.sh}.img"
  if [ -e "$HERE/$img_file2" ]; then
    IMG_DIR="$HERE"
    img_file="$img_file2"
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
  CMD="qemu-system-arm -m 256 -M versatilepb"
  CON=ttyAMA0
fi

extra=
if [ ! -t 0 ]; then
  user="$(python -u -c 'import sys; sys.stdout.write(sys.stdin.readline())')"
  append+=" heddle_serial_user=$user heddle_serial_prompt=in_heddle\n"
  extra=-nographic
fi
extra+=" $@"

tmp="$(mktemp)"
chmod +x "$tmp"
cat >> "$tmp" << EOF
#!/bin/bash
echo Booting: $img_file
$CMD -no-reboot -kernel "$UPDATE_DIR/linux" -initrd "$UPDATE_DIR/initrd.img" -hda "$img_file" -append "console=$CON,9600n8 console=tty0 $append" -net user,hostname=heddle -net nic $extra
EOF
# vga=0xF07 -usb -usbdevice serial::vc -usbdevice keyboard -usbdevice "disk:$IMG_DIR/heddle.img"

if [ -t 0 ]; then
  "$tmp"
else
  socat "EXEC:$HERE/_in_heddle.sh $user" "EXEC:$tmp" 3<&0 4>&1 | (
  IFS=''
  while read -r data; do
    if [[ "$data" == heddle_status:* ]]; then
      status="${data#heddle_status:}"
      status="${status%$'\r'}"
    else
      echo "$data"
    fi
  done
  exit $status
  )
fi

status=$?
rm -f "$tmp"
exit $status

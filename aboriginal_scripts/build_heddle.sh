#!/bin/bash
set -e

chroot_build=
while getopts c opt
do
  case $opt in
    c)
      chroot_build=1
      ;;
  esac
done
shift $((OPTIND-1))

HERE="$(cd "$(dirname "$0")"; echo "$PWD")"
export HDB="${HEDDLE_EXT_DIR:-"$HERE/.."}/images/home.img"
export HDC="${HEDDLE_EXT_DIR:-"$HERE/.."}/images/build.img"
export QEMU_MEMORY=2048

ROOT_DIR="$PWD/build/root-filesystem-${1:-x86_64}"
OVERLAY_DIR="$PWD/build/native-compiler-${1:-x86_64}"
cd "build/system-image-${1:-x86_64}"

e2extract() {
  e2ls -l "$1:$3" | while read -r l; do
    if [ -n "$l" ]; then
      f="$(echo "$l" | awk '{print $NF}')"
      if [ "$f" != lost+found ]; then
        m="$(echo "$l" | awk '{print substr($2, length($2)-4, 1)}')"
        if [ "$m" = 4 ]; then
          mkdir "$2$3/$f"
          e2extract "$1" "$2" "$3/$f"
        else
          e2cp "$1:$3/$f" "$2$3/$f"
        fi
        p="$(echo "$l" | awk '{print substr($2, length($2)-2)}')"
        chmod "$p" "$2$3/$f"
      fi
    fi
  done
}

if [ -n "$chroot_build" ]; then
  echo "chroot build" | tee /dev/tty
  mkdir /tmp/chroot home mnt tmp
  e2extract "$HDB" home
  e2extract "$HDC" mnt
  cp -r --remove-destination "$OVERLAY_DIR/." "$ROOT_DIR"
  sudo mount -o bind "$ROOT_DIR" /tmp/chroot
  sudo mount -o remount,ro /tmp/chroot
  sudo mount -o bind home /tmp/chroot/home
  sudo mount -o bind mnt /tmp/chroot/mnt
  sudo mount -o remount,ro /tmp/chroot/mnt
  sudo mount -o bind tmp /tmp/chroot/tmp # don't use memory for tmpfs
  sudo mount -o rbind /proc /tmp/chroot/proc
  sudo mount -o rbind /sys /tmp/chroot/sys
  sudo mount -o rbind /dev /tmp/chroot/dev
  sudo chroot /tmp/chroot /bin/ash << 'EOF'
set -e
export HOME=/home
export PATH
cd "$HOME"
touch /tmp/in_chroot
exec /mnt/init
EOF
  sudo tar --owner root --group root -Jc home/{install,chroot} | e2cp -P 400 -O 0 -G 0 - "$HDB:home.tar.xz"
else
  echo "qemu-kvm build" | tee /dev/tty
  exec ./dev-environment.sh
fi

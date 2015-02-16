#!/bin/bash
set -e

uml=
chroot=
while getopts uc opt
do
  case $opt in
    u)
      uml=1
      ;;
    c)
      chroot=1
      ;;
  esac
done
shift $((OPTIND-1))

HERE="$(cd "$(dirname "$0")"; echo "$PWD")"
export HDB="${HEDDLE_EXT_DIR:-"$HERE/.."}/images/home.img"
export HDC="${HEDDLE_EXT_DIR:-"$HERE/.."}/images/build.img"
export QEMU_MEMORY=2048

ROOT_DIR="$PWD/build/root-filesystem-${1:-x86_64}"
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

if [ -n "$uml" ]; then
  cat > "$ROOT_DIR/init.uml" << 'EOF'
#!/bin/ash
mount -t proc proc /proc
mount -t tmpfs tmp /tmp
mkdir /tmp/root
if [ -b /dev/ubda ]; then
  mount /dev/ubda /tmp/root
  mount -t devtmpfs dev /tmp/root/dev
else
  mknod /tmp/ubda b 98 0
  mount /tmp/ubda /tmp/root
  mkdir /tmp/dev
  mknod /tmp/dev/ttyS0 c 4 64
  mknod /tmp/dev/urandom c 1 9
  mknod /tmp/dev/null c 1 3
  mount -o bind /tmp/dev /tmp/root/dev
fi
mknod /tmp/root/dev/hdb b 98 16
mknod /tmp/root/dev/hdc b 98 32
exec /usr/sbin/chroot /tmp/root ash -c 'exec /sbin/init.sh < /dev/ttyS0 > /dev/ttyS0 2>&1'
EOF
  chmod +x "$ROOT_DIR/init.uml"
  exec linux.uml "ubd0=hda.sqf" "ubd1=$HDB" "ubd2=$HDC" "hostfs=$ROOT_DIR" rootfstype=hostfs init=/init.uml mem="${QEMU_MEMORY}M" con0=fd:3,fd:4 ssl0=fd:0,fd:1 console=ttyS0 "HOST=${1:-x86_64}" eth0=slirp 3>/dev/null 4>&1
elif [ -n "$chroot" ]; then
  mkdir /tmp/chroot home mnt tmp
  e2extract "$HDB" home
  e2extract "$HDC" mnt
  sudo mount -o bind "$ROOT_DIR" /tmp/chroot
  sudo mount -o remount,ro /tmp/chroot
  sudo mount -o bind home /tmp/chroot/home
  sudo mount -o bind mnt /tmp/chroot/mnt
  sudo mount -o remount,ro /tmp/chroot/mnt
  sudo mount -o rbind tmp /tmp/chroot/tmp # don't use memory for tmpfs
  sudo mount -o rbind /proc /tmp/chroot/proc
  sudo mount -o rbind /sys /tmp/chroot/sys
  sudo mount -o rbind /dev /tmp/chroot/dev
  # CI environments give permission denied when bind mount /dev directory
  #mkdir /tmp/dev
  #touch /tmp/dev/{urandom,null}
  #sudo mount -o bind /dev/urandom /tmp/dev/urandom
  #sudo mount -o bind /dev/null /tmp/dev/null
  #sudo mount -o bind /tmp/dev /tmp/chroot/dev
  exec sudo chroot /tmp/chroot /bin/ash << 'EOF'
set -e
export HOME=/home
export PATH
cd "$HOME"
exec /mnt/init
EOF
else
  exec ./dev-environment.sh
fi

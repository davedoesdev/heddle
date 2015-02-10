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
  mknod /tmp/dev/ubdb b 98 16
  mknod /tmp/dev/ubdc b 98 32
  mknod /tmp/dev/ttyS0 c 4 64
  mknod /tmp/dev/urandom c 1 9
  mknod /tmp/dev/null c 1 3
  mount -o bind /tmp/dev /tmp/root/dev
fi
ln -s ubdb /tmp/root/dev/hdb
ln -s ubdc /tmp/root/dev/hdc
exec /usr/sbin/chroot /tmp/root ash -c 'exec /sbin/init.sh < /dev/ttyS0 > /dev/ttyS0 2>&1'
EOF
  chmod +x "$ROOT_DIR/init.uml"
  linux.uml ubd0=hda.sqf "ubd1=$HDB" "ubd2=$HDC" "hostfs=$ROOT_DIR" rootfstype=hostfs init=/init.uml mem="${QEMU_MEMORY}M" con0=fd:3,fd:4 ssl0=fd:0,fd:1 console=ttyS0 "HOST=${1:-x86_64}" eth0=slirp 3>/dev/null 4>&1
elif [ -n "$chroot" ]; then
  mkdir /tmp/chroot
  guestmount -a hda.sqf -m /dev/hda --ro /tmp/chroot
  sudo mount -t tmpfs tmp /tmp/chroot/tmp
  guestmount -a "$HDB" -m /dev/hdb /tmp/chroot/home
  guestmount -a "$HDC" -m /dev/hdc --ro /tmp/chroot/mnt
  sudo chroot /tmp/chroot /sbin/init.sh << 'EOF'
/mnt/init
EOF
else
  ./dev-environment.sh
fi

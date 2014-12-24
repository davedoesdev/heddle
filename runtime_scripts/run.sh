#!/bin/bash
set -e
if [ ! -h /dev/fd ]; then
  ln -s /proc/self/fd /dev
fi
HERE="$(dirname "$0")"
. "$HERE/common.sh"

. "$HERE/packages"
for pkg in "${PACKAGES[@]}"; do
  if type PST_$pkg 2> /dev/null | grep -q function; then
    PST_$pkg
  fi
done

export THE_PATH="$PATH"
export THE_LD_LIBRARY_PATH="$LD_LIBRARY_PATH"
if [ ! -d /home/root ]; then
  mkdir /home/root
  echo 'export PATH="$THE_PATH"' > /home/root/.profile
  echo 'export LD_LIBRARY_PATH="$THE_LD_LIBRARY_PATH"' >> /home/root/.profile
fi

mkdir -p /home/heddle

if [ -b /dev/[hsv]dd2 -a "$(cat /proc/swaps | wc -l)" -eq 1 ]; then
  swapon /dev/[hsv]dd2
fi

dev="$(echo /dev/[hsv]dd3)"
if [ -b "$dev" ] && ! mount | grep -q "/extra/docker "; then
  cat <<EOF | parted ---pretend-input-tty "${dev%3}" resizepart 3 100%
fix
3
100%
EOF
  parted "${dev%3}" print
  fsck -fy "$dev" || if [ $? -ne 1 ]; then exit $?; fi
  chroot "$CHROOT_DIR" mount "$dev" /extra
  resize2fs "$dev" || chroot "$CHROOT_DIR" btrfs filesystem resize max /extra
fi

chroot "$CHROOT_DIR" cgroupfs-mount

exec chroot "$CHROOT_DIR" /startup/runsvdir


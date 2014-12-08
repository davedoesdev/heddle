#!/bin/bash
set -e
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

if [ -b /dev/[hsv]dd3 ] && ! mount | grep -q "/extra/docker "; then
  ( e2fsck -fy /dev/[hsv]dd3 2>&1 || echo "e2fsck failed: $?" ) | tee "$CHROOT_DIR/var/log/e2fsck-startup.log"
  resize2fs /dev/[hsv]dd3
  chroot "$CHROOT_DIR" mount /dev/[hsv]dd3 /extra
else
  rm -f "$CHROOT_DIR/var/log/e2fsck-startup.log"
fi

chroot "$CHROOT_DIR" cgroupfs-mount

exec chroot "$CHROOT_DIR" /startup/runsvdir >& "$CHROOT_DIR/var/log/runsvdir-startup.log"


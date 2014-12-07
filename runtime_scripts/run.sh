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

if [ -b /dev/[hsv]dd2 ] && ! mount | grep -q "/extra/docker "; then
  resize2fs /dev/[hsv]dd2
  chroot "$CHROOT_DIR" mount /dev/[hsv]dd2 /extra
fi

chroot "$CHROOT_DIR" cgroupfs-mount

exec chroot "$CHROOT_DIR" /startup/runsvdir >& "$CHROOT_DIR/var/log/runsvdir-startup.log"


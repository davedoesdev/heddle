#!/bin/bash
set -e
if [ ! -h /dev/fd ]; then
  ln -s /proc/self/fd /dev
fi
if [ -f /home/home.tar.xz ]; then
  ls -l /home/home.tar.xz
  tar -C / -Jxf /home/home.tar.xz
  df
  rm -f /home/home.tar.xz
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

if [ -z "$root_part" ]; then
  dev="$(echo /dev/[hsv]dd)"
  swapon "${dev}2"
  cat <<EOF | parted ---pretend-input-tty "$dev" resizepart 3 100%
fix
3
100%
EOF
  parted "$dev" print
  fsck -fy "${dev}3" || if [ $? -ne 1 ]; then exit $?; fi
  chroot "$CHROOT_DIR" mount "${dev}3" /extra
  resize2fs "${dev}3" || chroot "$CHROOT_DIR" btrfs filesystem resize max /extra
fi

chroot "$CHROOT_DIR" cgroupfs-mount

rm -rf "$CHROOT_DIR/service"/*/supervise
chroot "$CHROOT_DIR" /startup/start_runsvdir

(
echo 'Syncing'
sync

echo 'Re-mounting drives read-only'
if [ -z "$root_part" ]; then
  dev="$(echo /dev/[hsv]dd)"
  mount -o remount,ro "${dev}3" || true
  mount -o remount,ro /dev/[hsv]db
  swapoff "${dev}2" || true
else
  mount -o remount,ro "$root_part"
  swapoff "${root_part%3}2"
fi

cmd="$(head -n 1 /tmp/heddle_is_shutting_down)"
echo "Operation: $cmd"
if [ "$cmd" = poweroff ]; then
  poweroff
else
  reboot
fi
) 2>&1 | awk '{print "<0>" $0}' > /dev/kmsg


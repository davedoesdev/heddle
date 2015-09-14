#!/bin/bash
set -e
if [ ! -h /dev/fd ]; then
  ln -s /proc/self/fd /dev
fi
if [ -f /home/home.tar.gz ]; then
  ls -l /home/home.tar.gz
  tar -C / -zxf /home/home.tar.gz home
  df
  rm -f /home/home.tar.gz
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
fi

if [ ! -f "$CHROOT_DIR/etc/profile" ]; then
  cat > "$CHROOT_DIR/etc/profile" << 'EOF'
if [ -n "$THE_PATH" ]; then
  export PATH="$THE_PATH"
fi
if [ -n "$THE_LD_LIBRARY_PATH" ]; then
  export LD_LIBRARY_PATH="$THE_LD_LIBRARY_PATH"
  export LIBRARY_PATH="$THE_LD_LIBRARY_PATH"
fi
if [ "$(/usr/bin/id -u)" -ne 0 ]; then
  umask 027
fi
EOF
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

if [ -c /dev/kvm ]; then
  chroot "$CHROOT_DIR" chgrp kvm /dev/kvm
  chmod g+rw /dev/kvm
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
  mount -o remount,ro /dev/[hsv]db || true
  swapoff "${dev}2" || true
else
  mount -o remount,ro "$root_part" || true
  swapoff "${root_part%3}2" || true
fi

cmd="$(head -n 1 /tmp/heddle_is_shutting_down)"
echo "Operation: $cmd"
if [ "$cmd" = poweroff ]; then
  poweroff
else
  reboot
fi
) 2>&1 | awk '{print "<0>" $0}' > /dev/kmsg


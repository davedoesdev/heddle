#!/bin/hush

export PATH=/bin:/sbin

# Mount filesystems
mountpoint -q proc || mount -t proc proc proc
mountpoint -q sys || mount -t sysfs sys sys
mountpoint -q dev || mount -t devtmpfs dev dev
mkdir -p dev/pts
mountpoint -q dev/pts || mount -t devpts dev/pts dev/pts
mount -t tmpfs /tmp /tmp

[ -z "$CONSOLE" ] &&
  CONSOLE="$(sed -n 's@.* console=\(/dev/\)*\([^ ]*\).*@\2@p' /proc/cmdline)"
[ -z "$CONSOLE" ] && CONSOLE=console

# Load coldplug kernel modules
grep -h MODALIAS /sys/bus/*/devices/*/uevent 2>/dev/null | cut -d = -f 2 | sort -u | xargs /home/install/sbin/modprobe -abq

exec /sbin/oneit -c /dev/"$CONSOLE" /home/run/init

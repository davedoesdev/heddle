#!/bin/ash

export HOME=/home

# Populate /dev
mountpoint -q proc || mount -t proc proc proc
mountpoint -q sys || mount -t sysfs sys sys
mountpoint -q dev || mount -t devtmpfs dev dev || mdev -s
mkdir -p dev/pts
mountpoint -q dev/pts || mount -t devpts dev/pts dev/pts

#export PS1='$HOST \w \$ '

# Make sure $PATH is exported, even if not set on kernel command line.
# (The shell gives us a default, but it's local, not exported.)
export PATH

# TODO: network setup and date
#  # If we have no RTC, try rdate instead:
#  [ "$(date +%s)" -lt 1000 ] && rdate 10.0.2.2 # or time-b.nist.gov

mount -t tmpfs /tmp /tmp

cd "$HOME"

[ -z "$CONSOLE" ] &&
  CONSOLE="$(sed -n 's@.* console=\(/dev/\)*\([^ ]*\).*@\2@p' /proc/cmdline)"
[ -z "$CONSOLE" ] && CONSOLE=console

exec /sbin/oneit -c /dev/"$CONSOLE" "$HOME/run/init"

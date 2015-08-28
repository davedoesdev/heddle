#!/bin/bash
set -e
HERE="$(dirname "$0")"

if [ $# -ne 1 ]; then
  echo "usage: $0 <chroot-dir>" 1>&2
  exit 1
fi

if [ -e "$1" ]; then
  rm -rf "$1"/{service,startup}
  tar -C "$1" -xf "$HERE/chroot.tar.gz" ./service ./startup ./var/log
else
  mkdir -p "$1"
  tar -C "$1" -xf "$HERE/chroot.tar.gz"
fi

# make sure chroot is a mount point
cd "$1"
if ! mount | grep -q "$1 "; then
  mount -o rbind . .
fi

for x in /*; do
  if [ -f "$x" ]; then
    continue
  fi
  d="$1$x"
  if [ ! -e "$d" ]; then
    mkdir -p "$d"
  fi
  if [ "$x" = /etc ]; then
    for y in "$x"/*; do
      d="$1$y";
      if [ -d "$y" ]; then
        mkdir -p "$d"
        if [ "$y" != /etc/default ] && ! mount | grep -q "$d "; then
          mount -o rbind "$y" "$d"
        fi
      elif [ ! -e "$d" ]; then
        cp "$y" "$d"
      fi
    done
  elif ! mount | grep -q "$d "; then
    mount -o rbind "$x" "$d"
  fi
done

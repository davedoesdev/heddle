#!/bin/bash
set -e
HERE="$(dirname "$0")"

if [ $# -ne 1 ]; then
  echo "usage: $0 <chroot-dir>" 1>&2
  exit 1
fi

if [ ! -e "$1" ]; then
  mkdir -p "$1"
  tar -C "$1" -xf "$HERE/chroot.tar.gz"
fi

for x in /*; do
  d="$1$x"
  if [ ! -e "$d" ]; then
    mkdir -p "$d"
  fi
  if [ "$x" = /etc ]; then
    for y in "$x"/*; do
      d="$1$y";
      if [ ! -e "$d" ]; then
        if [ -f "$y" ]; then
          touch "$d"
        else
          mkdir -p "$d"
        fi
      fi
      if ! mount | grep -q "$d "; then
        mount -o bind "$y" "$d"
      fi
    done
  else
    if ! mount | grep -q "$d "; then
      mount -o bind "$x" "$d"
    fi
  fi
done

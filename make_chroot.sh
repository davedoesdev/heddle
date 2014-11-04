#!/bin/bash
for x in /*; do
  d="$HOME/chroot$x"
  if [ ! -e "$d" ]; then
    mkdir -p "$d"
  fi
  if [ "$x" = /etc ]; then
    for y in "$x"/*; do
      d="$HOME/chroot$y";
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

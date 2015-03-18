#!/bin/bash
# copy files from /etc in home.img to chroot
set -e
cd "$(dirname "$0")"
ARCH="${1:-x86_64}"
IMG_HOME="../gen/$ARCH/images/home.img"

if [ $# -eq 0 ]; then
  files=( passwd shadow group gshadow login.defs )
else
  files=( "$@" )
fi

for f in "${files[@]}"; do
  src="$IMG_HOME:chroot/etc/$f"
  if e2ls "$src" >& /dev/null; then
    dest="../chroot/etc/$f"
    rm -f "$dest"
    e2cp "$src" "$dest"
    p="$(e2ls -l "$src" | awk '{print substr($2, length($2)-2)}')"
    chmod "$p" "$dest"
    ls -l "$dest"
  fi
done

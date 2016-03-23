#!/bin/bash
# copy files from /etc in home.img to xroot
set -e
HERE="$(cd "$(dirname "$0")"; echo "$PWD")"

ARCH=x86_64
if [ $# -ge 1 ]; then
  ARCH="$1"
  shift
fi

IMG_HOME="${HEDDLE_EXT_DIR:-"$HERE/.."}/gen/$ARCH/images/home.img"
DEST_DIR="${HEDDLE_EXT_DIR:-"$HERE/.."}/xroot/etc"
mkdir -p "$DEST_DIR"

if [ $# -eq 0 ]; then
  files=( passwd shadow group gshadow login.defs )
else
  files=( "$@" )
fi

for f in "${files[@]}"; do
  src="$IMG_HOME:xroot/etc/$f"
  if e2ls "$src" >& /dev/null; then
    dest="$DEST_DIR/$f"
    rm -f "$dest"
    e2cp "$src" "$dest"
    p="$(e2ls -l "$src" | awk '{print substr($2, length($2)-2)}')"
    chmod "$p" "$dest"
    ls -l "$dest"
  fi
done

#!/bin/bash
# make build.img, download packages and copy build.sh into it as /init
set -e
cd "$(dirname "$0")"
IMG_HOME=../images/home.img
IMG_BUILD=../images/build.img

if [ ! -e "$IMG_HOME" ]; then
  dd if=/dev/zero "of=$IMG_HOME" bs=1024 "seek=$((4 * 1024 * 1024))" count=0
  mke2fs -t ext4 "$IMG_HOME"
fi

if [ ! -e "$IMG_BUILD" ]; then
  dd if=/dev/zero "of=$IMG_BUILD" bs=1024 "seek=$((1 * 1024 * 1024))" count=0
  mke2fs "$IMG_BUILD"
fi

copy() {
  local p=400
  if [ -x "$1" ]; then p=500; fi
  e2cp -P $p -O 0 -G 0 "$1" "$IMG_BUILD:$2"
}

copy packages
copy ../runtime_scripts/build.sh init
copy ../runtime_scripts/common.sh
copy ../runtime_scripts/make_chroot.sh

(cd ../chroot; tar --owner root --group root -zc *) | copy - chroot.tar.gz
(cd ../supplemental; tar --owner root --group root -zc *) | copy - supplemental.tar.gz

. ./packages
e2mkdir "$IMG_BUILD:download"

for pkg in "${PACKAGES[@]}"; do
  vsrc="SRC_$pkg"
  vurl="URL_$pkg"
  vchk="CHK_$pkg"
  vsum="SUM_$pkg"
  dest="$IMG_BUILD:download/${!vsrc}"
  if ! e2ls "$dest" >& /dev/null; then
    if type GET_$pkg 2> /dev/null | grep -q function; then
      tmpd="$(mktemp -d)"
      ( cd "$tmpd"; GET_$pkg ) | copy - "download/${!vsrc}"
      rm -rf "$tmpd"
    else
      wget "${!vurl}" -O - | copy - "download/${!vsrc}"
      sum="$(e2cp "$dest" - | "${!vsum}sum" | awk '{print $1}')"
      if [ "$sum" != "${!vchk}" ]; then
        e2rm "$dest"
        echo "$0: checksum mismatch for $pkg: $sum != ${!vchk}" 1>&2
        exit 1
      fi
    fi
  fi
  if [ "$(e2ls -l "$dest" | awk '{print $5}')" -eq 0 ]; then
    e2rm "$dest"
    echo "$0: $pkg is empty"
    exit 2
  fi
done

e2ls -l "$IMG_BUILD:download" | awk '{if (NF > 0) print $NF}' | while read f; do
  found=0
  for pkg in "${PACKAGES[@]}"; do
    vsrc="SRC_$pkg"
    if [ "$f" = "${!vsrc}" ]; then
      found=1
    fi
  done
  if [ "$found" -eq 0 ]; then
    echo "Removing package: $f"
    e2rm "$IMG_BUILD:download/$f"
  fi
done

echo "Packages:"
e2ls "$IMG_BUILD:download"

#!/bin/bash
# make build.img, download packages and copy build.sh into it as /init
# use HDC=/path/to/build.img when running dev-environment.sh
set -e
cd "$(dirname "$0")"
IMG_BUILD=build.img

if [ ! -e "$IMG_BUILD" ]; then
  dd if=/dev/zero "of=$IMG_BUILD" bs=1024 "seek=$((1 * 1024 * 1024))" count=0
  mke2fs "$IMG_BUILD"
fi

copy() {
  e2cp -P 500 -O 0 -G 0 "$1" "$IMG_BUILD:$2"
}

copy build.sh init
copy packages
copy make_chroot.sh

(cd chroot; tar -zcf ../chroot.tar.gz *)
copy chroot.tar.gz

. ./packages
e2mkdir "$IMG_BUILD:download"

for pkg in "${PACKAGES[@]}"; do
  vsrc="SRC_$pkg"
  vurl="URL_$pkg"
  vchk="CHK_$pkg"
  vsum="SUM_$pkg"
  dest="$IMG_BUILD:download/${!vsrc}"
  if ! e2ls "$dest" >& /dev/null; then
    wget "${!vurl}" -O - | copy - "download/${!vsrc}"
    sum="$(e2cp "$dest" - | "${!vsum}sum" | awk '{print $1}')"
    if [ "$sum" != "${!vchk}" ]; then
      e2rm "$dest"
      echo "$0: checksum mismatch for $pkg: $sum != ${!vchk}" 1>&2
      exit
    fi
  fi
done

e2ls -l "$IMG_BUILD:download"

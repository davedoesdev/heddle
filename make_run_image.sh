#!/bin/bash
# make run.img and copy run into it as /init
# use HDC=/path/to/run when running dev-environment.sh
set -e
cd "$(dirname "$0")"
IMG_RUN=run.img
IMG_EXTRA=extra.img

if [ ! -e "$IMG_RUN" ]; then
  dd if=/dev/zero "of=$IMG_RUN" bs=1024 "seek=$((1 * 1024))" count=0
  mke2fs "$IMG_RUN"
fi

if [ ! -e "$IMG_EXTRA" ]; then
  dd if=/dev/zero "of=$IMG_EXTRA" bs=1024 "seek=$((32 * 1024 * 1024))" count=0
  mke2fs -t ext4 "$IMG_EXTRA"
fi

copy() {
  e2cp -P 500 -O 0 -G 0 "$1" "$IMG_RUN:$2"
}

copy run.sh init
copy common.sh
copy packages
copy make_chroot.sh

(cd chroot; tar --owner root --group root -zcf ../chroot.tar.gz *)
copy chroot.tar.gz

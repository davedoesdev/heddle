#!/bin/bash
set -e
HERE="$(dirname "$0")"
. "$HERE/common.sh"

. "$HERE/packages"
for pkg in "${PACKAGES[@]}"; do
  PST_$pkg
done

chroot "$CHROOT_DIR" ash


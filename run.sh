#!/bin/bash
set -e
HERE="$(dirname "$0")"
. "$HERE/common.sh"

. "$HERE/packages"
for pkg in "${PACKAGES[@]}"; do
  PST_$pkg
done

export LD_LIB_PATH="$LD_LIBRARY_PATH"
if [ ! -d /home/root ]; then
  mkdir /home/root
  echo 'export LD_LIBRARY_PATH="$LD_LIB_PATH"' > /home/root/.profile
fi

nohup chroot "$CHROOT_DIR" runsvdir /service 'log: ...........................................................................................................................................................................................................................................................................................................................................................................................................' &

exec chroot "$CHROOT_DIR" /startup/run

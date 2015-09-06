#!/bin/bash
set -e

version="$(git rev-parse --abbrev-ref HEAD)"
if [ "$version" = master -o "$version" = HEAD ]; then
  version="$(git rev-parse HEAD)"
fi
echo "version: $version"

cd aboriginal-*
( while true; do echo keep alive!; sleep 60; done ) &

build() {
  ../image_scripts/make_build_and_home_images.sh || return 1
  ../aboriginal_scripts/build_heddle.sh -c
}
logf="heddle-$version-log-x86_64.txt"
if ! build >& "../$logf"; then
  tail -n 1000 "../$logf"
  exit 1
fi
cd ..
tail -n 100 "$logf"
sudo rm -rf /tmp/chroot/home/source
df -h
mkdir /tmp/home
# mount home without recursive bind to get rid of its chroot bind mounts
sudo mount -o bind /tmp/chroot/home /tmp/home
sudo tar -zcf "heddle-$version-home-x86_64.tar.xz" "$logf" -C /tmp home
ls -lh

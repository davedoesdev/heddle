#!/bin/bash
set -e

version="$(git rev-parse --abbrev-ref HEAD)"
echo $version
if [ "$version" = master ]; then
  version="$(git rev-parse HEAD)"
fi
echo "version: $version"

cd aboriginal-*
( while true; do echo keep alive!; sleep 60; done ) &

build() {
  ../image_scripts/make_build_and_home_images.sh || return 1
  ../aboriginal_scripts/build_heddle.sh -c
}
logf=heddle-$version-log-x86_64.txt
if ! build >& ../$logf; then
  tail -n 1000 ../$logf
  exit 1
fi
tail -n 100 ../$logf
xz ../$logf


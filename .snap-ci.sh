#!/bin/bash
set -e
rm -rf build-aboriginal-travis heddle
git clone "https://github.com/davedoesdev/build-aboriginal-travis.git"
( cd build-aboriginal-travis; curl -L "https://github.com/davedoesdev/build-aboriginal-travis/releases/download/$(git tag | tail -n 1)/build-aboriginal-1.3.0-heddle.tar.xz" | tar -C .. -Jx )
mv heddle/images/*.img images
rm -rf build-aboriginal-travis heddle
sudo yum install e2fsprogs-devel user-mode-linux
curl "http://home.earthlink.net/~k_sheff/sw/e2tools/e2tools-0.0.16.tar.gz" | tar -zx
cd e2tools-0.0.16
./configure
make
ln -s e2cp e2mkdir
ln -s e2cp e2ls
PATH="$PATH:$PWD"
cd ../aboriginal-1.3.0
../image_scripts/make_build_and_home_images.sh
../aboriginal_scripts/build_heddle.sh -u

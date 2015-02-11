#!/bin/bash
set -e
rm -rf build-aboriginal-travis heddle
git clone "https://github.com/davedoesdev/build-aboriginal-travis.git"
( cd build-aboriginal-travis; curl -L "https://github.com/davedoesdev/build-aboriginal-travis/releases/download/$(git tag | tail -n 1)/build-aboriginal-1.3.0-heddle.tar.xz" | tar -C .. -Jx )
mv heddle/images/*.img images
rm -rf build-aboriginal-travis heddle
sudo apt-get update -qq
sudo apt-get install -y e2tools user-mode-linux slirp
cd aboriginal-1.3.0
../image_scripts/make_build_and_home_images.sh
../aboriginal_scripts/build_heddle.sh -u

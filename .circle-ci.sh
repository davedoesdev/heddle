#!/bin/bash
set -e
sudo apt-get update -qq
sudo apt-get install -y e2tools qemu-kvm parted mtools syslinux
rm -rf aboriginal-1.3.0 build-aboriginal-travis heddle
git clone "https://github.com/davedoesdev/build-aboriginal-travis.git"
( cd build-aboriginal-travis; curl -L "https://github.com/davedoesdev/build-aboriginal-travis/releases/download/$(git tag | tail -n 1)/build-aboriginal-1.3.0-heddle.tar.xz" | tar -C .. -Jx )
mv heddle/images/*.img images
rm -rf build-aboriginal-travis heddle
cd aboriginal-1.3.0
sed -i -e 's/-enable-kvm//' build/system-image-x86_64/run-emulator.sh
../image_scripts/make_build_and_home_images.sh
( while true; do echo keep alive!; sleep 60; done ) &
if ! ../aboriginal_scripts/build_heddle.sh -c >& build.log; then
  tail -n 200 build.log
  exit 1
fi
tail -n 100 build.log
../image_scripts/make_run_and_extra_images.sh
../aboriginal_scripts/run_heddle.sh -p

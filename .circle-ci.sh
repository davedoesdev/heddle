#!/bin/bash
set -e
sudo apt-get update -qq
sudo apt-get install -y e2tools qemu-kvm parted mtools syslinux syslinux-common coreutils squashfs-tools
rm -rf aboriginal-1.3.0 build-aboriginal-travis heddle
git clone "https://github.com/davedoesdev/build-aboriginal-travis.git"
( cd build-aboriginal-travis; curl -L "https://github.com/davedoesdev/build-aboriginal-travis/releases/download/$(git describe HEAD)/build-aboriginal-1.3.0-heddle.tar.xz" | tar -C .. -Jx )
mv heddle/images/*.img images
rm -rf build-aboriginal-travis heddle
cd aboriginal-1.3.0
sed -i -e 's/-enable-kvm//' build/system-image-x86_64/run-emulator.sh
( while true; do echo keep alive!; sleep 60; done ) &

build() {
  sudo ln -sf /bin/true /sbin/udevadm
  sudo service cassandra stop
  sudo service elasticsearch stop
  sudo service mongodb stop
  sudo service apache2 stop
  sudo service postgresql stop
  sudo service rabbitmq-server stop
  sudo service mysql stop
  ../image_scripts/make_build_and_home_images.sh || return 1
  ../aboriginal_scripts/build_heddle.sh -c
}
if ! build >& ../build.log; then
  tail -n 1000 ../build.log
  exit 1
fi
tail -n 100 ../build.log

version="$(git describe --exact-match HEAD || git rev-parse HEAD)"
echo "version: $version"
prepare_and_dist() {
  echo "type: $1"
  rm -f ../images/{extra,heddle}.img
  ../image_scripts/make_run_and_extra_images.sh $2   || return 1
  ../aboriginal_scripts/run_heddle.sh -p -q          || return 1
  ../image_scripts/make_dist_and_heddle_images.sh -l || return 1
  ../aboriginal_scripts/dist_heddle.sh -q -r         || return 1
  sudo bsdtar -C .. -s "/^\./heddle-$version-$1/" \
              -JLcf "/heddle-$version-$1.tar.xz" ./dist ./build.log
}
prepare_and_dist gpt-ext4
prepare_and_dist gpt-btrfs -b
prepare_and_dist mbr-ext4 -m
prepare_and_dist mbr-btrfs '-m -b'

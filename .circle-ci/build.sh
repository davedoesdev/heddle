#!/bin/bash
set -e
cd aboriginal-*
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
sudo cp ../build.log /
sudo xz /build.log

version="$(git describe --exact-match HEAD || git rev-parse HEAD)"
echo "version: $version"
prepare_and_dist() {
  echo "type: $1"
  prefix="heddle-$version-$1-x86_64"
  rm -f ../gen/x86_64/images/{extra,heddle}.img
  ../image_scripts/make_run_and_extra_images.sh $2   || return 1
  ../aboriginal_scripts/run_heddle.sh -p -q          || return 1
  ../image_scripts/make_dist_and_heddle_images.sh -l || return 1
  ../aboriginal_scripts/dist_heddle.sh -q -r         || return 1
  sudo bsdtar -C .. -s "/^\./$prefix/" \
              -JLcf "/$prefix.tar.xz" ./gen/x86_64/dist ./build.log
}
prepare_and_dist gpt-ext4
prepare_and_dist gpt-btrfs -b
prepare_and_dist mbr-ext4 -m
prepare_and_dist mbr-btrfs '-m -b'

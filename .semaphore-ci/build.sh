#!/bin/bash
set -e

version="$(git rev-parse --abbrev-ref HEAD)"
if [ "$version" = master ]; then
  version="$(git rev-parse HEAD)"
fi
echo "version: $version"

cd aboriginal-*
sed -i -e 's/-enable-kvm//' build/system-image-x86_64/run-emulator.sh
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

exit

sudo mv ../$logf /
sudo xz /$logf

(
e2extract() {
  e2ls -l "$1:$3" | while read -r l; do
    if [ -n "$l" ]; then
      f="$(echo "$l" | awk '{print $NF}')"
      if [ "$f" != lost+found ]; then
        m="$(echo "$l" | awk '{print substr($2, length($2)-4, 1)}')"
        if [ "$m" = 4 ]; then
          mkdir "$2$3/$f"
          e2extract "$1" "$2" "$3/$f"
        else
          e2cp "$1:$3/$f" "$2$3/$f"
        fi
        p="$(echo "$l" | awk '{print substr($2, length($2)-2)}')"
        chmod "$p" "$2$3/$f"
      fi
    fi
  done
}
srcp="heddle-$version-src-x86_64"
srcf="/$srcp.tar"

cd ../downloads
sudo bsdtar -s "@^@$srcp/@" -cf "$srcf" aboriginal-*.tar.gz

cd ..
git archive -o heddle.tar.gz HEAD
sudo bsdtar -s "@^@$srcp/@" -rf "$srcf" heddle.tar.gz
rm -f heddle.tar.gz

tmpd="$(mktemp -d)"
e2extract gen/build.img "$tmpd"
cd "$tmpd/download"
sudo bsdtar -s "@^@$srcp/@" -rf "$srcf" *
cd ../host
sudo bsdtar -s "@^@$srcp/@" -rf "$srcf" *
rm -rf "$tmpd"
)

prepare_and_dist() {
  echo "type: $1"
  prefix="heddle-$version-$1-x86_64"
  rm -f ../gen/x86_64/images/{extra,heddle}.img
  ../image_scripts/make_run_and_extra_images.sh $2   || return 1
  ../aboriginal_scripts/run_heddle.sh -p -q          || return 1
  ../image_scripts/make_dist_and_heddle_images.sh -l || return 1
  ../aboriginal_scripts/dist_heddle.sh -q -r         || return 1
  sudo bsdtar -C .. -s "/^\./$prefix/" -JLcf "/$prefix.tar.xz" ./gen/x86_64/dist
}
prepare_and_dist gpt-btrfs
prepare_and_dist gpt-ext4 -e
prepare_and_dist mbr-btrfs -m
prepare_and_dist mbr-ext4 '-m -e'

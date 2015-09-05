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
set -x
df -h
sudo rm -rf /tmp/chroot/home/source
df -h
bsdtar -Jcf "heddle-$version-home-x86_64.tar.xz" "$logf" -C /tmp/chroot home
df -h
ls -lh

#(
#e2extract() {
#  e2ls -l "$1:$3" | while read -r l; do
#    if [ -n "$l" ]; then
#      f="$(echo "$l" | awk '{print $NF}')"
#      if [ "$f" != lost+found ]; then
#        m="$(echo "$l" | awk '{print substr($2, length($2)-4, 1)}')"
#        if [ "$m" = 4 ]; then
#          mkdir "$2$3/$f"
#          e2extract "$1" "$2" "$3/$f"
#        else
#          e2cp "$1:$3/$f" "$2$3/$f"
#        fi
#        p="$(echo "$l" | awk '{print substr($2, length($2)-2)}')"
#        chmod "$p" "$2$3/$f"
#      fi
#    fi
#  done
#}
#srcp="heddle-$version-src-x86_64"
#srcf="$HOME/$srcp.tar"
#
#cd ..
#git archive -o heddle.tar.gz HEAD
#bsdtar -s "@^@$srcp/@" -cf "$srcf" heddle.tar.gz
#rm -f heddle.tar.gz
#
#tmpd="$(mktemp -d)"
#e2extract gen/build.img "$tmpd"
#cd "$tmpd/download"
#bsdtar -s "@^@$srcp/@" -rf "$srcf" *
#cd ../host
#bsdtar -s "@^@$srcp/@" -rf "$srcf" *
#rm -rf "$tmpd"
#
#cd "$SEMAPHORE_CACHE_DIR"
#bsdtar -s "@^@$srcp/@" -rf "$srcf" aboriginal-*.tar.gz
#)

#prepare_and_dist() {
#  echo "type: $1"
#  prefix="heddle-$version-$1-x86_64"
#  rm -f ../gen/x86_64/images/{extra,heddle}.img
#  ../image_scripts/make_run_and_extra_images.sh $2   || return 1
#  ../aboriginal_scripts/run_heddle.sh -p -q          || return 1
#  ../image_scripts/make_dist_and_heddle_images.sh -l || return 1
#  ../aboriginal_scripts/dist_heddle.sh -q -r         || return 1
#  bsdtar -C .. -s "/^\./$prefix/" -JLcf "$HOME/$prefix.tar.xz" ./gen/x86_64/dist
#}
#prepare_and_dist gpt-btrfs
#prepare_and_dist gpt-ext4 -e
#prepare_and_dist mbr-btrfs -m
#prepare_and_dist mbr-ext4 '-m -e'

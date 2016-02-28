#!/bin/bash
set -e

version="$(git rev-parse --abbrev-ref HEAD)"
if [ "$version" = master -o "$version" = HEAD ]; then
  version="$(git rev-parse HEAD)"
fi
echo "version: $version"

sudo ln -sf /bin/true /sbin/udevadm

cd aboriginal-*
sed -i -e 's/-enable-kvm//' build/system-image-x86_64/run-emulator.sh
( while true; do echo keep alive!; sleep 60; done ) &

../image_scripts/make_build_and_home_images.sh

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

hmac() {
  SECRET="$1" node 3<&0 << 'EOF'
var hmac = require('crypto').createHmac('sha256', process.env.SECRET);
require('fs').createReadStream(null, {fd: 3}).pipe(hmac);
var t = new require('stream').Transform();
t._transform = function (data, encoding, callback)
{
    this.push(data.toString('hex'));
    callback();
};
hmac.pipe(t);
t.pipe(process.stdout);
EOF
}

txf() {
  URL="$1" node << 'EOF'
require('http').request(process.env.URL, function (res)
{
    if (res.statusCode === 200)
    {
        res.pipe(process.stdout);
    }
    else
    {
        console.error('error', res.statusCode);
        process.exitCode = 1;
        res.pipe(process.stderr);
    }
}).end();
EOF
}

txf_url() {
  echo "http://txf-davedoesdev.rhcloud.com/default/$(echo -n "$1" | hmac "$DEFAULT_RECEIVER_SECRET")/$1"
}

homef="../heddle-$version-home-x86_64.tar.gz"

while ! txf "$(txf_url "heddle-$version")" > "$homef"; do sleep 1; done
while ! mac="$(txf "$(txf_url "heddle-$version.mac")")"; do sleep 1; done

ls -lh "$homef"
calc_mac="$(hmac "$INTEGRITY_SECRET" < "$homef")"
if [ "$mac" != "$calc_mac" ]; then
  echo "hmac mismatch" 1>&2
  exit 1
fi

logf="heddle-$version-log-x86_64.txt"
# If $home isn't for this version, it won't contain $logf
sudo tar -zxf "$homef" -C / "$logf"
sudo xz "/$logf"

e2cp -P 400 -O 0 -G 0 "$homef" ../gen/x86_64/images/home.img:home.tar.gz
rm -f "$homef"

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

ls -lh /heddle*

#!/bin/bash
set -e

sudo apt-get update -qq
sudo apt-get install -y e2tools qemu-kvm parted mtools syslinux syslinux-common coreutils squashfs-tools

ver_bat=1.0.0
ver_abo=1.4.0
bat_base="downloads/build-aboriginal-$ver_abo-heddle-$ver_bat"
bat_seal="$bat_base.seal"
bat_file="$bat_base.tar.xz"
if [ ! -f "$bat_seal" ]; then
  curl -L --create-dirs -o "$bat_file" "https://github.com/davedoesdev/build-aboriginal-travis/releases/download/v$ver_bat/build-aboriginal-$ver_abo-heddle.tar.xz"
  touch "$bat_seal"
fi
rm -rf aboriginal-* heddle
tar -Jxf "$bat_file"
mv heddle/images/*.img images
rm -rf heddle


#!/bin/bash
set -e
HERE="${0%/*}"
PATH="$PATH:$HERE"
busybox mount -o loop,ro -t squashfs "$HERE/root.sqf" /newroot/root
/newroot/root/sbin/swapon "${root_part%3}2"
busybox mount -o bind /newroot/home /newroot/root/home
busybox mount -o loop,ro -t squashfs "$HERE/install.sqf" /newroot/root/home/install
busybox mount -o loop,ro -t squashfs "$HERE/modules.sqf" /newroot/root/lib/modules
if [ -e "$HERE/firmware.sqf" ]; then
  busybox mount -o loop,ro -t squashfs "$HERE/firmware.sqf" /newroot/root/lib/firmware
fi
/newroot/root/bin/mkdir -p /newroot/{docker,updates}
busybox mount -o bind /newroot/docker /newroot/root/extra/docker
busybox mount -o bind /newroot/updates /newroot/root/extra/updates
busybox mount -o loop,ro -t squashfs "$HERE/run.sqf" /newroot/root/home/run
exec toybox switch_root /newroot/root /bin/hush < "$HERE/init2.sh"

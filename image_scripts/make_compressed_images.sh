#!/bin/bash
set -e
HERE="$(dirname "$0")"
qemu-img convert -c -f raw -O qcow2 "$HERE/../images/heddle."{img,qcow2}
qemu-img convert -c -f raw -O qcow2 "$HERE/../images/build."{img,qcow2}

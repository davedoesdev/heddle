#!/bin/bash
# build enough to get docker and capstan working
set -e
if [ ! -h /dev/fd ]; then
  ln -s /proc/self/fd /dev
fi
HERE="$(dirname "$0")"
. "$HERE/common.sh"

SOURCE_DIR="$HOME/source"
mkdir -p "$SOURCE_DIR" "$INSTALL_DIR"
cd "$SOURCE_DIR"

unset interactive
unset Interactive
while getopts iI opt
do
  case $opt in
    i)
      interactive=yes
      ;;
    I)
      Interactive=yes
      ;;
  esac
done

unset updated

. "$HERE/packages"
for pkg in "${PACKAGES[@]}"; do
  vdir="DIR_$pkg"
  vsrc="SRC_$pkg"
  if [ -z "$Interactive" -a ! -e "${!vdir}.built" ]; then
    rm -rf "${!vdir}"
    tar -xf "$HERE/download/${!vsrc}"
    chown -R root:root "${!vdir}"
    tar -xf "$HERE/supplemental.tar.gz" "${!vdir}" >& /dev/null || true
    pushd "${!vdir}"
    BLD_$pkg
    popd
    touch "${!vdir}.built"
    updated=1
  fi
  if type PST_$pkg 2> /dev/null | grep -q function; then
    PST_$pkg
  fi
done

[ -n "$interactive" -o -n "$Interactive" ] && chroot "$CHROOT_DIR" ash


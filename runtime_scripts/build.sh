#!/bin/bash
# build enough to get docker and capstan working
set -e
if [ ! -h /dev/fd ]; then
  ln -s /proc/self/fd /dev
fi
if [ -b /dev/hdd ]; then
  swapon /dev/hdd
fi
if [ -b /dev/sdd ]; then
  swapon /dev/sdd
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
shift $((OPTIND-1))

. "$HERE/packages"
if [ $# -gt 0 ]; then
  pkgs=("$@")
else
  pkgs=("${PACKAGES[@]}")
fi
for pkg in "${pkgs[@]}"; do
  declare "BLD_$pkg"=1
done
for pkg in "${PACKAGES[@]}"; do
  vdir="DIR_$pkg"
  vsrc="SRC_$pkg"
  vbld="BLD_$pkg"
  if [ -z "$Interactive" -a -n "${!vbld}" -a ! -e "${!vdir}.built" ]; then
    echo "+$pkg" > /dev/tty
    binf="$HERE/host/${!vdir}-$(uname -m).tar.xz"
    if [ -f "$binf" ]; then
      tar -C "$INSTALL_DIR" -Jxf "$binf"
    else
      rm -rf "${!vdir}"
      tar -xf "$HERE/download/${!vsrc}"
      chown -R root:root "${!vdir}"
      tar -xf "$HERE/supplemental.tar.gz" "./${!vdir}" >& /dev/null || true
      pushd "${!vdir}"
      BLD_$pkg
      popd
    fi
    touch "${!vdir}.built"
    echo "-$pkg" > /dev/tty
  fi
  if type PST_$pkg 2> /dev/null | grep -q function; then
    PST_$pkg
  fi
done

if [ -n "$interactive" -o -n "$Interactive" ]; then
  exec chroot "$CHROOT_DIR" ash
elif [ ! -f /tmp/in_chroot ]; then
  exec poweroff
fi


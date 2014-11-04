#!/bin/bash
# build enough to get weave, fold and salt working
set -e
HERE="$(dirname "$0")"
. "$HERE/packages"

ifconfig lo 127.0.0.1
"$HERE/make_chroot.sh"

SRC_DIR="$HOME/source"
export INSTALL_DIR="$HOME/install"
export PATH="$(echo $PATH | sed 's/\/usr\/distcc://'):$INSTALL_DIR/bin"
export CPPFLAGS="-I$INSTALL_DIR/include"
export LDFLAGS="-L$INSTALL_DIR/lib"
export LD_LIBRARY_PATH="$INSTALL_DIR/lib"
export TMPDIR=/tmp
mkdir -p "$SRC_DIR" "$INSTALL_DIR"
cd "$SRC_DIR"

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

for pkg in "${PACKAGES[@]}"; do
  vdir="DIR_$pkg"
  vsrc="SRC_$pkg"
  if [ -z "$Interactive" -a ! -e "${!vdir}" ]; then
    tar xf "$HERE/download/${!vsrc}"
    pushd "${!vdir}"
    BLD_$pkg
    popd
  fi
  PST_$pkg
done

[ -n "$interactive" -o -n "$Interactive" ] && chroot "$HOME/chroot" ash

# Cleanup source
# Support image upgrade

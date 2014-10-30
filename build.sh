#!/bin/bash
# build enough to get weave and fold working
set -e
HERE="$(dirname "$0")"
. "$HERE/packages"
SRC_DIR="$HOME/source"
export INSTALL_DIR="$HOME/install"
export PATH="$PATH:$INSTALL_DIR/bin"
export CPPFLAGS="-I$INSTALL_DIR/include"
export LDFLAGS="-L$INSTALL_DIR/lib"
export LD_LIBRARY_PATH="$INSTALL_DIR/lib"
mkdir -p "$SRC_DIR" "$INSTALL_DIR"
cd "$SRC_DIR"

unset interactive
while getopts i opt
do
  case $opt in
    i)
      interactive=yes
      ;;
  esac
done

for pkg in "${PACKAGES[@]}"; do
  vdir="DIR_$pkg"
  vsrc="SRC_$pkg"
  if [ ! -e "${!vdir}" ]; then
    tar xf "$HERE/download/${!vsrc}"
    pushd "${!vdir}"
    BLD_$pkg
    popd
  fi
  PST_$pkg
done

[ $interactive ] && ash

# Cleanup source

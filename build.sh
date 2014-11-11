#!/bin/bash
# build enough to get weave, fold and salt working
set -e
HERE="$(dirname "$0")"

# TODO: these lines should be in a startup script
ifconfig lo 127.0.0.1
CHROOT_DIR="$HOME/chroot"
"$HERE/make_chroot.sh" "$CHROOT_DIR"

SOURCE_DIR="$HOME/source"
export INSTALL_DIR="$HOME/install"
export PATH="/usr/bin:$(echo $PATH | sed 's/\/usr\/distcc://'):$INSTALL_DIR/bin:$INSTALL_DIR/sbin"
export CPPFLAGS="-I$INSTALL_DIR/include"
export LDFLAGS="-L$INSTALL_DIR/lib"
export LD_LIBRARY_PATH="$INSTALL_DIR/lib"
export TMPDIR=/tmp
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

. "$HERE/packages"
for pkg in "${PACKAGES[@]}"; do
  vdir="DIR_$pkg"
  vsrc="SRC_$pkg"
  if [ -z "$Interactive" -a ! -e "${!vdir}" ]; then
    tar -xf "$HERE/download/${!vsrc}"
    tar -xf "$HERE/supplemental.tar.gz" "${!vdir}" >& /dev/null || true
    pushd "${!vdir}"
    BLD_$pkg
    popd
  fi
  PST_$pkg
done

[ -n "$interactive" -o -n "$Interactive" ] && chroot "$CHROOT_DIR" ash

# Cleanup source
# Support image upgrade

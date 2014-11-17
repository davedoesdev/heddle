ifconfig lo 127.0.0.1
CHROOT_DIR="$HOME/chroot"
"$HERE/make_chroot.sh" "$CHROOT_DIR"

export INSTALL_DIR="$HOME/install"
export PATH="/usr/bin:$(echo $PATH | sed 's/\/usr\/distcc://'):$INSTALL_DIR/bin:$INSTALL_DIR/sbin"
export CPPFLAGS="-I$INSTALL_DIR/include"
export LDFLAGS="-L$INSTALL_DIR/lib"
export LD_LIBRARY_PATH="$INSTALL_DIR/lib"
export TMPDIR=/tmp


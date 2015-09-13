if [ ! -f /tmp/in_chroot ]; then
  mount -o remount,ro /
  mount -t tmpfs /tmp /tmp
  sysctl -q kernel.printk="3 4 1 3" || true
  ifconfig lo 127.0.0.1 up
fi

CHROOT_DIR=/home/chroot
if [ -z "$DONT_MAKE_CHROOT" ]; then
  "$HERE/make_chroot.sh" "$CHROOT_DIR"
fi

export INSTALL_DIR=/home/install
export PATH="$INSTALL_DIR/bin:$INSTALL_DIR/sbin:/usr/bin:$(echo $PATH | sed 's/\/usr\/distcc://')"
export CPPFLAGS="-I$INSTALL_DIR/include"
export LDFLAGS="-L$INSTALL_DIR/lib"
export LD_LIBRARY_PATH="$INSTALL_DIR/lib"
export TMPDIR=/tmp

if [ ! -f /tmp/in_chroot ]; then
  mount -o remount,ro /
  mount -t tmpfs /tmp /tmp
  sysctl -q kernel.printk="3 4 1 3" || true
  ifconfig lo 127.0.0.1 up
fi

if [ -z "$DONT_XROOT" ]; then
  xroot=/home/xroot
  here="$(dirname "$0")"

  if [ -e "$xroot" ]; then
    rm -rf "$xroot"/{service,startup}
    tar -C "$xroot" -xf "$here/xroot.tar.gz" ./service ./startup ./var/log
  else
    mkdir -p "$xroot"
    tar -C "$xroot" -xf "$HERE/xroot.tar.gz"
  fi

  mkdir -p "$xroot/etc"
  for x in /etc/*; do
    y="$xroot$x"
    if [ -d "$x" ]; then
      if [ "$x" != /etc/default ] && ! mount | grep -q "$y "; then
        mkdir -p "$y"
        mount -o rbind "$x" "$y"
      fi
    elif [ ! -e "$y" ]; then
      cp "$x" "$y"
    fi
  done

  for x in etc var service startup command package run; do
    mkdir -p "$xroot/$x"
    mount -o rbind "$xroot/$x" "/$x"
  done
fi

export INSTALL_DIR=/home/install
export PATH="$INSTALL_DIR/bin:$INSTALL_DIR/sbin:/usr/bin:$(echo $PATH | sed 's/\/usr\/distcc://')"
export CPPFLAGS="-I$INSTALL_DIR/include"
export LDFLAGS="-L$INSTALL_DIR/lib"
export LD_LIBRARY_PATH="$INSTALL_DIR/lib"
export TMPDIR=/tmp

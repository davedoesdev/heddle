#!/bin/bash
set -e

chroot_build=
uml_build=
while getopts cu opt
do
  case $opt in
    u)
      uml_build=1
      ;;
  esac
done
shift $((OPTIND-1))

ARCH="${1:-x86_64}"
HERE="$(cd "$(dirname "$0")"; echo "$PWD")"
export HDB="${HEDDLE_EXT_DIR:-"$HERE/.."}/gen/$ARCH/images/home.img"
export HDC="${HEDDLE_EXT_DIR:-"$HERE/.."}/gen/build.img"
export BUILD_MEM=2048

. "$HERE/../image_scripts/packages"
if [ -n "$HEDDLE_EXT_DIR" -a -e "$HEDDLE_EXT_DIR/image_scripts/packages" ]; then
  . "$HEDDLE_EXT_DIR/image_scripts/packages"
fi

for pkg in "${PACKAGES[@]}"; do
  vdir="DIR_$pkg"
  vsrc="SRC_$pkg"
  vhst="HST_$pkg"
  vxtr="XTR_$pkg"
  if [ -n "${!vhst}" ]; then
    eval archs="(\"\${$vhst[@]}\")"
    for a in "${archs[@]}"; do
      if [ "$a" = "$ARCH" ]; then
        binf="$HDC:host/${!vsrc}-$a.tar.xz"
        if ! e2ls "$binf"; then
          tmpd="$(mktemp -d)"
          e2cp "$HDC:download/${!vsrc}" "$tmpd"
          tar -C "$tmpd" -xf "$tmpd/${!vsrc}"
          INSTALL_DIR="$tmpd/install"
          mkdir "$INSTALL_DIR"
          pushd "$tmpd/${!vdir}"
          BLD_$pkg 
          popd
          tar --owner root --group root -C "$INSTALL_DIR" -Jc . | e2cp -P 400 -O 0 -G 0 - "$binf"
          rm -rf "$tmpd"
        fi
        break
      fi
    done
  fi
  if [ -n "${!vxtr}" ]; then
    eval xtr="(\"\${$vxtr[@]}\")"
    xtr2=()
    for ((i=0; i < ${#xtr[@]}; i+=5)); do
      if [ "${xtr[$i]}" = "$ARCH" ]; then
        xtr2+=("${xtr[$((i+1))]}"
               "${xtr[$((i+2))]}"
               "${xtr[$((i+3))]}"
               "${xtr[$((i+4))]}")
      fi
    done
    if [ ${#xtr2[@]} -gt 0 ]; then
      extraf="$HDC:host/${!vsrc}-$ARCH-extra.tar.xz"
      if ! e2ls "$extraf"; then
        tmpd="$(mktemp -d)"
        for ((i=0; i < ${#xtr2[@]}; i+=4)); do
          url="${xtr2[$((i))]}"
          chk="${xtr2[$((i+1))]}"
          sum="${xtr2[$((i+2))]}"
          file="${xtr2[$((i+3))]}"
          curl -o "$tmpd/$file" --create-dirs "$url"
          csum="$("${sum}sum" "$tmpd/$file" | awk '{print $1}')"
          if [ "$csum" != "$chk" ]; then
            rm -rf "$tmpd"
            echo "$0: checksum mismatch for $url: $csum != $chk"
            exit 1
          fi
        done
        tar -C "$tmpd" -Jc . | e2cp -P 400 -O 0 -G 0 - "$extraf"
        rm -rf "$tmpd"
      fi
    fi
  fi
done

ROOT_DIR="$PWD/build/root-filesystem-$ARCH"
OVERLAY_DIR="$PWD/build/native-compiler-$ARCH"
cd "build/system-image-$ARCH"

e2extract() {
  e2ls -l "$1:$3" | while read -r l; do
    if [ -n "$l" ]; then
      f="$(echo "$l" | awk '{print $NF}')"
      if [ "$f" != lost+found ]; then
        m="$(echo "$l" | awk '{print substr($2, length($2)-4, 1)}')"
        if [ "$m" = 4 ]; then
          mkdir "$2$3/$f"
          e2extract "$1" "$2" "$3/$f"
        else
          e2cp "$1:$3/$f" "$2$3/$f"
        fi
        p="$(echo "$l" | awk '{print substr($2, length($2)-2)}')"
        chmod "$p" "$2$3/$f"
      fi
    fi
  done
}

if [ -n "$uml_build" ]; then
  echo "uml build" | tee /dev/tty
  cp -r --remove-destination "$OVERLAY_DIR/." "$ROOT_DIR"
  rm -f "$ROOT_DIR/root.tar.xz"
  tar --owner root --group root -Jcf root.tar.xz -C "$ROOT_DIR" .
  mv root.tar.xz "$ROOT_DIR"
  cat > "$ROOT_DIR/init.uml" << 'EOF'
#!/bin/ash
mount -t proc proc /proc
mount -t tmpfs tmp /tmp

mkdir /tmp/dev
mknod /tmp/dev/ttyS0 c 4 64
mknod /tmp/dev/urandom c 1 9
mknod /tmp/dev/null c 1 3
mknod /tmp/dev/hdb b 98 0
mknod /tmp/dev/hdc b 98 16
ln -s hdb /tmp/dev/ubdb
ln -s hdc /tmp/dev/ubdc

mkdir /tmp/root
tar -C /tmp/root -Jxf /root.tar.xz

mount -o bind /tmp/dev /tmp/root/dev
mount -t proc proc /tmp/root/proc
mount -t sysfs sys /tmp/root/sys

mount /tmp/dev/hdb /tmp/root/home
mount -o ro /tmp/dev/hdc /tmp/root/mnt

mkdir /tmp/source /tmp/root/home/source
mount -o bind /tmp/source /tmp/root/home/source

export HOME=/home
export PATH

mount
ls /tmp/dev
ifconfig

exec /usr/sbin/chroot /tmp/root /mnt/init < /tmp/dev/ttyS0 > /tmp/dev/ttyS0 2>&1
EOF
  chmod +x "$ROOT_DIR/init.uml"
  exec linux.uml "ubd0=$HDB" "ubd1=$HDC" "hostfs=$ROOT_DIR" rootfstype=hostfs init=/init.uml mem="$((BUILD_MEM + 1024))M" con0=fd:3,fd:4 ssl0=fd:0,fd:1 console=ttyS0 "heddle_arch=$ARCH" eth0=slirp 3>/dev/null 4>&1
else
  echo "qemu/kvm build" | tee /dev/tty
  if [ "$ARCH" = x86_64 ]; then
    export QEMU_MEMORY="$BUILD_MEM"
    tmp=
  else
    tmp="$(mktemp)"
    dd if=/dev/zero "of=$tmp" bs=1024 "seek=$(($BUILD_MEM * 1024))" count=0
    mkswap "$tmp"
    export QEMU_EXTRA="-hdd $tmp"
  fi
  export KERNEL_EXTRA="heddle_arch=$ARCH"
  ./dev-environment.sh
  if [ -n "$tmp" ]; then
    rm -f "$tmp"
  fi  
fi

#!/bin/bash
set -e

chroot_build=
uml_build=
interactive=
Interactive=
while getopts cuiI opt
do
  case $opt in
    c)
      chroot_build=1
      ;; 
    u)
      uml_build=1
      ;;
    i)
      interactive=-i
      ;;
    I)
      Interactive=-I
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

if [ -n "$chroot_build" ]; then
  echo "chroot build" | tee /dev/tty
  mkdir /tmp/chroot tmp
  cp -r --remove-destination "$OVERLAY_DIR/." "$ROOT_DIR"
  sudo mount -o bind "$ROOT_DIR" /tmp/chroot
  sudo mount -o remount,ro /tmp/chroot
  sudo mount -o loop "$HDB" /tmp/chroot/home
  sudo mount -o loop,ro "$HDC" /tmp/chroot/mnt
  sudo mount -o bind tmp /tmp/chroot/tmp # don't use memory for tmpfs
  sudo mount -o rbind /proc /tmp/chroot/proc
  sudo mount -o rbind /sys /tmp/chroot/sys
  sudo mount -o rbind /dev /tmp/chroot/dev
  sudo chroot /tmp/chroot /bin/ash << EOF
set -e
export heddle_arch="$ARCH"
export HOME=/home
export PATH
cd
touch /tmp/in_chroot
exec /mnt/init $interactive $Interactive
EOF
elif [ -n "$uml_build" ]; then
  echo "uml build" | tee /dev/tty
  cp -r --remove-destination "$OVERLAY_DIR/." "$ROOT_DIR"
  mksquashfs "$ROOT_DIR" root.sqf -noappend -all-root
  cat > "$ROOT_DIR/init.uml" << EOF
#!/bin/ash
mount -t proc proc /proc
mount -t tmpfs tmp /dev

mknod /dev/random c 1 8
mknod /dev/urandom c 1 9
mknod /dev/null c 1 3
mknod /dev/hda b 98 0
mknod /dev/hdb b 98 16
mknod /dev/hdc b 98 32
ln -s hda /dev/ubda
ln -s hdb /dev/ubdb
ln -s hdc /dev/ubdc

mount -o ro /dev/hda /root
mount /dev/hdb /root/home
mount -o ro /dev/hdc /root/mnt
mount -o bind /dev /root/dev
mount -o bind /proc /root/proc
mount -t tmpfs tmp /root/tmp
mount -t sysfs sys /root/sys
mount

ifconfig eth0 10.0.2.15 up
route add default dev eth0
ifconfig

export HOME=/home
export PATH

exec /usr/sbin/chroot /root /mnt/init $interactive $Interactive
EOF
  chmod +x "$ROOT_DIR/init.uml"
  exec linux.uml "ubd0=root.sqf" "ubd1=$HDB" "ubd2=$HDC" "hostfs=$ROOT_DIR" rootfstype=hostfs init=/init.uml mem="${BUILD_MEM}M" "heddle_arch=$ARCH" eth0=slirp
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

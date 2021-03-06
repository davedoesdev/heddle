#!/bin/bash
set -e

cleanup() {
  trap - EXIT
  echo 'Syncing'
  sync
  echo 'Re-mounting drives read-only'
  mount -o remount,ro /dev/[hsv]db || true
  if [ -b /dev/[hsv]dd ]; then
    swapoff /dev/[hsv]dd || true
  fi
  # Not all QEMU machines support poweroff so assume -no-reboot was used
  exec reboot
}

if [ ! -h /dev/fd ]; then
  ln -s /proc/self/fd /dev
fi
if [ ! -f /tmp/in_chroot ]; then
  if [ -b /dev/[hsv]dd ]; then
    swapon /dev/[hsv]dd
  fi
  trap cleanup EXIT
fi

HERE="$(dirname "$0")"
. "$HERE/common.sh"

SOURCE_DIR=/home/source
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
  builtf="$(echo "${!vdir}" | tr / _).built"
  if [ -z "$Interactive" -a -n "${!vbld}" -a ! -e "$builtf" ]; then
    echo "+$pkg" | tee /dev/tty
    binf="$HERE/host/${!vsrc}-$heddle_arch.tar.xz"
    if [ -f "$binf" ]; then
      tar -C "$INSTALL_DIR" -Jxf "$binf"
    elif [ "$(type -t "BLD_$pkg")" = function -o "$(type -t "BLD_${pkg}_$heddle_arch")" = function ]; then
      rm -rf "${!vdir}"
      mkdir -p "${!vdir}"
      pushd "${!vdir}"
      case "${!vsrc}" in
        *.zip)
          miniunz "$HERE/download/${!vsrc}"
          ;;
        *)
          tar -xf "$HERE/download/${!vsrc}"
          ;;
      esac
      # assume one directory has been extracted
      shopt -s dotglob
      mv $(echo "${!vdir}" | sed -E 's:[^/]+:*:g') _heddle_build_xyz_
      mv _heddle_build_xyz_/* .
      shopt -u dotglob
      rmdir _heddle_build_xyz_
      popd
      tar -xvf "$HERE/supplemental.tar.gz" "./$pkg" "./${!vdir}" 2> /dev/null || true
      extraf="$HERE/host/${!vsrc}-$heddle_arch-extra.tar.xz"
      [ -f "$extraf" ] && tar -C "${!vdir}" -xf "$extraf"
      extraf="$HERE/host/${!vsrc}-any-extra.tar.xz"
      [ -f "$extraf" ] && tar -C "${!vdir}" -xf "$extraf"
      chown -R root:root "${!vdir}"
      pushd "${!vdir}"
      if [ "$(type -t "BLD_$pkg")" = function ]; then
        BLD_$pkg
      fi
      if [ "$(type -t "BLD_${pkg}_$heddle_arch")" = function ]; then
        BLD_${pkg}_$heddle_arch
      fi
      popd
    fi
    touch "$builtf"
    echo "-$pkg" | tee /dev/tty
  fi
  if type PST_$pkg 2> /dev/null | grep -q function; then
    PST_$pkg
  fi
done

if [ -n "$interactive" -o -n "$Interactive" ]; then
  hush
fi

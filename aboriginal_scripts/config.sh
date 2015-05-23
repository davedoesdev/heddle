#!/bin/bash
set -e
HERE="$(dirname "$0")"

# uClibc
echo >> sources/baseconfig-uClibc
cat "$HERE/config/uClibc" >> sources/baseconfig-uClibc
if [ -n "$HEDDLE_EXT_DIR" -a -e "$HEDDLE_EXT_DIR/aboriginal_scripts/config/uClibc" ]; then
  cat "$HEDDLE_EXT_DIR/aboriginal_scripts/config/uClibc" >> sources/baseconfig-uClibc
fi
sed -i -e 's/<= _NSIG/< _NSIG/g' sources/patches/uClibc-posix_spawn.patch

# uClibc++
sed -i -e 's/uClibc++-0\.2\.2/uClibc++-0.2.4/g' -e 's/f5582d206378d7daee6f46609c80204c1ad5c0f7/ffadcb8555a155896a364a9b954f19d09972cb83/g' download.sh
sed -i -e 's/TLS|//g' sources/sections/uClibc++.build
ed -s sources/sections/uClibc++.build << EOF
/CROSS= make oldconfig/i
sed -r -i 's/# (UCLIBCXX_HAS_WCHAR) is not set/\1=y/' .config &&
echo UCLIBCXX_SUPPORT_WCIN=y >> .config &&
echo UCLIBCXX_SUPPORT_WCOUT=y >> .config &&
echo UCLIBCXX_SUPPORT_WCERR=y >> .config &&
echo UCLIBCXX_SUPPORT_WCLOG=n >> .config &&
.
w
EOF

# BusyBox
(
echo 1i
cat "$HERE/config/busybox"
if [ -n "$HEDDLE_EXT_DIR" -a -e "$HEDDLE_EXT_DIR/aboriginal_scripts/config/busybox" ]; then
  cat "$HEDDLE_EXT_DIR/aboriginal_scripts/config/busybox"
fi
echo
echo .
echo w
) | ed -s sources/baseconfig-busybox

# Linux kernel (all architectures)
echo >> sources/baseconfig-linux
cat "$HERE/config/linux" >> sources/baseconfig-linux
if [ -n "$HEDDLE_EXT_DIR" -a -e "$HEDDLE_EXT_DIR/aboriginal_scripts/config/linux" ]; then
  cat "$HEDDLE_EXT_DIR/aboriginal_scripts/config/linux" >> sources/baseconfig-linux
fi

# Linux kernel (architecture config)
for f in "$HERE"/config/linux-* ${HEDDLE_EXT_DIR:+"$HEDDLE_EXT_DIR"/aboriginal_scripts/config/linux-*}; do
  if [ -e "$f" ]; then
    arch="$(basename "$f")"
    arch="${arch#linux-}"
    cat >> "sources/targets/$arch" << 'EOF'

LINUX_CONFIG+="
EOF
    cat "$f" >> "sources/targets/$arch"
    echo '"' >> "sources/targets/$arch"
  fi
done

# x86_64: Make sure old threads aren't used and enable KVM by default
sed -i -e '/LINUXTHREADS_OLD=y/d' -e 's/qemu-system-x86_64/\0 -enable-kvm/' sources/targets/x86_64

# armv6l: Aboriginal 1.4.1 stopped using ARM1136-R2 in kernel but forgot to
# remove from QEMU command line
sed -i -e 's/-cpu arm1136-r2//' sources/targets/armv6l

# Add module and firmware directories to root filesystem and point some utils to
# BusyBox for the time being
ed -s root-filesystem.sh << 'EOF'
/create_stage_tarball/i
mkdir -p "$STAGE_DIR/lib"/{modules,firmware}
ln -sf busybox "$STAGE_DIR/bin/mount"
ln -sf busybox "$STAGE_DIR/bin/sed"
ln -sf busybox "$STAGE_DIR/bin/mountpoint"
.
w
EOF

# Tell Aboriginal to make kernel modules
ed -s system-image.sh << 'EOF'
/cp "$KERNEL_PATH" "$STAGE_DIR/i
make "INSTALL_MOD_PATH=$STAGE_DIR/modules" ARCH=${BOOT_KARCH:-$KARCH} $DO_CROSS $LINUX_FLAGS $VERBOSITY modules_install &&
.
w
EOF

# Copy extra Heddle patches
cp "$HERE/patches"/*.patch sources/patches
for f in ${HEDDLE_EXT_DIR:+"$HEDDLE_EXT_DIR"/aboriginal_scripts/patches/*.patch}; do
  if [ -e "$f" ]; then
    cp "$f" sources/patches
  fi
done


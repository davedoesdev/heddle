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

# Add support for -pie to ccwrap
patch -p0 << 'EOF'
--- sources/toys/ccwrap.c.orig	2015-05-29 07:03:54.523059741 +0100
+++ sources/toys/ccwrap.c	2015-05-29 09:16:18.571311754 +0100
@@ -125,13 +125,14 @@
 // Some compiler versions don't provide separate T and S versions of begin/end,
 // so fall back to the base version if they're not there.
 
-char *find_TSpath(char *base, char *top, int use_shared, int use_static_linking)
+char *find_TSpath(char *base, char *top, int use_shared, int use_static_linking,
+                  int use_pie)
 {
   int i;
   char *temp;
 
   temp = xmprintf(base, top,
-    use_shared ? "S.o" : use_static_linking ? "T.o" : ".o");
+    use_shared || use_pie ? "S.o" : use_static_linking ? "T.o" : ".o");
 
   if (!is_file(temp, 0)) {
     free(temp);
@@ -144,7 +145,7 @@
 
 enum {
   Clibccso, Clink, Cprofile, Cshared, Cstart, Cstatic, Cstdinc, Cstdlib,
-  Cverbose, Cx, Cdashdash,
+  Cverbose, Cx, Cdashdash, Cpie,
 
   CPctordtor, CP, CPstdinc
 };
@@ -382,6 +383,10 @@
 
         return 0;
       } else if (!strcmp(c, "pg")) SET_FLAG(Cprofile);
+      else if (!strcmp(c, "pie")) {
+        keepc--;
+        SET_FLAG(Cpie);
+      }
     } else if (*c == 's') {
       keepc--;
       if (!strcmp(c, "shared")) {
@@ -440,6 +445,7 @@
     outv[outc++] = "-nostdlib";
     outv[outc++] = GET_FLAG(Cstatic) ? "-static" : dynlink;
     if (GET_FLAG(Cshared)) outv[outc++] = "-shared";
+    if (GET_FLAG(Cpie)) outv[outc++] = "-pie";
 
     // Copy libraries to output (first move fallback to end, break circle)
     libs = libs->next->next;
@@ -452,11 +458,12 @@
     if (GET_FLAG(CPctordtor)) {
       outv[outc++] = xmprintf("%s/lib/crti.o", topdir);
       outv[outc++] = find_TSpath("%s/cc/lib/crtbegin%s", topdir,
-                                 GET_FLAG(Cshared), GET_FLAG(Cstatic));
+                                 GET_FLAG(Cshared), GET_FLAG(Cstatic),
+                                 GET_FLAG(Cpie));
     }
     if (!GET_FLAG(Cprofile) && GET_FLAG(Cstart))
       outv[outc++] = xmprintf("%s/lib/%scrt1.o", topdir,
-                              GET_FLAG(Cshared) ? "S" : "");
+                              GET_FLAG(Cshared) || GET_FLAG(Cpie) ? "S" : "");
   }
 
   // Copy unclaimed arguments
@@ -482,7 +489,8 @@
     }
     if (GET_FLAG(CPctordtor)) {
       outv[outc++] = find_TSpath("%s/cc/lib/crtend%s", topdir,
-                                 GET_FLAG(Cshared), GET_FLAG(Cstatic));
+                                 GET_FLAG(Cshared), GET_FLAG(Cstatic),
+                                 GET_FLAG(Cpie));
       outv[outc++] = xmprintf("%s/lib/crtn.o", topdir);
     }
   }
EOF

# Add support for --sysroot to ccwrap
patch -p0 << 'EOF'
--- sources/toys/ccwrap.c.orig2	2015-10-15 21:31:25.361957394 +0100
+++ sources/toys/ccwrap.c	2015-10-16 07:00:44.543547413 +0100
@@ -264,6 +264,14 @@
     topdir = temp;
   }
 
+  // Override header/library search path with sysroot?
+  for (i=1; i<argc; i++) {
+    if (!strncmp(argv[i], "--sysroot=", 10)) {
+      topdir = xmprintf("%s/usr", &argv[i][10]);
+      break;
+    }
+  }
+
   // Name of the C compiler we're wrapping.
   cc = getenv("CCWRAP_CC");
   if (!cc) cc = "rawcc";
EOF

# Add env var (CCWRAP_PASSTHRU) to make ccwrap pass args through unchanged
patch -p0 << 'EOF'
--- sources/toys/ccwrap.c.orig3	2015-10-17 20:23:53.503000770 +0100
+++ sources/toys/ccwrap.c	2015-10-17 20:47:06.200903574 +0100
@@ -276,6 +276,14 @@
   cc = getenv("CCWRAP_CC");
   if (!cc) cc = "rawcc";
 
+  // Pass through arguments if required
+  if (getenv("CCWRAP_PASSTHRU")) {
+    argv[0] = cc;
+    execvp(*argv, argv);
+    fprintf(stderr, "%s: %s\n", *argv, strerror(errno));
+    exit(1);
+  }
+
   // Does toolchain have a shared libcc?
   temp = xmprintf("%s/lib/libgcc_s.so", topdir);
   if (is_file(temp, 0)) SET_FLAG(Clibccso);
EOF

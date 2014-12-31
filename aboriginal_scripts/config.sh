#!/bin/bash
set -e
HERE="$(dirname "$0")"

cat >> sources/baseconfig-uClibc << EOF

UCLIBC_HAS_THREADS=y
UCLIBC_HAS_TLS=y
UCLIBC_HAS_STDIO_FUTEXES=y
UCLIBC_HAS_SSP=y
UCLIBC_USE_NETLINK=y
UCLIBC_SUPPORT_AI_ADDRCONFIG=y
UCLIBC_HAS_SHA256_CRYPT_IMPL=y
UCLIBC_HAS_SHA512_CRYPT_IMPL=y
EOF

ed -s sources/baseconfig-busybox << EOF
1i
CONFIG_NTPD=y
CONFIG_FEATURE_NTPD_SERVER=y
CONFIG_HWCLOCK=y
CONFIG_FEATURE_HWCLOCK_ADJTIME_FHS=y

.
w
EOF

sed -i '/LINUXTHREADS_OLD=y/d' sources/targets/x86_64

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

sed -i -e 's/uClibc++-0\.2\.2/uClibc++-0.2.4/g' -e 's/f5582d206378d7daee6f46609c80204c1ad5c0f7/ffadcb8555a155896a364a9b954f19d09972cb83/g' download.sh

cp "$HERE"/*.patch sources/patches
rm -f sources/patches/uClibc++-unwind-cxx.patch

sed -i 's/-nographic/-enable-kvm \0/g' system-image.sh

cat >> sources/baseconfig-linux << EOF

CONFIG_IP_MULTICAST=y
CONFIG_IPV6=y
CONFIG_BRIDGE=y
CONFIG_NETFILTER=y
CONFIG_BRIDGE_NETFILTER=y
CONFIG_NETFILTER_ADVANCED=y
CONFIG_NETFILTER_XTABLES=y
CONFIG_NF_CONNTRACK=y
CONFIG_NF_CONNTRACK_IPV4=y
CONFIG_NF_CONNTRACK_IPV6=y
CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y
CONFIG_NETFILTER_XT_MATCH_CONNTRACK=y
CONFIG_IP_NF_IPTABLES=y
CONFIG_BRIDGE_NF_EBTABLES=y
CONFIG_IP_NF_TARGET_MASQUERADE=y
CONFIG_NF_NAT=y
CONFIG_NF_NAT_IPV4=y
CONFIG_NF_NAT_NEEDED=y
CONFIG_MD=y
CONFIG_BLK_DEV_DM=y
CONFIG_DM_THIN_PROVISIONING=y
CONFIG_UTS_NS=y
CONFIG_IPC_NS=y
CONFIG_PID_NS=y
CONFIG_NET_NS=y
CONFIG_USER_NS=y
CONFIG_CGROUPS=y
CONFIG_CGROUP_CPUACCT=y
CONFIG_BLK_CGROUP=y
CONFIG_RESOURCE_COUNTERS=y
CONFIG_MEMCG=y
CONFIG_MEMCG_SWAP=y
CONFIG_BTRFS_FS=y
CONFIG_DEVPTS_MULTIPLE_INSTANCES=y
CONFIG_CGROUP_DEVICE=y
CONFIG_CGROUP_FREEZER=y
CONFIG_CGROUP_SCHED=y
CONFIG_MACVLAN=y
CONFIG_VETH=y
CONFIG_VLAN_8021Q=y
CONFIG_CGROUP_PERF=y
CONFIG_EXT4_FS_POSIX_ACL=y
CONFIG_EXT4_FS_SECURITY=y
CONFIG_NET_CORE=y
CONFIG_IP_NF_FILTER=y
CONFIG_MEMCG_SWAP_ENABLED=y
CONFIG_NETFILTER_NETLINK=y
CONFIG_NF_CT_NETLINK=y
CONFIG_NF_CONNTRACK_EVENTS=y
CONFIG_NF_CONNTRACK_TIMEOUT=y
CONFIG_NF_CT_NETLINK_TIMEOUT=y
CONFIG_DUMMY=y
CONFIG_SERIO=y
CONFIG_SERIO_I8042=y
CONFIG_SERIO_SERPORT=y
CONFIG_SERIO_LIBPS2=y
CONFIG_INPUT_KEYBOARD=y
CONFIG_KEYBOARD_ATKBD=y
CONFIG_USB_HID=m
CONFIG_USB_SUPPORT=y
CONFIG_USB_COMMON=y
CONFIG_USB_ARCH_HAS_HCD=y
CONFIG_USB=y
CONFIG_USB_ANNOUNCE_NEW_DEVICES=y
CONFIG_USB_DEFAULT_PERSIST=y
CONFIG_USB_DYNAMIC_MINORS=y
CONFIG_USB_XHCI_HCD=y
CONFIG_USB_XHCI_PLATFORM=m
CONFIG_USB_EHCI_HCD=y
CONFIG_USB_EHCI_ROOT_HUB_TT=y
CONFIG_USB_EHCI_TT_NEWSCHED=y
CONFIG_USB_EHCI_PCI=y
CONFIG_USB_EHCI_HCD_PLATFORM=y
CONFIG_USB_OHCI_HCD=y
CONFIG_USB_OHCI_HCD_PCI=y
CONFIG_USB_OHCI_HCD_PLATFORM=y
CONFIG_USB_UHCI_HCD=y
CONFIG_USB_STORAGE=y
CONFIG_USB_SERIAL=y
CONFIG_USB_SERIAL_CONSOLE=y
CONFIG_USB_SERIAL_GENERIC=y
CONFIG_USB_SERIAL_FTDI_SIO=y
CONFIG_USB_SERIAL_PL2303=y
CONFIG_HID_GENERIC=y
CONFIG_BLK_DEV_INITRD=y
CONFIG_SMP=y
CONFIG_EFI=y
CONFIG_EFI_STUB=y
CONFIG_FB=y
CONFIG_FB_EFI=y
CONFIG_FRAMEBUFFER_CONSOLE=y
CONFIG_RTC_SYSTOHC=y
CONFIG_RTC_DRV_CMOS=y
EOF

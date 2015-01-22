#!/bin/bash
set -e
source init_config

# mount builtin filesystems
busybox mount -t proc proc /proc
busybox mount -t sysfs sys /sys
busybox mount -t devtmpfs dev /dev
toybox ln -s /proc/self/fd /dev

# make sure output goes to all consoles
exec > /dev/kmsg 2>&1

# log config options
echo "btrfs_raid_level: $btrfs_raid_level"

# sgdisk needs mtab
toybox ln -s /proc/mounts /etc/mtab

# find root device
unset root_part
unset root_type
highest_generation=-1
btrfs_partitions=()
echo "searching for root partition..."
while true; do
  for dev in /dev/[hsv]d?; do
    if [ "$dev" != '/dev/[hsv]d?' ]; then
      name="$(sgdisk -i 3 "$dev" | toybox grep 'Partition name' | toybox cut -d ' ' -f 3-)"
      if [ "$name" = "'heddle_root'" ] ||
         ( [ "$name" = "'Linux filesystem'" ] &&
           ( [ "$(e2label "${dev}3")" = "heddle_root" ] ||
             [ "$(btrfs filesystem label "${dev}3")" = "heddle_root" ] ) ); then
        # expand partition to fill disk
        toybox cat <<EOF | parted ---pretend-input-tty "$dev" resizepart 3 100%
fix
3
100%
EOF
        parted "$dev" print
        # check and repair filesystem
        fsck -fy "${dev}3" || if [ $? -ne 1 ]; then exit $?; fi
        # find generation/mount count
        generation="$(tune2fs -l "${dev}3" | toybox grep 'Mount count:' | busybox awk '{print $NF}')"
        if [ -n "$generation" ]; then
          dev_type=ext4
          # resize filesystem
          resize2fs "${dev}3"
        else
          generation="$(btrfs-show-super "${dev}3" | toybox grep '^generation' | busybox awk '{print $NF}')"
          if [ -n "$generation" ]; then
            dev_type=btrfs
            btrfs_partitions=("${btrfs_partitions[@]}" "${dev}3")
          else
            continue
          fi
        fi
        # partition with highest mount count will be root
        if [ "$generation" -gt "$highest_generation" ]; then
          root_part="${dev}3"
          root_type="$dev_type"
          highest_generation="$generation"
        fi
      fi
    fi
  done
  if [ -n "$root_part" ]; then
    echo "root partition: $root_part"
    echo "root type: $root_type"
    break
  fi
  toybox sleep 1
done

# scan btrfs partitions before mounting
if [ "$root_type" = btrfs ]; then
  btrfs device scan
fi

# mount root
busybox mount "$root_part" /newroot

if [ "$root_type" = btrfs ]; then
  # add partitions to RAID set if required
  unset btrfs_raid_changed
  if [ -n "$btrfs_raid_level" ]; then
    for part in "${btrfs_partitions[@]}"; do
      if btrfs device add -f "$part" /newroot; then # false if mounted
        echo "added RAID partition: $part"
        btrfs_raid_changed=1
      fi
    done
  fi
  # resize filesystem
  dev=1
  while btrfs filesystem resize $dev:max /newroot; do
    dev=$((dev + 1))
  done
  # balance data for RAID sets if required
  if [ -n "$btrfs_raid_level" -a -n "$btrfs_raid_changed" ]; then
    # fails for a single disk
    btrfs balance start -dconvert=raid$btrfs_raid_level /newroot || true
  fi
  # display filesystem info
  btrfs filesystem show
  btrfs filesystem df /newroot
fi

echo "cmdline: $(toybox cat /proc/cmdline)"
boot="$(toybox grep -oE 'heddle_boot=[^ ]+' /proc/cmdline | toybox head -n 1 | busybox sed 's/heddle_boot=//')"
if [ -z "$boot" ]; then
  boot=dist
  echo "available updates:"
  busybox find /newroot/updates -type d -mindepth 1 -maxdepth 1 | busybox sed 's@^/newroot/updates/@@g' | natsort
  update="$(toybox grep -oE 'heddle_update=[^ ]+' /proc/cmdline | toybox head -n 1 | busybox sed 's/heddle_update=//')"
  if [ -z "$update" ]; then
    update="$(toybox ls /newroot/updates/*/BOOT | natsort -r | toybox head -n 1 | busybox awk -F / '{print $(NF-1)}')"
  fi
  if [ -n "$update" ]; then
    if [ -d "/newroot/updates/$update" -a "$update" != / ]; then
      echo "selected update: $update"
      update="updates/$update"
      if [ -f "/newroot/$update/cmdline" ]; then
        cmdline="/newroot/$update/cmdline"
      else
        cmdline=/proc/cmdline
      fi
      kexec -l "/newroot/$update/bzImage" "--initrd=/newroot/$update/initrd.img" --command-line="heddle_boot=$update $(toybox cat "$cmdline")"
      toybox umount /newroot /proc /sys # using /dev/kmsg
      kexec -e
    elif toybox grep -q heddle_fallback=1 /proc/cmdline; then
      echo "update '$update' not found, booting '$boot'"
    else
      echo "update '$update' not found, press return to boot '$boot'"
      read
    fi
  fi
fi
echo "boot: $boot"

toybox umount /proc /sys

# toybox switch_root doesn't chroot
toybox cat > /newroot/init <<EOF
#!/newroot/$boot/bash
exec "/newroot/$boot/toybox" chroot /newroot "/$boot/init.sh"
EOF
toybox chmod +x /newroot/init
exec toybox switch_root /newroot init

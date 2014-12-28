#!/bin/bash
set -e

# mount builtin filesystems
busybox mount -t proc proc /proc
busybox mount -t devtmpfs dev /dev
toybox ln -s /proc/self/fd /dev

# make sure output goes to all consoles
exec > /dev/kmsg 2>&1

# determine btrfs RAID options
btrfs_raid_level="$(toybox grep -oE 'heddle_btrfs_raid_level=[0-9]+' /proc/cmdline | toybox tail -n 1 | busybox sed 's/heddle_btrfs_raid_level=//')"
btrfs_balance="$(toybox grep -oE 'heddle_btrfs_balance=[0-9]+' /proc/cmdline | toybox tail -n 1 | busybox sed 's/heddle_btrfs_balance=//')"
echo "btrfs_raid_level: $btrfs_raid_level"
echo "btrfs_balance: $btrfs_balance"

# sgdisk needs mtab
toybox ln -s /proc/mounts /etc/mtab

# find root device
unset root_part
unset root_type
highest_generation=-1
btrfs_partitions=()
for dev in /dev/[hsv]d?; do
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
done
if [ -z "$root_part" ]; then
  echo "no root partition found" 1>&2
  exit 1
fi
echo "root partition: $root_part"
echo "root type: $root_type"

# scan btrfs partitions before mounting
if [ "$root_type" = btrfs ]; then
  btrfs device scan
fi

# mount root
busybox mount "$root_part" /newroot

if [ "$root_type" = btrfs ]; then
  # add partitions to RAID set if required
  if [ -n "$btrfs_raid_level" ]; then
    for part in "${btrfs_partitions[@]}"; do
      if btrfs device add -f "$part" /newroot; then # false if mounted
        echo "added RAID partition: $part"
      fi
    done
  fi
  # resize filesystem
  dev=1
  while btrfs filesystem resize $dev:max /newroot; do
    dev=$((dev + 1))
  done
  # balance data if required
  if [ -n "$btrfs_raid_level" -a -n "$btrfs_balance" ]; then
    # may have been interrupted by reboot so start if required
# TODO: Is cmdline right place to put raid options?
# what if want to change later when upgrading? Maybe it should be part
# of the dist - top of this script perhaps!
    if [ "$btrfs_balance" -eq 1 ]; then
      btrfs balance start -dconvert=raid$btrfs_raid_level /newroot || true
    elif [ "$btrfs_balance" -eq 2 ]; then
      btrfs balance start -dconvert=raid$btrfs_raid_level /newroot &
    fi
  fi
  # display filesystem info
  btrfs filesystem show
  btrfs filesystem df /newroot
fi

toybox umount /proc
boot=dist
# toybox switch_root doesn't chroot
toybox cat > /newroot/init <<EOF
#!/newroot/$boot/bash
exec "/newroot/$boot/toybox" chroot /newroot "/$boot/init.sh"
EOF
toybox chmod +x /newroot/init
exec toybox switch_root /newroot init

[![Build Status](https://circleci.com/gh/davedoesdev/heddle.svg?style=svg)](https://circleci.com/gh/davedoesdev/heddle) [![Successful builds with links to disk images](http://rawgit.davedoesdev.com/davedoesdev/heddle/master/builds.svg)](http://rawgit.davedoesdev.com/davedoesdev/heddle/master/.circle-ci/builds.html)

Heddle is a Linux distribution for running [Docker](https://www.docker.com/) and [QEMU/KVM](http://www.qemu.org).

- Built from scratch using [Aboriginal Linux](http://landley.net/aboriginal/) to bootstrap the build.

- Completely automated build. Build Heddle images locally or on [Travis CI](https://travis-ci.org/davedoesdev/build-aboriginal-travis), [Semaphore CI](https://semaphoreci.com/davedoesdev/heddle) and [CircleCI](https://circleci.com/gh/davedoesdev/heddle).

- Builds only those packages necessary in order to get Docker and KVM up and running.

- Supports in-place, atomic update of the entire base operating system and all the packages. No dynamic package management required.

- GPT- or MBR-based images with Btrfs or Ext4 filesystems. RAID supported with Btrfs.

- Simple init system based on [runit](http://smarden.org/runit/). Heddle is a systemd-free zone!

- Currently supported architectures: x86_64 and armv6l (ARM Versatile). Other ARM targets should now be possible.

- [musl](http://www.musl-libc.org/) and [uClibc++](http://cxx.uclibc.org/) used throughout. No glibc.

- Easily customizable using configuration scripts, for example to build additional kernel drivers.

## Installing Heddle

### Pre-built images

First you need a Heddle image. Every time a commit is made to this repository, Heddle is built on SemaphoreCI and CircleCI. Successful builds are listed [here](http://rawgit.davedoesdev.com/davedoesdev/heddle/master/.circle-ci/builds.html). For each build, you can download the following artifacts:

- Build output archives
  - `heddle-[commitid]-gpt-btrfs-x86_64.tar.xz`
  - `heddle-[commitid]-gpt-ext4-x86_64.tar.xz`
  - `heddle-[commitid]-mbr-btrfs-x86_64.tar.xz`
  - `heddle-[commitid]-mbr-ext4-x86_64.tar.xz`
- Build log
  - `heddle-[commitid]-log-x86_64.txt.xz`
- Source archive
  - `heddle-[commitid]-src-x86_64.tar`

Each build output archive contains the following files:

- `gen/x86_64/dist/heddle.img` - Raw bootable disk image, partitioned with GPT or MBR and using a Btrfs or Ext4 filesystem. GPT images require EFI to boot.
- `gen/x86_64/dist/boot_heddle.sh` - Shell script to boot the disk image in KVM.
- `gen/x86_64/dist/in_heddle.sh` - Shell script for automating customisation of the disk image.
- `gen/x86_64/dist/update` - Directory containing files necessary to [update an existing Heddle installation](#updating-heddle) to this build.

`heddle.img` is a sparse file so you should extract the archive using a version of tar which supports sparse files, for example `bsdtar` or recent versions of GNU tar.

When writing `heddle.img` to a disk (or USB stick), using a program which supports sparse device writes will be faster than one which doesn't. For example, using [ddpt](http://sg.danny.cz/sg/ddpt.html) to write `heddle.img` to `/dev/sdb`:

```shell
ddpt if=heddle.img of=/dev/sdb bs=512 bpt=128 oflag=sparse
```

Don't worry that `heddle.img` doesn't fill the entire disk. Heddle detects this when it boots and resizes its main partition to fill the disk.

Once you've written `heddle.img` onto a disk, put the disk into a computer and boot it. You should see the normal Linux kernel boot messages and then a login prompt. There is one user account: `root` (password `root`). There are also two virtual terminals if you want two logon sessions.

The `shutdown` command stops all services, calls `sync`, remounts all filesystems read-only and then calls `poweroff`. To reboot instead, use `-r`. It waits for 7 seconds for services to exit. Use `-t` to change this timeout.

Alternatively, run `boot_heddle.sh` to run the image in KVM first. You'll get a login prompt and two virtual terminals like when booting on real hardware.

If you want to use a script to customise the image, see [Run-time customisation](#run-time-customisation).

### Release builds

From time-to-time release branches will be forked from `master` and named `v0.0.1`, `v0.0.2` etc.

The [build list](http://rawgit.davedoesdev.com/davedoesdev/heddle/master/.circle-ci/builds.html) shows the branch name for each build and can also show only release builds (click the __Release branches__ radio button).

## Building Heddle

### Install build dependencies

To build a Heddle image, you'll need the following things:

- Basic Unix shell utilities
- Basic build tools such as GCC and GNU Make
- [Ext2/3/4 tools](http://home.earthlink.net/~k_sheff/sw/e2tools/)
- [QEMU/KVM](http://www.qemu.org)
- [Parted](http://www.gnu.org/software/parted/)
- [MS-DOS tools](http://www.gnu.org/software/mtools/)
- [Syslinux](http://www.syslinux.org) (MBR images only)
- [SquashFS tools](https://github.com/plougher/squashfs-tools)

On Ubuntu you can do this:

```shell
sudo apt-get install coreutils build-essential e2tools qemu-kvm parted mtools syslinux syslinux-common squashfs-tools
```

When building GPT images, the Heddle build scripts automatically fetch the
[rEFInd boot manager](http://www.rodsbooks.com/refind/).

### Get the source

First get the Aboriginal Linux source code. Heddle requires [Aboriginal Linux 1.4.5](http://landley.net/aboriginal/downloads/aboriginal-1.4.5.tar.gz). Untar the archive to create an `aboriginal-1.4.5` directory.

Then fetch the Heddle source:

```shell
git clone https://github.com/davedoesdev/heddle.git
```

You should have a `heddle` directory alongside the `aboriginal-1.4.5` directory (although the two don't have to live in the same place).

### Build Aboriginal Linux

```shell
cd aboriginal-1.4.5
../heddle/aboriginal_scripts/config.sh
./build.sh x86_64
```

Of course, if the Heddle source lives somewhere else (e.g. you're [building an extension](#extending-heddle)) then replace `../heddle` with its location.

You can change the kernel configuration by editing `../heddle/aboriginal_scripts/config/linux` and `../heddle/aboriginal_scripts/config/linux-x86_64` (or at the equivalent locations in your extension directory if you're building an extension).

### Build Heddle packages

```shell
../heddle/image_scripts/make_build_and_home_images.sh
../heddle/aboriginal_scripts/build_heddle.sh
```

The first script downloads the Heddle packages (listed in the `../heddle/image_scripts/packages` script) and puts them into a disk image (`../heddle/gen/build.img`) together with the `packages` script. It also creates another disk image (`../heddle/gen/x86_64/images/home.img`) which is used when building Heddle...

The second script builds Heddle by first booting Aboriginal Linux in KVM. It then mounts `build.img` and `home.img` and builds each package in turn by doing the following:

1. Extract the source for the package from `build.img` onto `home.img`.
2. Execute the instructions listed for the package in the `packages` script. This includes installing the package to a directory named `install` on `home.img`.
3. Create a `.built` file for the package to indicate that the build was successful. This means subsequent builds can skip packages that have already been built.

This will take some time. My Intel Core i5-4300M does it in about 25 minutes.

### Running Heddle

You're now in a position to run Heddle in KVM. First you need to run:

```shell
../heddle/image_scripts/make_run_and_extra_images.sh [-m] [-e]
```

This creates two more disk images, `../heddle/gen/x86_64/images/run.img` and `../heddle/gen/x86_64/images/extra.img`. `run.img` contains scripts for running Heddle once the kernel has booted. `extra.img` is a large (sparse) disk image which is available for storing data (e.g. Docker images).

By default, `extra.img` uses GPT partitioning and is formatted with Btrfs. Supply `-m` for MSDOS paritions and `-e` for an Ext4 filesystem.

Next you need to run:

```shell
../heddle/aboriginal_scripts/run_heddle.sh -p
```

This runs Heddle in KVM and waits until all Heddle services indicate they have performed any one-time initialisation steps they require. You can find Heddle services in `../heddle/chroot/service`. Currently, there is one service which has a one-time initialisation step: `prepare_docker`. It creates the Docker `scratch` image.

Finally, if you want to run Heddle and play around before creating a bootable image then you can run:

```shell
../heddle/aboriginal_scripts/run_heddle.sh
```

You'll be able to login (user `root`, password `root`) and use any of the Heddle packages. If you want to customise Heddle, see [here](#customisingheddle).

### Creating a bootable image

To create a single, bootable image for distribution (writing to USB stick, imaging to disk etc), run the following:

```shell
../heddle/image_scripts/make_dist_and_heddle_images.sh
../heddle/aboriginal_scripts/dist_heddle.sh
```

The first command creates the distribution image (`../heddle/gen/x86_64/images/heddle.img`) as well as another image (`../heddle/gen/x86_64/images/dist.img`) which contains further scripts for populating `heddle.img` from within Heddle itself.

The second command runs KVM, mounts `heddle.img` and `dist.img` and runs the scripts on `dist.img`. When this command finishes, `heddle.img` will be bootable and ready for use.

You'll also find files for [upgrading existing Heddle installations](#updating-heddle) in `../heddle/gen/x86_64/dist/update`. The `dist` folder there gets archived when producing the [pre-built images](#pre-built-images) (it contains a symbolic link to `heddle.img` as well).

### Booting the image

You can write the distribution image you created to disk just like a [pre-built image](#pre-built-images), for example:

```shell
ddpt if=../heddle/gen/x86_64/images/heddle.img of=/dev/sdb bs=512 bpt=128 oflag=sparse
```

You can also test it in KVM by running the following command:

```shell
../heddle/image_scripts/boot_heddle.sh
```

## Building for different architectures

By default, Heddle is built for the `x86_64` architecture. To build for a different architecture, you must:

- Create an Aboriginal Linux target for the architecture. Each target is a separate file in the `sources/targets` directory of the Aboriginal Linux source code. I have successfully built using the existing `armv6l` target (ARM Versatile board).

- Create a kernel configuration file for your architecture in the `aboriginal_scripts/config` directory. The name of this file should begin with `linux-` and end with the architecture name (the `armv6l` one is called `linux-armv6l`).

- Run `gen/new_arch.sh` and pass it the name of your architecture as an argument. This creates a directory structure under `gen` for your architecture.

- In `image_scripts/packages`, make any adaptations you need when building Heddle packages. Usually the easiest way to do this is build without any adaptations for your architecture and fix it up as things break. Search for `armv6l` in this file to see the adaptations I had to make.

- Find a suitable bootloader for your architecture. For `armv6l` I chose [U-Boot](http://www.denx.de/wiki/U-Boot), which is in `image_scripts/packages` but currently built on `armv6l` only. You can also see special instructions for `armv6l` in `aboriginal_scripts/dist_heddle.sh` and `runtime_scripts/dist.sh` to copy `u-boot.bin` out of `home.img` and make a `boot.kbin` image suitable for booting on QEMU. 

Most of the build scripts take an optional architecture argument which defaults to `x86_64`. So to build for `armv6l` you'd do the following:

1. Build Aboriginal Linux. You can re-use your existing Aboriginal Linux source directory.
  1. `cd aboriginal-1.4.5`
  2. `./build.sh armv6l`
2. Build Heddle. You can re-use your existing Heddle source directory - the new images will be written to `gen/armv6l/images`.
  1. `../heddle/image_scripts/make_build_and_home_images.sh armv6l`
  2. `../heddle/aboriginal_scripts/build_heddle.sh armv6l` (this will take many hours because it uses QEMU emulation)
  3. `../heddle/image_scripts/make_run_and_extra_images.sh armv6l`
  4. `../heddle/aboriginal_scripts/run_heddle.sh -p armv6l`
  5. `../heddle/image_scripts/make_dist_and_heddle_images.sh armv6l`
  6. `../heddle/aboriginal_scripts/dist_heddle.sh armv6l`

This will generate `../heddle/gen/armv6l/images/heddle.img` and `../heddle/gen/armv6l/images/boot.kbin` which you can then write to disk or boot using:

```shell
../heddle/image_scripts/boot_heddle.sh armv6l
```

Of course, if the Heddle source lives somewhere else (e.g. you're [building an extension](#extending-heddle)) then replace `../heddle` with its location.

## RAID (Btrfs only)

Heddle can configure a RAID array automatically when it boots. Just write the same `heddle.img` to each disk in your computer and boot from one of them.

You can add a disk at any time to create or extend an array - just write `heddle.img` to the disk and then attach the disk to your computer.

Here are some points you should know about the Heddle boot procedure:

- Heddle is always booted from a FAT32 partition contained in `heddle.img`. 
- The boot script on this partition finds all the Heddle disks attached to the computer and chooses the one with the highest generation (Btrfs) or mount (Ext4) count as the root.
- When using Btrfs, all other Heddle disks are automatically added to the root's RAID set. Any existing data on those disks will be lost when they're first added to the set!
- It's probably best to use the same `heddle.img` on all disks attached to your computer so you have a consistent boot environment regardless of which disk your computer uses to boot from. Heddle has a [built-in mechanism for running updates](#updating-heddle), which you should use if you want to run later versions.

The RAID level defaults to 0 (striped). You can change it by editing `runtime_scripts/initrd_config.sh` before you run `image_scripts/make_dist_and_heddle_images.sh` and `aboriginal_scripts/dist_heddle.sh`.

## Updating Heddle

To update an existing Heddle installation to a newer version:

- Copy the contents of the `update` directory for your architecture (e.g. `gen/x86_64/dist/update`) into a subdirectory under `/updates` on your Heddle installation.
- Create an empty file named `BOOT` in the subdirectory.
- Reboot your Heddle box.

How you transfer the update files is up to you. You could use a USB stick or place them on a local Web server, for example. Please note that Heddle perform no verification on the files. Again, it's up to you to ensure you transfer them securely if your box in on an untrusted network and verify their integrity if necessary.

If you have more than one update (subdirectory) in `/updates`, Heddle chooses the last one according to [natural sort order](http://sourcefrog.net/projects/natsort/).

It's up to you how you name the subdirectories (e.g. by version number or `update1`, `update2`, ...) but remember the last one according to natural sort order is booted by default. To prevent problems with interrupted transfers you should copy the update into a directory outside `/updates` first and only `touch BOOT` inside it once the transfer is complete.

Here's how the update system works:

- Heddle boots from a FAT32 partition in `heddle.img`.
- The boot script on this partition finds all the Heddle disks attached to the computer and chooses the one with the highest generation (Btrfs) or mount (Ext4) count as the root.
- When using Btrfs, all other Heddle disks are automatically added to the root's RAID set.
- The boot script checks for subdirectories under `/updates` on the root which contain a `BOOT` file. If there are such subdirectories:
  - It natural sorts them and selects the last one.
  - It uses [`kexec`](http://en.wikipedia.org/wiki/Kexec) to boot the new kernel with the new initial ramdisk, both loaded from the selected update subdirectory.
  - If the selected subdirectory contains a file called `cmdline` then its contents are used as the kernel parameters for `kexec`.

You can use the following kernel boot parameters to control the boot process:

- `heddle_boot=dist` - boot the original version of Heddle installed on the machine.
- `heddle_update=<update-name>` - which update to boot (e.g. `heddle_update=update1`).
- `heddle_fallback=1` - if the update specified by `heddle_update` doesn't have a `BOOT` file in its subdirectory then automatically boot the original version of Heddle installed on the machine. Otherwise, you'll be prompted before booting the original version.
- `heddle_update=/` - use this if you want to see the list of installed updates without automatically booting Heddle. You'll be prompted before booting the original version of Heddle installed on the machine which gives you a chance to reboot instead and specify one of the available updates on the next boot.

You can specify these parameters when booting Heddle by interrupting the [rEFInd boot manager](http://www.rodsbooks.com/refind/) (GPT images) or [Syslinux boot loader](http://www.syslinux.org) (MBR images). Press F2 to interrupt rEFInd and then F2 again to edit the boot parameters. Press Tab to interrupt Syslinux and edit the boot parameters.

## Serial console

Heddle copies all boot output to `ttyS0` (first serial port) and runs a login prompt on `ttyS0` once the boot process is complete. The Linux kernel is configured with drivers for the following serial ports by default:

- Standard 8250- and 16550-based ports (RS-232).
- FTDI-based USB to RS232 adapters.
- PL2303-based USB to RS232 adapters.

If you need a different driver for your serial port, add it to `aboriginal_scripts/config/linux` (or the kernel configuration for your architecture in the same directory).

## NTP

Heddle runs an NTP client (BusyBox `ntpd`) which gets its time from the `heddle` vendor pool zone (`0.heddle.pool.ntp.org`, `1.heddle.pool.ntp.org`, `2.heddle.pool.ntp.org` and `3.heddle.pool.ntp.org`).

`ntpd` is launched in `chroot/service/ntpd/run`. If you want to run it as a server too on your network, add the `-l` flag.

If you're running a Heddle server on the public Internet, please consider [adding it to the NTP pool](http://www.pool.ntp.org/join.html). `pool.ntp.org` does a great job and always needs more servers.

## [Smartmontools](https://www.smartmontools.org/)

Heddle comes with `smartctl` and `smartd` for monitoring your machine's disks. `smartd` is _not_ started unless its configuration file exists at `/etc/smartd.conf`. The stock configuration file is available at `/home/install/etc/smartd.conf`.

`mail` and `sendmail` are _not_ available for sending alerts from `smartd`. An alternative is to write a Python script to do the same. The Python [`sender`](http://sender.readthedocs.org/en/latest/) module is available to make this easier.

## Customising Heddle

### Run-time customisation

You can of course use `boot_heddle.sh` to run `heddle.img` in KVM, login and make changes by hand. However, doing this more than a couple of times will become tiresome and should be scripted.

To automate customisation of a Heddle image, use `in_heddle.sh` (in the same directory as `boot_heddle.sh`).

It boots the image in KVM, forwards its standard input onto Heddle and then powers down the virtual machine. The first two lines must be a user name and password for logging in. The remaining lines are piped to `bash` running in the virtual machine.

For example, to login as `root`, change `root`'s password, add a user called `heddle` and list all Docker images on the system:

```shell
in_heddle.sh << 'EOF'
root
root
useradd -G docker heddle
chpasswd << 'EOP'
root:Password1
heddle:Password2
EOP
docker images
EOF
```

Note that `boot_heddle.sh` and `in_heddle.sh` also pass their arguments (after the first one which is the architecture and defaults to `x86_64`) to KVM. So if you need to transfer lots of data into the image you could do something like this:

```shell
dd if=/dev/zero of=my_disk.img bs=1 seek=1G count=0
mkfs.ext4 -F -O ^has_journal my_disk.img
e2cp some_files* my_disk.img:
in_heddle.sh x86_64 -hdb my_disk.img << 'EOF'
root
root
mkdir my_disk
mount /dev/[hsv]db my_disk
cp my_disk/* /to/wherever
EOF
```

(assuming `root`'s password hasn't been changed yet).

### Build-time customisation

If you're building Heddle yourself, you can also customise Heddle in these places:

- `aboriginal_scripts/config/` - Configuration files for the kernel, busybox and uClibc.
- `image_scripts/packages` - Details of packages to build. To add a package `FOO`, you should define the following variables:
  - `URL_FOO`: Location of the source archive for `FOO`.
  - `SRC_FOO`: What to save the source archive as locally when it's downloaded.
  - `CHK_FOO`: Digest of the source archive for verifying the download.
  - `SUM_FOO`: Digest method (e.g. `sha256`).
  - `BLD_FOO()`: Bash function which when executed should build and install foo. The install directory root will be in `$INSTALL_DIR`.
  - `PST_FOO()`: Optional bash function which sets any runtime configuration (e.g. environment variables) necessary to run `FOO`. This will be run every time your Heddle image boots.
- `chroot/` - When Heddle boots, it sets up a chroot to this directory and then merges in the (read-only) Aboriginal Linux root filesystem. If you add directories or files to `chroot`, you'll see them in the final image.
  - You can add extra services to run when Heddle starts in `chroot/service/`. See the existing services for examples or read the [runit documentation](http://smarden.org/runit/). Your service should terminate when sent a `TERM` signal. If you leave processes running then `shutdown` won't be able to re-mount your disks in read-only mode before powering off the machine.
- You can [write a Heddle extension](#extending-heddle).

Of course, feel free to fork the Heddle repository and make changes.

### Boot-time customisation

You can change Heddle's kernel command line by editing `boot/refind.conf` (GPT images) or `boot/syslinux.cfg` (MBR images).

## Security

Out of the box, Heddle has a single user account: `root` (password `root`). You should of course change `root`'s password using `passwd`. The default `umask` for `root` is `0022`.

You can create new users using `useradd`. The default `umask` for non-`root` users is `0027`. A group with the same name as the user will be created and set as the user's primary group.

Users must be in the (builtin) `kvm` group to run KVM and in the (builtin) `docker` group to run Docker. However, be aware that the `docker` group [is root-equivalent](https://docs.docker.com/articles/security/#docker-daemon-attack-surface) so only add trusted users to it.

There is no `sudo`. The following services run as `root` on boot:

- `agetty-serial` - login prompt on the serial port
- `agetty-tty1` - login prompt on first virtual terminal
- `agetty-tty2` - login prompt on second virtual terminal
- `dhcpcd` - [DHCP client](http://roy.marples.name/projects/dhcpcd/index)
- `docker` - Docker daemon (listening on Unix domain sockets only)
- `ntpd` - BusyBox NTP daemon (operating in client mode only)
- `prepare` - Waits for all `prepare_*` services to finish (only runs for `run_heddle.sh -p)`
- `prepare_docker` - Creates the Docker `scratch` image (`run_heddle.sh -p` only)

You should prefer to run additional services using Docker or KVM.

There are no certificate authority (CA) certificates in Heddle images by default (the Heddle build and prepare stages don't need access to HTTPS sites). If you need CA certificates, it's up to you to manage them yourself. Make sure you have a strategy in place for updating certificates once they're in place and for handling subsequent revocations. It's also up to you to manage any certificates you put into Docker or KVM images.

Docker and cURL are configured to look for a CA certificate bundle file at `/etc/ssl/certs/ca-certificates.crt`. Heddle has the [`extract-nss-root-certs`](https://github.com/agl/extract-nss-root-certs) tool installed to help with generating a bundle file given the list maintained by Mozilla as input. The Mozilla list should be downloaded over HTTPS and then transferred into your Heddle image or onto a machine running Heddle. For example:

```shell
(
echo root
echo root
echo "cat > /tmp/certdata.txt << 'EOF'"
curl https://hg.mozilla.org/mozilla-central/raw-file/tip/security/nss/lib/ckfw/builtins/certdata.txt
echo EOF
echo rm -rf /etc/ssl/certs
echo mkdir -p /etc/ssl/certs
echo "extract-nss-root-certs /tmp/certdata.txt > /etc/ssl/certs/ca-certificates.crt"
echo rm -f /tmp/certdata.txt
) | in_heddle.sh
```

Alternatively you could copy the CA certificate bundle from another Linux distribution.

Note that without CA certificates, `docker search`, `docker pull` etc will fail. If you don't want to manage CA certificates, an alternative approach is to `docker pull` the Docker image on some other machine, export it to a file using `docker save`, transfer it to your Heddle machine or Heddle image and then `docker load` it. You could put the Docker image into your Heddle image using [`in_heddle.sh` with a disk image](#run-time-customisation) or if you're [extending Heddle](#extending-heddle) then you could do it as part of your build - see Dobby's [`packages`](https://github.com/davedoesdev/dobby/blob/master/image_scripts/packages) and [`prepare_weave`](https://github.com/davedoesdev/dobby/blob/master/chroot/service/prepare_weave/run) service files for an example.

## Extending Heddle

Heddle's build-time extension mechanism provides a way to add packages and change build configuration without changing the Heddle source itself.

Heddle scripts check whether the environment variable `HEDDLE_EXT_DIR` is set. This should point to an extension directory outside the Heddle source code directory. 

If `HEDDLE_EXT_DIR` is set then Heddle scripts look for files in the extension directory in addition to files in the Heddle source code directory. Here's where you can put files in your extension directory so the Heddle scripts pick them up:

- `aboriginal_scripts/config/` - BusyBox, uClibc and Linux kernel configuration files
- `image_scripts/packages` - package definitions
- `chroot/` - files to add to the root filesystem, including services in `chroot/service`
- `boot/` - boot loader configuration files (`refind.conf`, `syslinux.cfg`)

You should run `gen/new_arch.sh` (defaults to `x86_64`), fetch and extract a new copy of the Aboriginal Linux source and then follow the Heddle build instructions from [building Aboriginal Linux](#build-aboriginal-linux) onwards. Images will be written under `$HEDDLE_EXT_DIR/gen`.

For an example Heddle extension, see [Dobby](https://github.com/davedoesdev/dobby).

## Licences

Heddle is made up of the following:

- [Aboriginal Linux](http://landley.net/aboriginal/), which is licensed under GPL version 2.

- Aboriginal Linux's component packages, which are redistributed under their respective licences. See the Aboriginal Linux [package download script](http://landley.net/hg/aboriginal/file/default/download.sh) for the list of packages versions and URLs.

- Heddle's component packages, which are redistributed under their respective licences. See the Heddle [package download script](image_scripts/packages) for the list of package versions and URLs.

- Original works developed as part of the Heddle project (including scripts, source code and documentation). These are licensed under [GPL version 2](LICENCE).


[![Build Status](https://circleci.com/gh/davedoesdev/heddle.svg?style=svg)](https://circleci.com/gh/davedoesdev/heddle) [![Successful builds with links to disk images](http://githubraw.herokuapp.com/davedoesdev/heddle/master/builds.svg)](http://githubraw.herokuapp.com/davedoesdev/heddle/master/.circle-ci/builds.html)

Heddle is a Linux distribution for running [Docker](https://www.docker.com/) and [Capstan](http://osv.io/capstan/) applications.

- Built from scratch using [Aboriginal Linux](http://landley.net/aboriginal/) to bootstrap the build.

- Completely automated build. Build Heddle images locally or on [Travis CI](https://travis-ci.org/davedoesdev/build-aboriginal-travis) and [CircleCI](https://circleci.com/gh/davedoesdev/heddle).

- Builds only those packages necessary in order to get Docker and Capstan up and running.

- Supports in-place, atomic upgrade of the entire base operating system and all the packages. No dynamic package management required.

- GPT- or MBR-based images with Btrfs or Ext4 filesystems. RAID supported with BTRFS.

- Simple init system based on [runit](http://smarden.org/runit/). Heddle is a systemd-free zone!

- Currently supported architectures: x86_64 and armv6l (ARM Versatile). Other ARM targets should now be possible.

- [uClibc](http://www.uclibc.org/)/[uClibc++](http://cxx.uclibc.org/) used throughout. No glibc.

- Easily customizable using configuration scripts, for example to build additional kernel drivers.

## Installing Heddle

[Pre-built images](#prebuiltimages)
[Release builds](#releasebuilds)
[Building Heddle](#buildingheddle)

### Pre-built images

First you need a Heddle image. Every time a commit is made to this repository, Heddle is built on CircleCI. Successful builds are listed [here](http://githubraw.herokuapp.com/davedoesdev/heddle/master/.circle-ci/builds.html). For each build, you can download the following artifacts:

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

- `gen/x86_64/dist/heddle.img` - Raw bootable disk image, partitioned with GPT or MBR and using a Btrfs or Ext4 filesystem.
- `gen/x86_64/dist/boot_heddle.sh` - Shell script to boot the disk image in KVM.
- `gen/x86_64/dist/update` - Directory containing files necessary to [upgrade an existing Heddle installation](#updatingheddle) to this build.

`heddle.img` is a sparse file so you should extract the archive using a version of tar which supports sparse files, for example `bsdtar` or recent versions of GNU tar.

When writing `heddle.img` to a disk (or USB stick), using a program which supports sparse device writes will be faster than one which doesn't. For example, using [ddpt](http://sg.danny.cz/sg/ddpt.html) to write `heddle.img` to `/dev/sdb`:

```shell
ddpt if=heddle.img of=/dev/sdb bs=512 bpt=128 oflag=sparse
```

Don't worry that `heddle.img` doesn't fill the entire disk. Heddle detects this when it boots and resizes its main partition to fill the disk.

Once you've written `heddle.img` onto a disk, put the disk into a computer and boot it. You should see the normal Linux kernel boot messages and then a login prompt. There are two existing accounts: `root` (password `root`) and `heddle` (password `heddle`). There are also two virtual terminals if you want two logon sessions.

There are no shutdown scripts - use `poweroff` or `reboot`. Software should be resilient to sudden failure so I've made that the normal operation. `fsck` is run on every boot.

## Release builds

From time-to-time release branches will be forked from `master` and named `v0.0.1`, `v0.0.2` etc.

The [build list](http://githubraw.herokuapp.com/davedoesdev/heddle/master/.circle-ci/builds.html) shows the branch name for each build and can also show only release builds (click the __Release branches__ radio button).

## Building Heddle

[Install build dependencies](#installbuilddependencies)
[Get the source](#getthesource)
[Build Aboriginal Linux](#buildaboriginallinux)
[Build Heddle packages](#buildheddlepackages)
[Running Heddle](#runningheddle)
[Creating a bootable image](#creatingabootableimage)
[Booting the image](#bootingtheimage)

### Install build dependencies

To build a Heddle image, you'll need the following things:

- Basic Unix shell utilities
- Basic build tools such as GCC and GNU Make
- [Ext2/3/4 tools](http://home.earthlink.net/~k_sheff/sw/e2tools/)
- [QEMU/KVM](http://www.qemu.org)
- [Parted](http://www.gnu.org/software/parted/)
- [MS-DOS tools](http://www.gnu.org/software/mtools/)
- [Syslinux](http://www.syslinux.org)
- [SquashFS tools](https://github.com/plougher/squashfs-tools)

On Ubuntu you can do this:

```shell
sudo apt-get install coreutils build-essential e2tools qemu-kvm parted mtools syslinux syslinux-common squashfs-tools
```

### Get the source

First get the Aboriginal Linux source code. Heddle requires [Aboriginal Linux 1.4.0](http://landley.net/aboriginal/downloads/aboriginal-1.4.0.tar.gz). Untar the archive to create an `aboriginal-1.4.0` directory.

Then fetch the Heddle source:

```shell
git clone https://github.com/davedoesdev/heddle.git
```

You should have a `heddle` directory alongside the `aboriginal-1.4.0` directory (although the two don't have to live in the same place).

### Build Aboriginal Linux

```shell
cd aboriginal-1.4.0
../heddle/aboriginal_scripts/config.sh
./build.sh x86_64
```

Of course, if you put the Heddle source somewhere else, replace `../heddle` with its location.

You can change the kernel configuration by editing `../heddle/aboriginal_scripts/config/linux` and `../heddle/aboriginal_scripts/config/linux-x86_64`.

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

By default, `extra.img` uses GPT paritioning and is formatted with Btrfs. Supply `-m` for MSDOS paritions and `-e` for an Ext4 filesystem.

Next you need to run:

```shell
../heddle/aboriginal_scripts/run_heddle.sh -p
```

This runs Heddle in KVM and waits until all Heddle services indicate they have performed any one-time initialisation steps they require. You can find Heddle services in `../heddle/chroot/service`. Currently, there is one service which has a one-time initialisation step: `prepare_docker`. It creates the Docker `scratch` image.

Finally, if you want to run Heddle and play around before creating a bootable image then you can run:

```shell
../heddle/aboriginal_scripts/run_heddle.sh
```

You'll be able to login (user `root`, password `root`) and use any of the Heddle packages. If you want to customise Heddle, it's probably best to [write an extension](#extendingheddle) rather than do it by hand.

### Creating a bootable image

To create a single, bootable image for distribution (writing to USB stick, imaging to disk etc), run the following:

```shell
../heddle/image_scripts/make_dist_and_heddle_images.sh
../heddle/aboriginal_scripts/dist_heddle.sh
```

The first command creates the distribution image (`../heddle/gen/x86_64/images/heddle.img`) as well as another image (`../heddle/gen/x86_64/images/dist.img`) which contains further scripts for populating `heddle.img` from within Heddle itself.

The second command runs KVM, mounts `heddle.img` and `dist.img` and runs the scripts on `dist.img`. When this command finishes, `heddle.img` will be bootable and ready for use.

You'll also find files for [upgrading existing Heddle installations](#updatingheddle) in `../heddle/gen/x86_64/dist/update`. The `dist` folder there is what gets archived when producing the [pre-built images](#prebuiltimages) (it contains a symbolic link to `heddle.img` too).

### Booting the image

You can write the distribution image you created to disk just like a [pre-built image](#prebuiltimages), for example:

```shell
ddpt if=../heddle/gen/x86_64/images/heddle.img of=/dev/sdb bs=512 bpt=128 oflag=sparse
```

You can also test it in KVM by running the following command:

```shell
../heddle/image_scripts/boot_heddle.sh
```

## Building for different architectures

By default, Heddle is built for the `x86_64` architecture. To build for a different architecture, you must:

- Create an Aboriginal Linux target for the architecture. Each target is a separate file in the `sources/targets` directory of the Aboriginal Linux source code. I have successfully built using the existing `armv6l` target (ARM Versatile board with ARM 1136-R2 processor).

- In `image_scripts/packages`, make any adaptations you need when building Heddle packages. Usually the easiest way to do this is build without any adaptations for your architecture and fix it up as things break. Search for `armv6l` in this file to see the adaptations I had to make.

- Find a suitable bootloader for your architecture. For `armv6l` I chose [U-Boot](http://www.denx.de/wiki/U-Boot), which is in `image_scripts/packages` but currently built on `armv6l` only. You can also see special instructions for `armv6l` in `aboriginal_scripts/dist_heddle.sh` and `runtime_scripts/dist.sh` to copy `u-boot.bin` out of `home.img` and make a `boot.kbin` image suitable for booting on QEMU. 

Most of the build scripts take an optional architecture argument which defaults to `x86_64`. So to build for `armv6l` you'd do the following:

1. Extract the Aboriginal Linux source archive to a _new_ directory. You can re-use your Heddle source directory - the new images will be written to `gen/armv6l/images`.
2. `cd some-new-directory/aboriginal-1.4.0`
3. `/path/to/heddle/aboriginal_scripts/config.sh armv6l`
4. `./build.sh armv6l`
5. `/path/to/heddle/image_scripts/make_build_and_home_images.sh armv6l`
6. `/path/to/heddle/aboriginal_scripts/build_heddle.sh armv6l` (this will take many hours because it uses QEMU emulation)
7. `/path/to/heddle/image_scripts/make_run_and_extra_images.sh armv6l`
8. `/path/to/heddle/aboriginal_scripts/run_heddle.sh -p armv6l`
9. `/path/to/heddle/image_scripts/make_dist_and_heddle_images.sh armv6l`
10. `/path/to/heddle/aboriginal_scripts/dist_heddle.sh armv6l`

This will generate `/path/to/heddle/gen/armv6l/images/heddle.img` which you can then write to disk or boot using:

```shell
/path/to/heddle/image_scripts/boot_heddle.sh armv6l
```



## foobar

create a script to call all of the build scripts? if yes then update doc

How to RAID
  RAID level config

How to upgrade

Serial

NTP pool

getetc script
extending heddle (services, packages) - allow extend kernel config / busy box config etc


## Licences

Heddle is made up of the following:

- [Aboriginal Linux](http://landley.net/aboriginal/), which is licensed under GPL version 2.

- Aboriginal Linux's component packages, which are redistributed under their respective licences. See the Aboriginal Linux [package download script](http://landley.net/hg/aboriginal/file/default/download.sh) for the list of packages versions and URLs.

- Heddle's component packages, which are redistributed under their respective licences. See the Heddle [package download script](image_scripts/packages) for the list of package versions and URLs.

- Original works developed as part of the Heddle project (including scripts, source code and documentation). These are licensed under [GPL version 2](LICENCE).


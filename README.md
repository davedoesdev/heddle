[![Build Status](https://circleci.com/gh/davedoesdev/heddle.svg?style=svg)](https://circleci.com/gh/davedoesdev/heddle) [![Successful builds with links to disk images](http://githubraw.herokuapp.com/davedoesdev/heddle/master/builds.svg)](http://githubraw.herokuapp.com/davedoesdev/heddle/master/.circle-ci/builds.html)

Heddle is a Linux distribution for running [Docker](https://www.docker.com/) and [Capstan](http://osv.io/capstan/) applications.

- Built from scratch using [Aboriginal Linux](http://landley.net/aboriginal/) to bootstrap the build.

- Completely automated build. Build Heddle images locally or on [Travis CI](https://travis-ci.org/davedoesdev/build-aboriginal-travis) and [CircleCI](https://circleci.com/gh/davedoesdev/heddle).

- Builds only those packages necessary in order to get Docker and Capstan up and running.

- Supports in-place, atomic upgrade of the entire base operating system and all the packages. No dynamic package management required.

- GPT- or MBR-based images with Ext4 or BTRFS filesystems. RAID supported with BTRFS.

- Simple init system based on [runit](http://smarden.org/runit/). Heddle is a systemd-free zone!

- Currently supported architectures: x86_64 and armv6l (ARM Versatile). Other ARM targets should now be possible.

- [uClibc](http://www.uclibc.org/)/[uClibc++](http://cxx.uclibc.org/) used throughout. No glibc.

- Easily customizable using configuration scripts, for example to build additional kernel drivers.

## Licences

Heddle is made up of the following:

- [Aboriginal Linux](http://landley.net/aboriginal/), which is licensed under GPL version 2.

- Aboriginal Linux's component packages, which are redistributed under their respective licences. See the Aboriginal Linux [package download script](http://landley.net/hg/aboriginal/file/default/download.sh) for the list of packages versions and URLs.

- Heddle's component packages, which are redistributed under their respective licences. See the Heddle [package download script](image_scripts/packages) for the list of package versions and URLs.

- Original works developed as part of the Heddle project (including scripts, source code and documentation). These are licensed under [GPL version 2](LICENCE).

More documentation soon...

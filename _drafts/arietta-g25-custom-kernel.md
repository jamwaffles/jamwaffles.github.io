# Building your own kernel for the Arietta G25

I wanted to add a USB wireless adapter to my board (why oh why didn't I just buy an ACME Systems WiFi module!), so I needed to configure and compile my own kernel.

## Install dependencies

Adapted from [this guide](http://www.acmesystems.it/arm9_toolchain).

Crunchbang Waldorf (Debian Wheezy), guide [here](https://wiki.debian.org/EmdebianToolchain)

Add sources for cross toolchain. **These must be for `squeeze` or dependencies won't resolve.**

```bash
echo "deb http://ftp.us.debian.org/debian/ squeeze main" >> /etc/apt/sources.list.d/emdebian.list
echo "deb http://www.emdebian.org/debian/ squeeze main" >> /etc/apt/sources.list

apt-get update
```

Install toolchain:

```bash
apt-get install \
	emdebian-archive-keyring \
	libc6-armel-cross \
	libc6-dev-armel-cross \
	binutils-arm-linux-gnueabi \
	gcc-4.4-arm-linux-gnueabi \
	g++-4.4-arm-linux-gnueabi \
	u-boot-tools \
	libncurses5-dev
```

## Build kernel

Download these files:

- [kernel 3.16.1](https://www.kernel.org/pub/linux/kernel/v3.x/linux-3.16.1.tar.xz)
- [acme.patch](http://www.acmesystems.it/www/compile_linux_3_16/acme.patch)

### Extract kernel and apply patch:

```bash
tar xvfJ linux-3.16.1.tar.xz

cd linux-3.16.1

patch -p1 < ../acme.patch
```

### Base configuration

```bash
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- acme-arietta_defconfig
```

If you need to do any custom configuration, use the handy interface:

```bash
make ARCH=arm menuconfig
```

Make sure you save before exit.

### Compile kernel

Change `-j4` to however many jobs you want to run in parallel (`-j2` for a dual core machine, for example)

```bash
make -j4 ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- acme-arietta.dtb \
make -j4 ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- zImage \
make modules -j4 ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- \
make modules_install INSTALL_MOD_PATH=./modules ARCH=arm
```

### Copy to SD card

I had a working board at this point so using `rsync` over a SSH connection was possible.

Try [my guide to getting an SD card working](TODO) if you're having problems

**Copy kernel to first partition**

```bash
scp arch/arm/boot/dts/acme-arietta.dtb root@arietta.local:/boot
scp arch/arm/boot/zImage root@arietta.local:/boot
```

**Copy kernel modules to rootfs (second partition)**

```bash
rsync -avc modules/lib/. root@arietta.local:/lib/.
```

If you're having problems connecting to `arietta.local` try using the IP address (`192.168.10.10` if you've followed [my other guide](TODO))

### Final setup

Reboot the board, then when it's back up type

```bash
depmod -a
```

## All done

Again, this guide is heavily inspired by [the official Arietta kernel 3.16 docs](http://www.acmesystems.it/compile_linux_3_16) with some adaptations for Debian and the Arietta G25.
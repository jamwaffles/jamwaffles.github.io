+++
layout = "post"
title = "Building a LinuxCNC 2.9 simulator on Linux Mint 21.3"
date = "2024-01-10 10:50:40"
+++

An update on my [previous guide for LM 19.3](@/2020-01-25-linuxcnc-simulator-build-linux-mint.md) on
how to set up a LinuxCNC simulator on Linux Mint 21.3 Virginia. The LinuxCNC simulator is useful for
testing/debugging drivers, gcode parsing and other non-realtime features without having to crawl
around under your machine's actual control.

<!-- more -->

## Versions

- LinuxCNC Git at tag [`v2.9.2` (`ac9a84a`)](https://github.com/LinuxCNC/linuxcnc/tree/v2.9.2).
- Linux Mint 21.3 Cinnamon
- Kernel 6.5.0-14-generic

## Dependencies

```bash
apt install --no-recommends \
    bwidget \
    intltool \
    kmod \
    libboost-python-dev \
    libglu-dev \
    libgtk2.0-dev \
    libmodbus-dev \
    libtk-img \
    libudev-dev \
    libusb-1.0-0-dev \
    libx11-dev \
    libxinerama-dev \
    libxmu-dev \
    mesa-common-dev \
    python3 \
    python-tk \
    tclx \
    tk-dev \
    yapps2 \
    libreadline-dev \
    asciidoc \
    python3-opengl
```

There might be an issue finding `yapps` where it's installed as `yapps2`. In this case, remove the
`yapps2` line from above, and run this as well:

```bash
apt install python-pip
pip install yapps
```

## Build

The following steps are a condensed version of the
[official build docs](http://linuxcnc.org/docs/devel/html/code/building-linuxcnc.html#_non_realtime).

```bash
git clone https://github.com/LinuxCNC/linuxcnc.git
cd linuxcnc/src
git checkout v2.9.2
./autogen.sh
./configure \
  --with-realtime=uspace \
  --enable-non-distributable=yes \
  --disable-userspace-pci
make -j12
cd ..
./scripts/linuxcnc
```

- `--with-realtime=uspace` will compile LinuxCNC to run on non-realtime kernels, or kernels that use
  the Preempt-RT patches.
- `--enable-non-distributable=yes` squelches a warning. Remove this flag to see a message with
  alternatives.

+++
layout = "post"
title = "Building a LinuxCNC 2.8 simulator on Linux Mint"
date = "2020-01-25T12:21:06+00:00"
categories = "cnc"
path = "cnc/2020/01/25/linuxcnc-simulator-build-linux-mint.html"
+++

A quick guide on how to set up a LinuxCNC simulator on Linux Mint. The LinuxCNC simulator is useful
for testing/debugging drivers, gcode parsing and other non-realtime features without having to crawl
around under your machine's actual control.

## Versions

- LinuxCNC Git at commit
  [10ae35219](https://github.com/LinuxCNC/linuxcnc/tree/10ae352190d13b60a2153b5284c5cda7d7de59a9).
- Linux Mint 19.3 Cinnamon
- Kernel 5.0.0-32-generic

## Dependencies

```bash
apt install \
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
    python \
    python-tk \
    tclx \
    tk-dev \
    yapps2
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
./autogen.sh
./configure \
  --with-realtime=uspace \
  --enable-non-distributable=yes \
  --disable-userspace-pci \
  --disable-check-runtime-deps
make -j12
cd ..
./scripts/linuxcnc
```

- `--with-realtime=uspace` will compile LinuxCNC to run on non-realtime kernels, or kernels that use
  the Preempt-RT patches.
- `--enable-non-distributable=yes` squelches a warning. Remove this flag to see a message with
  alternatives.

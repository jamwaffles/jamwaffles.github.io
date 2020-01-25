---
layout: post
title: 'Building a LinuxCNC 2.8 simulator on Linux Mint'
date: 2020-01-25T12:21:06+00:00
categories: cnc
---

A quick guide on how to set up a LinuxCNC simulator on Linux Mint. The LinuxCNC simulator is useful for testing/debugging drivers, gcode parsing and other non-realtime features without having to crawl around under your machine's actual control.

## Versions

- LinuxCNC Git at commit [10ae35219](https://github.com/LinuxCNC/linuxcnc/tree/10ae352190d13b60a2153b5284c5cda7d7de59a9).
- Linux Mint 19.3 Cinnamon
- Kernel 5.0.0-32-generic

## Dependencies

```bash
apt install \
    libmodbus-dev \
    libgtk2.0-dev \
    yapps2 \
    intltool \
    tk-dev \
    bwidget \
    libtk-img \
    tclx \
    python-tk \
    libboost-python-dev \
    libxmu-dev \
    libudev-dev \
    libusb-1.0-0-dev
```

## Build

The following steps are a condensed version of the [official build docs](http://linuxcnc.org/docs/devel/html/code/building-linuxcnc.html#_non_realtime).

```bash
git clone https://github.com/LinuxCNC/linuxcnc.git
cd linuxcnc/src
./autogen.sh
./configure --with-realtime=uspace --enable-non-distributable=yes
make -j12
cd ..
./scripts/linuxcnc
```

- `--with-realtime=uspace` will compile LinuxCNC to run on non-realtime kernels, or kernels that use the Preempt-RT patches.
- `--enable-non-distributable=yes` squelches a warning. Remove this flag to see a message with alternatives.

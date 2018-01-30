---
layout: post
title:  "Getting started with the RTFM framework"
date:   2018-01-30 12:00:00
categories: electronics rust
image: todo.jpg
---

No not that RTFM, [this RTFM](http://blog.japaric.io/)! Rust has had ARM support for quite some time now, but getting up and running on a bare metal chip still required the usual register fiddling to get things running. RTFM solves many of those issues whilst using Rust's compile-time safety to make programming ARM chips easier and more reliable. In this post, I want to go through writing and running a Rust hello world program on an STM32F103C8 ARM microcontroller.

I'm using a Blue Pill board and Windows 10 here, but you should get good results on macOS and Linux, as all the tooling is available cross-platform.

## TL;DR

<https://github.com/jamwaffles/blue-pill-rtfm-demo>

## Hardware setup

This tutorial is going to program the board using the chip's built-in bootloader over USART1 on pins A9 and A10. Other methods utilise the ST-Link debugger (and clones), but I don't have one to hand. You might not either, so maybe this tutorial is useful to you. You don't get debugging support, but getting started is pretty easy if you already have a serial adapter lying around.

You'll need:

- An STM32F106C8T6 board with pins A9 and A10 broken out. I'm using the ever popular [Blue Pill](https://www.aliexpress.com/item/1-pices-STM32F103C8T6-ARM-STM32-Minimum-System-Development-Board-Module-For-arduino-Sensing-Evaluation-for-Skiller/32765534610.html) board, but anything with the same chip should work.
- An FTDI USB to serial breakout. I'm using one [like this](https://www.aliexpress.com/item/Free-shipping-1pcs-lot-New-FT232RL-FT232-USB-TO-TTL-5V-3-3V-Download-Cable-To/32645814447.html). You could potentially use a hardware serial port, **but the line levels must be 0 – 3v3 so as not to damage the STM32.**

Hook it all up as follows:

- TODO PIC: Wiring schematic

The FTDI board I'm using has a switchable voltage option. If yours does, make sure you switch it to the 3v3 setting. If not, you can leave the FTDI <-> board power disconnected and power the board from its USB port. Some pins on the STM32 are 5V tolerant, so should work fine with a standard 3V3 or 5V serial to USB or RS232 to 5V converter. The following image marks which pins are 5V tolerant with a black line end.

![5V tolerant IO diagram](http://wiki.stm32duino.com/images/a/ae/Bluepillpinout.gif)

- TODO PIC: Wire connections from FTDI and power to 3v3 switch

- TODO PIC: BOOT0 jumper

- TODO PIC: Wires from FTDI

## Tools setup

There are a few dependencies to install before we can start writing programs, so let's install those. I'm assuming you have [Rustup](https://www.rustup.rs/) installed. You'll need the following:

- The [GNU ARM development toolchain](https://developer.arm.com/open-source/gnu-toolchain/gnu-rm/downloads)
- Nightly rust with `rustup default set nightly`. RTFM won't work on non-nightly builds!
- The Rust source with `rustup component add rust-src` TODO: CHECK COMMAND
- [Xargo](https://github.com/japaric/xargo) with `cargo install xargo`
- [stm32flash](https://sourceforge.net/projects/stm32flash/) with `apt-get install stm32flash` or [download the Windows build from SourceForge](https://sourceforge.net/projects/stm32flash/).

## Project setup

### Code

TODO Smash this into `src/main.rs`

```rust

```

### Build

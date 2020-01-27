---
layout: post
title: 'Write a LinuxCNC HAL component in Rust'
date: 2020-01-25T12:49:22+00:00
categories: cnc
---

[LinuxCNC](https://linuxcnc.org) is a popular, open source machine controller. It's very powerful and is an excellent way to get into CNC on an absolute budget. LinuxCNC is also expandable with custom components called HAL components or HAL comps.

Up to now, most components are written in C or Python. Pretty unsafe or slow - these languages don't make the best choice for a potentially heavy/dangerous/fast machine! With its safety and low to zero overhead, Rust is a prime replacement for writing HAL comps, however there doesn't seem to be any way to integrate Rust with LinuxCNC... until now!

I've been working on two crates to integrate Rust components into LinuxCNC. You can find them at [linuxcnc-hal](https://crates.io/crates/linuxcnc-hal) (high-level interface) and [linuxcnc-hal-sys](https://crates.io/crates/linuxcnc-hal-sys) (low-level interface).

There are [examples](https://github.com/jamwaffles/linuxcnc-hal-rs/tree/master/linuxcnc-hal/examples) for [both](https://github.com/jamwaffles/linuxcnc-hal-rs/tree/master/linuxcnc-hal-sys/examples), but let's go through making a HAL component step by step!

## A primer on HAL components

LinuxCNC has the concept of a HAL (Hardware Abstraction Layer). The HAL allows (among other things) custom components to be loaded at startup which hook into the HAL using virtual "pin"s. These pins allow comps to take inputs from LinuxCNC and provide outputs to it. A HAL component is often used to communicate with custom hardware such as VFDs, toolchangers or information readouts.

A HAL component is a normal binary with a standard `main()` function, however there are certain component-specific actions that must be taken to hook it into LinuxCNC. The two crates mentioned above ([linuxcnc-hal](https://crates.io/crates/linuxcnc-hal) and [linuxcnc-hal-sys](https://crates.io/crates/linuxcnc-hal-sys)) facilitate this linking in Rust.

## Hello world

First, let's write a basic component with one input and one output pin to get a feel for the interface. Set up a binary project and add `linuxcnc-hal` as a dependency:

```bash
cargo new --bin hello-comp
cd hello-comp
cargo add linuxcnc-hal
```

> You might need to install [cargo-edit](https://github.com/killercup/cargo-edit) if `cargo add` isn't found:
>
> `cargo install --force cargo-edit`


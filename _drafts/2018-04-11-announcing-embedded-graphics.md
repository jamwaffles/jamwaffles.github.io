---
layout: post
title:  "Announcing the Embedded Graphics Crate"
date:   2018-04-11 12:00:00
categories: electronics rust
image: rust-on-a-display-banner.jpg
---

The Rust embedded ecosystem is growing rapidly. There's the [embedded working group] and the awesome [weekly driver initiative]. I've been helping write a driver for the popular [ssd1306] OLED display driver IC which surfaced the need for a lightweight graphics API for use with these handy little displays. To that end, I'll use this post to announce the low-memory-usage, `no-std` [embedded_graphics] crate and talk a bit about how it works.

![Image of a starburst of lines]()

One of the main goals of `embedded_graphics` is to be as lightweight as possible; a Raspberry Pi has a lot of resources available to it, but an ARM Cortex M3 does not, and `embedded_graphics` should work on both! The main problem is storing and drawing pixels. A common approach is to use a framebuffer, however a buffer for even a modestly sized display can consume a large portion of a µC's RAM.

Rust has fantastic iterator support, a feature I lean on heavily for this crate to reduce the memory consumption as much as possible. Instead of using a screenbuffer, primitives are drawn by calling `.into_iter()` and iterating over the returned coordinate/pixel pairs. This massively reduces memory usage aside from a few tracking variables in the iterator, and means that graphics objects can be drawn to arbitrarily large sizes (good for a giant NeoPixel display perhaps?) without running out of memory. There's a slight performance hit with this method, but if performance is important you can always cache the output of an iterator!

* Talk about implementing the `Drawable` trait for the simulator, maybe link to the SSD1306 impl?
* Show simulator screenshots and what the code looks like
* Go through creating a new drawable "thing". Unsure what yet.
* Composing iterators. Can I do this? Example: drawing a square button with text in it
* Talk briefly about translations

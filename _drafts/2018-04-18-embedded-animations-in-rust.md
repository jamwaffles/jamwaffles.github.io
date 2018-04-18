---
layout: post
title:  "Embedded animations on an SSD1306"
date:   2018-04-18 12:00:00
categories: electronics rust
image: todo.jpg
---

* Start with a static pixel (no e_gfx yet)
* Now bounce it around with RTFM sys_tick
* Now introduce embedded_graphics; change pixel to a rect
* Change rect to image (talk about ImageMagick and the niceties of include_bytes!())
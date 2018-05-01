---
layout: post
title:  "Embedded animations on an SSD1306"
date:   2018-04-18 12:00:00
categories: electronics rust
image: todo.jpg
---

After releasing [embedded-graphics]() and [ssd1306]() which makes extensive use of it, I thought it would be useful and fun to walk throuhg building a quick demo using both. In this post I'll go through drawing a single pixel with these libraries to animating an image bouncing around the screen. I'll be using a CRIUS branded OLED display on I2C1 of an STM32F103 "Blue Pill". It should be easy enough to adapt this tutorial to your hardware.

## Let there be light

The first thing to do is to establish a connection with the display. To check it's working, we'll light the top left (`(0, 0)`) pixel of the display.

* Start with a static pixel (no e_gfx yet)
* Now bounce it around with RTFM sys_tick
* Now introduce embedded_graphics; change pixel to a rect
* Change rect to image (talk about ImageMagick and the niceties of include_bytes!())

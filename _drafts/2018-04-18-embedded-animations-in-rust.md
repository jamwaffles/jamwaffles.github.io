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

Adding `opt-level = "s"` to release mode does this for size (`cargo bloat --release`):

Before:

```
File  .text   Size                       Crate Name
0.0%   1.1%    42B                             [7 Others]
0.3%  19.8%   772B ssd1306_animations_blogpost ssd1306_animations_blogpost::init
0.2%  14.2%   554B                     ssd1306 ssd1306::command::Command::send
0.2%  13.4%   522B                 cortex_m_rt SYS_TICK
0.2%  12.9%   504B            stm32f103xx_hal? <stm32f103xx_hal::i2c::I2c<stm32f103xx::I2C1, PINS> as embedded_hal::blocking::i2c::Write>::write                                                                                             
0.2%  10.3%   400B                 cortex_m_rt cortex_m_rt::reset_handler
0.1%   5.7%   224B             stm32f103xx_hal <stm32f103xx_hal::i2c::I2c<stm32f103xx::I2C1, PINS>>::init
0.1%   5.7%   222B                     ssd1306 <ssd1306::mode::graphics::GraphicsMode<DI>>::flush
0.1%   4.1%   160B                         std __aeabi_memcpy4
0.1%   3.6%   142B                         std __aeabi_memset4
0.0%   2.5%    96B                         std __aeabi_memset
0.0%   2.4%    94B                         std __aeabi_memcpy
0.0%   2.3%    90B ssd1306_animations_blogpost ssd1306_animations_blogpost::main
0.0%   0.3%    10B                 cortex_m_rt USAGE_FAULT
0.0%   0.3%    10B                 cortex_m_rt SVCALL
0.0%   0.3%    10B                 cortex_m_rt PENDSV
0.0%   0.3%    10B                 cortex_m_rt NMI
0.0%   0.3%    10B                 cortex_m_rt MEM_MANAGE
0.0%   0.3%    10B                 cortex_m_rt HARD_FAULT
0.0%   0.3%    10B                 cortex_m_rt DEFAULT_HANDLER
0.0%   0.3%    10B                 cortex_m_rt DEBUG_MONITOR
1.5% 100.0% 3.8KiB                             .text section size, the file size is 258.9KiB
```

After:

```
File  .text   Size                       Crate Name
0.0%   1.5%    52B                             [8 Others]
0.3%  22.6%   766B ssd1306_animations_blogpost ssd1306_animations_blogpost::init
0.2%  16.3%   554B                     ssd1306 ssd1306::command::Command::send
0.2%  11.8%   400B                 cortex_m_rt SYS_TICK
0.1%   8.4%   286B            stm32f103xx_hal? <stm32f103xx_hal::i2c::I2c<stm32f103xx::I2C1, PINS> as embedded_hal::...
0.1%   6.6%   224B             stm32f103xx_hal <stm32f103xx_hal::i2c::I2c<stm32f103xx::I2C1, PINS>>::init
0.1%   6.4%   216B                     ssd1306 <ssd1306::mode::graphics::GraphicsMode<DI>>::flush
0.1%   4.7%   160B                         std __aeabi_memcpy4
0.1%   4.2%   142B                         std __aeabi_memset4
0.1%   4.2%   142B           embedded_graphics <embedded_graphics::image::image1bpp::Image1BPPIterator<'a> as core::...
0.0%   2.9%   100B ssd1306_animations_blogpost ssd1306_animations_blogpost::main
0.0%   2.8%    96B                         std __aeabi_memset
0.0%   2.8%    94B                         std __aeabi_memcpy
0.0%   2.7%    92B                 cortex_m_rt cortex_m_rt::reset_handler
0.0%   0.3%    10B                 cortex_m_rt USAGE_FAULT
0.0%   0.3%    10B                 cortex_m_rt SVCALL
0.0%   0.3%    10B                 cortex_m_rt PENDSV
0.0%   0.3%    10B                 cortex_m_rt NMI
0.0%   0.3%    10B                 cortex_m_rt MEM_MANAGE
0.0%   0.3%    10B                 cortex_m_rt HARD_FAULT
0.0%   0.3%    10B                 cortex_m_rt DEFAULT_HANDLER
1.3% 100.0% 3.3KiB                             .text section size, the file size is 253.6KiB
```

It also gives us a nice speed increase, getting buttery smooth anim
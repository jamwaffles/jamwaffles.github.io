+++
layout = "post"
title = "Weird high frequency behaviour on your STM32 pins? Change the mode!"
date = "2021-07-24 20:35:38"
categories = "rust"
path = "rust/2021/07/24/dont-forget-to-change-pin-mode.html"
+++

A quick PSA in case you're at a loss as to why you're seeing strange behaviour from your STM32 MCU
pins when running higher frequencies through them like I was.

After successfully getting MCO (Microcontroller Clock Output) working on the only STM32L031 I could
find in the universe, I was seeing some strange behaviour when attempting to push the output
frequency above 2MHz.

![](/assets/images/mco/mco-1.png)

If you look at the measurements at the bottom, the frequency is correct but why is the amplitude so
low and where's that DC offset come from?!

Turns out all we need to do is change the pin speed. Because I'm using the
[Rust HAL for my device](github.com/stm32-rs/stm32l0xx-hal), it was as easy as calling
[`set_speed`](https://docs.rs/stm32l0xx-hal/0.7.0/stm32l0xx_hal/gpio/gpioa/struct.PA8.html#method.set_speed):

```rust
let gpioa = dp.GPIOA.split(&mut rcc);

let mco_pin = gpioa.pa8.set_speed(Speed::Medium);
```

Internally, `set_speed` modifies the `ospeedr` register for the appropriate GPIO port. If you're not
using the HAL or Rust, check your datasheet for the correct values to set.

Now I can double the output frequency (8MHz) and get a far better defined squarewave:

![](/assets/images/mco/mco-8mhz.png)

## Other speeds

I thought I'd experiment with `Speed::High` and `Speed::VeryHigh` too using a single pulse.

Here's `Speed::High`, zoomed in a little bit:

![](/assets/images/mco/pin-speed-high.png)

The rise time is more than twice as good as `Medium`, giving us more frequency headroom.

There's a little bit more ringing, but that could be due to the PCB I'm using having quite long
traces between the MCU and the test point the scope is attached to.

And `Speed::VeryHigh`:

![](/assets/images/mco/pin-speed-veryhigh.png)

Rise time has improved a bit from `High` (6ns down to 4ns) but the ringing has got a little bit
worse. YMMV!

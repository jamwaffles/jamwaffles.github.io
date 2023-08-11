+++
layout = "post"
title = "Reducing fan noise on the Morefine S500+"
date = "2023-08-11 19:25:19"
+++

I got a Ryzen 5625U Morefine S500+ Mini PC
[from Aliexpress](https://www.aliexpress.com/item/1005004673937974.html) for
[EtherCrab](https://github.com/ethercrab-rs/ethercrab) development recently. It's a lovely little
machine for the price and about 7x faster than my previous dev box. There's one very annoying issue
though: the noisy little fan installed on the CPU heatsink. Let's fix that.

<!-- more -->

I took two approaches here. Skip ahead to the one you prefer:

- [Swap the fan's 12V power for 5V](#running-the-cpu-fan-off-5v) - requires soldering but is an
  entirely reversible procedure. Very quiet, but runs the CPU a little hot
- [Install a Noctua inline fan speed reducer](#adding-a-noctua-fan-speed-reducer) - still an
  improvement, but is the noisier of the two solutions. It does however keep the CPU a bit cooler,
  so is probably better for sustained workloads or warmer environments.

# Running the CPU fan off 5V

This is my preferred solution _for my use case_ which is compiling code, so quite bursty and not too
heating.

The cooling fan uses PWM to control its speed and runs off 12V through the (thankfully standard!) 4
pin fan connector on the mainboard. I was originally going to swap it out for a 92mm Noctua slim fan
but there's just no space for it. Instead, I popped the 12V power pin out of the fan connector and
soldered it to a small wire fed through the PCB to steal 5V from the rear USB ports.

{{ images2(p1="/images/s500/connector-2.jpg" p2="/images/s500/wire-run.jpg") }}

Slip a bit of heatshrink over the joint and tuck it in behind the connector, making sure to not
allow any metal to stick out of either end.

{{ images2(p1="/images/s500/heatshrink.jpg" p2="/images/s500/tucked.jpg") }}

If you'd like to go back to the stock fan, simply unsolder the added wire from the connector crimp
terminal and click it back into the original connector. Fan RPM reporting still works accurately
with this mod, too.

With this method, the fan is practically inaudible even at full pelt, **however, the CPU does run
quite hot**.

My system is running Linux Mint and with a looped Rust compile to generate some heat load, I saw
~84C sustained. This is pretty hot, but I'm willing to make the sacrifice for two reasons. One, the
workloads I run are quite bursty, and there's enough thermal mass to soak those bursts up without
too much heating. Second, the fan at stock speeds is extremely annoying and the unit sits with me on
my desk, so I'd like it to at least be quiet if not silent.

For what it's worth, my unit stands on its side with the exhaust vent pointing up, but laying it on
its feet doesn't make much difference to the peak temperature so either orientation is fine.

# Adding a Noctua fan speed reducer

This is the slightly louder, but cooler and no-soldering-required solution for those in a bit of a
pinch or without access to electronics tools. I used a Noctua NA-RC7 but any inline speed reducer
should work, thanks to the standard 4 pin fan header in the Morefine.

With the same looped Rust compile on Linux, I measured a peak of 73C, a 9C improvement from my
ultra-silent soldering mods above, although I still didn't like the tone of the fan sound with the
inline reducer.

# Closing out

I thought I'd share my attempts into quieting down the S500+ as it's a rather nice unit aside from
the fan noise.

The best solution I think would be a mini adjustable power supply module hooked into the 12V supply
to the fan to drop it down to maybe 7V or so, allowing one to strike a balance between noise and
cooling performance for one's different workloads on this machine. The two options presented above
are just what I had lying around and are the bare minimum, but still effective for the work I'm
doing on this box.

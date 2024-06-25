+++
layout = "post"
title = "Setting up an MPG Jog Pendant in LinuxCNC"
date = "2020-02-23T12:06:37+00:00"
categories = "[cnc]"
path = "cnc/2020/02/23/linuxcnc-jog-wheel-setup.html"
+++

CNC jog pendants are super useful devices for quick setup and configuration of CNC machines. A quick
search for
[CNC jog pendant](https://www.aliexpress.com/wholesale?catId=0&initiative_id=SB_20200223040744&SearchText=cnc+jog+wheel)
on AliExpress turns up a bunch of results. For this post, I'll cover connecting a wired jog pendant
with ESTOP to a Mesa 5i25 FPGA card to control a 3 axis CNC mill.

<!-- more -->

The config below works for me. The plethora of hardware configs out there mean this article likely
won't work for you verbatim, but it's my hope that it provides a good starting point for other
configs.

**Please note that I got this config working on LinuxCNC 2.9.0-pre0. It should also work on 2.8.\*,
but will not work on anything before the joints/axes split.**

# Hardware

{{ images1(path="images/cnc-mpg.jpg") }}

This is the jog pendant I'll be using.

It provides estop, axis select, multiplier and encoder outputs on a bunch of bare wires as seen in
the image. I'm going to connect it to the internal `P2` connector of a Mesa 5i25 FPGA card, so I'll
trim the bare wires and solder them to a DB25 cable-end connector in a bit.

{{ images1(path="images/mesa-5i25-annotated.png") }}

I'm using a [Mesa 5i25](/images/mesa-5i25.png) FPGA card through a DB25 breakout cable (like
[this one](https://www.ebay.co.uk/itm//380662654989)) connected to `P2`. Other Mesa cards with
parallel port breakout options like the 6i25 should also work, but are untested.

The Mesa card can optionally provide +5V to external circuitry on the last 4 pins of the parallel
port connector. **This must be enabled for the jog pendant to work.** From the manual, ensure that
jumper `W1` is in the `UP` position.

For reference, here's an image of the breakout cable:

{{ images1(path="images/parport.png") }}

# Soldering up the jog wheel connector

We now need to solder a DB25 connnector to the jog pendant cable so it can be plugged into the Mesa
card. The exact pinout doesn't matter _too_ much as connections can be remapped in software, but in
my setup the jog wheel encoder is bound to pins 11 and 12.

This is the full pinout:

| Name          | DB25 connector pin | Hostmot2 GPIO (we'll use this later) | Wire colour  |
| ------------- | ------------------ | ------------------------------------ | ------------ |
| ESTOP         | 4                  | gpio.023                             | Blue/black   |
| ESTOP gnd     | 21                 | -                                    | Blue         |
| Encoder +5V   | 25                 | -                                    | Red          |
| Encoder gnd   | 20                 | -                                    | Black        |
| Encoder A     | 11                 | encoder.01.input-a                   | Green        |
| Encoder B     | 12                 | encoder.01.input-b                   | White        |
| Encoder A-    | -                  | -                                    | Purple       |
| Encoder B-    | -                  | -                                    | Purple/black |
| Common        | 19                 | -                                    | Orange/black |
| Select axis X | 1                  | gpio.017                             | Yellow       |
| Select axis Y | 14                 | gpio.018                             | Yellow/black |
| Select axis Z | 2                  | gpio.019                             | Brown        |
| Select axis 4 | 5                  | -                                    | Brown/black  |
| X1            | 15                 | gpio.020                             | Grey         |
| X10           | 3                  | gpio.021                             | Grey/black   |
| X100          | 16                 | gpio.022                             | Orange       |
| LED+          | -                  | -                                    | Green/black  |
| LED-          | -                  | -                                    | White/black  |

`Encoder +5V`, `Encoder gnd` and `Common` are connected to ground and +5V, with the 5V supplied by
the last 4 pins by enabling the auxiliary power on the Mesa card by setting jumper `W1` to the `UP`
position.

I'm leaving the inverted signals of the encoder disconnected for simplicity. If you need the noise
suppression features of differential wiring, you'll need to add some external circuitry to deal with
that - the Mesa encoder inputs are single-sided.

I'm also leaving the enable LED disconnected because I can't be bothered to hook it up.

# Mesa card configuration

I'm using the `5i25_prob_rfx2` bitfile for the Mesa 5i25. It seems to be a pretty general purpose
config for these cards. Other configs might work, but the pinout could be different so YMMV.

The pendant is mostly simple GPIO, but you'll need to add an extra encoder to your Mesa config when
loaded. In your `<machine name>.hal` file, find the `loadrt` line and change it:

```diff
- loadrt hm2_pci config="firmware=hm2/5i25/5i25_prob_rfx2 num_encoders=1 num_pwmgens=0 num_stepgens=3"
+ loadrt hm2_pci config="firmware=hm2/5i25/5i25_prob_rfx2 num_encoders=2 num_pwmgens=0 num_stepgens=3"
```

This will add an extra encoder called `encoder.01` for the HAL config to use later.

The above `hm2` config is for a 3 axis mill with a spingle encoder. Because I'm already using one
encoder for the spindle, I'm upping the encoder count to `2`. This puts the second encoder signals
on pins 11 and 12 of the DB25 connector on `P2` which we'll use for the jog pendant. If you've got a
different number of encoders, you might have to change the connector pinout in the table above or
use a completely different Mesa card/tutorial. Sorry.

# Jog pendant HAL configuration

Create a new HAL file called `mpg.hal` and add the following:

```bash
# MPG (jog wheel) config
#
# MPG is plugged into secondary (internal) connector via a DB25 breakout cable. Pinout can be found
# at https://wapl.es/cnc/2020/02/23/linuxcnc-jog-wheel-setup.html
#
# This config requires `numencoders=2` when loading the Mesa component. It uses the second encoder,
# as the first is connected to the spindle motor

# Add component to mux axis selection into the selected axis
loadrt mux16 names=jogincr
addf jogincr                  servo-thread

# --- JOINT-SELECT-A ---
net joint-select-a     <=  hm2_5i25.0.gpio.017.in_not

# --- JOINT-SELECT-B ---
net joint-select-b     <=  hm2_5i25.0.gpio.018.in_not

# --- JOINT-SELECT-C ---
net joint-select-c     <=  hm2_5i25.0.gpio.019.in_not

# --- JOG-INCR-A ---
net jog-incr-a     <=  hm2_5i25.0.gpio.020.in_not

# --- JOG-INCR-B ---
net jog-incr-b     <=  hm2_5i25.0.gpio.021.in_not

# --- JOG-INCR-C ---
net jog-incr-c     <=  hm2_5i25.0.gpio.022.in_not

# --- ESTOP-EXT ---
net estop-ext     <=  hm2_5i25.0.gpio.023.in_not

# ---jogwheel signals to mesa encoder - shared MPG---

net joint-selected-count     <=  hm2_5i25.0.encoder.01.count

#  ---mpg signals---

#       for axis x MPG
setp    joint.0.jog-vel-mode 1
net selected-jog-incr    =>  joint.0.jog-scale axis.x.jog-scale
net joint-select-a       =>  joint.0.jog-enable axis.x.jog-enable
net joint-selected-count =>  joint.0.jog-counts axis.x.jog-counts

#       for axis y MPG
setp    joint.1.jog-vel-mode 1
net selected-jog-incr    =>  joint.1.jog-scale axis.y.jog-scale
net joint-select-b       =>  joint.1.jog-enable axis.y.jog-enable
net joint-selected-count =>  joint.1.jog-counts axis.y.jog-counts

#       for axis z MPG
setp    joint.2.jog-vel-mode 1
net selected-jog-incr    =>  joint.2.jog-scale axis.z.jog-scale
net joint-select-c       =>  joint.2.jog-enable axis.z.jog-enable
net joint-selected-count =>  joint.2.jog-counts axis.z.jog-counts


# connect selectable mpg jog increments
# Note that increments of 0.025 scale to 0.1 due to 4x scaling of encoder pulses vs clicks

net jog-incr-a           =>  jogincr.sel0
net jog-incr-b           =>  jogincr.sel1
net jog-incr-c           =>  jogincr.sel2
net jog-incr-d           =>  jogincr.sel3
net selected-jog-incr    <=  jogincr.out-f
    setp jogincr.debounce-time      0.200000
    setp jogincr.use-graycode      False
    setp jogincr.suppress-no-input True
    setp jogincr.in00          0.000000
    setp jogincr.in01          0.000250
    setp jogincr.in02          0.002500
    setp jogincr.in03          0.000000
    setp jogincr.in04          0.025000
    setp jogincr.in05          0.000000
    setp jogincr.in06          0.000000
    setp jogincr.in07          0.000000
    setp jogincr.in08          0.000000
    setp jogincr.in09          0.000000
    setp jogincr.in10          0.000000
    setp jogincr.in11          0.000000
    setp jogincr.in12          0.000000
    setp jogincr.in13          0.000000
    setp jogincr.in14          0.000000
    setp jogincr.in15          0.000000
```

Some observations:

- I'm using the `in_not` inverted pin values. The 5i25 has weak pullups, so pins are active low and
  default to high (`TRUE`).
- I'm using `mux16` instead of `mux4` because I'm lazy.
- Because the jog wheel is a quadrature encoder, there are 4 counts per "click". The jog scales of
  `0.00025`, `0.0025`, etc are the `1x`, `10x` and `100x` markings on the pendant panel divided
  by 4.
- The `selected-jog-incr`, `joint-select-*` and `joint-selected-count` signals are wired to **both**
  the `joint` and `axis` signals. This is required to make the axes move after homing, and is a
  result of the joints/axes split that happened around LinuxCNC 2.8/2.9.

Finally, to load this extra HAL config into the machine, add a line to the `[HAL]` section in
`<config name>.ini`:

```diff
  [HAL]
  HALUI = halui
  HALFILE = <config name>.hal
+ HALFILE = mpg.hal
  POSTGUI_HALFILE = postgui_call_list.hal
  SHUTDOWN = shutdown.hal
```

Now you should be good. If something's not working check the HAL Meter for GPIO states and
`encoder.01` values.

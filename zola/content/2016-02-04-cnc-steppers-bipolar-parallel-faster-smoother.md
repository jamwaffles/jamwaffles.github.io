+++
layout = "post"
title = "Faster, smoother, better, stronger (at high speeds): bipolar parallel stepper wiring"
date = "2016-02-04 22:03:30"
categories = "cnc"
path = "cnc/2016/02/04/cnc-steppers-bipolar-parallel-faster-smoother.html"

[extra]
image = "images/stepper-header.jpg"
+++

Quick tip: if you're looking for higher maximum speeds with your bipolar stepper motors, try wiring
the windings in parallel instead of series. According to
[a short National Instruments article](http://digital.ni.com/public.nsf/allkb/B1CC4C64ABBC7D3C86257BC70017B9E2),
it can increase torque at higher speeds, reducing the chance that the motor will stall during fast
rapids.

_Header photo by [Yung Chang](https://unsplash.com/@yungnoma)_

![Parallel wiring diagram](/assets/images/bipolar-parallel.jpg)

<sup>_Credit:
[National Instruments](http://digital.ni.com/public.nsf/allkb/B1CC4C64ABBC7D3C86257BC70017B9E2)_</sup>

There is a caveat though: **you'll need a higher current to get the required torque.** That's not a
problem for the M542T stepper drivers I'm using; my motors are rated for 3 amps in bipolar parallel
which the driver can easily handle.

I've managed to reliably get 150mm/sec (9m/min!) rapids out of my gantry router using 10mm/rev
ballscrews. Peck drilling is even more fun to watch now.

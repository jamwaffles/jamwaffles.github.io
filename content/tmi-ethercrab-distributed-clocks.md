+++
layout = "post"
title = "This Month In Rust EtherCat: Distributed Clocks"
slug = "this-month-in-rust-ethercat-distributed-clocks-ethercrab"
started_date = "2024-02-29 22:22:19"
draft = true
# TODO
date = "2024-02-23"

# [extra]
# image = "/images/ethercat.jpg"
+++

- Waiting for 0.4 release
- TODO: Intro

<!-- more -->

{% callout() %}

TODO: This is an experimental feature, so ask for HW to test with or GH sponsors instead of
commercial support.

{% end %}

TODO: Series TOC

# WTF even are Distributed Clocks

- Link to announcement post for general EtherCAT intro
- DC is a way of compensating for device processing times, as well as the speed of light in copper
  (~4ns/m?), to synchronise input and/or output states across all devices in the network with each
  other.
- Reasonably complex but it's configurable which is nice.
- One device is designated as the clock source.
  - Can either be the controller itself (e.g. PC time)
  - Or the first sub device that supports DC. In this case, the controller would sync its cyclic
    process data updates to that device's clock (TODO: I think?)
- ~10ns (TODO: Verify) synchronisation times are possible with TODO ns of jitter

# Support in EtherCrab

- Show a simple example
- Link to long example
- What's supported for now
- What's not
- Still kind of experimental

# SubDevice clock alignment

- Debug this by logging the various SubDevice `DcSystemTimeDifference` (note: it's not `i32`!)
- TODO: Capture example plot from Gnuplot or something, showing bouncing effect

# Dynamic MainDevice clock sync

- Key point is aligning first sync pulse to round multiple of cycle time
- Then in the future, when we read the DC System Time back during process cycle, we can modulo that
  time against our sync0 period.
- This then allows us to calculate a dynamic delay to the _next_ process data send time, meaning we
  get very good sync with the DC System Time (and therefore SYNC0 pulses) even though the OS clock
  might be a bit jittery.
- You can debug this in your setup by logging `this_cycle_delay`. It should be nice and low. If it
  isn't, sort your OS/NIC/etc settings out
  - TODO: Grab a Gnuplot example of good jitter

# Performance

- Jitter wise, `thread::sleep` and `smol::Timer::at` are identical. Very low jitter numbers in my
  testing with a pair of LAN9252s TODO: Insert pic
- Tokio is atrocious TODO insert pic/numbers
  - BUT `tokio_timerfd` fixes this!

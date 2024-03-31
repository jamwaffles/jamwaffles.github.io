+++
layout = "post"
title = "EtherCrab 0.4: Distributed Clocks, `io_uring`, Derives, Oh My"
slug = "ethercrab-0-4-io-uring-derives-ethercat-distributed-clocks"
started_date = "2024-03-31 10:46:26"
date = "2024-03-31"
draft = true

# [extra]
# image = "/images/ethercat.jpg"
+++

TODO intro

<!-- more -->

{% callout() %}

Are you looking to use Rust in your next EtherCAT deployment? Experiencing jitter or latency issues
in an existing EtherCrab app? I can help! Send me an email at [james@wapl.es](mailto:james@wapl.es)
to discuss your needs.

{% end %}

# Distributed clocks

- Brief intro to DC

  - OS clocks are good but not quite good enough for smooth and precise motion control e.g. for a
    DS402 drive in cyclic synchronous position mode.
  - Some systems also need to update outputs and read inputs at exactly the same time, e.g. to
    synchronise motion between multiple axes of a robot arm, otherwise you get deviations from the
    true path because axes aren't synced.
  - Briefly mention SYNC0 - need to define this terminology
  - DC fixes this by

    1. Using the first SD in the chain that supports DC as a reference clock for the rest of the
       network. This reference clock is much more consistent than the OS clock as it isn't
       constantly being interrupted by kernels, tasks, web browsers, etc
    2. Continuously sending alignment PDUs over the network to the other SDs to mitigate both phase
       and frequency drift between the reference clock and each SD's internal timebase as no two
       clocks will ever run at the same frequency

  - With this, it is possible to sync IO to within 100ns over the whole network.
  - Mitigates jitter from the MD by giving a window between SYNC0 pulses. The SD accepts the new
    data, then waits until the next SYNC0 to output it, or writes its inputs into a buffer ready for
    the next PD frame to transit the ESC.
  - There's other stuff to DC like calc and copy time but I won't cover it here

- My test system already has low jitter with `smol` executor, but this still isn't good enough for
  precise applications like motion control.
- EtherCrab can now do DC
- DC is quite complex so the example is long af but
  [here it is](https://github.com/ethercrab-rs/ethercrab/blob/cd049d84d144ca279c9c641b13104093daa04481/examples/dc.rs)
- The MD can read the EtherCAT system time. This can be moduloed to get an offset into the current
  DC cycle

  - This is how we sync the MD clock to the SYNC0 cycle
  - EtherCrab provides some utilities to allow a variable delay in the PD cycle to compensate for MD
    clock drift and jitter

- Results
  - Oscope screenshot: two SD clocks are aligned now, even though there's about 350ns of network
    propagation delay between them and the two clocks drift apart when not actively synced
  - Oscope screenshot: the example sends the PD frame at a 50% phase offset to SYNC0. You can also
    see the jitter, but it's consistently 50% in the DC cycle and very low, because we dynamically
    delay each PD cycle on the MD to account for network delays, hitches in the OS, clock drift, etc

# `io_uring`

- Improved performance and jitter over async
- Do I have comparisons I can show from the analyser GUI maybe?
- Control over thread count and placement, e.g. maybe you want to pin to a core the kernel is
  excluded from. Hard to do with e.g. `smol` which spawns another IO thread.
- Talk a little bit about how it works
  - Basically a hyper specific futures executor tailored for our application requirements, namely
    low latency and low jitter
  - Doesn't rely on hope that the internal implementation of an executor like `tokio` or `smol`
    meets these requirements
    - `tokio` for example has extremely variable jitter which isn't great for tight timing
    - TODO: Benchmark this
  - Efficient: it parks the thread when nothing needs to be sent, so CPU usage is very low

# Custom derives

- Added traits `EtherCrabWireRead`, `EtherCrabWireWrite`, `EtherCrabWireReadWrite`
- Not too bad to implement yourself, e.g. here's a simple struct with some custom behaviour.
- Derives! Not super fleshed out yet but they're good enough for most scenarios IMO. EtherCAT
  doesn't have particularly exotic types, just lots of cmoposition into structs and such.
  - Dogfooding, so if they work for me they should work for most of your cases.
- Why?
  - Originally used packed_struct but it gets strange around LE data and the bit/byte indexing, so I
    made my own
  - Safety around packing/unpacking, e.g. any padding bytes or reordering from Rust
  - Didn't want to have to make getters/setters for every field, which is why I liked packed_struct,
    so other options wouldn't work for me
  - Can do more EtherCAT-specific stuff in the future
- Why not?
  - If you need super spicy performance, just use #[repr(packed)] but be careful about the field
    accesses, need to use `addr_of!()` everywhere or make your own setters/getters
  - `packed_struct` works too but you have to be careful with the bit/byte indexing around little
    endian data.

# Conclusion

- Github
- crates.io
  - Derive crates too
- Looking for testimonials
- Sponno? Please? x

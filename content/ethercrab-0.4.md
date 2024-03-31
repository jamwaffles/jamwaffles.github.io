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

[EtherCrab 0.4.0](https://crates.io/crates/ethercrab/0.4.0), the pure Rust EtherCAT MainDevice is
out! I've added a lot of features and fixes to this release, including Distributed Clocks support,
an `io_uring`-based network driver for better performance, and a brand new set of derive-able traits
to make getting data into and out of your EtherCAT network easier than ever! The full changelog
including breaking changes can be found
[here](https://github.com/ethercrab-rs/ethercrab/blob/master/CHANGELOG.md), but for the rest of this
article let's dig a little deeper into some of the headline features.

<!-- more -->

{% callout() %}

Are you looking to use Rust in your next EtherCAT deployment? Experiencing jitter or latency issues
in an existing EtherCrab app? I can help! Send me an email at [james@wapl.es](mailto:james@wapl.es)
to discuss your needs.

{% end %}

# A quick note on terminology

The EtherCAT Technology Group (ETG) historically used the words "master" and "slave" to refer to the
controller of an EtherCAT network, and a downstream device respectively. These terms were changed by
the ETG recently to "MainDevice" and "SubDevice".The EtherCrab crate itself hasn't yet made this
transition, but will be doing so in a future release. This article uses "MainDevice" to refer to the
EtherCrab `Client` and "SubDevice" to refer to a `Slave` or `SlaveRef`.

# Distributed clocks

First up, Distributed Clocks (DC) support. I'm really proud of this feature because DC is complex to
implement and verifying correct operation is challenging, but I got through all that, and EtherCrab
now has support for Distributed Clocks! It's currently being used in the field and has solved a
bunch of problems the user was having with their servo drives without DC enabled which was fantastic
to see.

## A quick intro to Distributed Clocks

If you're not familiar with EtherCAT's Distributed Clocks functionality, I'll give a quick intro
here. Feel free to skip ahead if you don't need the refresher.

Distributed Clocks or DC for short is a fantastic part of EtherCAT that compensates for the fact
that the clocks in every device in the network suffer from drift, phase noise and incoherence
relative to each other. It is able to do this by designating a specific SubDevice as a reference
clock and distributing (hah) that timebase across the network, taking into account propagation
delays as well as continuously compensating for drift. EtherCAT networks with DC enabled can
synchronise all SubDevice input and ouput latching to within 100ns of each other if desired.

Because the timebase consistency is now handed over from the MainDevice to a SubDevice with a much
tighter clock source, this absolves the network of any jitter or latency in the clock or network
stack of the MainDevice when sending the PDI (Process Data Image).

A lot of applications don't need levels of timing this accurate (e.g. reading sensor data every half
a second is pretty relaxed) but for SubDevices like servo drives in Cyclic Synchronous Position
mode, it is vital to have a regular point in time where inputs and outputs are sampled. If the
timing is even a little irregular, the drive can error out, or even cause damage to the plant.

Another common use case for DC is synchronising multiple axes of motion. If the outputs of each axis
are not latched at the same time, deviations from the planned trajectory can occur.

With DC, a SubDevice will buffer the PDI until the next DC sync cycle (SYNC0 pulse), at which time
it will latch the input/output data. This gives a window of time in which the MainDevice can jitter,
stall or go on smoko before it sends the next PDI without the SubDevice having to care, as long as
the MainDevice sends the PDI before the next SYNC0 pulse.

## DC in EtherCrab

As an example of the best possible performance, EtherCrab is capable of sub-10ns coherence between
two SubDevices. The plot below shows the SYNC0 falling edge of two SubDevices aligned to within ~7ns
of each other. The green trace exhibits a small amount of jitter as real life is never perfect, but
still, seven nanoseconds!

{{ images1(path="/images/ethercrab-dc/lan9252-jitter.png") }}

The MainDevice (EtherCrab) is responsible for repeatedly sending synchronisation frames to keep all
SubDevice clocks aligned, as well as ensuring the Process Data Image (PDI) is sent at the right time
within the DC cycle.

EtherCrab's new `tx_rx_dc` method will handle sending the sync frame alongside the PDI, but also
returns a `CycleInfo` struct containing some timing data that can be used to establish a consistent
offset into the process data cycle. Here's an example using `smol` timers:

```rust
let (_tx, _rx, pdu_loop) = PDU_STORAGE.try_split().expect("can only split once");
let client = Client::new(pdu_loop, Timeouts::default(), ClientConfig::default());

let cycle_time = Duration::from_millis(5);

let mut group = client
    .init_single_group::<MAX_SUBDEVICES, PDI_LEN>(ethercat_now)
    .await
    .expect("Init");

// This example enables SYNC0 for every detected SubDevice
for mut sd in group.iter(&client) {
    sd.set_dc_sync(DcSync::Sync0);
}

let group = group
    .into_pre_op_pdi(&client)
    .await
    .expect("PRE-OP -> PRE-OP with PDI")
    .configure_dc_sync(
        &client,
        DcConfiguration {
            // Start SYNC0 100ms in the future
            start_delay: Duration::from_millis(100),
            // SYNC0 period should be the same as the process data loop in most cases
            sync0_period: cycle_time,
            // Send process data half way through cycle
            sync0_shift: cycle_time / 2,
        },
    )
    .await
    .expect("DC configuration")
    .request_into_op(&client)
    .await
    .expect("PRE-OP -> SAFE-OP -> OP");

// Wait for all SubDevices in the group to reach OP, whilst sending PDI to allow DC to start correctly.
while !group.all_op(&client).await? {
    let now = Instant::now();

    let (
        _wkc,
        CycleInfo {
            next_cycle_wait, ..
        },
    ) = group.tx_rx_dc(&client).await.expect("TX/RX");

    smol::Timer::at(now + next_cycle_wait).await;
}

// Main application process data cycle
loop {
    let now = Instant::now();

    let (
        _wkc,
        CycleInfo {
            next_cycle_wait, ..
        },
    ) = group.tx_rx_dc(&client).await.expect("TX/RX");

    // Process data computations happen here

    smol::Timer::at(now + next_cycle_wait).await;
}
```

This example configures a 5ms DC cycle time, and will produce delay values that allow the MainDevice
to send the PDI 2.5ms or 50% into the cycle. You can find a more complete example
[here](https://github.com/ethercrab-rs/ethercrab/blob/cd049d84d144ca279c9c641b13104093daa04481/examples/dc.rs).
DC is tricky to get right, so the example is quite long.

It's important to use `smol::Timer::at` (or equivalent for your executor/blocking code) instead of a
naive delay to compensate for variable computation times in the loop. With the above code, we can
achieve extraordinarily low jitter from the MainDevice that fits well within the established DC
cycle:

{{ images1(path="/images/ethercrab-dc/lan9252-low-std-dev-30s-persist-edit.png") }}

If you decide not to use the `next_cycle_wait` parameter, **or you use `tokio`**, the jitter will
look a lot worse:

{{ images1(path="/images/ethercrab-dc/lan9252-bad-tokio.png") }}

If you would prefer not to use async timers, I'd recommend the
[`timerfd` crate](https://docs.rs/timerfd/latest/timerfd/) to get best timing accuracy.

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

# Honourable mentions

## Multiple EtherCAT frames can now be sent in one Ethernet frame

If two or more EtherCAT frames needed to be sent at once, EtherCrab 0.3.x would send these in two
separate Ethernet frames. This is inefficient and became an issue when DC support was added. DC
requires a sync frame to be sent alongside the PDI, and in 0.3.x this means doubling the network
overhead.

EtherCrab 0.4 now sends this sync frame next to the PDI frame, reducing overhead and improving
performance.

There are other places in EtherCrab that don't yet use this functionality, but they're less
performance sensitive than the application process data cycle.

# Conclusion

- Github
- crates.io
  - Derive crates too
- Looking for testimonials
- Sponno? Please? x

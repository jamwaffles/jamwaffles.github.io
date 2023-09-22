+++
layout = "post"
title = "Announcing EtherCrab: The 100% Rust EtherCAT controller"
slug = "announcing-ethercrab-the-rust-ethercat-controller"
date = "2023-09-19 11:50:47"
draft = true
+++

The EtherCrab story started with my dream of writing a motion controller in Rust to provide a modern
alternative to the venerable [LinuxCNC project](https://github.com/LinuxCNC/linuxcnc/). But motion
controllers are hard, even with the right books, so I did what any good programmer would do:
procrastinate by implementing an entire industrial automation protocol in instead! **Say hello to
[EtherCrab](https://crates.io/crates/ethercrab) - a pure Rust EtherCAT controller that supports
Linux, macOS, Windows and even `no_std`.**

<!-- more -->

{% callout() %}

TODO P.s. I'm looking for work!

- Contracting/consulting
- Fulltime
- EtherCAT or other Rust work
- Please
- CV [here](https://wapl.es/cv/)
- Remote pls, or Edinburgh local

{% end %}

# A quick primer on EtherCAT

Feel free to skip this section if you're already familiar with EtherCAT.

If not, here's a high level overview [EtherCAT](https://www.ethercat.org/default.htm):

- It is a very widely supported and used industrial communication protocol pioneered and
  standardised by [Beckhoff](https://www.beckhoff.com).
- It uses the Ethernet physical layer (i.e. cables and connectors) for good compatibility, but uses
  its own packet structure to cater to EtherCAT's needs around latency and topology.
- It is designed for realtime systems with cycle times into the microseconds if desired
- There is one controller ("master" in EtherCAT terminology)
- Many devices ("slaves") are connected in a long chain, so have at least two ports: input and
  output.
  - A quick aside: EtherCAT is really a tree topology, traversed in a well defined order, but is
    most often deployed in a chain. "Fork" or "star" nodes will have 3 or 4 ports respectively.
- EtherCAT packets are sent along the entire chain in a fixed traversal order, then sent all the way
  back to the controller, allowing devices to read and write data to packets addressed to them.
- Packets are read/written during their transit through each device meaning latencies are in the low
  hundreds of nanoseconds per device range.
- Cyclic process data is sent in one 4GB address space. Devices are configured by the controller to
  read from/write into specific pieces of this address space.

There are other bits of the protocol and many extensions available, but the above hopefully gives a
good high level introduction. I've also found the
[EtherCAT Device Protocol poster](https://www.ethercat.org/download/documents/EtherCAT_Device_Protocol_Poster.pdf)
a good reference.

# Prior art

There are a couple of good solutions out there already, namely the Etherlab
[IgH master](https://gitlab.com/etherlab.org/ethercat) as well as
[SOEM](https://github.com/OpenEtherCATsociety/SOEM), so why didn't I just use those? These are
battle-tested EtherCAT controllers and there are even Rust wrappers for both.

C. They're written in C.

SOEM seemed a good choice as it provides a lower level interface which is what I was looking for,
but I decided the world needed a pure Rust implementation instead. I found SOEM frustrating to work
with, mainly because there is very little documentation and example code, along with the C API which
is just a pile of functions in a trench coat. The [Rust wrapper](https://crates.io/search?q=soem) is
quite lightweight and leaks a lot of the C-ness through, so it didn't help much as glad as I was to
find it.

Human and physical safety is critical in many applications, so why are we still writing the control
software behind these systems in unsafe languages like C? Let's fix that!

EtherCrab was borne out of these frustrations, and I think provides a better, safer, native option
for those wanting to expand the nascent Rust-in-automation field.

# TODO: Title. EtherCrab's ethos, design, etc

- Safe with various API design decisions
  - There's some unsafety in the core, but it's abstracted away in a safe high level API, as is Rust
    tradition
- async-first for a nice API, and the ability to easily use EtherCrab from multiple threads
  - You can block if you like
    - Spawn a dedicated PDU loop thread, set RT prio, use e.g. `smol::block_on`
    - Main thread can run a single task or multiple tasks
    - `thread::scoped` is handy here
    - Should be possible in embedded as well with interrupts, but this needs testing
- no-std compatible. Doesn't even need an allocator
- Designed around device groups from the ground up, so it's easy to run different devices at
  different cycle times
- Uses Rust's trait/ownership system to ensure the EtherCAT PDI is held correctly. A lot of EtherCAT
  controllers let you do whatever with the PDI which can be useful, but isn't safe. EtherCrab does a
  lot of checks at compile time to remain fast, although does use an `atomic_refcell::AtomicRefCell`
  when getting a device reference from a group.
- Low jitter when used in a realtime system. Caveat benchmark but `examples/jitter.rs` gives pretty
  good results on a PREEMPT_RT system!
- Works on Linux, macOS and Windows but please just use Linux for your sanity's sake

## A quick note on `no_std``

EtherCrab is async, therefore needs an executor to run on. It's still early days in the embedded
Rust async ecosystem, but there are at least two rather good environments to consider:
[RTIC 2](https://rtic.rs/2) and [Embassy](https://embassy.dev/). There's a basic EtherCrab example
using Embassy to get started with
[here](https://github.com/ethercrab-rs/ethercrab/tree/master/examples/embassy-stm32). If you use
RTIC and would like to contribute an example for it, I'd be very happy to accept a PR!

Because EtherCrab's storage is all fixed-size, and the fixed sizes are configurable with const
generics, it's easy to tune EtherCrab to the resources available on whichever target microcontroller
is used. Statically allocating resources like this is also of benefit to `std` environments - no
dynamic alloc means no hitches or hiccups from dynamically allocating more memory.

# Example tiem!!11!

Now I've described EtherCrab's design, let's see it in action with a quick example.

This code is taken from
[here](https://github.com/ethercrab-rs/ethercrab/blob/master/examples/multiple-groups.rs). It
initialises the EtherCAT network and groups the devices into two groups, allowing two concurrent
tasks to update different parts of the process data at different rates.

More examples can be found in
[the `examples/` folder in the repo](https://github.com/ethercrab-rs/ethercrab/tree/master/examples).

- Walk through line by line
- Use a std environment for niceness.
- Multiple groups
- Put it all together at the end

# Conclusion

- Hmm.
- Use it, break it, let me know!
- Still some features to go
  - FSoE
  - MDP
    - One pain point for me was CiA402/DS402. Would like to build in support for servos as it's a
      common use case
      - Would like ideas
      - Open a Github discussion and link to it
- EtherCrab is already in limited commercial use.
  - I'm looking for guinea pigs!
- I'm looking for work (again)
- Link to Github again
  - Star it pls
  - Share it pls
- Link to Matrix

+++
layout = "post"
title = "Announcing EtherCrab: A 100% Rust EtherCAT controller"
date = "2023-09-19 11:50:47"
draft = true
+++

> I'm looking for work!
>
> - Contracting/consulting
> - Fulltime
> - EtherCAT or other Rust work
> - Please
> - CV [here](https://wapl.es/cv/)
> - Remote pls, or Edinburgh local

# Intro

- I have a CNC machine I'd like to control with some nice servos
  - Most drives support at least EtherCAT these days
  - It's a nice protocol that just uses normal Ethernet cables so you don't need special control
    hardware
- I like Rust. A lot.
- Rust is perfect for automation: fast, safe
- Not much going on yet though. Let's fix that!
- I looked at IgH (TODO: Full name), SOEM. Gave the Rust wrappers a go but they leak the C-ness of
  the underlying library

  - Lack of good examples and docs (although EtherCrab does still need work in this area)
  - EtherCrab was borne of this frustration with docs and C-like API of SOEM

# A quick primer on EtherCAT

Feel free to skip this section if you're already familiar with EtherCAT.

- Very widely supported industrial communication protocol pioneered and standardised by Beckhoff.
- It uses Ethernet physical layer for good compatibility, but uses its own packet structure to cater
  to EtherCAT needs
- Designed for realtime systems with cycle times into the microseconds if desired
- Devices have at least an input and output port. Conceptual topology is a tree, but more often used
  as a simpler single chain of devices.
- Packets are sent to the end of the tree in a defined traversal order, then sent all the way back
  to the controller, allowing a quite elegant way to read and write data
- Packets are read/written during their transit through each device so latencies are in the hundreds
  of nanoseconds per device range

# With that then, what is EtherCrab

- Safe with various API design decisions
  - There's some unsafety in the core, but it's abstracted away in a safe high level API, as is Rust
    tradition
- async-first for a nice API, and the ability to easily use EtherCrab from multiple threads
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

# A quick note on no_std

- Requires async but we're getting better at that with stuff like RTIC and Embassy
- Point to Embassy example
- Arrays and const generics so known memory footprint
- "Allocate"s everything up front
- Also a good design for std systems as the lack of dynamic alloc makes the system deterministic

# Example tiem!!11!

Find more at [here](todo lol).

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

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

And I like Rust. A lot. More seriously though, human, physical, electrical and ATEX safety (among
others) is critical in many industrial applications, so why are we still writing the control
software behind these systems in an unsafe, easy to misuse language? Let's fix that!

At first, SOEM seemed like a good choice for me as it provides a lower level interface which is what
I was looking for, but I pretty quickly decided the world needed a Rust implementation instead.
SOEM, like many C libraries, is frustrating to work with. It has very little documentation and
example code, along with a C API which is just a pile of functions in a trench coat. The
[Rust wrapper](https://crates.io/search?q=soem) is quite thin and leaks a lot of the C-ness through,
so it didn't help much.

EtherCrab was borne out of these frustrations. I was looking for a safe, ergonomic EtherCAT
controller and couldn't find one that was particularly well suited to the Rust ecosystem. One
EtherCAT membership application later, and here we are.

# A motivating example

Let's see EtherCrab in action with a quick example.

This code is taken from
[here](https://github.com/ethercrab-rs/ethercrab/blob/master/examples/multiple-groups.rs). It
initialises the EtherCAT network and groups the devices into two groups allowing two concurrent
tasks to update different parts of the process data at different rates. This example targets Linux,
but should work on macOS and even Windows as long as the weird NPcap driver is setup correctly.

More examples can be found in
[the `examples/` folder in the repo](https://github.com/ethercrab-rs/ethercrab/tree/master/examples).

You can also find a `no_std` example using [Embassy](https://embassy.dev/)
[here](https://github.com/ethercrab-rs/ethercrab/tree/master/examples/embassy-stm32).

```rust
use ethercrab::{
    error::Error, std::tx_rx_task, Client, ClientConfig, PduStorage, SlaveGroup, SlaveGroupState,
    Timeouts,
};

/// Maximum number of slaves that can be stored. This must be a power of 2 greater than 1.
const MAX_SLAVES: usize = 16;
/// Maximum PDU data payload size - set this to the max PDI size or higher.
const MAX_PDU_DATA: usize = 1100;
/// Maximum number of EtherCAT frames that can be in flight at any one time.
const MAX_FRAMES: usize = 16;

static PDU_STORAGE: PduStorage<MAX_FRAMES, MAX_PDU_DATA> = PduStorage::new();

#[derive(Default)]
struct Groups {
    /// EL2889 and EK1100/EK1501. For EK1100, 2 items, 2 bytes of PDI for 16 output bits. The EK1501
    /// has 2 bytes of its own PDI so we'll use an upper bound of 4.
    ///
    /// We'll keep the EK1100/EK1501 in here as it has no useful PDI but still needs to live
    /// somewhere.
    slow_outputs: SlaveGroup<2, 4>,
    /// EL2828. 1 item, 1 byte of PDI for 8 output bits.
    fast_outputs: SlaveGroup<1, 1>,
}

#[tokio::main]
async fn main() -> Result<(), Error> {

    let interface = "enp2s0";

    let (tx, rx, pdu_loop) = PDU_STORAGE.try_split().expect("can only split once");

    let client = Client::new(pdu_loop, Timeouts::default(), ClientConfig::default());

    tokio::spawn(tx_rx_task(&interface, tx, rx).expect("spawn TX/RX task"));

    let client = Arc::new(client);

    // Read configurations from slave EEPROMs and configure devices.
    let Groups {
        slow_outputs,
        fast_outputs,
    } = client.init::<MAX_SLAVES, _>(|groups: &Groups, slave| match slave.name() {
            "EL2889" | "EK1100" | "EK1501" => Ok(&groups.slow_outputs),
            "EL2828" => Ok(&groups.fast_outputs),
            _ => Err(Error::UnknownSlave),
        })
        .await
        .expect("Init");

    let client_slow = client.clone();

    let slow_task = tokio::spawn(async move {
        let slow_outputs = slow_outputs
            .into_op(&client_slow)
            .await
            .expect("PRE-OP -> OP");

        let mut slow_cycle_time = tokio::time::interval(Duration::from_millis(10));

        let slow_duration = Duration::from_millis(250);

        // Only update "slow" outputs every 250ms using this instant
        let mut tick = Instant::now();

        // EK1100 is first slave, EL2889 is second
        let el2889 = slow_outputs
            .slave(&client_slow, 1)
            .expect("EL2889 not present!");

        // Set initial output state
        el2889.io_raw().1[0] = 0x01;
        el2889.io_raw().1[1] = 0x80;

        loop {
            slow_outputs.tx_rx(&client_slow).await.expect("TX/RX");

            // Increment every output byte for every slave device by one
            if tick.elapsed() > slow_duration {
                tick = Instant::now();

                let (_i, o) = el2889.io_raw();

                // Make a nice pattern on EL2889 LEDs
                o[0] = o[0].rotate_left(1);
                o[1] = o[1].rotate_right(1);
            }

            slow_cycle_time.tick().await;
        }
    });

    let fast_task = tokio::spawn(async move {
        let mut fast_outputs = fast_outputs.into_op(&client).await.expect("PRE-OP -> OP");

        let mut fast_cycle_time = tokio::time::interval(Duration::from_millis(5));

        loop {
            fast_outputs.tx_rx(&client).await.expect("TX/RX");

            // Increment every output byte for every slave device by one
            for slave in fast_outputs.iter(&client) {
                let (_i, o) = slave.io_raw();

                for byte in o.iter_mut() {
                    *byte = byte.wrapping_add(1);
                }
            }

            fast_cycle_time.tick().await;
        }
    });

    tokio::join!(slow_task, fast_task);

    Ok(())
}
```

A few lines have been omitted for brevity in this walkthrough. The full example can be found
[here](TODO).

# EtherCrab's design

EtherCrab supports Linux, macOS and Windows but please, for your sanity, target Linux or macOS at a
push. There is also `no_std` support as EtherCrab makes heavy use of const generics to remove the
need for an allocator. You can find an embedded example using [Embassy](https://embassy.dev/)
[here](https://github.com/ethercrab-rs/ethercrab/tree/master/examples/embassy-stm32), although other
runtimes should work great too, like [RTICv2](https://rtic.rs/2).

<!-- EtherCrab has a split architecture. It has a TX/RX task that handles queuing of packets, and sending/receiving them over the network interface. This is wrapped in a client handle that is used -->

<!-- EtherCrab is `async`-first, allowing the
The API presented is `async`, and the ability to easily use EtherCrab from multiple threads -->

On initialisation, EtherCrab scans the EtherCAT network and assigns a Configured Station Address to
each discovered device. Two options are then available: a single group can be created with all
devices in it, or multiple groups can be created, allowing different devices to have different
behaviours during operation. A device is always owned by only one group.

1. Devices are in groups - you can have one by default or multiple
2. groups need the client
3. client is a wrapper around the PDU loop
4. PDU loop is a split design
5. TX/RX task can be run in a different thread
6. TX/RX task is not coupled to the actual network comms mechanism so can support whatever you want
   as long as that interface can send a byte slice, and pass one to the PDU loop when a response is
   received

## Thread safety

The PDU loop is the only place writable data is stored. It contains the only unsafety in the crate,
and has checks, careful design and atomics to ensure that packet buffers are only ever given out
once. This means that the PDU loop is `Sync`, allowing `Client` to be sync, allowing it to be used
safely by multiple threads or tasks running their own process cycles.

- Designed around device groups from the ground up, so it's easy to run different devices at
  different cycle times, e.g. IO at low freq and a servo loop at high freq
- Safe with various API design decisions
  - There's some unsafety in the core, but it's abstracted away in a safe high level API, as is Rust
    tradition
- Uses Rust's trait/ownership system to ensure the EtherCAT PDI is held correctly. A lot of EtherCAT
  controllers let you do whatever with the PDI which can be useful, but isn't safe. EtherCrab does a
  lot of checks at compile time to remain fast, although does use an `atomic_refcell::AtomicRefCell`
  when getting a device reference from a group.

  - E.g. a group can only transmit/receive the PDI by calling `group.tx_rx().await`. This method is
    `&mut self` which doesn't allow anything else to access the PDI while it's in flight.

  - Something for the future: an API to interpret the raw PDI as a struct, with some checks, for
    better ergonomics whilst retaining safety. Still a chance that the bytes don't map to the right
    things if the slave is misconfigured, but that's difficult to fix as the slave's PDI can be
    configured in so many different ways. But it will be safe in Rust's meaning of the word - no
    leaks or out of bounds reads.

- Low jitter is achievable when used in a realtime system. Caveat benchmark of course, but
  [`examples/jitter.rs`](https://github.com/ethercrab-rs/ethercrab/blob/master/examples/jitter.rs)
  gives pretty good results on a PREEMPT_RT system!

<!-- NOTE: This probably isn't needed - no_std could just block too -->
<!-- ## A quick note on `no_std``

EtherCrab is async, therefore needs an executor to run on. It's still early days in the embedded
Rust async ecosystem, but there are at least two rather good environments to consider:
[RTIC 2](https://rtic.rs/2) and [Embassy](https://embassy.dev/). There's a basic EtherCrab example
using Embassy to get started with
[here](https://github.com/ethercrab-rs/ethercrab/tree/master/examples/embassy-stm32). If you use
RTIC and would like to contribute an example for it, I'd be very happy to accept a PR!

Because EtherCrab's storage is all fixed-size, and the fixed sizes are configurable with const
generics, it's easy to tune EtherCrab to the resources available on whichever target microcontroller
is used. Statically allocating resources like this is also of benefit to `std` environments - no
dynamic alloc means no hitches or hiccups from dynamically allocating more memory. -->

# Use in non-async contexts

The example above is async. This can be a problem if:

1. The application around EtherCrab isn't async and/or
2. You need more control over the threads that each task runs in for jitter or latency reasons

- You can block instead if you like - just run everything in threads. This gives more control over
  priority and scheduling, e.g. using the
  [`thread_priority` crate](https://crates.io/crates/thread_priority).

  E.g.

  ```rust
  let thread_id = thread_native_id();
  set_thread_priority_and_policy(
      thread_id,
      ThreadPriority::Crossplatform(ThreadPriorityValue::try_from(99u8).unwrap()),
      ThreadSchedulePolicy::Realtime(RealtimeThreadSchedulePolicy::Fifo),
  )
  .expect("could not set thread priority. Are the PREEMPT_RT patches in use?");
  ```

- We'll use `smol::block_on` for this example as it gave good jitter results when tested against
  `tokio`.
- Spawn a dedicated PDU loop thread, set RT as above
- Main thread can run a single task or multiple tasks in spawned threads. Each group can be sent to
  only one thread, guaranteeing no clobbering of PDI.
- `thread::scoped` is handy here
- Should be possible to use a blocking wrapper in embedded as well with interrupts so you're not
  tied to e.g. RTICv2 or Embassy, although this is untested
- This approach works pretty well

# Conclusion

- Hmm.
- If you find some unsoundness or unsafety please tell me. I'll look like a tit for saying EtherCrab
  is safe, and I do even test some bits with MIRI, but I'm sure I've missed something.
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

```

```

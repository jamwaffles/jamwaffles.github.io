+++
layout = "post"
title = "Announcing EtherCrab: The 100% Rust EtherCAT controller"
slug = "announcing-ethercrab-the-rust-ethercat-controller"
started_date = "2023-10-12 14:11:00"
date = "2023-10-12 14:11:00"

[extra]
image = "/images/ethercat.jpg"
+++

The EtherCrab story started with my dream of writing a motion controller in Rust to provide a modern
alternative to the venerable [LinuxCNC project](https://github.com/LinuxCNC/linuxcnc/). But motion
controllers are hard, even with the right books, so I did what any good programmer would do:
procrastinate by implementing an entire industrial automation protocol instead! **Say hello to
[EtherCrab](https://crates.io/crates/ethercrab) - a pure Rust EtherCAT controller that supports
Linux, macOS, Windows and even `no_std`.**

<!-- more -->

{% callout() %}

Are you looking to use Rust in your next EtherCAT deployment? Experiencing jitter or latency issues
in an existing EtherCrab app? I can help! Send me an email at [james@wapl.es](mailto:james@wapl.es)
to discuss your needs.

{% end %}

# A quick primer on EtherCAT

Feel free to skip this section if you're already familiar with EtherCAT.

If you're new to [EtherCAT](https://www.ethercat.org/default.htm), here's a quick high level
overview:

- It is a very widely supported and used industrial communication protocol pioneered and
  standardised by [Beckhoff](https://www.beckhoff.com).
- It uses the Ethernet physical layer (i.e. cables and connectors) for good compatibility, but
  describes its own packet structure on top of Ethernet II frames to cater to EtherCAT's needs
  around latency and topology.
- It is designed for realtime systems with cycle times down into the microseconds if desired
- There is one controller ("master" in EtherCAT terminology)
- One or more devices ("slaves") are connected in a long chain, so have at least two ports: input
  and output.
- EtherCAT packets are sent along the entire chain in a fixed traversal order, then sent all the way
  back to the controller, allowing devices to read and write data to packets addressed to them.
- Packets are read/written during their transit through each device meaning latencies are in the low
  hundreds of nanoseconds per device range.
- Cyclic process data is sent in one 4GB address space. Devices are configured by the controller to
  read from/write into specific pieces of this address space.

There are other bits of the protocol and many extensions available, but the above hopefully gives a
decent introduction to the basics. I've also found the
[EtherCAT Device Protocol poster](https://www.ethercat.org/download/documents/EtherCAT_Device_Protocol_Poster.pdf)
a good starting point for further learning.

# Prior art

There are many EtherCAT controller solutions out there already, two of which are the Etherlab
[IgH master](https://gitlab.com/etherlab.org/ethercat) as well as
[SOEM](https://github.com/OpenEtherCATsociety/SOEM). These are battle-tested EtherCAT controllers
and there are even Rust wrappers for both, so why didn't I just pick one and use it?

C. They're written in C.

And I like Rust. A lot. More seriously though, human, physical, electrical and ATEX safety (among
others) is critical in many industrial applications, so why are we still writing the control
software behind these systems in an unsafe, easy to misuse language? Let's fix that!

Of the solutions I looked at in detail, SOEM seemed like a good choice for me as it provides a lower
level interface, which is what I was looking for. After working through some code and even getting a
servo drive running, I pretty quickly decided the world needed a Rust implementation instead.

SOEM, like many C libraries, is frustrating to work with. It has very little documentation and
example code, along with a C API which is just a pile of functions in a trench coat. The
[Rust wrapper](https://crates.io/search?q=soem) is quite thin and leaks a lot of the C-ness through,
so it didn't help much.

EtherCrab was borne out of these frustrations. I was looking for an open, safe, ergonomic EtherCAT
controller and couldn't find one that was particularly well suited to the Rust ecosystem. One
EtherCAT membership application later, and here we are.

# A motivating example

With our brief history lesson over, let's see EtherCrab in action with a quick example.

This code is taken from
[here](https://github.com/ethercrab-rs/ethercrab/blob/master/examples/multiple-groups.rs). It
initialises the EtherCAT network and assigns the discovered devices into two groups. Groups are an
EtherCrab concept, and allow concurrent tasks to update different parts of the process data image
(PDI) at different rates. For example, a machine in a factory might have some digital IOs polled at
a "slow" 10ms, and a servo drive cycle at 1ms. Groups are `Send` so can be run concurrently in
different threads.

This example targets Linux, but should work on macOS and even Windows as long as the weird NPcap
driver is setup correctly.

More examples can be found in
[the `examples/` folder in the repo](https://github.com/ethercrab-rs/ethercrab/tree/master/examples).

You can also find a `no_std` example using [Embassy](https://embassy.dev/)
[here](https://github.com/ethercrab-rs/ethercrab/tree/master/examples/embassy-stm32).

Firstly, some imports as is tradition.

```rust
use ethercrab::{
    error::Error, std::tx_rx_task, Client, ClientConfig, PduStorage, SlaveGroup, SlaveGroupState,
    Timeouts,
};
```

One import of note is `std::tx_rx_task`. This is a ready-made function that creates a future which
handles all network communications. This would be switched out for something else if a different
network driver is used, or for a mock if writing tests. EtherCrab provides building blocks to make
writing your own networking adapters as easy as possible.

Next, because EtherCrab statically allocates all its memory using const generics, it needs to know
some details about how much storage it should be given. We could use magic numbers where required,
but let's give these values sensible names so we know which numbers mean what.

```rust
/// Maximum number of slaves that can be stored. This must be a power of 2 greater than 1.
const MAX_SLAVES: usize = 16;
/// Maximum PDU data payload size - set this to the max PDI size or higher.
const MAX_PDU_DATA: usize = 1100;
/// Maximum number of EtherCAT frames that can be in flight at any one time.
const MAX_FRAMES: usize = 16;
```

Next up is `PduStorage`. This is where all network packets are queued and held while waiting for a
response. Because this example uses `tokio`, which requires `Send + 'static` futures, we'll make a
static instance called `PDU_STORAGE`. If you're using scoped threads or a more relaxed executor,
this could be an ordinary `let` binding in `main`.

`PduStorage` contains `unsafe` code, but is carefully designed and checked to contain it, whilst
providing a safe API on top. `PduStorage` has no public API, but its creation is handled by the end
application so as to control the lifetimes of the data it hands out.

```rust
static PDU_STORAGE: PduStorage<MAX_FRAMES, MAX_PDU_DATA> = PduStorage::new();
```

We'd like multiple groups so let's define a struct to give them names. This could be a tuple
instead, but the indexes can get confusing so we'll use a struct.

```rust
#[derive(Default)]
struct Groups {
    /// EL2889 and EK1100/EK1501. For EK1100, 2 items, 2 bytes of PDI for 16 output bits. The
    /// has 2 bytes of its own PDI so we'll use an upper bound of 4.
    ///
    /// We'll keep the EK1100/EK1501 in here as it has no useful PDI but still needs to live
    /// somewhere.
    slow_outputs: SlaveGroup<2, 4>,
    /// EL2828. 1 item, 1 byte of PDI for 8 output bits.
    fast_outputs: SlaveGroup<1, 1>,
}
```

Let's begin our app code by starting the TX/RX task in the background, along with creating a
`Client`. The `Client` is the main handle into EtherCrab and is what any application code should
use.

```rust
let interface = "enp2s0";

let (tx, rx, pdu_loop) = PDU_STORAGE.try_split().expect("can only split once");

let client = Client::new(pdu_loop, Timeouts::default(), ClientConfig::default());

tokio::spawn(tx_rx_task(&interface, tx, rx).expect("spawn TX/RX task"));
```

If different network machinery is used, `tx` and `rx` would be passed into custom code to drive
them.

We're going to need the client in two tasks, so we'll wrap it in an `Arc` to allow it to be
`clone()`d. The methods on `Client` are `&self` allowing concurrent usage without any kind of mutex
or lock. EtherCrab was designed from the start to be thread safe.

```rust
let client = Arc::new(client);
```

Now we'll initialise the EtherCAT network. `client.init()` will assign an EtherCAT "Configured
Station Address" to each device, read their EEPROM configurations and set up the sync managers and
FMMUs ready for configuration and communication.

`init()` takes a closure that must return a reference to a group the current device will be added
to. In this example, we match on the device name but other identifiers or application-specific logic
could be used.

Once `init` returns, we will have two groups with all devices in `PRE-OP` state.

```rust
let Groups {
    slow_outputs,
    fast_outputs,
} = client
    .init::<MAX_SLAVES, _>(|groups: &Groups, device| match device.name() {
        "EL2889" | "EK1100" | "EK1501" => Ok(&groups.slow_outputs),
        "EL2828" => Ok(&groups.fast_outputs),
        _ => Err(Error::UnknownSlave),
    })
    .await
    .expect("Init");
```

{% callout() %}

ℹ️ If only one group is desired, we could forego the `Groups` struct and use
`client.init_single_group` instead:

```rust
/// Maximum total PDI length.
const PDI_LEN: usize = 64;

let all_devices = client
    .init_single_group::<MAX_SLAVES, MAX_PDI>()
    .await
    .expect("Init");
```

{% end %}

Now we'll create a clone of the client (well, the `Arc` that wraps it) so we can pass it to a second
task. Again, we don't need a lock or mutex because the methods on `Client` are `&self`, `Client` is
`Sync`, and EtherCrab's internals are thread safe.

```rust
let client_slow = client.clone();
```

Now we come to the application logic. This will most often be a `loop` with a set delay in it to
define the cycle time for the group.

```rust
let slow_task = tokio::spawn(async move {
    let slow_outputs = slow_outputs
        .into_op(&client_slow)
        .await
        .expect("PRE-OP -> OP");

    let mut slow_cycle_time = tokio::time::interval(Duration::from_millis(10));

    let slow_duration = Duration::from_millis(250);

    let mut tick = Instant::now();

    // We're assuming the first device is the EL2889
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
```

Pay attention to the `loop { ... }`, specifically:

1. This is the cyclic application logic. The code in this example does some low level bit twiddling
   but this is where more complex logic can be performed, **as long as the computation time doesn't
   exceed the cycle time.** If it does, you'll get stalls or hitches in the output.
2. The `tx_rx` method **must** be called every cycle otherwise the group's data will not be sent or
   received!
3. `tick().await` internally compensates for the execution time in each loop iteration, so there's
   no need to handle this manually.

Now we can spawn the other "fast" task which just increments each byte of the outputs of each device
in this group's PDI (Process Data Image).

```rust
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
```

Now we can start both tasks concurrently, exiting if one of them errors out.

```rust
tokio::join!(slow_task, fast_task);
```

Error handling and a few other lines have been omitted from this walkthrough for brevity. The full
example can be found
[here](https://github.com/ethercrab-rs/ethercrab/blob/master/examples/multiple-groups.rs).

# EtherCrab's design

EtherCrab is `async`-first and supports Linux, macOS and Windows but please, for your sanity, target
Linux. macOS at a push. There is also `no_std` support as EtherCrab makes heavy use of const
generics to remove the need for an allocator. You can find an embedded example using
[Embassy](https://embassy.dev/)
[here](https://github.com/ethercrab-rs/ethercrab/tree/master/examples/embassy-stm32), although other
runtimes should work great too, like [RTICv2](https://rtic.rs/2).

<!-- EtherCrab has a split architecture. It has a TX/RX task that handles queuing of packets, and sending/receiving them over the network interface. This is wrapped in a client handle that is used -->

<!-- EtherCrab is `async`-first, allowing the
The API presented is `async`, and the ability to easily use EtherCrab from multiple threads -->

On initialisation, EtherCrab scans the EtherCAT network and assigns a Configured Station Address to
each discovered device. Two options are then available: a single group can be created with all
devices in it, or multiple groups can be created, allowing different devices to have different
behaviours during operation. A device is always owned by only one group.

EtherCAT devices must be transitioned through various operational states before they can operate
with cyclic application data. EtherCrab leverages Rust's strong type system to only allow method
calls that are valid for the current state of a group. For example, the `tx_rx` method which
transfers the group's PDI is only callable in `SAFE-OP` or `OP` as this functionality is invalid in
any other state. This makes the API simpler to use, and removes most of the footguns I found when
trying out SOEM.

<!-- 1. Devices are in groups - you can have one by default or multiple
1. groups need the client
2. client is a wrapper around the PDU loop
3. PDU loop is a split design
4. TX/RX task can be run in a different thread
5. TX/RX task is not coupled to the actual network comms mechanism so can support whatever you want
   as long as that interface can send a byte slice, and pass one to the PDU loop when a response is
   received -->

## Thread safety and ownership

The PDU loop is the single place where writable data is stored. It contains the only `unsafe` code
in the crate, and has checks, careful design and uses atomics to ensure that packet buffers are only
ever loaned to one owner. This means that the PDU loop is `Sync`, allowing `Client` to also be
`Sync`, so can be used safely by multiple threads or tasks running their own process cycles.

A lot of EtherCAT controllers let you do whatever you want with the PDI which is flexible, but isn't
even close to safe. Concurrent writes and other potential race conditions erode confidence in what
is actually sent to the device.

By leveraging Rust's strong type system and borrow checker, EtherCrab prevents this issue from
happening almost entirely at compile time. There is a single runtime check using an
`atomic_refcell::AtomicRefCell` when getting a reference to a device in a group, but performance is
otherwise unaffected when accessing the PDI.

<!-- EtherCrab solves this mostly with Rust's strong type system and borrow checker at compile time.
The only runtime check is the use of `atomic_refcell::AtomicRefCell` and a fallible API when getting a reference to
a device in a group to prevent the same device reference being held in two places. -->

A good concise example of this deliberate safety in the API is the `group.tx_rx().await` call:

```rust
impl SlaveGroup {
    // snip

    async fn tx_rx(&self, client: &Client<'_>) -> Result<u16, Error> {
        // ...
    }
```

Because `tx_rx()` is `&mut self`, no references to any devices may be held while their underlying
PDI data is read/written over the network. This completely removes the possibility of a race
condition _entirely at compile time_ with _no performance penalty._

# Use in non-async contexts

The example shown earlier uses `tokio` and a lot of `async`/`await`. This can be a problem if:

1. The application around EtherCrab isn't async and/or
2. You need more control over the threads that each task runs in for jitter or latency reasons

If your application (std or even `no_std`) does not use `async`, EtherCrab's methods can be wrapped
in functions that block on the returned future, making it a sync API.

Here's an example of a small blocking application using `smol::block_on`. It spawns a thread in the
background to run the TX/RX task.

```rust
use ethercrab::{error::Error, std::tx_rx_task, Client, ClientConfig, PduStorage, Timeouts};
use std::{sync::Arc, time::Duration};

const MAX_SLAVES: usize = 16;
const MAX_PDU_DATA: usize = 1100;
const MAX_FRAMES: usize = 16;
const PDI_LEN: usize = 64;

static PDU_STORAGE: PduStorage<MAX_FRAMES, MAX_PDU_DATA> = PduStorage::new();

fn main() -> Result<(), Error> {
    let (tx, rx, pdu_loop) = PDU_STORAGE.try_split().expect("can only split once");

    let client = Arc::new(Client::new(
        pdu_loop,
        Timeouts::default(),
        ClientConfig::default(),
    ));

    std::thread::spawn(move || {
        smol::block_on(tx_rx_task(&interface, tx, rx).expect("spawn TX/RX task"))
            .expect("TX/RX task failed");
    });

    let mut group = smol::block_on(async {
        let group = client
            .init_single_group::<MAX_SLAVES, PDI_LEN>()
            .await
            .expect("Init");

        log::info!("Discovered {} slaves", group.len());

        group.into_op(&client).await.expect("PRE-OP -> OP")
    });

    loop {
        smol::block_on(group.tx_rx(&client)).expect("TX/RX");

        // Increment every output byte for every slave device by one
        for slave in group.iter(&client) {
            let (_i, o) = slave.io_raw();

            for byte in o.iter_mut() {
                *byte = byte.wrapping_add(1);
            }
        }

        // NOTE: Jitter on this will be awful - consider using `timerfd` or something better.
        std::thread::sleep(Duration::from_millis(5));
    }
}
```

Running EtherCrab this way does give more control over thread priority and placement. For example,
on a realtime system we can use the
[`thread_priority` crate](https://crates.io/crates/thread_priority) to set the priority of the TX/RX
thread:

E.g.

```rust
std::thread::spawn(move || {
    let thread_id = thread_native_id();

    set_thread_priority_and_policy(
        thread_id,
        ThreadPriority::Crossplatform(ThreadPriorityValue::try_from(49u8).unwrap()),
        ThreadSchedulePolicy::Realtime(RealtimeThreadSchedulePolicy::Fifo),
    )
    .expect("could not set thread priority. Are the PREEMPT_RT patches in use?");

    smol::block_on(tx_rx_task(&interface, tx, rx).expect("spawn TX/RX task"))
        .expect("TX/RX task failed");
});
```

# Performance

Tests on both of my dev machines, as well as those of a client using EtherCrab in production, have
shown that with a little bit of system tuning an extremely consistent process data cycle of 1000us
is achievable using [`smol`](https://docs.rs/smol) in a `SCHED_FIFO` thread. Network latencies are
low and predictable, and timing jitter from `smol`'s timer is miniscule which is great to see for
such an easy to use API.

A small benchmark in
[`examples/jitter.rs`](https://github.com/ethercrab-rs/ethercrab/blob/master/examples/jitter.rs) is
available to see how your system performs. It prints statistics every few seconds, so doesn't give
much insight but is still useful.

I've also created some tools in [`dump-analyser`](https://github.com/ethercrab-rs/dump-analyser)
which ingests Wireshark packet captures into a Postgres database for further analysis. Please note
that at time of writing it is _very_ rough but it's already proven invaluable when checking results
of system tuning in Linux.

# Conclusion

Give EtherCrab a try, and do reach out via
[Github issues](https://github.com/ethercrab-rs/ethercrab/issues/new) or
[Matrix](https://matrix.to/#/#ethercrab:matrix.org) if you get stuck!

EtherCrab is in a pretty good state already - you may have noticed the `0.2.x` version if you visit
it on [crates.io](https://crates.io/crates/ethercrab) - and I'm proud to say it is already in
production use! That said, there are still many features to implement, including `FSoE` (Functional
Safety over EtherCAT), MDP (Modular Device Profile) for easier communication with servo drives, and
other extensions.

**If you want to use EtherCrab but it doesn't currently provide functionality you need, please
[open a feature request](https://github.com/ethercrab-rs/ethercrab/issues/new?assignees=&labels=feature&projects=&template=feature.md&title=)!**

I've really enjoyed working on EtherCrab to both scratch my own itch, and hopefully help others at
the same time. If you're interested in seeing where it goes or in helping expand Rust's industrial
automation footprint, please [give it a star](https://github.com/ethercrab-rs/ethercrab), share it
with anyone who might find it interesting/useful, and try it out! I'm always looking for guinea pigs
to see what EtherCrab might be missing, or what oddware it refuses to work on.

We're [on Matrix](https://matrix.to/#/#ethercrab:matrix.org) too, so come and hang out if chatting
about industrial automation (Rust or not) is your kind of thing. We'd love more members, so I'll see
you there! ;)

As always, thanks for reading, and happy automating!

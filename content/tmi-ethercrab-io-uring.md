+++
layout = "post"
title = "This Month In Rust EtherCat: `io_uring`"
slug = "this-month-in-rust-ethercat-io-uring-ethercrab"
started_date = "2024-02-23 15:29:34"
draft = true
# TODO
date = "2024-02-23"

# [extra]
# image = "/images/ethercat.jpg"
+++

- Waiting for 0.4 release
- Available in 0.4.0: `io_uring` support! For excellent performance with minimal CPU overhead.
- Alternative to current `smol` impl

<!-- more -->

{% callout() %}

Are you looking to use Rust in your next EtherCAT deployment? Experiencing jitter or latency issues
in an existing EtherCrab app? I can help! Send me an email at [james@wapl.es](mailto:james@wapl.es)
to discuss your needs.

{% end %}

TODO: Series TOC

# Quick intro to EtherCAT and EtherCrab

- EtherCAT is a realtime industrial fieldbus protocol
- EtherCrab is a Rust implementation of EtherCAT
  - GH link
  - For more, see [the EtherCrab announcement post](@/announcing-ethercrab.md)

# Current impl: `smol`

- Pretty damn good already
- Pleasantly lightweight - just give something that impls `RawFd` to `async_io::Async`.
  - TODO: Confirm trait bounds
- Spawns its own `async-io` thread which inherits RT priority but you as the developer have no
  control over e.g. core pinning in code. The best you can do is pin the core out-of-band which
  doesn't feel very elegant.
- Dependent on the internals of `smol` for low latency.
- Anecdotally better performance than `tokio`
  - TODO: Benchmark this, only showing `smol`/`tokio` (ignoring `io_uring` results)

# Git gud: `io_uring`

- Quick intro to `io_uring`
  - I won't go too deep here
  - But basically, two ring buffers; submit work to one, wait for completion events in the other
- Link to `tx_rx_io_uring` in EtherCrab

## How it works with EtherCrab's full `async`

- We're using a blocking/spin-polling implementation here. Sounds scary!
- But we can do it efficiently

  - Elsewhere in the app, EtherCrab will prepare a frame for TX, then call `wake_by_ref()` on a
    waker registered by the `PduTx` instance. This is how EtherCrab notifies the TX task that
    something is ready to send.
  - To interface this with our blocking `io_uring` loop, we can park the thread, then un-park it
    when `wake_by_ref()` is called.
  - TODO: Paste in our shitty waker code
  - When frames are sent and in flight, for latency and performance reasons, the loop spin-polls
    `io_uring`'s completion queue for PDU responses received from the network, BUT
    - We only spin when waiting for PDU responses which are received on the order of microseconds
      (TODO: Give concrete values from i5-3450)
    - Meaning that if e.g. your cycle time is 1ms (1000us) and only one frame is sent per cycle,
      that's 960us (TODO: Percentage, concrete frame TX/RX times on i5-3450) of your time spent
      asleep.
    - End results in minimal CPU usage, leaving lots of headroom for either cheaper hardware, or
      more processing per cycle.
      - TODO: Get concrete CPU usage values from i5 system.
  - When no more frames are in flight, we park the thread again and wait to be unparked by EtherCrab
    calling `wake_by_ref` on us again.

## No executor, yes control

- Unlike the `smol` implementation, this method only requires spawning a native thread. In essence
  we're implementing our own hyper-specific, crappy futures runtime that does exactly what EtherCrab
  needs and nothing more.
- This means YOU can set RT prio, core pinning, etc and not depend on your futures executor.
- Ah but in not-`no_std` EtherCrab uses `smol` internally! Yes indeed, dear reader, but only for
  status poll loop ticks and timeouts. We don't mind if these are a little slower or have a bit more
  jitter, because they don't affect normal operation when sending/receiving process data frames,
  which is the important part of latency and jitter.

## But why

- Kinda because I felt like trying out io_uring
  - Touted as a high perf Linux networking interface which sounded perfect for EtherCAT.
- Never felt great about `smol`'s `async-io` thread - but I really like smol for EtherCrab client
  code! Great balance between simplicity and featureset.
- Performance
  - Driving down jitter
  - Driving down latency
  - Did we succeed?
    - TODO: Analyse results!
  - I think so? Latency is _slightly_ lower but quite dependent on the rest of the Linux networking
    stack/tuning.
  - Idk what jitter is like.

## Did we win?

- Testing: I can run 2x 100us cycle time concurrent tasks with io_uring on an i5-3450 for over 24h
  with absolutely no hickups and basically no CPU usage.
- Yes?
- It's not a magic bullet. The "normal" `smol`-based `async` TX/RX driver is still available if you
  need it, or it works better for you.
- Link AGAIN to `tx_rx_io_uring` to try it out

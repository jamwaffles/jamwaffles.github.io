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

Are you looking to use Rust in your next EtherCAT deployment? Experiencing jitter or latency issues
in an existing EtherCrab app? I can help! Send me an email at [james@wapl.es](mailto:james@wapl.es)
to discuss your needs.

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

- TODO: Impl lol
- Show a simple example
- Link to long example
- What's supported for now
- What's not
- Still kind of experimental

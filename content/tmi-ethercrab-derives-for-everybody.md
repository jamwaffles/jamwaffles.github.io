+++
layout = "post"
title = "This Month In Rust EtherCat: Derives for Everybody"
slug = "this-month-in-rust-ethercat-ethercrab-derives"
started_date = "2024-01-18 09:29:47"
# TODO
date = "2024-02-23"
draft = true
+++

Intro

<!-- more -->

{% callout() %}

Are you looking to use Rust in your next EtherCAT deployment? Experiencing jitter or latency issues
in an existing EtherCrab app? I can help! Send me an email at [james@wapl.es](mailto:james@wapl.es)
to discuss your needs.

{% end %}

Why did I go my own way

- Waiting for 0.4.0 release
- Packed struct got frustrating with the little endian bit ordering
- More control over the traits and generated code, e.g. we can now infallibly pack to a fixed size
  array
- Performance tuning over time (both size and speed)
- Better integration into EtherCrab as the traits are a bit more general than packed_struct
  - We can have `String`s when in `std` now, for example
  - Slices are possible too
  - Vectors of things, both `heapless::Vec` and `std::Vec`
- Opens the door to adding non-`*_raw` versions of slave Is and Os.

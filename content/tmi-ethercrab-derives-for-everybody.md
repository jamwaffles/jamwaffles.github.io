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

TODO: Series TOC

Why did I go my own way

- This post is waiting for 0.4.0 release
- Packed struct got frustrating with the little endian bit ordering
- More control over the traits and generated code, e.g. we can now infallibly pack to a fixed size
  array.
- "If an instance exists, we can infallibly pack to the right sized array. This is indeed up to the
  user to confirm, but if using a derive this is checked automatically. packed_struct is always
  fallible which isn't necessary.
- Performance tuning over time (both size and speed). What did I mean here? As in I can tune the
  generated code to make EtherCrab smaller/faster based on its needs? Something like that.
- Better integration into EtherCrab as the traits are a bit more specific than packed_struct
  - We can have `String`s when in `std` now, for example. Couldn't we do this with packed_struct
    anyway?
  - Slices are possible too because we pack to slice.
  - Vectors of things, both `heapless::Vec` and `std::Vec`
- Opens the door to adding non-`*_raw` versions of slave Is and Os.

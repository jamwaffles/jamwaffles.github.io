+++
layout = "post"
title = "EtherCrab 0.4: Derives for everybody"
date = "2024-01-18 09:29:47"
draft = true
+++

Why did I go my own way

- Packed struct got frustrating with the little endian bit ordering
- More control over the traits and generated code, e.g. we can now infallibly pack to a fixed size
  array
- Performance tuning over time (both size and speed)
- Better integration into EtherCrab as the traits are a bit more general than packed_struct
  - We can have `String`s when in `std` now, for example
  - Slices are possible too
  - Vectors of things, both `heapless::Vec` and `std::Vec`
- Opens the door to adding non-`*_raw` versions of slave Is and Os.

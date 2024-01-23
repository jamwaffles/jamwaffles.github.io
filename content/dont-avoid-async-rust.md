+++
title = "Don't avoid async Rust"
date = "2024-01-23 21:03:23"
draft = true
+++

- <https://news.ycombinator.com/item?id=39102078> "Avoid Async Rust at All Cost"
  - Actually read it! lol
  - The C10K problem
    - Async is useful in other domains - EtherCrab, ethercrab + embedded, Embassy is a posterchild
- Ethercrab loves async
- Lets you interleave packets from threads or tasks, allowing ergonomic concurrency
- Customers are using it with `smol::block_on` in a thread so you get the control over core
  pinning/RT prio/etc
- Address any specific points from the article
  - TODO
- Async split (<https://news.ycombinator.com/item?id=39102078>)
  - How much of a strawman is it?
  - I haven't encountered an issue in my travels, but they are limited :D

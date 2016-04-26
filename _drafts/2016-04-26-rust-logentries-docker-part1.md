---
layout: post
title:  "Parsing Logentries output safely using Rust (part 1)"
date:   2016-04-26 10:14:03
categories: rust
<!-- image: huanyang-header-2.jpg -->
---

- Part 1 - Writing the service in Rust
- [Part 2](/rust/docker/2016/04/26/rust-logentries-docker-part2.html) - Deployment using Docker

I'm fascinated by Rust for it's safety and speed, but also because it's simple to write low level code in what feels like a high level language. To that end, I've been working on a small Rust project at [TotallyMoney.com](http://www.totallymoney.com) (where I work) for the last week or so to see if it's viable for production use. It's a simple service that polls a [Logentries](https://logentries.com) endpoint for JSON, parses it and saves some values in a Postgres database. It's not a very complicated task, but I saw this as a good opportunity to try Rust in a production-ish role. For this series of articles I want to walk through writing the service and deploying it to production using Docker.

> Note: I could very well have written this in NodeJS like the rest of the app it fits into, but I wanted to learn Rust a little better. The memory safety of Rust is somewhat lost on this task but it's interesting how the language handles errors and optional types. Read on for more.

## Dependencies

I'm assuming you've got Rust, Cargo and a project folder (`cargo init --bin` will do) set up for this project. I'm going to use the following crates:

- `hyper`; HTTP library for making GET requests to Logentries
- `chrono`; Date and time, we'll be using it to store the log entry timestamp
- `time`; More date and time, used in this case for sleeping for a certain number of milliseconds
- `rustc_serialize`; JSON parsing
- `postgres`; Postgres database connector

At the time of writing, my `Cargo.toml` looks like this:

```toml
[package]
name = "logentries_poller"
version = "0.1.0"
authors = ["James Waples <jwaples@totallymoney.com>"]

[dependencies]
hyper = "^0.8.1"
rustc-serialize = "^0.3.19"
chrono = "^0.2"
time = "^0.1"
postgres = { version = "^0.11.0", features = [ "chrono" ] }
```

Crates will be installed/updated when you run `cargo build` or `cargo run` for the first time. Pretty neat!


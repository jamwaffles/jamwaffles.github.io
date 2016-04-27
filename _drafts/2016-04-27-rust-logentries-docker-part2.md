---
layout: post
title:  "Parsing Logentries output safely using Rust (part 2)"
date:   2016-04-27 10:49:50
categories: rust
<!-- image: huanyang-header-2.jpg -->
---

In part 1 I went through creating a program that fetched some Logentries logs from an HTTP endpoint and parsing some data out of the returned lines. In this part I want to add polling and database functionality so the program can keep a Postgres database up to date (minus at most 5 seconds) with the Logentries stream.

- [Part 1](/rust/2016/04/26/rust-logentries-docker-part1.html) - Fetching and parsing Logentries data
- Part 2 - Saving data to the database
- Part 3 - (coming soon) Deployment using Docker
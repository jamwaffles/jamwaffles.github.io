---
layout: post
title: 'Writing a motion controller in Rust'
date: 2019-11-22 16:06:00
categories: rust cnc
image: todo.jpg
---

# Outcome

An off-line trajectory planner that converts a path into something that can be queried for position/velocity by time _t_ along that path

# Basic approach

- Accept a path consisting of straight segments between two waypoints
- Add circular blends to straight segments so they may be differentiated as per P. 1 - 2 of [this paper](http://www.golems.org/papers/KunzRSS12-Trajectories.pdf)
- Implement basic trapezoidal motion with infinite jerk as per the first bit of [this paper](https://duckduckgo.com/?q=on-line+planning+of+time-optimal%2C+jerk+limited+trajectories&t=lm&ia=web)
- Work through paper some more, adding third-order jerk-limited motion control
- Add support for arcs (`G2`/`G3`, etc) in the input

# Parts

1. Implement basic trapezoidal profile for path with no blends

   - Turn path into segments
   - Plan using basic trapezoidal profile

1. Side-article into plotting data from planner in gnuplot

   - Use `#[cfg()]` to output stuff or not
   - Figure out a nice way of writing to a file (lazy_static with a vec/hashmap and a close handler maybe?). Maybe implement a custom `log!()` driver. Use https://github.com/drakulix/simplelog.rs as reference.

1. Add jerk-limit to planner
1. Usage in jog mode
1. Add circular blends(?)
1. Add support for arcs in the input

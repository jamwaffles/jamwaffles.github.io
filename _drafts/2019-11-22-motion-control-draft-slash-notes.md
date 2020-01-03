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

# Blog post notes

- Target web assembly and use it to draw animated demos on `<canvas>` - I can still use std here

# Part 1

## About the series

- From [this paper](TODO)
- Talk about series in general - start simple, end up with jerk limited complete traj
- Targetting step/dir motion control of 3+ axis CNC milling machines or 3D printer
- Realtime so we can control things like max velocity and feed rate override
- Quick aside on Nalgebra and multiple dimensions - paper describes one at a time, we'll use 3 dimensions for a basic cartesian "robot" (CNC) but should be expandable up to 9 or whatever Nalgebra allows
- Targetting WASM and no-std - examples in this series will use the code we write

## None-jerk Algorithm and calculations

- Talk through equations in the one-dimensional case and what we need to compute
  - Copypasta first equation from paper `x(t) = ...` gonna need [Mathjax](https://www.mathjax.org/) with Mathml input.
  - Break this down into the three `t` sections, copypasta those equations out too
  - Paste section `A.` (one dimensional case) and talk through calculating the `delta(t)` variables and shit. Trajectory can also be "wedge-shaped" if time is too short. Can mostly gloss over `d` - this is just gonna be `-1.0` or `1.0`
- Multi-dimensional case
  - We now need to work in multiple dimensions
  - Mention but skip bits of paper that talks about simple scaling
  - Follow through rest of paper until section (jerk)
- I'll talk about the jerk limited bit later

# Part 2

## Starting out

- Using `f64` because JS uses 64 bit floats under the hood, and because WASM
- This first part will only talk about an acceleration-limited profile (no jerk yet)
- Single straight line only, end velocity and acceleration are zero. We'll change this later to join linear segments together

# Part 2a

Put in same page as part 2 if it's not too long

## Visual aids

- Segue into logging/plotting values - try and recreate profile graph from paper with logging/gnuplot

## Implementation

- Struct with methods on it (will convert into trait later to cater for different segment profiles). Unlike above which mirrors paper order, this should mirror sensible implementation order

  - `from_waypoints(start, end)` - we'll calculate the segment times here
  - `position(&self, max_acc, max_vel, time)` - we'll fill in the body later
  - `velicity(max_acc, max_vel, time)` - I'll need to figure this out as the derivative of position. Talk about position being useless to send to an external drive

- Cleanup: use a struct instead of `(max_acc, max_vel, time)`

# Part _N_

- Expand part 1 to work with multiple straight line segments - create a `Trajectory`

# Part _N + 1_

- Get freaky deaky (generics) - change from `f64` to Nalgebra's weird generics thing so we can use `f32` and put `f64` behind a feature flag `double-precision` or something. This could also be enabled by the `wasm` flag, same as `no_std` or something?

# Part _last_

- Port to `no_std` because I'm a massochist

# Conclusion

Probably before **Part _N_**

- Talk about no_std/WASM limitations

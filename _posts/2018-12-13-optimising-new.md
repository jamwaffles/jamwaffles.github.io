---
layout: post
title:  "Optimising out calls to `new()`"
date:   2018-12-13T20:13:21+00:00
categories: rust
---

A quick note to self: Rust (and LLVM) are _really_ good at optimising things.

I have a struct, `TrajectoryStep`, that I pass to some methods in my program as arguments because positional arguments and magic booleans are bad. It looks like this:

```rust
pub struct TrajectoryStep {
    pub position: f64,
    pub velocity: f64,
    pub time: f64,
}

impl TrajectoryStep {
    pub fn new(position: f64, velocity: f64) -> Self {
        Self {
            position,
            velocity,
            time: 0.0,
        }
    }
}
```

Now, rather amazingly these two following invocations **appear to compile down to the same assembly:**

```rust
// Convenient and ergonomic
let step = TrajectoryStep::new(10.0, 10.0);

// Less ergonomic
let step = TrajectoryStep { position: 10.0, velocity: 10.0, time: 0.0 };
```

As can be seen [on Godbolt.org](https://godbolt.org/z/8-TxTR), the asm output by Rust 1.31.0 looks like this:

```asm
example::TrajectoryStep::new:
        mov     rax, rdi
        movsd   qword ptr [rdi], xmm0
        movsd   qword ptr [rdi + 8], xmm1
        xorps   xmm0, xmm0
        movsd   qword ptr [rdi + 16], xmm0
        ret
```

Is this right? If it is, Rust amazes me more every day. We get the ergonomics of just being able to call `new()` without any performance penalty.

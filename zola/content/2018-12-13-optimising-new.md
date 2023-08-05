+++
layout: post
title:  "Optimising out calls to `new()`"
date:   2018-12-13T20:13:21+00:00
categories: rust
+++

Rust (and LLVM) are _really_ good at optimising things.

I have a struct, `TrajectoryStep`, that I pass to some methods in my program. I don't want to use
positional arguments as it's impossible to tell what `some_func(f32, f32, f32)` might actually
require. It looks like this:

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

For convenience, I added a `new()` method as `time` is almost always zero:

```rust
// Convenient and ergonomic
let step = TrajectoryStep::new(10.0, 10.0);

// Less ergonomic
let step = TrajectoryStep { position: 10.0, velocity: 10.0, time: 0.0 };
```

Because Rust and LLVM are friggin spectacular bits of technology, these two invocations **compile
down to the same machine code.**

As can be seen [on Godbolt.org](https://godbolt.org/z/8-TxTR), the assembly output by rustc 1.31.0
looks like this:

```asm
example::TrajectoryStep::new:
        mov     rax, rdi
        movsd   qword ptr [rdi], xmm0
        movsd   qword ptr [rdi + 8], xmm1
        xorps   xmm0, xmm0
        movsd   qword ptr [rdi + 16], xmm0
        ret
```

Being able to have easily read code with zero performance penalty is yet another reason I like Rust
so much.

As you were!

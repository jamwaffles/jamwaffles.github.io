+++
title = "A study of Rust micro-optimisations"
date = "2024-01-06 20:20:48"
draft = true
+++

In working on [`ethercrab`](https://crates.io/crates/ethercrab) I found myself down the rabbit hole
of trying to reduce binary size, in this case for the `thumbv7m-none-eabi` architecture used in
embedded. This post is a collection of examples of attempted code size reductions by refactoring
sometimes the most tiny of functions. It will hopefully serve as a reference to both me and you,
dear reader, in your travels through the Rust lands.

I don't have much knowledge of the deeper bits of the optimisation pipeline in both LLVM or Rust, so
these experiments are probably super obvious to anyone with an inkling, but it was a good learning
experience for me either way so I thought I'd share.

## 1. Clamp length offsets to the buffer length

[Godbolt](https://godbolt.org/z/cfG1o11ff)

This is code that will quite happily panic for what it's worth. The `skip` function is part of a
larger set of uh "generator-combinator" functions (generate stuff instead of parsing it like `nom`)
and will jump over a given number of bytes in the provided buffer, returning the rest.

```rust
// Original impl
pub fn skip(len: usize, buf: &mut [u8]) -> &mut [u8] {
    let (_, rest) = buf.split_at_mut(len);

    rest
}

// Naive attempt: a little improvement
//
// Important note: the actual asm compiles to the same 4 instructions as `skip` above, however it
// generates one less exception jump and one less string in the final binary.
pub fn skip2(len: usize, buf: &mut [u8]) -> &mut [u8] {
    &mut buf[len..]
}

// Clamp length: maybe now LLVM knows this won't panic?
//
// There are no more assertion checks so we're pretty much as small as we can get.
pub fn skip3(len: usize, buf: &mut [u8]) -> &mut [u8] {
    let len = len.min(buf.len());

    &mut buf[len..]
}

/// Slightly more instructions than `skip3` but maybe a little bit clearer if that matters to you.
pub fn skip4(len: usize, buf: &mut [u8]) -> &mut [u8] {
    if len >= buf.len() {
        return &mut buf[0..0]
    }

    &mut buf[len..]
}
```

`skip3` seems to be the best here. If the returned buffer length is zero, the other original code
that uses it will panic instead so we've probably just moved the assertion check in the wide program
than removed it entirely.

## 2. Idiomatic method chaining is smarter than you think

[Godbolt](https://godbolt.org/z/T5xTK83dM)

Fewer lines really is faster!

```rust
use core::hint::unreachable_unchecked;
use core::convert::TryInto;

/// Original attempt at getting optimised output, with sad trombone bonus `unsafe`` :(
pub fn unpack_from_slice_naive(buf: &[u8]) -> Result<u32, ()> {
    if buf.len() < 4 {
        return Err(());
    }

    let arr = match buf[0..4].try_into() {
        Ok(arr) => arr,
        // SAFETY: We check the buffer size above
        Err(_) => unsafe { unreachable_unchecked() },
    };

    Ok(u32::from_le_bytes(arr))
}

/// Look at this nice API!
pub fn unpack_from_slice_pleasant(buf: &[u8]) -> Result<u32, ()> {
    buf.get(0..4)
        .ok_or(())
        .and_then(|raw| raw.try_into().map_err(|_| ()))
        .map(u32::from_le_bytes)
}
```

The two latter solutions produce identical assembly, so there's no need for `unsafe` here - the
performance is already there.

There's also an in-between if you find a lot of chained methods hard to read, which is
understandable:

```rust
pub fn unpack_from_slice_naive(buf: &[u8]) -> Result<u32, ()> {
    if buf.len() < 4 {
        return Err(());
    }

    buf[0..4].try_into().map(u32::from_le_bytes).map_err(|_| ())
}
```

Again, identical assembly as the two above.

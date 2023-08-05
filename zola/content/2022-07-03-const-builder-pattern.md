+++
layout: post
title: "A const builder pattern in Rust"
date: 2022-07-03 14:43:59
categories: rust
+++

During the creation of [EtherCrab](https://github.com/ethercrab-rs/ethercrab), a pure-Rust EtherCAT
master, one of the core structs in the crate started growing quite a few const generic parameters.
Here's a reduced example of what I'm talking about:

```rust
struct Client<const N: usize, const D: usize, const TIMEOUT: u64> {
    foo: [u8; N],
    bar: [u8; D],
    idx: u8
}
```

There are/will be a few more parameters in the future, but this is already pretty unwieldy, so let's
fix that.

## But first: a normal builder

Skip this section if you already know what the builder pattern is :)

For structs with many different parameters, you'll often see the builder pattern used in Rust
crates, for example in [`embedded-graphics`](https://docs.rs/embedded-graphics):

```rust
let style = PrimitiveStyleBuilder::new()
    .stroke_width(5)
    .stroke_color(Rgb565::RED)
    .fill_color(Rgb565::GREEN)
    .build();

let radii = CornerRadiiBuilder::new()
    .top_left(Size::new(5, 6))
    .top_right(Size::new(7, 8))
    .bottom_right(Size::new(9, 10))
    .bottom_left(Size::new(11, 12))
    .build();

RoundedRectangle::new(Rectangle::new(Point::new(5, 5), Size::new(40, 50)), radii)
```

The builder allows the final struct (`RoundedRectangle` in this case) to have private fields, but
more importantly helps disambiguate passing random values for various fields. Let's take a look at
what creating a `PrimitiveStyle`, created by `PrimitiveStyleBuilder` in the example above, would
look like without a builder:

```rust
// Ordered as above: stroke width, stroke colour, fill colour
let style = PrimitiveStyle::new(5, Rgb565::RED, Rgb565::GREEN);
```

Now, assuming we don't have nice inlay hints in our editor showing the argument names, how do we
know what the three magic arguments correspond to? We don't! We can take a guess, but that's a
recipe for disaster. Hopefully this example demonstrates the added safety and readability that
builders provide.

A fantastic extra feature also falls out of the builder pattern: we can have sensible defaults
within the builder, meaning the programmer doesn't have to specify _all_ field values every time. In
contrast, to support this in the non-builder API it sucks even more:

```rust
// Use the default fill colour but override everything else
let style = PrimitiveStyle::new(Some(5), Some(Rgb565::RED), None);
```

## Const builders

We need a slightly different pattern with a builder for `const` parameters. Let's see what a first
incarnation looks like.

```rust
struct ConstBuilder<const N: usize, const D: usize, const TIMEOUT: u64>;

impl<const N: usize, const D: usize, const TIMEOUT: u64> ConstBuilder<N, D, TIMEOUT> {
    const fn with_n<const N_SET: usize>(self) -> ConstBuilder<N_SET, D, TIMEOUT> {
        ConstBuilder::<N_SET, D, TIMEOUT>
    }

    const fn with_d<const D_SET: usize>(self) -> ConstBuilder<N, D_SET, TIMEOUT> {
        ConstBuilder::<N, D_SET, TIMEOUT>
    }

    const fn with_timeout<const TIMEOUT_SET: u64>(self) -> ConstBuilder<N, D, TIMEOUT_SET> {
        ConstBuilder::<N, D, TIMEOUT_SET>
    }

    const fn build(self) -> Client<N, D, TIMEOUT> {
        Client {
            foo: [0x00; N],
            bar: [0x00; D],
            idx: 0,
        }
    }
}
```

If your first thought is "wow, that's quite verbose with all the `const`s there!" you are absolutely
correct and I agree with you. But the usage isn't so bad:

```rust
let thing = ConstBuilder::new()
    .with_n::<16>()
    .with_d::<32>()
    .with_timeout::<30_000>()
    .build();
```

That almost looks like a normal builder!

## Defaults

But where does `new()` come from? This took me a few tries to figure out. Here's the first solution
I reached for:

```rust
const fn new() -> Self {
    Self
}
```

Ah...

```
   |
61 |     let thing = ConstBuilder::new()
   |                 ^^^^^^^^^^^^^^^^^ cannot infer the value of const parameter `N`
```

Alright then, how about...

```rust
const fn new() -> ConstBuilder<N, D, TIMEOUT> {
    ConstBuilder::<N, D, TIMEOUT>
}
```

nah, same error. Note that the error also percolates to `D`, then `TIMEOUT` if we define `N`.

We need two things out of this `new()` method;

1. No errors please
2. An ability to initialise the builder with some default values

The solution to both these points is thankfully pretty simple: We must define _another_ `impl` block
but this time, we'll use concrete values:

```rust
impl ConstBuilder<16, 16, 30_000> {
    const fn new() -> Self {
        Self
    }
}
```

This works, but I admit it does replicate the magic values issue we had with the
`let style = PrimitiveStyle::new(5, Rgb565::RED, Rgb565::GREEN);`-style API above. That said, the
defaults are more likely to be contained within the crate or module, so they're not exposed to the
user to make mistakes with - only you, great author, can mess your crate up ;).

That said, we can guard against this a little bit better by giving some names to the default values:

```rust
const DEFAULT_N: usize = 16;
const DEFAULT_D: usize = 16;
const DEFAULT_TIMEOUT: u64 = 30_000;

impl ConstBuilder<DEFAULT_N, DEFAULT_D, DEFAULT_TIMEOUT> {
    const fn new() -> Self {
        Self
    }
}
```

This doesn't prevent reordering defaults of the same type, but perhaps it goes a little way to
making the code less error prone.

## The whole lot

Overall, I'm pretty happy with this builder pattern. I doubt I'm the first to discover it, but it
was a bit of a eureka moment for me and I thought it interesting enough to share. The full code is
below, or you can
[visit the Rust playground to run it yourself](https://play.rust-lang.org/?version=stable&mode=debug&edition=2021&gist=91799c2dba1211543fc196504fee6617).

```rust
use core::future;
use core::time::Duration;
use tokio::time::error::Elapsed;

const DEFAULT_N: usize = 16;
const DEFAULT_D: usize = 16;
const DEFAULT_TIMEOUT: u64 = 30_000;

struct ConstBuilder<const N: usize, const D: usize, const TIMEOUT: u64>;

impl ConstBuilder<DEFAULT_N, DEFAULT_D, DEFAULT_TIMEOUT> {
    const fn new() -> Self {
        Self
    }
}

impl<const N: usize, const D: usize, const TIMEOUT: u64> ConstBuilder<N, D, TIMEOUT> {
    // Compile error: "cannot infer the value of const parameter `N`"
    // const fn new() -> ConstBuilder<N, D, TIMEOUT> {
    //     ConstBuilder::<N, D, TIMEOUT>
    // }

    const fn with_n<const N_SET: usize>(self) -> ConstBuilder<N_SET, D, TIMEOUT> {
        ConstBuilder::<N_SET, D, TIMEOUT>
    }

    const fn with_d<const D_SET: usize>(self) -> ConstBuilder<N, D_SET, TIMEOUT> {
        ConstBuilder::<N, D_SET, TIMEOUT>
    }

    const fn with_timeout<const TIMEOUT_SET: u64>(self) -> ConstBuilder<N, D, TIMEOUT_SET> {
        ConstBuilder::<N, D, TIMEOUT_SET>
    }

    const fn build(self) -> Client<N, D, TIMEOUT> {
        Client {
            foo: [0x00; N],
            bar: [0x00; D],
            idx: 0,
        }
    }
}

struct Client<const N: usize, const D: usize, const TIMEOUT: u64> {
    foo: [u8; N],
    bar: [u8; D],
    idx: u8,
}

impl<const N: usize, const D: usize, const TIMEOUT: u64> Client<N, D, TIMEOUT> {
    async fn do_a_thing(&self) -> Result<u8, Elapsed> {
        let fut = future::ready(1u8);

        dbg!(N);
        dbg!(D);
        dbg!(TIMEOUT);

        tokio::time::timeout(Duration::from_nanos(TIMEOUT), fut).await
    }
}

#[tokio::main]
async fn main() {
    let thing = ConstBuilder::new()
        // `N` left at its default
        // .with_n::<16>()
        .with_d::<32>()
        .with_timeout::<30_000>()
        .build();

    thing.do_a_thing().await;
}

```

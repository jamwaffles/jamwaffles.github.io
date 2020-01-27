---
layout: post
title: 'Announcing linuxcnc-hal: write LinuxCNC HAL components in Rust'
date: 2020-01-27T23:26:43+00:00
categories: [cnc, rust]
---

I'd like to announce two crates I've been working to integrate Rust components into LinuxCNC. You can find them at [linuxcnc-hal](https://crates.io/crates/linuxcnc-hal) (high-level interface) and [linuxcnc-hal-sys](https://crates.io/crates/linuxcnc-hal-sys) (low-level interface). The rest of this post is a getting started tutorial, so follow along if you have a cool idea for a custom bit of CNC hardware and an itch to write the interface in Rust!

[LinuxCNC](https://linuxcnc.org) is a popular, open source machine controller. It's very powerful and is an excellent way to get into CNC on an absolute budget. LinuxCNC is also expandable with custom components called HAL components or HAL comps.

Up to now, most components are written in C or Python. Pretty unsafe or slow - these languages don't make the best choice for a potentially heavy/dangerous/fast machine! With its safety and low to zero overhead, Rust is a prime replacement for writing HAL comps, however there doesn't seem to be any way to integrate Rust with LinuxCNC... until now!

There are [examples](https://github.com/jamwaffles/linuxcnc-hal-rs/tree/master/linuxcnc-hal/examples) for [both](https://github.com/jamwaffles/linuxcnc-hal-rs/tree/master/linuxcnc-hal-sys/examples), but let's go through making a HAL component step by step!

## A primer on HAL components

LinuxCNC has the concept of a HAL (Hardware Abstraction Layer). The HAL allows (among other things) custom components to be loaded at startup which hook into the HAL using virtual "pin"s. These pins allow comps to take inputs from LinuxCNC and provide outputs to it. A HAL component is often used to communicate with custom hardware such as VFDs, toolchangers or information readouts.

A HAL component is a normal binary with a standard `main()` function, however there are certain component-specific actions that must be taken to hook it into LinuxCNC. The two crates mentioned above ([linuxcnc-hal](https://crates.io/crates/linuxcnc-hal) and [linuxcnc-hal-sys](https://crates.io/crates/linuxcnc-hal-sys)) facilitate this linking in Rust.

## Hello world

Let's write a basic component with one input and one output pin to get a feel for the interface. Set up a binary project and add `linuxcnc-hal` as a dependency:

```bash
cargo new --bin hello-comp
cd hello-comp
cargo add linuxcnc-hal
```

> You might need to install [cargo-edit](https://github.com/killercup/cargo-edit) if `cargo add` isn't found:
>
> `cargo install --force cargo-edit`

The code described below should go into `src/main.rs`.

First, we need some imports. Both the input and output are going to accept `f32` values, so we'll use `HalPinF64`. Other types [are available](https://docs.rs/linuxcnc-hal/0.1.0/linuxcnc_hal/hal_pin/index.html#structs).

```rust
use linuxcnc_hal::{hal_pin::HalPinF64, HalComponentBuilder};
use std::{
    error::Error,
    thread,
    time::{Duration, Instant},
};
```

Moving onto `main()`, we need to change the signature slightly as the component is going to return a `Result` for better error handling. Replace any existing `main()` with this:

```rust
fn main() -> Result<(), Box<dyn Error>> {
    // Everything will go here
}
```

Now let's populate `main()`. First, a `HalComponentBuilder` needs to be created. This is the first thing that should happen in the component as it registers the comp with LinuxCNC's HAL and gets an ID assigned to it. In this example, we'll register a component called `hello-comp`. This is equivalent to a call to `hal_init()` in C comp land.

```rust
let mut builder = HalComponentBuilder::new("hello-comp")?;
```

Next, we need some pins. We'll create one input and one output called `input-1` and `output_1` respectively. These are the HAL pin names you'll see in LinuxCNC.

```rust
let input_1 = builder.register_input_pin::<HalPinF64>("input-1")?;
let output_1 = builder.register_output_pin::<HalPinF64>("output-1")?;
```

Once the pins are registered, the builder can be consumed into a complete HAL component. This signals to LinuxCNC that the component has registered all pins and is ready to use. LinuxCNC will hang if `ready()` isn't called in the component. In C comp land, you'd call `hal_ready()` at this point.

```rust
let comp = builder.ready()?;
```

Pins can't be registered after `ready()` is called, and we take care of that with Rust's type system. The `builder.ready()` call above consumes the builder into a `HalComponent` which doesn't have any way to register pins on it. In a C HAL comp, an error is logged if you _do_ register a pin after the `ready()` call, but it's obviously a lot safer to capture that error at compile time! Yay Rust!

Anyway, now we've got the comp let's start the main control loop of the component. We'll check `comp.should_exit()` every iteration to see if a Unix signal has been received from LinuxCNC asking the component to quit.

```rust
let start = Instant::now();

while !comp.should_exit() {
    let time = start.elapsed().as_secs() as i32;

    output_1.set_value(time.into())?;

    println!("Input: {:?}", input_1.value());

    thread::sleep(Duration::from_millis(1000));
}
```

This simple loop sets the `output-1` pin's value to the current elapsed time in seconds every iteration. It also prints the value of `input-1` to the console. If you hook `input-1` up to, say, the `spindle.0.speed-out` pin in a `.hal` file, you should see the spindle RPM value printed to the console.

So as not to lag LinuxCNC up too much, we call `thread::sleep(Duration::from_millis(1000))` to poll/update the pins every second. This delay can be made shorter for a more responsive component. An emergency stop control would need to respond much faster than 1 second!

The above loop will cycle forever until a `SIGTERM`, `SIGINT` or `SIGKILL` signal is received. LinuxCNC will send one of these on shutdown, ending the loop. Once the loop is over the component should exit with a success status. Add the following to the bottom of `main()`:

```rust
Ok(())
```

At this point in C comp land, you'd have to remember to call `hal_exit`. Not too hard, but it's possible to forget. With `linuxcnc-hal` there's a custom `Drop` impl for `HalComponent`. It automatically calls `hal_exit` for you when it goes out of scope at the end of the program. Rust lets us be lazy _and_ safe. Noice.

If the above is difficult to follow, here's the complete final `src/main.rs`:

```rust
//! Create a component that adds some pin types

use linuxcnc_hal::{hal_pin::HalPinF64, HalComponentBuilder};
use std::{
    error::Error,
    thread,
    time::{Duration, Instant},
};

fn main() -> Result<(), Box<dyn Error>> {
    let mut builder = HalComponentBuilder::new("hello-comp")?;

    let input_1 = builder.register_input_pin::<HalPinF64>("input-1")?;

    let output_1 = builder.register_output_pin::<HalPinF64>("output-1")?;

    let comp = builder.ready()?;

    let start = Instant::now();

    while !comp.should_exit() {
        let time = start.elapsed().as_secs() as i32;

        output_1.set_value(time.into())?;

        println!("Input: {:?}", input_1.value());

        thread::sleep(Duration::from_millis(1000));
    }

    Ok(())
}
```

With any luck, running `cargo build` will successfully compile your new component. `cargo run` is unlikely to work, as the raw `hal_*` functions aren't defined by the crate. They're defined in `liblinuxcnchal.so` which is loaded by LinuxCNC.

## Loading into LinuxCNC

I'm assuming some basic knowledge of how the LinuxCNC HAL is configured in this section. If you need a primer, the [official LinuxCNC docs](http://linuxcnc.org/docs/2.7/html/) are a good place to start. I'm also assuming you have a LinuxCNC config ready to go, either a simulator or a real machine.

> _Disclaimer_: I do not accept responsibility for any loss or injury caused by following this tutorial with real hardware. CNC can be dangerous. Use your common sense.

Running `cargo build` will create a binary artifact at `./target/debug/hello-comp`. We now need to hook this into LinuxCNC and wire some pins up using a `.hal` file.

To create a basic `.hal` config, add the following to `hello-comp.hal` in the crate root.

```
loadusr /full/path/to/comp/target/debug/hello-comp
net input-1 spindle.0.speed-out hello-comp.input-1
```

The config first loads the component into userspace. We're not creating a realtime component here. It then creates a net called `input-1`, joining `spindle.0.speed-out` to the input pin `hello-comp.input-1`.

Add this to your machine `.ini` config like so:

```ini
HALFILE = /full/path/to/comp/hello-comp.hal
```

You might get some pin conflicts on startup, so if LinuxCNC crashes check the error messages and fix any conflicting pin errors in your `.hal` files.

Start LinuxCNC as you normally would. Note that you'll need to run it from the console to see the input pin value printed. With luck, you should see `pins.input-1` and `pins.output-1` under the **Pins** tab of **Machine** -> **Hal Meter**. Select `pins.output-1` and you should see the current elapsed time in seconds.

## Final Thoughts

Rust's type safety and ownership rules mean we get a safe, easy to use interface to the underlying LinuxCNC HAL methods.

There's still a lot more left to do on `linuxcnc-hal`. There isn't a way to register signals yet, and a lot of the [autogenerated methods](https://docs.rs/linuxcnc-hal-sys/0.1.5/linuxcnc_hal_sys/#functions) don't have a safe wrapper yet. That said, hopefully the pins-only interface is useful to see where the pain points/bugs are in `linuxcnc-hal`.

Thanks for reading, and happy machining!

---
layout: post
title: 'Making linuxcnc-hal-rs a bit safer'
date: 2020-02-15T09:08:17+00:00
categories: [cnc, rust]
---

Evolution:

1. Start with raw API bindings. Let's just get this thing working, but not safely
1. First iteration was to get individual variables out of internal assignments
   - Good because we hide the unsafety from the user
   - Bad because pin and component lifetimes are kinda decoupled - see the log below for out of order freeing
   - Calls ready()
     - Good because type states don't let us register pins after call to `hal_ready()`
1. Now we impl a trait that gets a reference to the component to register pins on
   - Good because registration logic and stuff is still hidden inside component
   - Good because component is scoped only to the registration method
   - Good because component owns pins now, only returns a readonly reference to them, disallowing modification
   - No more type states (aw they were cool) but now we can't forget to call `ready()` - that's handled inside Component::new(), as is all the registration.
   - Good because pins are freed before component - see low below

- Before, pins were freed after component. Not great TODO: Get a print log of this
  - We'll use the `Option` container trick from [here](https://aochagavia.github.io/blog/enforcing-drop-order-in-rust/) to let us drop the resources before the component.
- Using RAII principle, HalComponent::new now does _everything_
- Pin registration moved into a struct that gets passed a subset of the component that can only register stuff - still using type system safety yee. It's now a struct so the comp can keep the pins, ensuring they live for the lifetime of the comp
- Gotta implement the `Resources` trait for your struct
- You can only ever have a reference to the component resources. This ensures that neither the resources nor component outlive each other.

- Safety side note: ID is now a `u32` - the HAL binding to `hal_init` returns an `i32` as error codes are negative, but any valid ID is always gt 0

So, what did I learn?

- Can't take `Drop` for granted when dealing with nested structs and smart pointers
- `Drop`s are recursive and, due to [RFC1857](https://github.com/rust-lang/rfcs/blob/master/text/1857-stabilize-drop-order.md), are called in struct field order.
  - But! This sucks for us because `Drop::drop` for struct fields is called _after_ `Drop::drop` for `HalComponent`. This doesn't work for us because we need to drop `resources` before calling `hal_exit`.
- Using borrowck and references to ensure that resources only live for as long as the component

Master branch log:

```
$ RUST_LOG=debug ../scripts/linuxcnc ~/Repositories/jog-wheel-controller/hal-comp/axis_mm.ini
LINUXCNC - 2.7.15
Machine configuration directory is '/home/james/Repositories/jog-wheel-controller/hal-comp'
Machine configuration file is 'axis_mm.ini'
Starting LinuxCNC...
emc/iotask/ioControl.cc 768: can't load tool table.
Found file(lib): /home/james/Repositories/linuxcnc/lib/hallib/core_sim.hal
Note: Using POSIX non-realtime
Found file(lib): /home/james/Repositories/linuxcnc/lib/hallib/axis_manualtoolchange.hal
Found file(lib): /home/james/Repositories/linuxcnc/lib/hallib/simulated_home.hal
Found file(REL): ./jog-pendant.hal
 DEBUG linuxcnc_hal::builder > Init component rust-comp with ID 48
 DEBUG linuxcnc_hal::hal_pin::hal_pin > Allocating 8 bytes
 DEBUG linuxcnc_hal::hal_pin::hal_pin > Allocated value 0x0 at 0x7f42ce46c470
 DEBUG linuxcnc_hal::hal_pin::input_pin > Make pin rust-comp.input-1 returned 0
 DEBUG linuxcnc_hal::hal_pin::hal_pin   > Allocating 8 bytes
 DEBUG linuxcnc_hal::hal_pin::hal_pin   > Allocated value 0x0 at 0x7f42ce46c478
 DEBUG linuxcnc_hal::hal_pin::output_pin > Make pin rust-comp.output-1 returned 0
 DEBUG linuxcnc_hal::builder             > Signals registered, component is ready
Input: Ok(0.0)
task: main loop took 0.011898 seconds
task: main loop took 0.013888 seconds
Input: Ok(0.0)
Input: Ok(0.0)
Input: Ok(0.0)
Input: Ok(0.0)
Shutting down and cleaning up LinuxCNC...
task: 3862 cycles, min=0.000005, max=0.013888, avg=0.001107, 2 latency excursions (> 10x expected cycle time of 0.001000s)
 DEBUG linuxcnc_hal                      > Closing component ID 48, name rust-comp
 DEBUG linuxcnc_hal::hal_pin::input_pin  > Drop InputPin rust-comp.input-1
 DEBUG linuxcnc_hal::hal_pin::output_pin > Drop OutputPin rust-comp.output-1
Note: Using POSIX non-realtime
```

After log:

```
$ RUST_LOG=debug ../scripts/linuxcnc ~/Repositories/jog-wheel-controller/hal-comp/axis_mm.ini
LINUXCNC - 2.7.15
Machine configuration directory is '/home/james/Repositories/jog-wheel-controller/hal-comp'
Machine configuration file is 'axis_mm.ini'
Starting LinuxCNC...
emc/iotask/ioControl.cc 768: can't load tool table.
Found file(lib): /home/james/Repositories/linuxcnc/lib/hallib/core_sim.hal
Note: Using POSIX non-realtime
Found file(lib): /home/james/Repositories/linuxcnc/lib/hallib/axis_manualtoolchange.hal
Found file(lib): /home/james/Repositories/linuxcnc/lib/hallib/simulated_home.hal
Found file(REL): ./jog-pendant.hal
 DEBUG linuxcnc_hal::component > Init component rust-comp with ID 48
 DEBUG linuxcnc_hal::hal_pin::hal_pin > Allocating 8 bytes
 DEBUG linuxcnc_hal::hal_pin::hal_pin > Allocated value 0x0 at 0x7f673622e470
 DEBUG linuxcnc_hal::hal_pin::input_pin > Make pin rust-comp.input-1 returned 0
 DEBUG linuxcnc_hal::hal_pin::hal_pin   > Allocating 8 bytes
 DEBUG linuxcnc_hal::hal_pin::hal_pin   > Allocated value 0x0 at 0x7f673622e478
 DEBUG linuxcnc_hal::hal_pin::output_pin > Make pin rust-comp.output-1 returned 0
 DEBUG linuxcnc_hal::component           > Signals registered
 DEBUG linuxcnc_hal::component           > Component is ready
Input: Ok(0.0)
task: main loop took 0.012260 seconds
task: main loop took 0.012903 seconds
Input: Ok(0.0)
Input: Ok(0.0)
Input: Ok(0.0)
Input: Ok(0.0)
Input: Ok(0.0)
Shutting down and cleaning up LinuxCNC...
Input: Ok(0.0)
task: 5355 cycles, min=0.000005, max=0.012903, avg=0.001116, 2 latency excursions (> 10x expected cycle time of 0.001000s)
 DEBUG linuxcnc_hal::hal_pin::input_pin  > Drop InputPin rust-comp.input-1
 DEBUG linuxcnc_hal::hal_pin::output_pin > Drop OutputPin rust-comp.output-1
 DEBUG linuxcnc_hal::component           > Closing component ID 48, name rust-comp
Note: Using POSIX non-realtime
```

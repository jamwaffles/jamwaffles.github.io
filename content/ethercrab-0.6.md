+++
layout = "post"
title = "EtherCrab 0.6 Released"
slug = "ethercrab-0-6"
started_date = "2025-03-29 09:39:57"
date = "2025-03-29"
+++

[EtherCrab 0.6.0](https://crates.io/crates/ethercrab/0.6.0)
([lib.rs](https://lib.rs/crates/ethercrab)) is out as the next release of this pure Rust EtherCAT
MainDevice! I'll go over some of the bigger features in this post, and for the full changelog you
can check it out [here](https://github.com/ethercrab-rs/ethercrab/blob/master/CHANGELOG.md). The
MSRV has been bumped from 1.77 to 1.81.

<!-- more -->

# SubDevice group PDI spinlocks

As of 0.6, the Process Data Image (PDI) for each SubDevice group is wrapped in a spinlock. This
relaxes some of the API so that SubDevices can be safely shared between tasks/threads now, however
when locks are involved, deadlocks are also much more likely. As a general rule, try to hold the
`Pdi*Guard` returned by `SubDevice::{io_raw, outputs_mut, ...}` for as little time as possible and
if you need to persist the PDI somewhere, copy it into other memory like a struct, `Vec` or array.

The lock and EtherCrab API is designed in such a way that the PDI state is always consistent. This
means that all SubDevices will always see the same iteration of the PDI, which is important when the
PDI is sent over the network in multiple EtherCAT frames. In this case, the group TX/RX call will
only release the PDI lock when _all_ frame responses have been received. Conversely, if a SubDevice
is reading from or writing to its PDI, the TX/RX operation for the next cycle will wait for all
SubDevices to release the PDI lock.

It's tempting to only lock the part of the PDI storage that's currently being updated (either from
the application or received frame), however this risks some SubDevices in the group observing the
next frame's data, whilst others will see the current frame or vice versa. EtherCAT strives to
produce a temporally accurate representation of the real world, so allowing partial state
observations is antithetical to that goal. The locks in EtherCrab are designed to uphold this goal.

The PDI lock is scoped to each group, so running multiple groups with different cycle times is still
fine and a supported/desired use case.

# SubDevice status now read during TX/RX

Prior to this release, reading the SubDevice status for all devices in a group was cumbersome and,
more importantly, slow. It required writing a loop to send multiple separate EtherCAT frames without
a good way to parallelise the network traffic.

This is now vastly improved by making the `SubDeviceGroup::tx_rx*` methods pack SubDevice status
check EtherCAT frames into the same Ethernet packet as the PDI, if there's space left. If there
isn't, another packet will be sent with as many status check frames packed into it as possible
resulting in minimal extra network traffic for up to 128 status checks (if memory serves correctly).
This process continues until all SubDevice status check frames have been sent.

For small to medium networks, it's quite likely that no additional network layer traffic will be
sent as the PDI _and_ status check EtherCAT frames will all fit in a single Ethernet packet.

To make use of this extra data, the `tx_rx*` methods now return a `TxRxResponse` struct. This is a
breaking change to the tuple returned before, but it is a much more flexible API which EtherCrab can
use more in the future. Here's a short example of running a process data cycle and checking
SubDevice statuses all in one operation:

```rust
loop {
    let now = Instant::now();

    let response @ TxRxResponse {
        working_counter: _wkc,
        extra:
            CycleInfo {
                dc_system_time,
                next_cycle_wait,
                cycle_start_offset,
            },
        ..
    } = group.tx_rx_dc(&maindevice).await.expect("TX/RX");

    if !response.all_op() {
        for (i, status) in response.subdevice_states.iter().enumerate() {
            if *status != SubDeviceState::Op {
                log::error!("Subdevice {} is {}, expected OP", i, status);
            }
        }
    }

    // ... logic here ...

    smol::Timer::at(now + next_cycle_wait).await;
}
```

# Windows

EtherCrab used to provide the `tx_rx_task` async function for Windows users for consistency with the
async function of the same name offered for Linux and macOS, however this is removed in 0.6 as the
internals of the function are all blocking anyway, and it doesn't make sense to add async executor
overhead to running the TX/RX task. Now, instead of spawning an async task to run the TX/RX loop,
you should `thread::spawn` the `tx_rx_task_blocking` function. It is also recommended to use
something like [`thread-priority`](https://crates.io/crates/thread-priority) and other tricks in the
[EtherCrab Windows tuning guide](https://github.com/ethercrab-rs/ethercrab/blob/master/doc/windows-tuning.md)
to improve performance on Windows. It'll never be as good as something like Linux - don't expect
100us cycle times! - but the tricks in that guide do help timing consistency quite a lot.

# Other stuff

A few EEPROM methods were added which now allows things like dumping of EEPROMs using EtherCrab (see
example [here](https://github.com/ethercrab-rs/ethercrab/blob/master/examples/dump-eeprom.rs)) and
reading/setting the SubDevice alias address.

It's now possible to read/write SDO sub indices using arrays, for a bit less typing in configuration
code. For example:

```rust
subdevice
    .sdo_write_array(0x1c13, &[0x1a00u16, 0x1a02, 0x1a04, 0x1a06])
    .await?;

// The `sdo_write_array` call above is equivalent to the following
// subdevice.sdo_write(0x1c13, 0, 0u8).await?;
// subdevice.sdo_write(0x1c13, 1, 0x1a00u16).await?;
// subdevice.sdo_write(0x1c13, 2, 0x1a02u16).await?;
// subdevice.sdo_write(0x1c13, 3, 0x1a04u16).await?;
// subdevice.sdo_write(0x1c13, 4, 0x1a06u16).await?;
// subdevice.sdo_write(0x1c13, 0, 4u8).await?;
```

A couple of the variants in `Error` have been removed as they're no longer returned by any EtherCrab
code, and a couple of new ones have been added like `Error::Mailbox(MailboxError::Emergency)`.

The rest of the changelog is largely filled with reliability and robustness improvements. For
example, EtherCrab's internal storage is slightly more resilient to race conditions, and SubDevice
initialisation is a lot more reliable when the EEPROM is empty or only partially populated.

# What's next

While these aren't solid commitments, I thought I'd quickly list some other stuff I'd like to see in
EtherCrab in the next release anyway:

- A primitive API to bypass EtherCrab's automatic SubDevice configuration. Currently, EtherCrab
  relies on a SubDevice's EEPROM being properly populated, which is becoming less and less good as
  EtherCrab is used on more SubDevices where this isn't the case. Most EtherCAT MainDevice
  implementations rely on ESI files or similar static configuration methods. ESI files are even
  required for SubDevice certification, so they're probably a lot more reliable as a config source.

  As a step towards ESI file support, I'd like to expose a reasonably nice way to set explicit
  configuration for FMMUs and Sync Managers, completely bypassing the EEPROM autoconfig. This should
  allow extremely basic support for ESI files too, leading me onto my next feature.

- Some kind of more ergonomic way to map a SubDevice's PDO configuration into its slice of the PDI
  using the config described above. This could be a precursor to a derive macro which does a bunch
  of magic to automatically configure and map a SubDevice's PDI from its ESI file, but I think a
  first pass should be more basic with no magic.

- The above features should also allow the creation of a high level DS402 interface for servo drives
  and other motor drivers that support this common protocol. This feature _is_ a solid commitment
  for the next release, so stay tuned.

If you have other features you'd like to see in EtherCrab, please
[open a feature request](https://github.com/ethercrab-rs/ethercrab/issues)!

To current users of EtherCrab, thanks heaps for using it! It's becoming more widely used in some
really interesting machines and I love seeing every photo and video posted of EtherCrab in action!

+++
layout = "post"
title = "EtherCrab 0.7 Released"
slug = "ethercrab-0-7"
started_date = "2026-03-15 17:32:46"
date = "2026-03-16"
+++

[EtherCrab 0.7.0](https://crates.io/crates/ethercrab/0.7.0)
([lib.rs](https://lib.rs/crates/ethercrab)) is out as the next release of this pure Rust EtherCAT
MainDevice! There are some minor breaking changes, but nothing too difficult to migrate. Otherwise,
not much to report as this is a release to get a couple of features out in the wild before some
larger breaking changes in future EtherCrab versions. Full changelog is available
[here](https://github.com/ethercrab-rs/ethercrab/blob/main/CHANGELOG.md).

<!-- more -->

# Breaking changes

There isn't too much in this release, so don't worry. First off, the Minimum Supported Rust Version
(MSRV) has been bumped from 1.81 to 1.85, with a migration to Rust edition 2024 at the same time.

Next, an extra generic parameter has been added to `SubDeviceGroup` and related items such as
`PdiReadGuard`. For example, this is how `SubDeviceGroup` has changed:

```rust
// EtherCrab 0.6
pub struct SubDeviceGroup<
    const MAX_SUBDEVICES: usize,
    const MAX_PDI: usize,
    S = PreOp,
    DC = NoDc,
>

// EtherCrab 0.7
pub struct SubDeviceGroup<
    const MAX_SUBDEVICES: usize,
    const MAX_PDI: usize,
    R: RawRwLock = crate::DefaultLock, // <-- NEW
    S = PreOp,
    DC = NoDc,
>
```

To mirror EtherCrab 0.6 behaviour by default, the field is set to a lock of `spin::Yield` for `std`,
and `spin::Spin` for `no_std`, however this change allows the use of custom locks, as long as they
implement the [`lock_api`](https://docs.rs/lock_api) traits.

Another minor API breakage is in `MainDevice::init`. It now requires a default groups struct to be
passed as an extra argument, instead of requiring `G: Default` and doing it internally. This should
just be a one line change as there was already a `Default` bound on `MainDevice::init`:

```rust
#[derive(Default)]
struct Groups {
    /* snip */
}

let groups = maindevice
    .init::<MAX_SUBDEVICES, _>(
        ethercat_now,
        Groups::default(), // <-- NEW
        |groups: &Groups, subdevice| match subdevice.name() {
            "EL2889" | "EK1100" | "EK1501" => Ok(&groups.slow_outputs),
            "EL2828" => Ok(&groups.fast_outputs),
            _ => Err(Error::UnknownSubDevice),
        },
    )
    .await
    .expect("Init");
```

This allows customising the initialisation of the groups struct passed to `init`.

Finally, `Error::Timeout` has an inner enum describing the reason for a timeout. The change to
`Error` is minimal:

```rust
use ethercrab::Error;

let result = /* snip */;

// EtherCrab 0.6
if let Error::Timeout = result {
    log::error!("Timeout!");
}

// EtherCrab 0.7
if let Error::Timeout(timeout) = result {
    log::error!("Timeout: {}", timeout);
}
```

# New features

Not much to show here really, but there are still some niceties added:

- XDP is now supported on Linux systems by enabling the `xdp` feature. XDP is a lower level way to
  access networking hardware, so may help performance on systems.
- SDO info getters have been added to list out available SDOs present in a SubDevice. Search for
  `sdo_info_object_description_list` and `sdo_info_object_quantities` in the docs, or look at the
  [`sdo-info` example](https://github.com/ethercrab-rs/ethercrab/blob/7cb8f8b0fa38c69d80db04863e5881e668e88ef3/examples/sdo-info.rs)
  for more.
- In lieu of a more complete setup using ESI files and such, basic oversampling support was added
  with the `SubDevice::set_oversampling` method. The
  [`el3702-oversampling` example](https://github.com/ethercrab-rs/ethercrab/blob/7cb8f8b0fa38c69d80db04863e5881e668e88ef3/examples/el3702-oversampling.rs)
  shows a demo of this functionality. Pay attention to how the `SYNC1` config is set up!

# Other fixes and small behavioural changes

- SubDevice status codes and SDO abort codes are now read and returned to the user correctly.
- Distributed Clocks should be more reliable with SubDevices that have 32 bit clocks.
- Sync Manager config is now read from EEPROM instead of over CoE, improving reliability for some
  SubDevices.
- Sync Managers with a length of `0` are no longer enabled, again helping reliability with some
  SubDevices.
- The minimally documented register `0x980` is no longer used internally in EtherCrab. Its use is
  present in other MainDevice implementations but causes issues with some SubDevices.

# What's next

Pretty much the same as [EtherCrab 0.6](/ethercrab-0-6/#what-s-next)...

As usual, if you have other features you'd like to see in EtherCrab, please
[open a feature request](https://github.com/ethercrab-rs/ethercrab/issues)!

Thanks to everyone using and improving EtherCrab every day ❤️

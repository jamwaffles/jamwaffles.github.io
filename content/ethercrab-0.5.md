+++
layout = "post"
title = "EtherCrab 0.5: Not Much In A Name"
slug = "ethercrab-0-5"
started_date = "2024-07-28 10:37:01"
date = "2024-07-28"

# [extra]
# image = "/images/ethercat.jpg"
+++

I've just released [EtherCrab 0.5.0](https://crates.io/crates/ethercrab/0.5.0)
([lib.rs](https://lib.rs/crates/ethercrab)), the pure Rust EtherCAT MainDevice. This is a smaller
release than usual, with added support for FreeBSD/NetBSD and a bunch of renamed items in the public
API. The full changelog can be found
[here](https://github.com/ethercrab-rs/ethercrab/blob/master/CHANGELOG.md).

<!-- more -->

# Renamed items

This release removes the "master" and "slave" terminology in favour of the ETG-specified
"MainDevice" and "SubDevice" respectively. The full list of changes is as follows:

| Type      | Old                                        | New                                            |
| --------- | ------------------------------------------ | ---------------------------------------------- |
| `enum`    | `SlaveState`                               | `SubDeviceState`                               |
| `fn`      | `Client::num_slaves()`                     | `MainDevice::num_subdevices()`                 |
| `fn`      | `Ds402::slave()`                           | `Ds402::subdevice()`                           |
| `fn`      | `SlaveGroup::slave()`                      | `SubDeviceGroup::subdevice()`                  |
| `mod`     | `ethercrab::slave_group`                   | `ethercrab::subdevice_group`                   |
| `struct`  | `Client`                                   | `MainDevice`                                   |
| `struct`  | `ClientConfig`                             | `MainDeviceConfig`                             |
| `struct`  | `GroupSlaveIterator`                       | `GroupSubDeviceIterator`                       |
| `struct`  | `Slave`                                    | `SubDevice`                                    |
| `struct`  | `SlaveGroup`                               | `SubDeviceGroup`                               |
| `struct`  | `SlaveGroupRef`                            | `SubDeviceGroupRef`                            |
| `struct`  | `SlaveIdentity`                            | `SubDeviceIdentity`                            |
| `struct`  | `SlavePdi`                                 | `SubDevicePdi`                                 |
| `struct`  | `SlaveRef`                                 | `SubDeviceRef`                                 |
| `variant` | `AlStatusCode::SlaveNeedsColdStart`        | `AlStatusCode::SubDeviceNeedsColdStart`        |
| `variant` | `AlStatusCode::SlaveNeedsInit`             | `AlStatusCode::SubDeviceNeedsInit`             |
| `variant` | `AlStatusCode::SlaveNeedsPreop`            | `AlStatusCode::SubDeviceNeedsPreop`            |
| `variant` | `AlStatusCode::SlaveNeedsRestartedLocally` | `AlStatusCode::SubDeviceNeedsRestartedLocally` |
| `variant` | `AlStatusCode::SlaveNeedsSafeop`           | `AlStatusCode::SubDeviceNeedsSafeop`           |
| `variant` | `Error::UnknownSlave`                      | `Error::UnknownSubDevice`                      |

This is largely a find and replace operation, but it's still a non-zero effort. Apologies for the
churn, but now EtherCrab is more consistent with ETG documentation, and the oddly named `Client`
struct is now called `MainDevice`. Frankly I don't know why I called it `Client` - it should've been
`Master` or `Controller`. It's fixed now anyway 🙂.

# FreeBSD/NetBSD support

EtherCrab now supports FreeBSD and NetBSD! It might support other BSDs too although it hasn't been
tested against anything but FreeBSD. If you use a BSD, please give EtherCrab a try and open any
issues on [GitHub](https://github.com/ethercrab-rs/ethercrab/issues) - I'm not too familiar with the
BSD ecosystem.

# Other smaller changes

- MSRV is now 1.77, increased from 1.75.
- Strings loaded from SubDevices are now required to be valid ASCII. Previously, UTF-8 strings were
  accepted however the EtherCAT spec defines strings as ASCII-only (technically a subset of the full
  ASCII set).
- Some small changes to some `Error` variants to reduce the size of the enum on embedded systems.

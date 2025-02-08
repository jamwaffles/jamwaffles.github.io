+++
layout = "post"
title = "Computing the EtherCAT SubDevice SII/EEPROM checksum"
slug = "ethercat-sii-eeprom-checksum"
date = "2025-02-08"
+++

This is an answer to
[this StackExchange question](https://electronics.stackexchange.com/q/33821/2212) which I'm posting
here instead as I refuse to add any more of my time or energy to that website.

I'm using Rust and the [`crc`](https://crates.io/crates/crc) crate to calculate the checksum of the
first 14 bytes of an EtherCAT SubDevice EEPROM. I first tried `CRC-8/ROHC` (`crc::CRC_8_ROHC`) as
suggested [by @craig-mcqueen](https://electronics.stackexchange.com/a/196840/2212) but it gave me
incorrect results when checking a few known-good EEPROM dump files I have.

I also iterated through every `CRC_8_*` constant in `crc` and none of them gave the correct result.

The SOEM EtherCAT MainDevice has its CRC implementation
[here](https://github.com/OpenEtherCATsociety/SOEM/blob/2752dc25882ab24d7cfcad674226b65270fb0c61/test/linux/eepromtool/eepromtool.c#L64)
which I used to cross check my Rust "implementation":

```rust
const ECAT_CRC: crc::Algorithm<u8> = crc::Algorithm {
    width: 8,
    poly: 0x07,
    init: 0xff,
    refin: false,
    refout: false,
    xorout: 0x00,
    check: 0x80,
    residue: 0x00,
};

const EEPROM_CRC: crc::Crc<u8> = crc::Crc::<u8>::new(&ECAT_CRC);
```

This is very close to `CRC-8/ROHC` but I had to change `check` from `0xd0` to `0x80`. My checksums
now line up with the presumably more exercised SOEM implementation and the actual value in the
dumped EEPROM files so I believe it's correct, however I couldn't find a match in
[the catalogue](https://reveng.sourceforge.io/crc-catalogue/1-15.htm) which is weird.

Hope this helps :)

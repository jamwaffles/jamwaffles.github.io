+++
layout = "post"
title = "Controlling an Electric iQool AC with ESPHome and Home Assistant"
slug = "electriq-iqool-aircon-esphome-home-assistant"
started_date = "2024-02-25 15:06:14"
draft = true
# TODO
date = "2024-02-23"

# [extra]
# image = "/images/ethercat.jpg"
+++

TODO INTRO

<!-- more -->

# Investigation

- This unit is almost identical to the Qlima
  ["Monoblock airco cooling and heating WDH 229 PTC white"](https://www.qlima.com/monoblock-airco-cooling-and-heating-wdh-229-ptc-white.html)
  - Eleqtric CEO mentions going to china and buying the same whitelabeled units so this makes sense.
    TODO: Link press release.
  - Not very useful information because there's nothing else out there about this unti anyway.
- Started with spoofing IR remote. protocol seems to almost be `TROTEC_3550` using
  [IRremoteESP8266](https://github.com/crankyoldgit/IRremoteESP8266) but more often than not this
  tool just ended up decoding the remote data as `Pronto`. I did get the unit working using
  ESPHome's `remote_transmitter` component but it feels messy sending raw Pronto codes so I cracked
  the unit open and had a dig around to see if I could hack in an ESP32.
- Thankfully it turns out the unit uses a `TODO: Company` `TODO: Model` wifi module with Tuya
  compatible firmware by default. This module can be flashed with ESPHome, so no hacking necessary!
- The way I did it does require physical access to the WiFi module, but it may be possible to hack
  it over the air by following [this guide](#TODO). I was comfortable taking my unit apart but if
  you're not, you might still have an option.

# Hardware pin mapping

- Status LED
- TODO: Programming ports
- TODO: Connector pin mapping

# Flashing ESPHome to the `TODO` module

- Physical access
- Serial adapter. I used Sipeed Slogic Combo8 but any UART will work.
- Backup original FW
  - TODO: Command
  - TODO: Link to original FW for posterity
- Programming process
  - Power on AC
  - Unplug WiFi module
  - `esphome run ac.yaml`
  - Hold button, plug in, release button
  - Firmware should flash now. Might have to try this process a few times to get `esptool` to bite.

# ESPHome configuration

- Initially tried with IR `remote_transmitter` ESPHome component which worked but I didn't like it.
  Bit janky. Some functions didn't work and I wanted the status feedback in case e.g. I thought I
  turned the unit off but it was actually on all night.
- Ended up cracking into the case and reflashing the Tuya firmware to ESPHome.
- Basically the same as {TODO} unit. Electriq buys stuff from the same factory and relabels it.
- Uses a {TODO} module with Tuya-compatible firmware by default.
- I used ESPHome and Home Assistant
- Works with Apple Home, presumably other stuff too!
- Had to use some not-yet-merged ESPHome stuff. Link to my repo and the upstream PR from that other
  guy's changes.
- My unit has a PTC heater. Alas I couldn't see anything that responds to the PTC :(. The manual
  says it's only supported on the remote, which might be why.
- The ESPHome Tuya component can talk to the MCU in the aircon. Startup log looked like this:

  ```
  [13:40:56][C][tuya:033]: Tuya:
  [13:40:56][C][tuya:048]:   Datapoint 1: switch (value: OFF)
  [13:40:56][C][tuya:050]:   Datapoint 2: int value (value: 6)
  [13:40:56][C][tuya:054]:   Datapoint 4: enum (value: 0)
  [13:40:56][C][tuya:054]:   Datapoint 5: enum (value: 0)
  [13:40:56][C][tuya:056]:   Datapoint 106: bitmask (value: 0)
  [13:40:56][C][tuya:056]:   Datapoint 111: bitmask (value: 0)
  [13:40:56][C][tuya:054]:   Datapoint 19: enum (value: 0)
  [13:40:56][C][tuya:050]:   Datapoint 3: int value (value: 13)
  [13:40:56][C][tuya:048]:   Datapoint 101: switch (value: OFF)
  [13:40:56][C][tuya:048]:   Datapoint 102: switch (value: OFF)
  [13:40:56][C][tuya:048]:   Datapoint 104: switch (value: OFF)
  [13:40:56][C][tuya:054]:   Datapoint 110: enum (value: 0)
  [13:40:56][C][tuya:050]:   Datapoint 105: int value (value: 0)
  [13:40:56][C][tuya:050]:   Datapoint 103: int value (value: 0)
  [13:40:56][C][tuya:068]:   Product: '{"p":"2tgd3qnobb1mcgd9","v":"1.0.0","m":1}'
  ```

  - Unsure what all the mappings are but playing with the remote got me these:

    | Datapoint | Function                                    |
    | --------- | ------------------------------------------- |
    | 1         | On/off (standby)                            |
    | 2         | Target temperature in ºC                    |
    | 3         | Current measured temperature in ºC          |
    | 4         | Mode (cool `0`, fan `1`, dry `2`, heat `3`) |
    | 5         | Fan speed (`0` low, `1` medium, `2` high)   |
    | 101       | "Sleep" (quiet mode) preset on/off          |
    | 104       | Vertical swing on/off                       |

    There are some other enums and bitmasks which might be unused features for a more advanced unit
    (horizontal swing for example) or maybe error bitmaps. If anyone finds out please let me know!

# Grafana

- TODO: Screenshots
- Talk about presenting sensors for logging stuff in Grafana. `tuya` doesn't expose these in a way
  that's usable with Grafana by default.
  - TODO: YAML

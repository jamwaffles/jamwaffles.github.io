---
layout: post
title: 'Hook up an Aliexpress Special jog wheel'
date: 2019-11-22 16:06:00
categories: rust cnc
image: todo.jpg
---

- Enable button is a physical connection to axis/multiplier selector
- LED can run at 3.3v but it's pretty dim
- EStop (Blue and Blue/Black) button has both pins broken out. Tie high so short to ground (more likely than short to +V) stops machine
- Encoder needs 5v, outputs ~2.7v logic high. Take care to connect to 5v tolerant pin in ref to pinout image
- Definitely need to bump clock to 72MHz/periph to 36MHz otherwise steps get missed on encoder

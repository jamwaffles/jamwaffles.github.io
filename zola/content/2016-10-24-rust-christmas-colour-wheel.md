+++
layout = "post"
title = "A white (and red and green) Christmas"
date = "2016-10-24 22:55:05"
categories = "rust"

[extra]
image = "images/rgw-header.jpg"
+++

Here's a quick one; I'm making a Christmas display out of a bunch of serially controllable APA106
RGB LEDs, but how do I turn a value of `0 – 255` into a glorious RGW (Red Green White) struct with
the correct colour, and the correct wrapping rules?

## First, some theory

The code in the next section is based on the RGB linear colour wheel approximation from the
[Adafruit NeoPixel library](https://github.com/adafruit/Adafruit_NeoPixel/blob/master/examples/strandtest/strandtest.ino#L123).
So that I can make modifications to the generated colours, it helps to first visualise the RGB
brightnesses against time. For a rainbow RGB pattern, that looks a bit like this:

![Linear RGB graph](/assets/images/rgb-linear.png)

We'll get onto the RGW stuff in a sec.

## Code

I'm writing this project in Rust, however my code is modified from
[the original RGB wheel C code from Adafruit](https://github.com/adafruit/Adafruit_NeoPixel/blob/master/examples/strandtest/strandtest.ino#L123).

### RGB

Here's what the reference RGB function looks like in C:

```c
uint32_t Wheel(byte WheelPos) {
	WheelPos = 255 - WheelPos;
	if(WheelPos < 85) {
		return strip.Color(255 - WheelPos * 3, 0, WheelPos * 3);
	}
	if(WheelPos < 170) {
		WheelPos -= 85;
		return strip.Color(0, WheelPos * 3, 255 - WheelPos * 3);
	}
	WheelPos -= 170;
	return strip.Color(WheelPos * 3, 255 - WheelPos * 3, 0);
}
```

Easy stuff. It's not perfect because it's linear instead of sinusoidal as we saw in the graph above,
but it makes a good enough approximation for fading some LEDs over the rainbow. And it uses simple
integer maths which is nice and fast.

This is what the same thing (still RGB) looks like in Rust:

```rust
#[derive(Copy, Clone)]
pub struct Apa106Led {
	pub red: u8,
	pub green: u8,
	pub blue: u8,
}

pub fn rgb_wheel(wheelpos: u8) -> Apa106Led {
	let mut thingy = wheelpos;

	if thingy < 85 {
		Apa106Led { red: thingy * 3, green: 255 - thingy * 3, blue: 0 }
	} else if thingy < 170 {
		thingy -= 85;

		Apa106Led { red: 255 - thingy * 3, green: 0, blue: thingy * 3 }
	} else {
		thingy -= 170;

		Apa106Led { red: 0, green: thingy * 3, blue: 255 - thingy * 3 }
	}
}
```

Note that I'm using a struct to return the values because Rust is cool, and structs are cool.

### Chrismus – RGW

Apparently the colours of Christmas are red, green and white. To this end, we need to make a slight
modification to our wheel function to fade through white instead of blue:

![Linear RGW graph](/assets/images/rgw-linear.png)

There's one caveat to this algorithm: between white and red, there's this wishy washy pink colour
that shows up. It's not that bad, but on my LED display it looks odd due to the other colours being
reasonably well saturated.

The code to do this looks like the following:

```rust
// Red - green - white colour wheel
pub fn christmas_wheel(wheelpos: u8) -> Apa106Led {
	let mut thingy = wheelpos;

	// Ramp red down to 0, green up to 255
	if thingy < 85 {
		Apa106Led { red: 255 - thingy * 3, green: thingy * 3, blue: 0 }
	} else if thingy < 170 {	// Ramp red and blue up, leave green at 255
		thingy -= 85;

		Apa106Led { red: thingy * 3, green: 255, blue: thingy * 3 }
	} else {		// Ramp green and blue down, leave red at 255
		thingy -= 170;

		Apa106Led { red: 255, green: 255 - thingy * 3, blue: 255 - thingy * 3 }
	}
}
```

Proper wrapping was a bit hard to figure out because red is the only colour that wraps. Drawing
diagrams really helps with this kind of stuff.

Sw33t!

![LED cube. Does anybody ever read these?](/assets/images/rgw-cube.jpg)

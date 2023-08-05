---
layout: post
title:  "Embedded Graphics 0.4.7 and TinyBMP 0.1.0"
date:   2019-03-04 19:04:00
categories: rust
image: tinybmp-header.jpg
---

[Embedded graphics](https://crates.io/crates/embedded-graphics) 0.4.7 has been released, along with a new sister crate, [tinybmp](https://crates.io/crates/tinybmp)! TinyBMP aims to parse BMP-format image data using no dynamic allocations. It targets embedded environments but can be used in any place a small BMP parser is required. Thanks to TinyBMP, Embedded Graphics now supports loading this simple image format. The header photo was made using Embedded Graphics and the [SSD1331 driver](https://crates.io/crates/ssd1331) in pure Rust. In this post, I'll talk through how the BMP file is parsed in no_std environments with [nom](https://crates.io/crates/nom) and how to get BMP images working with embedded_graphics.

## BMP format

The BMP format is pretty simple. It consists of the following sections which I'll cover separately below:

* File header (metadata)
* DIB header (more metadata)
* Colour pallette table (for colour-indexed images, ignored by TinyBMP)
* Bitmap information

### File header and DIB header

I'm not sure why the header is split into two parts, but TinyBMP treats them as a single section as they form a contiguous block of bytes in the file. The parser ignores some extraneous fields in the header. The ones we're interested in are described in the [`Header`](https://docs.rs/tinybmp/0.1.0/tinybmp/struct.Header.html) struct:

```rust
/// BMP header information
#[derive(Debug, Clone, PartialEq)]
pub struct Header {
    /// Bitmap file type
    pub file_type: FileType,
    /// Total file size in bytes
    pub file_size: u32,
    /// Reserved field 1 (unused)
    pub reserved_1: u16,
    /// Reserved field 2 (unused)
    pub reserved_2: u16,
    /// Byte offset from beginning of file at which pixel data begins
    pub image_data_start: usize,
    /// Image width in pixels
    pub image_width: u32,
    /// Image height in pixels
    pub image_height: u32,
    /// Number of bits per pixel
    pub bpp: u16,
    /// Length in bytes of the image data
    pub image_data_len: u32,
}
```

There are some other fields present in the header segments, but they're not important for bitmap parsing.

To parse this header, I'm using [nom](https://crates.io/crates/nom) (a parser-combinator library) in no_std mode. It's defined in TinyBMP's `Cargo.toml` like this:

```toml
[dependencies.nom]
version = "4.2.1"
default-features = false
```

The parser is pretty simple. BMP data is little-endian encoded, so we can use Nom's `le_u16` and `le_u32` to parse all the fields out with a function called `parse_header`:

```rust
named!(parse_header<&[u8], Header>,
    do_parse!(
        // "Magic bytes" marker for BMP files
        tag!("BM") >>
        file_size: le_u32 >>
        reserved_1: le_u16 >>
        reserved_2: le_u16 >>
        image_data_start: le_u32 >>
        // Skip 4 bytes: Remaining header length in bytes
        le_u32 >>
        image_width: le_u32 >>
        image_height: le_u32 >>
        // Skip 4 bytes: Number of color planes
        le_u16 >>
        bpp: le_u16 >>
        // Skip 4 bytes: Compression method used
        le_u32 >>
        image_data_len: le_u32 >>
        // Skip other fields here
        (Header{
            file_type: FileType::BM,
            file_size,
            reserved_1,
            reserved_2,
            image_data_start: image_data_start as usize,
            image_width,
            image_height,
            image_data_len,
            bpp
        })
    )
);
```

This takes a slice (`&[u8]`) and produces a `Header` struct from the first few bytes of it. It should be pretty self explanatory, but I'll address some odd parts of the code above.

* `tag!("BM")` This is the "magic bytes" `BM` marker for BMP files, and must be present for the BMP to be valid.
* Lines with a lonesome `le_u16` or `le_u32` simply skip ahead 2 or 4 bytes respectively. This will be a field in the header that we want to ignore.

The `Header` struct is all we need to parse from the BMP file to be able to use it. On 32 bit systems (i.e. ARM MCUs, other embedded devices), `Header` only [requires 28 bytes of RAM](https://play.rust-lang.org/?version=stable&mode=debug&edition=2018&gist=f17e0aabe4f1471f22a34a7bf9426ad3). Nice!

### Bitmap information

BMP pixel data is pretty unremarkable, the only caveat being that the Y values are inverted, with the bottom row at the start of the data. Pixel values are stored in little-endian order in whatever bit depth is specified in the header. This will commonly be 32 or 24 bits, but 16, 8 or even 1BPP is supported by the BMP format. **Currently, only 8 and 16 BPP images are supported by Embedded Graphics. If you'd like to see other bit-depths supported, please [open an issue](https://github.com/jamwaffles/embedded-graphics/issues/new)!**

## Containing everything

The other data type exported by TinyBMP is the [`Bmp`](https://docs.rs/tinybmp/0.1.0/tinybmp/struct.Bmp.html) struct:

```rust
/// A BMP-format bitmap
#[derive(Debug, Clone, PartialEq)]
pub struct Bmp<'a> {
    /// Image header
    pub header: Header,

    image_data: &'a [u8],
}
```

This is how you should use TinyBMP, namely with the [`from_slice`](https://docs.rs/tinybmp/0.1.0/tinybmp/struct.Bmp.html#method.from_slice) method:

```rust
/// Create a bitmap object from a byte array
///
/// This method keeps a slice of the original input and does not dynamically allocate memory.
/// The input data must live for as long as this BMP instance does.
pub fn from_slice(bytes: &'a [u8]) -> Result<Self, ()> {
    let (_remaining, header) = parse_header(bytes).map_err(|_| ())?;

    let image_data = &bytes[header.image_data_start..];

    Ok(Bmp { header, image_data })
}
```

This method takes a slice representing a complete BMP file and creates a `Bmp` from it. The header is parsed and a sub-slice of the input data is kept in the `image_data` field, based on the `image_data_start` field from the header.

Keeping with the no_std, low-memory-usage theme, [`Bmp` only consumes 48 bytes of memory](https://play.rust-lang.org/?version=stable&mode=debug&edition=2018&gist=441d59cefe15b51ba0efd57887f329f6)! Bear in mind the playground uses 64 bit Rust (I think), so memory usage on a 32 bit ARM microcontroller might even be a bit less. The original bitmap data must be kept somewhere of course, but this works well with `include_bytes!()` in and embedded context; `include_bytes!()` data is kept in flash memory, leaving precious RAM available for your application. Microcontrollers generally have a lot more flash than RAM, so it's sensible to store large byte arrays in flash.

## Embedded Graphics

TinyBMP exposes BMP image data through the [`image_data()`](https://docs.rs/tinybmp/0.1.0/tinybmp/struct.Bmp.html#method.image_data) method on `Bmp`. We can use this image data to form an `Image` iterator for Embedded Graphics to use.

### The struct

First, let's define `ImageBmp` that wraps a `Bmp` file with some extra data to allow for cool Embedded Graphics things like transforms:

```rust
/// BMP format image
#[derive(Debug, Clone)]
pub struct ImageBmp<'a, C: PixelColor> {
    bmp: Bmp<'a>,

    /// Top left corner offset from display origin (0,0)
    pub offset: Coord,

    pixel_type: PhantomData<C>,
}
```

`PixelColor` will be used a bit later to make `ImageBmp` compatible with multiple pixel types.

You can read the entire source for `ImageBmp` [here](https://github.com/jamwaffles/embedded-graphics/blob/10b9aacb668b732863a66fa5fcd055dfb2f72eba/embedded-graphics/src/image/image_bmp.rs). I'll only cover some parts of it to keep this post to a reasonable length.

### Iterator setup

Now we have an `ImageBmp`, we need to get an iterator for it so the pixel data can be used by Embedded Graphics-compatible libraries. This can be done by creating `ImageBmpIterator` and implementing `IntoIterator for ImageBmp`:

```rust
#[derive(Debug)]
pub struct ImageBmpIterator<'a, C: 'a>
where
    C: PixelColor,
{
    x: u32,
    y: u32,
    im: &'a ImageBmp<'a, C>,
    image_data: &'a [u8],
}

impl<'a, C> IntoIterator for &'a ImageBmp<'a, C>
where
    C: PixelColor + From<u8> + From<u16>,
{
    type Item = Pixel<C>;
    type IntoIter = ImageBmpIterator<'a, C>;

    fn into_iter(self) -> Self::IntoIter {
        ImageBmpIterator {
            im: self,
            image_data: self.bmp.image_data(),
            x: 0,
            y: 0,
        }
    }
}
```

`image_data` uses the `Bmp::image_data()` method mentioned above. Note that everything uses _references to the original data_, meaning **no new allocations of huge amounts of pixel data.**

I'm also adding `From<u8> + From<u16>` as trait bounds for reasons that will become clear in the next section.

### The iterator

This is the most important part of the compatibility between Embedded Graphics and TinyBMP - the iterator implementation. It's responsible for iterating over the BMP pixel data correctly (remember that it starts from the bottom up) as well as converting 8 or 16 bit words into the correct `PixelColor*`. This is what it looks like:

```rust
impl<'a, C> Iterator for ImageBmpIterator<'a, C>
where
    C: PixelColor + From<u8> + From<u16>,
{
    type Item = Pixel<C>;

    fn next(&mut self) -> Option<Self::Item> {
        let current_pixel = loop {
            let w = self.im.bmp.width();
            let h = self.im.bmp.height();
            let x = self.x;
            let y = self.y;

            // End iterator if we've run out of stuff
            if x >= w || y >= h {
                return None;
            }

            let offset = ((h - 1 - y) * w) + x;

            let bit_value = if self.im.bmp.bpp() == 8 {
                self.image_data[offset as usize] as u16
            } else if self.im.bmp.bpp() == 16 {
                let offset = offset * 2; // * 2 as two bytes per pixel

                (self.image_data[offset as usize] as u16)
                    | ((self.image_data[(offset + 1) as usize] as u16) << 8)
            } else {
                panic!("Bit depth {} not supported", self.im.bmp.bpp());
            };

            let current_pixel = self.im.offset + Coord::new(x as i32, y as i32);

            // Increment stuff
            self.x += 1;

            // Step down a row if we've hit the end of this one
            if self.x >= w {
                self.x = 0;
                self.y += 1;
            }

            if current_pixel[0] >= 0 && current_pixel[1] >= 0 {
                break Pixel(current_pixel.to_unsigned(), bit_value.into());
            }
        };

        Some(current_pixel)
    }
}
```

(it could probably stand to be optimised a bit. PRs welcome!)

This function is responsible for stepping through _on screen_ pixels; a translation may put some of the image off the top left corner of the screen, so those pixels must be skipped. This is why most of the function body is wrapped in a `loop`.

For each pixel coordinate, either 1 (for 8BPP) or two (for 16BPP) bytes are taken from the image data and cast to a `u16`.

If the pixel has positive coordinates, it's position and colour are returned. This is where the `From<u8> + From<u16>` bounds come in - they allow `bit_value.into()` to cast the pixel value into the correct `PixelColor*` used in calling code. I'll explain that better in the next section.

## An example

Let's walk through some of the steps to display this image on an embedded display:

![Rust logo with rainbow.](/assets/images/rust-bmp-large.jpg)

The [SSD1331 crate](https://crates.io/crates/ssd1331) uses the new TinyBMP support in Embedded Graphics to draw colour images like the one in the header for this post. The SSD1331 is a 16 bit colour display. It requires pixel data to be sent to it as 16 bit words split into 5 red, 6 green and 5 blue colour bits. This works nicely as we can use [`PixelColorU16`](https://docs.rs/embedded-graphics/0.4.7/embedded_graphics/pixelcolor/struct.PixelColorU16.html) to iterate over an image correctly.

First, we need an RGB565 image. The GIMP can export these quite easily - go to File -> Export As or press <kbd>Shift</kbd> + <kbd>Ctrl</kbd> + <kbd>E</kbd> and save as a file ending in `.bmp`. The BMP export options dialog will now show up. Make sure you choose `Advanced Options` -> `16 bits` -> `R5 G6 B5` option when exporting:

<img src="/assets/images/rust-bmp-export.png" srcset="/assets/images/rust-bmp-export.png 2x" />

Now we have a 16 bit BMP, it can be loaded into a Rust program using `include_bytes!()`, like this:

```rust
use embedded_graphics::image::ImageBmp;
use embedded_graphics::prelude::*;

let im = ImageBmp::new(include_bytes!("./awesome-image.bmp")).unwrap();
```

`im` can now be used to draw to a display compatible with Embedded Graphics with a simple `disp.draw(im.into_iter())` command. There's a complete example [here in the SSD1331 examples folder](https://github.com/jamwaffles/ssd1331/blob/e55cc11c40fdaaa137b39c9853367864d767b856/examples/bmp.rs) if you want to see a complete program.

Because Rust is awesome, it should be able to figure out whether you intended to use `PixelColourU8` or `PixelColorU16` based on the type of pixel the display driver uses. 8BPP BMP images will be converted to either type, and 16BPP BMP images will automatically convert two-byte words into a `PixelColorU16` which should make more images compatible with more displays.

And that's it! BMP support is great for Embedded Graphics, as it's now far simpler to work with images that are used in embedded projects. Hell, it's even just nice to get an image preview in the file browser! More image formats will be added in the future, namely ones that support simple compression like TGA _et al_, so stay tuned.

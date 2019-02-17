---
layout: post
title:  "Cross compiling Rust from Linux to macOS"
date:   2019-02-17 13:40:00
categories: rust
---

I've recently been working on a Rust project at [work](https://repositive.io/) which requires compiling for Linux (GNU), Linux (musl - for Alpine Linux) and macOS. I use Linux Mint nearly all the time, so building for macOS targets has required asking very nicely to borrow a spare Macbook Air. This is naturally a bit crap, so I set out to find a Linux-only solution to cross compile for macOS using [osxcross](https://github.com/tpoechtrager/osxcross). A weekend of pain later, and I have the following post. Hopefully it spares you a weekend of your own pain.

## Environment

This process should work in any modern-ish Debian-based environment. This is the setup I used:

* Linux Mint 19.1, Dell XPS1 15, Intel i9 x64
* Rust 1.32.0 (with [Rustup](http://rustup.rs/))
* Clang 6.0.0

I've also tested this process in [CircleCI](http://circleci.com/) and it seems to be working fine.

The only device I have to test on at time of writing is a Macbook Air with macOS Mojave on it. This process **should** work for other macOS versions, but is untested.

## Requirements

There are a few system dependencies required to work with osxcross. I don't think the version requirements are too strict for the packages listed below. You may want to check the [osxcross requirements](https://github.com/tpoechtrager/osxcross#installation) as well if you're having problems.

```bash
# Install build dependencies
apt install \
    clang \
    gcc \
    g++ \
    zlib1g-dev \
    libmpc-dev \
    libmpfr-dev \
    libgmp-dev

# Add macOS Rust target
rustup target add x86_64-apple-darwin
```

## Building osxcross

The following process is based on [this tutorial on Reddit](https://www.reddit.com/r/rust/comments/6rxoty/tutorial_cross_compiling_from_linux_for_osx/) and some trial and error. I'm using the macOS 10.10 SDK as I had the least problems getting up and running with it.

Add the following to a script called `osxcross_setup.sh` and make it executable.

```bash
git clone https://github.com/tpoechtrager/osxcross
cd osxcross
wget -nc https://s3.dockerproject.org/darwin/v2/MacOSX10.10.sdk.tar.xz
mv MacOSX10.10.sdk.tar.xz tarballs/
UNATTENDED=yes OSX_VERSION_MIN=10.7 ./build.sh
```

Not a lot to it, thanks to the hard work put in by the osxcross developers. Running `./osxcross_setup.sh` should create a folder named `osxcross` with everything you need in it to cross compile to macOS with Clang. This doesn't modify `$PATH` or install any system files, so is useful for CI as well.

_Append `./build_gcc.sh` to `osxcross_setup.sh` if you want to use GCC to cross compile._

## Configuring Cargo

Cargo needs to be told to use the correct linker for the `x86_64-apple-darwin` target, so add the following to your project's `.cargo/config` file:

```toml
[target.x86_64-apple-darwin]
linker = "x86_64-apple-darwin14-clang"
ar = "x86_64-apple-darwin14-ar"
```

If you've used a different macOS SDK version, you might need to replace `darwin14` with `darwin15`. To check what binary to use, look in `osxcross/target/bin`.

## Building the project

Because I chose not to install osxcross at the system level, the `$PATH` variable must be modified for Cargo to pick up the linker binaries specified previously. The build command changes to:

```bash
# Add --release to build in release mode
PATH="$(pwd)/osxcross/target/bin:$PATH" \
cargo build --target x86_64-apple-darwin
```

This adds `[pwd]/osxcross/target/bin` to `$PATH`, which means the linker binaries should get picked up. The path must be absolute to work properly, hence `$(pwd)`.

Now you should have a binary in `target/x86_64-apple-darwin/[debug|release]` which works on macOS!

## Building `*-sys` crates

You can stop here if none of your crates require any C bindings to function. Quite a few of them do, so read on if you run into compilation or linking errors.

The project I'm cross compiling uses the [git2](https://crates.io/crates/git2) crate which has [libz-sys](https://github.com/rust-lang/libz-sys/) in its dependency tree. Unfortunately this means digging out a C compiler. The build uses the _host_ system compiler by default, so the architectures for the final binary (target arch) and these linked libraries (host arch) don't match up.

The solution to this is to set the `CC` and `CXX` environment variables in our build command:

```bash
PATH="$(pwd)/osxcross/target/bin:$PATH" \
CC=o64-clang \
CXX=o64-clang++ \
cargo build --target x86_64-apple-darwin
```

This uses `o64-clang` and `o64-clang++` in `osxcross/target/bin`.

Now git2 compiles, but fails to link! This is due to the fact that libz-sys attempts to link to the host system `zlib` library. Because I'm building on a Linux machine, this is a Linux-native library which won't work on macOS.

Luckily, libz-sys supports building its own statically linked version of zlib. According to [libz-sys' `build.rs`](https://github.com/rust-lang/libz-sys/blob/master/build.rs#L25), if `LIBZ_SYS_STATIC=1` is set in the environment a bundled version of zlib will be built. Because we set `CC` and `CXX`, this statically linked code will be compiled for a macOS target. The full build command ends up looking like this:

```bash
PATH="$(pwd)/osxcross/target/bin:$PATH" \
CC=o64-clang \
CXX=o64-clang++ \
LIBZ_SYS_STATIC=1 \
cargo build --target x86_64-apple-darwin

## CI

I got the above process working in CircleCI, but it should be pretty easy to get any Debian-based CI service to work.

It should be possible to cache the `osxcross` folder so it doesn't have to be built for every job. The cache should be invalidated when your build script(s) change. For example, I use the cache checksum `project-v1-{{ checksum "osxcross_setup.sh" }}` to ensure the `osxcross` folder is regenerated correctly.

## Wrapping up

The final build command is pretty long, so I'd suggest putting it in a script. In my case, I have a build script containing the following snippet:

```bash
# ... snip ...

MACOS_TARGET="x86_64-apple-darwin"

echo "Building target for platform ${MACOS_TARGET}"
echo

# Add osxcross toolchain to path
export PATH="$(pwd)/osxcross/target/bin:$PATH"

# Make libz-sys (git2-rs -> libgit2-sys -> libz-sys) build as a statically linked lib
# This prevents the host zlib from being linked
export LIBZ_SYS_STATIC=1

# Use Clang for C/C++ builds
export CC=o64-clang
export CXX=o64-clang++

cargo build --release --target "${MACOS_TARGET}"

echo
echo Done
```

Now you can just run `./osxcross_setup.sh` and `./build_macos.sh` in your CI.

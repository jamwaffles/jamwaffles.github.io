+++
layout = "post"
title = "Setting the GDB safe-path cross platform"
date = "2018-02-19 20:52:00"
categories = "rust"
path = "rust/2018/02/19/cross-platform-gdb-safe-path.html"
+++

I've been developing an embedded Rust app (yay!) on Windows (blegh) recently. The Rust team have put
incredible effort into making Rust itself work great in Windows environments, but the tooling around
it can be difficult to get working correctly. My current problem was making GDB load a `.gdbinit`
file from the current projecting when doing `xargo run`. Here's how I fixed it in `.cargo/config`:

<!-- more -->

```toml
# .cargo/config
[target.thumbv7em-none-eabihf]
runner = [ "arm-none-eabi-gdb.exe", "-iex", "set auto-load safe-path ." ]
rustflags = [
  "-C", "link-arg=-Tlink.x",
  "-C", "linker=arm-none-eabi-ld",
  "-Z", "linker-flavor=ld",
  "-Z", "thinlto=no",
]
```

The key is being able to pass arguments to the `runner =` line. Nailing arguments onto the end of a
string _didn't_ work, which was frustrating. As far as I can tell, the array syntax for the
`runner = [ ... ]` line [isn't documented](https://doc.rust-lang.org/cargo/reference/manifest.html),
but it allows you to append command line arguments that aren't mishandled by GDB.

The main kicker for cross platform "compatibility" is setting `safe-path` to `.`. Setting this to
anything else will result in weird problems with a
`\backslashy\windows\path\ending\with\a\unix/path`. GDB moans that this isn't a real path, which is
true, but sucks for actually getting the thing working. This of course requires you to have a
`.gdbinit` file in your project root.

Easy peasy.

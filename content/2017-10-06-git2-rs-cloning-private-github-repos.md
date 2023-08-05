+++
layout = "post"
title = "Cloning private Github repos in Rust"
date = "2017-10-06 04:42:52"
categories = "rust"
path = "rust/2017/10/06/git2-rs-cloning-private-github-repos.html"

[extra]
image = "images/private-repo-clone-header.jpg"
+++

Cloning a private Github repo using SSH auth in Rust has proved to be a pretty gnarly problem (for
my anyway), so I thought I'd share this quick tutorial to help anyone else out that might be
struggling with the same issue. I'm using [git2-rs](https://github.com/alexcrichton/git2-rs) which
has good interface documentation, but _very few pieces of example code_, so I set out to fix that
somewhat with this post.

_Header photo by [Mark Wilson](https://unsplash.com/@mkwlsn)_

Boosh. Straight in:

```rust
let repo_url = "git@github.com:jamwaffles/git2-rs-github-clone-demo.git";
let repo_clone_path = "workspace/";

println!("Cloning {} into {}", repo_url, repo_clone_path);

let mut builder = RepoBuilder::new();
let mut callbacks = RemoteCallbacks::new();
let mut fetch_options = FetchOptions::new();

callbacks.credentials(|_, _, _| {
	let credentials =
		Cred::ssh_key(
			"git",
			Some(Path::new("/Users/jwaples/.ssh/id_rsa.pub")),
			Path::new("/Users/jwaples/.ssh/id_rsa"),
			None
		).expect("Could not create credentials object");


	Ok(credentials)
});

fetch_options.remote_callbacks(callbacks);

builder.fetch_options(fetch_options);

let repo = builder.clone(repo_url, Path::new(repo_clone_path)).expect("Could not clone repo");

println!("Clone complete");

// Do things with `repo` here
```

The key here is the `Cred::ssh_key()` call. This will load a SSH key from your filesystem (don't
forget to change the path) and attach it to the clone request as part of the `RemoteCallbacks`
object. The callbacks are in turn attached to the fetch options which are passed to the builder.
This rather convoluted chain is what got me so confused.

A full demo of this code [on Github](https://github.com/jamwaffles/git2-rs-github-clone-demo). The
code there will clone the repo itself to a folder called `workspace/`. Ironically the repo is
public, but you could fork it and make your fork private if you want to test it properly.

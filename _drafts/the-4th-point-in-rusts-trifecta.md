# New article tiem

- Hot take territory
- I don't keep up with C so please correct me on the bits I'm _objectively_ wrong on.

1. Rust isn't just about memory safety
2. Rust is a modern language with well designed and actually nice features, and strives to treat the
   programmer a) as fallible and b) respectfully.

- This second point is just as important as Rust's memory safety guarantees and I don't see enough
  people talking about it. By having a well-designed language with a great featureset inspired by
  learnings of the last 40 years and a very solid standard library, the programmer is free to think
  about their problem domain. This doesn't even have to be about Rust, but I like it so I'm gonna
  keep going. `rustc` prevents whole classes of memory errors, but logic errors will still remain.
  (find the sudo reimpl link or whatever).

- Also: package management opens this freedom to hink up further. Yes it can go a bit far
  (pathalogical point: `left-pad`) but we mustn't discount the importance of being able to reuse
  complex, important bits of code. Could you implement `serde` better than `serde`? I certainly
  couldn't! Caveat code review - maybe the dependency is total garbage - but once it reaches a
  certain scale, issues are found and fixed fast enough to not be a problem.

  Rust is also much more conducive to better tested libraries with the inclusion of `cargo test`.

- The C "feel" seems to be the classic "good programmers don't make mistakes" which has been proven
  time and time again to be false. Package management is either dynamic linking more C, or copying
  and pasting a few files into the project. How many bugfixes and security vulns are missed in
  important projects because nobody can (rightly) be arsed to merge in new changes from upstream.

  What's wrong with a `cargo update`? (caveat semver shut up lol)

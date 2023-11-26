# I'm sick of this shit

## inb4

So why don't you help then???!!//!?!/

Let me tell you why.

## Why doe

- C is indefensible now tbh.

<https://mastodon.social/@marcan@treehouse.systems/111476558162133076>
<https://mastodon.social/@marcan@treehouse.systems/111476658233740936>

- This is hot take territory.

- Me:
  - Not a C guy
  - Big Rust guy
    - Literally a walking stereotype
  - A consumer though, and it's what the rest of the world is built on
  - Two problems I see

1. A process problem.

   Meet potential new contributors where they are, which means to me the bare minimum at this point
   is the PR/MR workflow pioneered(?) by Github, Gitlab and others. MS hold a dangerous monopoly
   with Github, but there are alternatives. Whatever happens though, people don't like working with
   email patches and the standard flow these days involves "a tool with literally any ergonomics".
   If (let's face it, when) MS do something silly with Github, would most developers move back to
   email patches, or would they wait or implement its replacement? I'd wager the latter.

2. A pipeline problem.

   - Awful reputation of the "cranky old maintainer" drives people away.

   - Hm what else.

# Conclusion

For me personally, even with the language barrier being removed by Rust getting into the kernel, I
_still_ don't want to contribute. The reputation of kernel maintainers and the horrid email patch
workflow really put me off, and I don't think that's a rare opinion.

People don't like change, and neither do I. But. Those who don't want a better language than C (not
hard lol) in the kernel or other key parts of our computing infrastructure need to be sidestepped
for the benefit of everyone else. I'll parrot the 75% memory unsafety stat but how many other bugs
and mistakes do we need to find (find a link to that sudo thing where it was a logic bug) that are
due to the programmer spending all their time making sure their C code isn't total garbage instead
of making sure logic bugs aren't missed.

---

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
  time and time again to be false.

---
layout: post
title:  "Default arguments for cooler testing"
date:   2018-12-10 22:02:59
categories: typescript
---

In my [other post](TODO) about creating properly typechecked helper functions in Typescript, I missed something out from the examples that's present in the real code: default argument values! There's a function, `createEvent`, that returns an object with a dynamically generated UUID value in it. It also includes the current timestamp. This is great from the programmer's point of view as there's no need to wire up these values manually, but it sucks for unit tests because the values always change! The solution is to use [default parameters](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Functions/Default_parameters) to keep the ergonomics of a clean public API, but still support unit testing and special cases gracefully.

...

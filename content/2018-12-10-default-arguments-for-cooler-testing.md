+++
layout = "post"
title = "Default arguments for cooler testing"
date = "2018-12-10 22:02:59"
categories = "typescript"
path = "typescript/2018/12/10/default-arguments-for-cooler-testing.html"
+++

In my [other post](/typescript/2018/12/10/typechecking-helper-functions-in-typescript.html) about
creating properly typechecked helper functions in Typescript, I missed something out from the
examples that's present in the real code: default parameters! There's a function, `createEvent`,
that returns an object with a dynamically generated UUID value in it. It also includes the current
timestamp. This is great from the programmer's point of view as there's no need to wire up these
values manually, but it sucks for unit tests because the values always change! The solution is to
use
[default parameters](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Functions/Default_parameters)
to keep the ergonomics of a clean public API, but still support unit testing and special cases
gracefully.

<!-- more -->

Let's say we have the following function:

```typescript
import { v4 } from "uuid";

function createUser(name: string, email: string) {
  return {
    name,
    email,
    id: v4(),
    created_at: new Date().toISOString(),
  };
}
```

Pretty standard. Calling it is ergonomic:

```typescript
const user = createUser("Bobby Beans", "bobby@beans.com");
```

Great, my ground-breaking code goes live yet again. Or would if I had any unit tests! Fine. Bloody
review process.

## Unit testing

Unit testing this function should be pretty easy, right? I'll just write something like this (using
[Mocha](https://mochajs.org/) and [Chai](https://www.chaijs.com/)):

```typescript
describe("Create user", () => {
  it("Creates a user with ID and created at fields", () => {
    const expected = {
      name: "Bobby Beans",
      email: "bobby@beans.com",
      id: "33713144-3a28-4eac-ba0b-f626489d3993",
      created_at: "2018-01-02T03:04:05",
    };

    const created = createUser("Bobby Beans", "bobby@beans.com");

    expect(created).to.deep.equal(expected);
  });
});
```

A pretty contrived test, but good enough for the purposes of this post. Naturally, it fails.

Because UUIDs are _unique_, the value returned by `createUser` will be different every time, failing
our `expect()` equality check. Similarly, the timestamp returned is always the _current_ timestamp
so that's of no use to compare against either.

One solution to this problem is to only check that _some_ fields are returned, perhaps just `name`
and `email`, but this makes the unit test even less useful. Let's fix it properly by using **default
parameters** in our `createUser` function:

```typescript
import { v4 } from "uuid";

function createUser(
  name: string,
  email: string,
  _uuid = v4,
  _timestamp = () => new Date().toISOString()
) {
  return {
    name,
    email,
    id: _uuid(),
    created_at: _timestamp(),
  };
}
```

When the function is called normally as `createUser(name, email)`, `_uuid` and `_timestamp` are left
undefined, so use their default values as used. These are `v4` (from `uuid`) and a function that
returns the current timestamp. This doesn't change the normal interface to this function, however
now we can do much nicer stuff with our test:

```typescript
describe("Create user", () => {
  it("Creates a user with ID and created at fields", () => {
    const id = "33713144-3a28-4eac-ba0b-f626489d3993";
    const created_at = "2018-01-02T03:04:05";

    const expected = {
      name: "Bobby Beans",
      email: "bobby@beans.com",
      id,
      created_at,
    };

    const created = createUser(
      "Bobby Beans",
      "bobby@beans.com",
      () => id,
      () => created_at
    );

    expect(created).to.deep.equal(expected);
  });
});
```

The above changes hardcode the `id` and `created_at` values, allowing the test to do a deep
comparison on the whole returned object. This simplifies the test code, and improves coverage by
ensuring that every field returned is what we expect. Adding tests like this to a well-typed
Typescript codebase should lead to more robust code and fewer (hopefully no) errors in production.
Fingers crossed anyway.

_Now_ someone can approve my pull request. Hooray!

## Caveats

There's a somewhat major caveat to this method, and that's one of argument counts. What if I want to
add a third field `password` to my handy `createUser` function? That's easy enough, but now all the
existing code that uses `createUser` will error out. The `_uuid` argument is now being given a
string as input, which is of course not what we want it to do. Typescript will likely warn you in
this case, but maybe not. A solution I can think of is to pass all your arguments to the function as
an object with overridable functions defined after:

```typescript
import { v4 } from 'uuid';

function createUser(
  {
    name
    email
  }: {
    name: string,
    email: string
  },
  _uuid = v4,
  _timestamp = () => (new Date()).toISOString()
) {
  return {
    name,
    email,
    id: _uuid(),
    created_at: _timestamp()
  }
}
```

Now adding `password` is as easy as extending the first arguments object, and the "hidden" test
helper arguments `_uuid` and `_timestamp` are left neatly alone. Personally I think this is safer
and easier to reason about than positional string arguments, so take this as just another reason to
pass objects as function arguments.

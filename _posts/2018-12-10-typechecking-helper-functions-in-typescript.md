---
layout: post
title:  "Typechecking builder functions in Typescript"
date:   2018-12-10 21:30:36
categories: typescript
---

I've been working on toasting a lot of our tech debt [at Repositive](https://repositive.io) recently. We use an event driven microservice architecture which has various benefits, but some drawbacks concerning what data is sent where due in part to the liberal use of `any` in our Typescript codebases. During my refactoring rampage, I encountered some places where event objects were missing fields or otherwise weren't being generated properly. To this end, I set out to create a type-checked solution to this problem.

## What events look like to us

Firstly, an event as seen on a Repositive-branded wire looks like this (prettified):

```json
{
  "id": "18efffd3-8b0d-48b4-bf3b-1e2d17a91822",
  "data": {
    "type": "some_namespace.SomeEventType",
    "event_namespace": "some_namespace",
    "event_type": "SomeEventType",
    "some_field": true,
    "some_other_field": 100
  },
  "context": {
    "time": "2018-12-10T12:40:52Z"
  }
}
```

There's an ID field, a `data` payload and a `context` which holds (amongst other things IRL) and event creation time.

Inside `data`, there are three fields common to **all** events which denote which type of event it is:

* `event_namespace` - the _namespace_ (domain) from which this event was emitted (`accounts`, `products`, etc).
* `event_type` - the _type_ of this event, used to define what the payload should contain when consuming the event.
* `type` - legacy field that contains both the above pieces of information.

The rest of the fields inside `data` are freeform and can be anything, including nested objects, as long as the object keys `type`, `event_type` and `event_namespace` are not used.

## Typescript implementation

In Typescript, we define some types to use when handling events like the above. There's one that holds the three common event type fields `EventData`:

```typescript
interface EventData {
  type: string;
  event_namespace: string;
  event_type: string;
}
```

This forms the core of an event's payload. Next, there's a wrapping type called `Event` which is what the complete event object should look like:

```typescript
interface Event<D extends EventData> {
  id: string;
  data: D;
  context: { time: string };
}
```

And finally let's define the event given in the JSON example above:

```typescript
interface BlogEvent extends EventData {
  some_field: boolean;
  some_other_field: number;
}
```

Note that I'm using `string` a lot here. You should probably create type aliases like `type Uuid = string;`. It might not aid with format checking, but it will at least make clear to other programmers what the intent of that field is.

A better idea might be to use [io-ts](https://www.npmjs.com/package/io-ts) which would let you do awesome things like validate your payloads at runtime using the type system!

Anyway, now that those types are defined, events can be created that match the correct type signature:

```typescript
import { v4 } from 'uuid'; 

const emit_this: Event<BlogEvent> = {
  id: v4(),
  data: {
    type: "some_namespace.SomeEventType",
    event_namespace: "some_namespace",
    event_type: "SomeEventType",
    some_field: true,
    some_other_field: 100
  },
  context: {
    time: (new Date()).toISOString()
  }
};
```

This isn't too bad. Fields in `data` can't be missed and, critically, the event metadata (`type`, `event_namespace` and `event_type`) fields can't be typoed! Thanks Typescript!

## First attempt: lazy is dangerous

The above is alright I guess. At least the final event object is checked at compile time before serializing and sending/storing it. The problem is it's pretty verbose. Wouldn't it be nicer to have a function that, given a `data` payload _just makes us an event_? This is what I came up with to solve this problem the first time:

```typescript
import { v4 } from 'uuid';

export function createEvent(
  event_namespace: string,
  event_type: string,
  data: object
): Event<EventData> {
  return {
    id: v4(),
    data: {
      ...data,
      type: `${event_namespace}.${event_type}`,
      event_type,
      event_namespace,
    },
    context: { time: (new Date()).toISOString(),
  };
}

```

Neat. Now the programmer doesn't have to care about the particular shape of the object, just some specific fields. Usage looks like this:

```typescript
const emit_this = createEvent(
  'some_namespace', 
  'SomeEventType', 
  {
    some_field: true,
    some_other_field: 100
  }
);
```

This is obviously a lot cleaner. The programmer doesn't have to worry about the joined `type` field matching `event_namespace` and `event_type` anymore, and the UUID and timestamp are automatically inserted in the right places. The event's shape will also always be correct. But there's a problem...

Typescript doesn't type check this properly! At least it didn't at the time of writing. For example, adding an explicit type still doesn't catch the incorrect spelling of `some_namespace` in the example below:

```typescript
const emit_this: Event<BlogEvent> = createEvent(
  'potato', 
  'SomeEventType', 
  {
    some_field: true,
    some_other_field: 100
  }
);
```

This is more ergonomic, **but is a step backward in the reliability of the system**. Mistyped fields and events with missing keys were encountered _in production_ when using the `createEvent` defined above. This is pretty terrible. We should be pushing the programmer into the [pit of success](https://blog.codinghorror.com/falling-into-the-pit-of-success/)! 

## Into the pit - safely

What `createEvent` needs is some actual, smart type checking. Issues arose when we decided to make `createEvent` construct the returned object from a few different fields in its arguments. Typechecking multiple arguments that get munged into a single object is pretty difficult (at least in Typescript) but can be done as you'll see next:

```typescript
import { v4 } from 'uuid';

type Omit<T, K extends keyof T> = 
  Pick<T, Exclude<keyof T, K>>;

export function createEvent<D extends EventData>(
  event_namespace: D["event_namespace"],
  event_type: D["event_type"],
  data: Omit<D, "event_namespace" | "event_type" | "type">
): Event<D> {
  return {
    id: v4(),
    // Unsure why `as T` is required
    // but doesn't stop type checking working
    data: {
      ...data,
      type: `${event_namespace}.${event_type}`,
      event_type,
      event_namespace,
    } as D,
    context: { 
      time: (new Date()).toISOString() 
    },
  };
}
```

Usage looks like this:

```typescript
const emit_this = createEvent<BlogEvent>(
  'some_namespace', 
  'SomeEventType', 
  {
    some_field: true,
    some_other_field: 100
  }
);
```

Nearly identical to before, save for adding `<BlogEvent>` to the call signature. Our ergonomics are preserved, but now we get proper type checking! Now, any errors in any arguments will fail to compile. For example:

```typescript
// Fails: typo in `SomeEventType`
const emit_this = createEvent<BlogEvent>(
  'some_namespace', 
  'SomeEventTpr', 
  {
    some_field: true,
    some_other_field: 100
  }
);

// Fails: missing `some_other_field`
const emit_this = createEvent<BlogEvent>(
  'some_namespace', 
  'SomeEventTpr', 
  {
    some_field: true
  }
);
```

This code couples the power of generics with Typescripts weird (but quite pleasant) string-literals-are-types feature to enforce that, given an event payload, the string arguments given to `createEvent` _must_ match whatever is defined for `BlogEvent`. The magic comes from using the square brace `T["field_here"]` syntax to match the string literals, and some gymnastics to implement an `Omit` type. This type states, in plainer words, every field in `D` **except** `type`, `event_namespace` and `event_type` must be present in the passed object.

The code isn't as elegant as just providing a type, but now it means that **our function properly type checks the resulting object**. This means **no more typoed event name fields** and **no more missing/mis-spelled data fields**! This inelegance can also be tucked away in some library code, leaving just the nice interface. The only caveat with the above implementation that I've found so far is that the programmer must explicitly provide the type, or typechecking won't be "enabled". There's a compiler option - `--noImplicitAny` - which might help with this but I haven't tried it yet.

Typescript is _actually good_ if you don't slap `any`s everywhere and leverage its type system fully. People have a lot of strong opinions both ways about static type checking, but if it _stops broken stuff getting into production_, then it absolutely should be another tool in your toolbox.
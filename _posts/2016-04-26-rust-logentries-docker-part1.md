---
layout: post
title:  "Parsing Logentries output safely using Rust (part 1)"
date:   2016-04-26 10:14:03
categories: rust
<!-- image: huanyang-header-2.jpg -->
---

- Part 1 - Fetching and parsing Logentries data
- Part 2 - Saving data to the database
- Part 3 - Deployment using Docker

I'm fascinated by Rust for it's safety and speed, but also because it's simple to write low level code in what feels like a high level language. To that end, I've been working on a small Rust project at [TotallyMoney.com](http://www.totallymoney.com) (where I work) for the last week or so to see if it's viable for production use. It's a simple service that polls a [Logentries](https://logentries.com) endpoint for JSON, parses it and saves some values in a Postgres database. It's not a very complicated task, but I saw this as a good opportunity to try Rust in a production-ish role. For this series of articles I want to walk through writing the service and deploying it to production using Docker.

> Note: I could very well have written this in NodeJS like the rest of the app it fits into, but I wanted to learn Rust a little better. The memory safety of Rust is somewhat lost on this task but it's interesting how the language handles errors and optional types. Read on for more.

I'm not very good at Rust (yet), so I may be writing terrible Rust code. Let me know [@jam_waffles](https://twitter.com/jam_waffles) if I've made any glaring mistakes!

## Dependencies

I'm assuming you've got Rust, Cargo and a project folder (`cargo init --bin` will do) set up for this project. I'm going to use the following crates:

- `hyper`; HTTP library for making GET requests to Logentries
- `chrono`; Date and time, we'll be using it to store the log entry timestamp
- `time`; More date and time, used in this case for sleeping for a certain number of milliseconds
- `rustc_serialize`; JSON parsing
- `postgres`; Postgres database connector

My `Cargo.toml` looks like this:

```toml
[package]
name = "logentries_poller"
version = "0.1.0"
authors = ["James Waples <jamwaffles@gmail.com>"]

[dependencies]
hyper = "^0.8.1"
rustc-serialize = "^0.3.19"
chrono = "^0.2"
time = "^0.1"
postgres = { version = "^0.11.0", features = [ "chrono" ] }
```

Crates will be installed/updated when you run `cargo build` or `cargo run` for the first time. Pretty neat!

## Fetching Logentries data

First, we need to fetch some stuff from Logentries to parse. Logentries provides a simple GET endpoint which returns lines of a particular log. Their [documentation](https://logentries.com/doc/api-download/) specifies the URL as something like this:

    https://pull.logentries.com/YOUR_LOGENTRIES_ACCOUNT_KEY/hosts/YOUR_LOG_SET_NAME/YOUR_LOG_NAME/?start-10000

For our purposes we only want the last 10 seconds of data (`?start-10000`). The code will poll Logentries every 5 seconds, so requesting the last 10 seconds worth of data will provide a crude mechanism to deal with failures.

Let's write some Rust. Put this in `src/main.rs`:

```rust
extern crate hyper;

use hyper::{ Client };

fn main() {
    // Create new Hyper HTTP client
    let client = Client::new();

    // We're going to request JSON from Logentries here:
    let url = "https://pull.logentries.com/cafebabe-cafe-babe-cafe-babecafebabe/hosts/My.Log/logset/?start=-10000&filter=src:HddRestGateway";

    // Make the request. This will quit if there is some kind of failure
    let response = match client.get(url).send() {
        Ok(response) => response,
        Err(e) => panic!("Could not fetch Logentries data: {}", e)
    };

    // Turn response into stream so we can parse it line by line
    let reader = BufReader::new(response);

    // Go through each line in the result and just print it for now
    for reader_line in reader.lines() {
        // Get string result from `Result<>` container
        // (assumes line always has a value)
        let line = reader_line.unwrap();

        println!("{}", line);
    }
}
```

Try running the code with `cargo run`. With any luck, you should have the last 10 seconds worth of Logentries submissions printed in your console. In my case, I see lines like this:

```
2016-04-26 15:18:23.1185 | lvl:INFO | ------------ src:HddRestGateway | { "message": { "status": "Success", "elapsed": 1089 } }
2016-04-26 15:17:53.9890 | lvl:INFO | ------------ src:HddRestGateway | { "message": { "status": "NotFound", "elapsed": 2443 } }
2016-04-26 15:17:56.8014 | lvl:INFO | ------------ src:HddRestGateway | { "message": { "status": "Success", "elapsed": 1375 } }
2016-04-26 15:17:38.9468 | lvl:INFO | ------------ src:HddRestGateway | { "message": { "status": "Timeout", "elapsed": 5897 } }
2016-04-26 15:18:38.6810 | lvl:INFO | ------------ src:HddRestGateway | { "message": { "status": "NotFound", "elapsed": 1100 } }
2016-04-26 15:17:52.6964 | lvl:INFO | ------------ src:HddRestGateway | { "message": { "status": "Success", "elapsed": 2246 } }
2016-04-26 15:18:14.7228 | lvl:INFO | ------------ src:HddRestGateway | { "message": { "status": "Success", "elapsed": 2987 } }
```

The rest of the code in this article assumes the data is in this format. It should be reasonably simple to change the code to suit your needs. Once we have the log output, it's just a matter of parsing strings however you see fit.

## Filtering and parsing each line

Each line contains some fields separated by a pipe character, the first of which is a timestamp and the latter of which is some JSON data. We're not interested in any of the other bits. We're also only interested in log lines with `{ "status": "Success" }`, so we'll do some simple filtering after parsing the line.

Our program now becomes the following:

```rust
extern crate hyper;
extern crate chrono;
extern crate time;
extern crate rustc_serialize;

use std::thread;
use std::env;
use std::time::Duration;
use chrono::{ DateTime };
use std::error::Error;
use rustc_serialize::json::Json;
use std::io::{ BufReader, BufRead };
use hyper::{ Client };

fn main() {
    // Create new Hyper HTTP client
    let client = Client::new();

    // We're going to request JSON from Logentries here:
    let url = "https://pull.logentries.com/cafebabe-cafe-babe-cafe-babecafebabe/hosts/My.Log/logset/?start=-10000&filter=src:HddRestGateway";

    // Make the request. This will quit if there is some kind of failure
    let response = match client.get(url).send() {
        Ok(response) => response,
        Err(e) => panic!("Could not fetch Logentries data: {}", e)
    };

    // Turn response into stream so we can parse it line by line
    let reader = BufReader::new(response);

    // Go through each line in the result and just print it for now
    for reader_line in reader.lines() {
        // Get string result from `Result<>` container
        // (assumes line always has a value)
        let line = reader_line.unwrap();

        // Split the string into it's constituent parts
        let parts: Vec<&str> = line.split(" | ").collect();

        // First item is timestamp. Turn it into a Chrono::DateTime
        let created = match parts.first() {
            Some(created) => {
                let mut padded = String::from(*created);

                // Logentries prints the date in a stupid format (or at least one Chrono
                // can't parse), so let's add some zeroes and a fake timezone
                padded.push_str("0000+0000");

                match DateTime::parse_from_str(padded.as_str(), "%Y-%m-%d %H:%M:%S.%f%z") {
                    Ok(parsed) => parsed,

                    // If there's a parse error, don't do anything else with this line
                    Err(_) => continue,
                }
            },

            // No timestamp, must be a bad record, skip remaining processing for this line
            None => continue
        };

        // JSON is last part of log entry (`parts.last()`). Parse it into an object.
        let payload = match parts.last() {
            Some(payload) => match Json::from_str(&payload) {
                Ok(parsed) => parsed,

                // Skip this record if there was an error
                Err(e) => {
                    println!("JSON parse error: {}", Error::description(&e));

                    continue;
                },
            },

            // If for whatever reason we can't find the last part of the
            // split line (it might be blank), skip it completely
            None => {
                println!("Malformed log message");

                continue;
            }
        };

        // Look for response status in `message.status` key
        let status = match payload.find_path(&[ "message", "status" ]) {
            Some(status) => status.as_string().unwrap(),
            None => "InvalidMessage"
        };

        // Look for elapsed time in `message.elapsed` key
        let time = match payload.find_path(&[ "message", "elapsed" ]) {
            Some(time) => time.as_u64().unwrap() as i32,
            None => 0
        };

        // We only care about successful responses
        if status == "Success" {
            println!("------ Status: {}, elapsed time: {}ms at {}", status, time, created);
        } else {
            println!("Ignoring status {}", status)
        }
    }
}
```

This is where Rust's safety starts to shine and look incredibly verbose at the same time. The code above deals with a lot of `Result<>` and `Option<>` types, which return `Ok()` or `Err()` and `Some()` or `None()` respectively. Rust checks at compile time to make sure we're matching every possible return type, meaning we _have to_ handle the `Err()` or `None()` cases in the code above. Sometimes that means setting a sensible default (`0` for elapsed time, for example) or `continue`ing if the code can't do anything proper with the current line. This code is going to run as a persistent service so it makes sense to `continue` or otherwise bail on processing the current line instead of, say, `panic!`ing and quitting the program.

Running the program again with `cargo run`, you should see something like the following:

```
------ Status: Success, elapsed time: 1089ms at 2016-04-26 15:18:23.1185
Ignoring status NotFound
------ Status: Success, elapsed time: 1375ms at 2016-04-26 15:17:56.8014
Ignoring status Timeout
Ignoring status NotFound
------ Status: Success, elapsed time: 2246ms at 2016-04-26 15:17:52.6964
------ Status: Success, elapsed time: 2987ms at 2016-04-26 15:18:14.7228
```

## Further explanation

Code comments aren't very good for learning a language by example, so I'll explain some of the code above.

First, we need to fetch some data from Logentries, in this case using the Hyper HTTP library.

```rust
// Create new Hyper HTTP client
let client = Client::new();

// Make the request. This will quit if there is some kind of failure
let response = match client.get(url).send() {
    Ok(response) => response,
    Err(e) => panic!("Could not fetch Logentries data: {}", e)
};
```

Hyper's `client.get(url).send()` reutrns a `Result<>` which we're `match`ing on. If the request fails, it returns `Result<Err>` which we're handling by `panic!()`ing as there's no clean way to recover from a failed request (ok so we could just try again using an exponential falloff but let's keep things simple). If we get a `Result<Ok>`, we return the HTTP response from the `match` and store it in `response` for use later.

---

Next, we turn the HTTP response into a `BufReader` stream. This step isn't necessary but it might make parsing a little faster if the HTTP response can be streamed, although I haven't looked into it.

```rust
// Turn response into stream so we can parse it line by line
let reader = BufReader::new(response);
```

---

Let's get a timestamp. Logentries (at least in my case) outputs timestamps formatted in a non-standard way, specifically in the milliseconds part. The last part of the stamp is 4 digits long (tens of microseconds or something?) however Rust's `%f` [date format placeholder](https://lifthrasiir.github.io/rust-chrono/chrono/format/strftime/index.html) expects 8 digits, so I'm going to add those on as a string literal along with a fake timezone.

If someone can point out a better way of parsing a timestamp like `2016-04-26 15:18:23.1185` using `DateTime` or the `chrono` crate, please let me know.

```rust
// First item is timestamp. Turn it into a Chrono::DateTime
let created = match parts.first() {
    Some(created) => {
        let mut padded = String::from(*created);

        // Logentries prints the date in a stupid format (or at least one Chrono
        // can't parse), so let's add some zeroes and a fake timezone
        padded.push_str("0000+0000");

        match DateTime::parse_from_str(padded.as_str(), "%Y-%m-%d %H:%M:%S.%f%z") {
            Ok(parsed) => parsed,

            // If there's a parse error, don't do anything else with this line
            Err(_) => continue,
        }
    },

    // No timestamp, must be a bad record, skip remaining processing for this line
    None => continue
};
```

Notice the nested `match` statements in the code above. If everything goes well and we go down the `Some(created)` and `Ok(parsed)` branches, that parsed date will be assigned to `created` at the top level.

Finally, if there's an error, the code will call `continue` which skips the remaining iteration of the loop and moves straight on to the next.

The rest of the code is similar to the above examples in terms of how `match` is utilised.

## Conclusions and next steps

Rust's strict type system caused me quite a bit of friction coming from a loosely-typed Node ecosystem, but once you get the hang of it the compile time checking and comprehensive, required error handling makes for very safe code. You'll notice above that only one variable is `mut`able. I'm not doing anything fancy with pointers so it doesn't add much for memory safety, but it allows the compiler to make sure I'm not doing anything stupid reassigning variables and such.

In part 2 I'll go through taking our parsed data and writing it into a Postgres database periodically.
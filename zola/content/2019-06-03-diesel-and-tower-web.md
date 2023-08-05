+++
layout = "post"
title = "Persistent state with Tower Web"
date = "2019-06-03 13:34:00"
categories = "rust"
path = "rust/2019/06/03/diesel-and-tower-web.html"
+++

We're building a new product at [work](https://repositive.io/), for which we've decided to use Rust
and [tower-web](https://crates.io/crates/tower-web) for the backend. There don't seem to be any
Tower examples using state in request handlers, so this is a quick copypasta showing how to add
Diesel so request handlers can do database operations.

First, establish a connection. I'm using an `r2d2::Pool` wrapping a Diesel Postgres connection:

```rust
use diesel::pg::PgConnection;
use diesel::r2d2::{ConnectionManager, Pool};
use std::env;
use std::error;

pub fn establish_connection() -> Result<Pool<ConnectionManager<PgConnection>>, Box<error::Error>> {
    let database_url = env::var("DATABASE_URL")?;
    let cm = ConnectionManager::new(database_url);
    let pool = Pool::new(cm)?;
    Ok(pool)
}
```

Next, implement the handler. The example below returns every item for the `categories` table. I'm
assuming you've got your Diesel schemas and stuff set up here. If not, following
[the getting started guide](http://diesel.rs/guides/getting-started/).

```rust
use crate::models::Category;
use tower_web::impl_web;
use std::io;

#[derive(Clone)]
pub struct Categories {
    conn: Pool<ConnectionManager<PgConnection>>,
}

#[derive(Response)]
struct CategoriesResponse {
    categories: Vec<Category>,
}

impl_web! {
    impl Categories {
        pub fn new(conn: Pool<ConnectionManager<PgConnection>>) -> Self {
            Self { conn }
        }

        #[get("/api/categories")]
        #[content_type("json")]
        fn categories(&self) -> Result<CategoriesResponse, io::Error> {
            let cats = categories
                .load::<Category>(
                    &self
                        .conn
                        .get()
                        .map_err(|e| io::Error::new(io::ErrorKind::Other, e))?,
                )
                .map_err(|e| io::Error::new(io::ErrorKind::Other, e))?;

            Ok(CategoriesResponse { categories: cats })
        }
    }
}

```

Most tower-web examples use a unit struct with no fields like `struct Categories;`. In this case,
I'm adding a `conn` field to store a connection. I also add a `new()` method to create a new
`Categories` handler without making `conn` public.

You can use this in your Tower setup code like this:

```rust
mod handlers;
mod models;

use diesel::pg::PgConnection;
use diesel::r2d2::{ConnectionManager, Pool};
use handlers::categories;
use std::error;
use tower_web::ServiceBuilder;

pub fn main() -> Result<(), Box<error::Error>> {
    let pool = establish_connection()?;

    let addr = "127.0.0.1:9000".parse().expect("Invalid address");

    println!("Listening on http://{}", addr);

    ServiceBuilder::new()
        .resource(categories::Categories::new(pool.clone()))
        .run(&addr)
        .unwrap();

    Ok(())
}

```

Note the categories handler line and its use of `Categories::new()`.

Done!

This might be blatantly obvious to most Tower Web users, but this short tutorial is here in case
it's not. I'm not sure how non-pooled connections will work, as the `impl_web!` macro hides a lot of
the lifetimes and trait bounds, so YMMV.

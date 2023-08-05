---
layout: post
title: "Clockwise Triangles Performance: Addendum"
date: 2020-07-26 09:30:00
categories: rust
---

A quick update on my [previous article](/rust/2020/07/25/optimising-with-cmp-and-ordering.html).

[Nicholas Wilcox (@redbluemonkey) on Twitter](https://twitter.com/redbluemonkey/status/1287186446986514432) made a very good point:

<blockquote class="twitter-tweet" data-conversation="none" data-dnt="true"><p lang="en" dir="ltr">Do you need a full sort, or do you just need to reverse the order if it doesn&#39;t already have the correct winding? You can check the winding of any polygon with only the first 3 points using a cross product.</p>&mdash; Nicholas Wilcox (@redbluemonkey) <a href="https://twitter.com/redbluemonkey/status/1287186446986514432?ref_src=twsrc%5Etfw">July 26, 2020</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

I might need a full sort for polygons, but with a focus on triangles right now this sounded like a good idea to investigate. Am I being nerd-sniped? Hmm.

Here's the new code as a method on the `Triangle` struct we defined [previously](/rust/2020/07/25/optimising-with-cmp-and-ordering.html):

```rust
impl Triangle {
    // ...

    /// Create a new triangle with points sorted in a clockwise direction.
    pub fn sorted_clockwise(&self) -> Self {
        let Self { p1, p2, p3 } = self;

        let determinant = -p2.y * p3.x + p1.y * (p3.x - p2.x) + p1.x * (p2.y - p3.y) + p2.x * p3.y;

        match determinant.cmp(&0) {
            // Triangle is wound CCW. Swap two points to make it CW.
            Ordering::Less => Self::new(p2, p1, p3),
            // Triangle is already CW, do nothing.
            Ordering::Greater => *self,
            // Triangle is colinear. Sort points so they lie sequentially along the line.
            Ordering::Equal => {
                let (p1, p2, p3) = sort_yx(p1, p2, p3);

                Self::new(p1, p2, p3)
            }
        }
    }
}
```

The `determinant` calculation is an optimised version of the formula presented [here](https://en.wikipedia.org/wiki/Curve_orientation#Practical_considerations). It's actually the doubled area of the triangle where counter-clockwise triangles produce negative values. This behaviour is useful because we can just swap two of the triangle's points to make it clockwise if the result is negative.

If the determinant is zero, the triangle is colinear. In this instance, we'll sort the triangle's points in ascending Y then X direction. This ensures the points always lie on the single line in order.

The `sort_yx` function above is implemented like this:

```rust
fn sort_two_yx(p1: Point, p2: Point) -> (Point, Point) {
    // If p1.y is less than p2.y, return it first. Otherwise, if they have the same Y coordinate,
    // the first point becomes the one with the lesser X coordinate.
    if p1.y < p2.y || (p1.y == p2.y && p1.x < p2.x) {
        (p1, p2)
    } else {
        (p2, p1)
    }
}

/// Sort 3 points in order of increasing Y value. If two points have the same Y value, the one with
/// the lesser X value is put before.
fn sort_yx(p1: Point, p2: Point, p3: Point) -> (Point, Point, Point) {
    let (y1, y2) = sort_two_yx(p1, p2);
    let (y1, y3) = sort_two_yx(p3, y1);
    let (y2, y3) = sort_two_yx(y3, y2);

    (y1, y2, y3)
}
```

## Benchmarks

Here's the table from [the original investigation](/rust/2020/07/25/optimising-with-cmp-and-ordering.html) with this new method added in:

| Suite                                       | Result (avg) |
| ------------------------------------------- | ------------ |
| Straight C port (baseline)                  | 9.4473 ns    |
| Use `Ordering` instead of `bool`            | 10.712 ns    |
| Hoist some repeated comparisons             | 10.160 ns    |
| Convert everything to a big, single `match` | 12.024 ns    |
| **Simplified algorithm**                    | **2.9 ns**   |

A huge improvement! Thanks internet!

And we didn't even need to look at the generated assembly.

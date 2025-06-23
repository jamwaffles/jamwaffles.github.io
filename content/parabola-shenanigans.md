+++
layout = "post"
title = "Parabola Shenanigans"
slug = "parabola-shenanigans"
date = "2025-04-15"
+++

TODO: Should probably merge this with parabola-arc-line.md and make it more medial-axis centric

# Intersection of line and parabola

TODO

<https://math.stackexchange.com/a/1359003/4506>

# Tangent of a parabola at a given point

TODO

Assumes point lies on the parabola

Uses normal of line between focus and closest point on directrix from the test point.

# Parabola circle intersection

I think this will only be for cases where the parabola intersects once

TODO

## Arcs

We can extend this to arcs by using my `point_lies_on_arc` function

## The medial axis of an inwards pointing arc and a line

This is an answer to [this StackExchange question](https://math.stackexchange.com/q/5049503/4506)
which I'm posting here instead as the answer I posted there was downvoted and deleted with no reason
given.

- Focus is arc centre
- Directrix is line offset by arc radius

## Medial axis between

| A                  | B                  | Medial shape                                                                                              |
| ------------------ | ------------------ | --------------------------------------------------------------------------------------------------------- |
| Line               | Line               | Line                                                                                                      |
| Line               | Point              | Parabola with focus at point and directrix on line                                                        |
| Line               | Convex arc         | Parabola with focus at projection of arc centre on line and directrix parallel to line and tangent to arc |
| Non-concentric arc | Non-concentric arc | Hyperbola                                                                                                 |
| Concentric-ish arc | Concentric-ish arc | Ellipse with foci on arc centres                                                                          |

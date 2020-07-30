---
layout: post
title: "Rasterising thick polylines with integer-only maths"
date: 2020-07-30
categories: rust
---

- Examples are using e-g-web-canvas-wahtever by <person name here>
- Roughly using this method <https://www.codeproject.com/Articles/226569/Drawing-polylines-by-tessellation>
- Start by getting (l, r) extents for thick line
  - Walk outwards on alternating edges using bresenham
  - Clever cos we just check a threshold (but squared so we don't have to use sqrt to get the true length)
    - Note that threshold is weird as it takes into account proper line thickness - see kt8216.unixcab.org/murphy/index.html
  - A bit shit because it's iterative, but most line widths will be very small so this isn't a huge issue
  - Alternating sides so we can get a balanced line if aligned to center
  - Supports stroke alignment by adding together both center side offsets
- Get extents for both the line terminating at joint and line starting at joint
- Intersect both left and both right edges
  - We won't use _segment_ intersection, because intersection for outside corner is in space somewhere
  - We can detect which direction the joint turns by looking at `denom`
    - lt 0 -> left-turning joint
    - 0 -> lines are colinear
    - gt 0 -> right-turning joint
- Need to check for "degnerate" line
  - Thick segments self-intersect
  - TODO: finish this section lol
- Actually drawing the thick lines and joints
  - We'll triangulate everything using mathematically defined triangles. (picture of adjacent edges compared to bresenham). This ensures no overdraw. The hard bit (defining edge corners and joints) is done.
  - Overdraw will occur with "degenerate" line segments but oh well
- Later on: check for bevel/miter. We'll use a heuristic of 2x stroke width but it doesn't really matter what you pick.
  - Uses some squaring here to again remove the sqrt required when getting length of line.
- Triangle extras
  - Sort clockwise, we can simplify stuff by assuming outside edge is always left
  - Need to check if triangle is filled. At this point we need to switch how we draw it to a triangle fan from the centroid.

---
layout: post
title: "Rasterising thick polylines with integer-only maths"
date: 2020-07-30
categories: rust
---

- Requirements
  - Integer maths
  - No overdraw
  - No sqrt() because floats and slow
- Examples are using e-g-web-canvas-wahtever by <person name here>
- Roughly using this method <https://www.codeproject.com/Articles/226569/Drawing-polylines-by-tessellation> to get joint points
- Start by getting (l, r) extents for thick line
  - Walk outwards on alternating edges using bresenham
  - Clever cos we just check a threshold (but squared so we don't have to use sqrt to get the true length)
    - Note that threshold is weird as it takes into account proper line thickness - see kt8216.unixcab.org/murphy/index.html
  - A bit shit because it's iterative, but most line widths will be very small so this isn't a huge issue
  - Alternating sides so we can get a balanced line if aligned to center
    - If we want to support stroke alignment, the rest of the algorithm stays the same, except that we collect all to one side or the other.
- Get extents for both the line terminating at joint and line starting at joint
  - Special cases for start/end joints
- Intersect both left and both right edges
  - We won't use _segment_ intersection, because intersection for outside corner is in space somewhere
  - We can detect which direction the joint turns by looking at `denom`
    - lt 0 -> left-turning joint
    - 0 -> lines are colinear
    - gt 0 -> right-turning joint
  - Special cases
    - Need to check for bevel or miter style joint
      - We'll use a heuristic of 2x stroke width to cut into a bevel, but it doesn't really matter what you pick.
      - Uses some squaring here to again remove the sqrt required when getting length of line.
    - Need to check for "degnerate" line
      - Thick segments self-intersect
      - TODO: What do we do in this case again?
      - TODO: finish this section lol
- Actually drawing the thick lines and joints
  - Overdraw will occur with "degenerate" line segments but oh well - not a problem unless we're using transparency
  - First attempt triangulated the line as might be done in a "normal" graphics context. This lead to a bunch of overdraw due to how the triangles are rasterised by e-g. Spent a long time trying to fix that and gave up.
  - Second attempt uses a scanline iterator
    - Explain how this works.
      - Each segment turned into a 5 or 6 sided shape. Should always be convex I think?, so it only ever has two intersection points.
      - Run a scanline through current Y. Each thick segment that intersects this line does so only once, so we can map all matching segments into their intersection line.
      - Loop over these lines and return them in an iterator
        - But wait! We didn't want overdraw, so we gotta un-overlap lines.
          - Diagram with partial left, partial right, complete and no overlap fixed. Show vertical progression of each type with 4 steps: original, split apart vertically for clearer view, split apart and start/end positions moved accordingly and finally shoved back together again.
      - Weird "Bresenham scanline intersection" -> more results of integer only maths and desire for pixel accuracy. Creates either a point or a short line (show two zoomed screenshots to demo)

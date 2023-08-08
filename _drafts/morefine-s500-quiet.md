Morefine S500+ quieter fan

- Originally planned to put a Noctua 92mm slim fan in but it won't fit on the inside
  - Would like to keep case clean
- No component fix, requires soldering
- But reversible
- Irritating whine at idle is gone
- The CPU just doesn't get that warm - particularly not for the noise this stupid fan makes
- Running Linux Mint 21
- AMD Ryzen 5 5625U
- Kernel 5.15 PREEMPT_RT 
- Fan uses PWM pin, not DC control
- 12v 0.35A. Could use a dropper resistor but I didn't have one
- Pop power pin out of fan connector
- Steal USB5V and pass through board to fan connector
  - I used underside of the board because I like pointless complexity but there's an equivalent circuit on the front USB3 connectors
  - TODO: Show pic
- 5V is extremely quiet even at full pelt
- No way of measuring RPM unfortunately
- 5V is a bit slow though - I see ~80C with a looped Rust project compile with no case (which is my target workload for this thing)
  - A proper benchmark might cause higher temps and more issues
  - That said, my workload is quite bursty so I might not see those temps during normal usage. YMMV!
- Ideal solution is an adjustable LDO from 12V down to 5V to tune noise/temp curve but I was going for quick and dirty.
- 84C on looped compile in case standing on end
  - TODO: Picture
  - Face down doesn't seem to make much difference

Maybe a better balance

- Noctua Low Noise Adapter NA-RC7
- Still somewhat noisy but way better than before
- Requires buying stuff unlike above solution
- But no mods!
- Same compile loop the CPU is now at ~73C sustained (caseless)
- Idle still has that irritating whine

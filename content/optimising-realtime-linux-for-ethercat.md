+++
title = "Optimising Realtime Linux for EtherCAT"
date = "2023-10-20 13:34:03"
draft = true
+++

Originally spurred by 250us (yes, MICRO second) responses from sending a PDU.

Explain EtherCAT packets briefly - slightly unique in that they're

- Raw
- Ping/pongs

EtherCAT needs:

1. Enough time per cycle to respond to inputs, compute, and make outputs ready for next cycle.
2. Consistent cycle-to-cycle rate. Mostly handled by the nice async timer impls `tokio` or `smol`
   provide, but we need to mitigate the rest of the OS

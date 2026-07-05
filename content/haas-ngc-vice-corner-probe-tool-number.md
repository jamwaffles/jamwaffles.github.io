+++
title = "Fixing 941 POCKET-TOOL TABLE ERROR for VPS 'vice corner' probing on Haas NGC"
date = "2026-07-04 17:08:25"
+++

My Haas tech had originally set up my WIPS spindle probe as `T31`, however I wanted it in `T1` to
match my other machines. The process went as follows:

- Move probe in the tool table as you would a normal tool, i.e. zero out the old `T31`, fill in tool
  details in `T1`.
- Do the whole spindle and tool probe setup dance using the VPS/macros as described in
  [this YouTube video by Haas](https://www.youtube.com/watch?v=VUY2c39jykM&list=PLezLpo9qXy2dV_qRH7eH2DvvpdjY2K06f&index=3).

Now the probe should be fine for most VPS probing macros, however for me the "vice corner" macro
errored out with `941 POCKET-TOOL TABLE ERROR`. It turns out the probe tool number macro variable
hadn't been updated. This macro seems to use different subroutines to the other ones, which might be
why only it is broken.

To update the macro:

- Hit the <kbd>Current Commands</kbd> button, tab over to `Macro vars`, then down to the
  `(Global) 10400-105999` column.
- Page down to var `10560` (this is equivalent to legacy macro number `560`).
- Set the value to e.g. `1.0` for `T1`. This was originally `31.00000` for my `T31`.

I figured this out from
[the troubleshooting page](https://www.haascnc.com/service/troubleshooting-and-how-to/troubleshooting/Wireless-Intuitive-Probe-System-WIPS-Troubleshooting-Guide.html#gsc.tab=0)
which mentions `560: Tool number for the OMP40-2 probe` under `OMP40-2 - Macro Variables`.

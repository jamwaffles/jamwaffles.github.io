+++
title = "Fixing 941 POCKET-TOOL TABLE ERROR and 1106 OMP40 NEEDS CALIBRATION on Haas NGC"
date = "2026-07-04 17:08:25"
+++

My Haas tech had originally set up my WIPS spindle probe as `T31`, however I wanted it in `T1` to
match my other machines. The process went as follows:

- Move probe in the tool table as you would a normal tool, i.e. zero out the old `T31`, fill in tool
  details in `T1`.
- Edit the calibration routines to calibrate vector probing, if you have it
- Do the whole spindle and tool probe setup dance using the VPS/macros as described in
  [this YouTube video by Haas](https://www.youtube.com/watch?v=VUY2c39jykM&list=PLezLpo9qXy2dV_qRH7eH2DvvpdjY2K06f&index=3).

## 941 POCKET-TOOL TABLE ERROR

The probe should be fine for most VPS probing macros, however for me the "vice corner" macro errored
out with `941 POCKET-TOOL TABLE ERROR`. It turns out the probe tool number macro variable hadn't
been updated. The vice corner macro seems to use different subroutines to the other ones, which
might be why only it is broken.

To update the macro value:

- Hit the <kbd>CURRENT COMMANDS</kbd> button, tab over to `Macro vars`, then down to the
  `(Global) 10400-105999` column.
- Page down to var `10560` (this is equivalent to legacy macro number `560`).
- Set the value to e.g. `1.0` for `T1`. This was originally `31.00000` for my `T31`.

I figured this out from
[the troubleshooting page](https://www.haascnc.com/service/troubleshooting-and-how-to/troubleshooting/Wireless-Intuitive-Probe-System-WIPS-Troubleshooting-Guide.html#gsc.tab=0)
which mentions `560: Tool number for the OMP40-2 probe` under `OMP40-2 - Macro Variables`.

## 1106 OMP40 NEEDS CALIBRATION

I recalibrated the probe quite a few times, but got this error every time when using the 3 point
probing routine `P9823`. A 3 point probe routine uses something called "Vector Probing" which needs
a different calibration macro to be called (`P9804` instead of `P9803`) when calibrating the probe
through the Haas VPS. This call is somewhat buried in a bunch of subroutine calls but here are the
steps:

- Disable **Setting 23** to allow edits of probe routines
- Edit file `Memory/O0P9023_RENISHAW_STORM.nc`
- Search for `P9803` (type `P9803`, then press <kbd>↓</kbd>)
- Modify to `P9804` by typing `P9804` then hitting the <kbd>ALTER</kbd> key, then save the file
- Go to `VPS` -> `PROBING` -> `CALIBRATION` -> `Spindle Probe Diameter Calibration`
- Do calibration with a gauge ring as normal, but now the vector probing routines will be calibrated
  as well. This probes a few more points in the ring gauge.
- Select a program not in the `09000` folder, then change **Setting 23** back to `Off` to disable
  editing of probing routines. It won't change the setting while you have a macro file open in the
  editor.
- According to
  [the manual](https://www.haascnc.com/content/dam/haascnc/en/service/reference/probe/renishaw-inspection-plus-programming-manual---2008.pdf)
  you don't need to run `P9803` as well; just `P9804` is required.
- Done!

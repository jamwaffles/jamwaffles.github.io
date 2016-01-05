---
layout: post
title:  "Spindle speed control using LinuxCNC 2.7 with a Huanyang inverter"
date:   2014-12-04 20:14:47
categories: cnc
image: huanyang-header.jpg
---

Huanyang branded VFD drives are ubiquitous on eBay and other sites like AliExpress. I bought one some time ago and have been controlling the speed manually with the difficult to use control panel on the front. It is, however, possible to control the VFD from within LinuxCNC, which I'll go through setting up in this post.

The first thing I tried was [PDM](https://en.wikipedia.org/wiki/Pulse-density_modulation) using signals from the parallel port. This doesn't set the speed accurately _at all_ and the PDM/speed conversion curve is hilariously inaccurate. If you want to try this method for whatever reason, there's a [guide in the LinuxCNC documentation](http://wiki.linuxcnc.org/cgi-bin/wiki.pl?VFD_Digital/Analog_Interface).

Most Huanyang VFDs have an RS-485 two-wire interface, so let's use this to communicate with the drive from LinuxCNC. They supposedly support Modbus, but aren't compliant, so a custom HAL component for LinuxCNC is required. Since LinuxCNC 2.7, this component is now bundled with the default image so all we need to do is set it up properly.

# Hardware required

- A computer running LinuxCNC 2.7+ with at least one USB port
- A USB ↔ RS-485 converter. I got one on eBay for less than a fiver.
- Huanyang VFD
- Two core signal (light gauge) wire to hook up between the VFD and converter

---

My Notes

- You can sort of control the speed using [crappy PDM like this](http://wiki.linuxcnc.org/cgi-bin/wiki.pl?VFD_Digital/Analog_Interface)
- VFD has an RS-485 bus
- Get a USB ↔ RS-485 converter for dirt cheap on eBay. Mine looked like this:
	- Pic
- VFD is not modbus compliant but...
- Someone wrote a HAL component [in this forum thread](http://www.cnczone.com/forums/phase-converters/91847-software.html)
- Now this HAL component is **bundled with LinuxCNC**, so no more fucking about with compiling modules. Docs [here](http://linuxcnc.org/docs/html/man/man1/hy_vfd.1.html)
	- The signal names it produces are modified from the original in that thread, however
TODO: Upload latest config file to OneDrive

---

# VFD configuration

We first need to change some settings in the VFD. Most of these settings are identical to those defined in [the hy_vfd man page](http://linuxcnc.org/docs/html/man/man1/hy_vfd.1.html) so look there if you need more information. Running `hy_vfd --help` from a terminal will give you the same helptext.

Change the following registers to make the VFD listen on the RS-485 bus for control signals:

- **PDxxxx**: `0`
- Bla

My notes:

- Make sure the baud rate is explained; it must match whatever you set in the `loadusr` line in `custom.hal`

# LinuxCNC Configuration

TODO: Complete ZIP of Allie conf

For completeness' sake, I'm making available my entire machine config [here](TODO) to help make configuring the VFD clearer if you need it. Read on for step by step config instructions and make reference to the config files in the download if need be. It's provided purely as an example of what to add to it to get the Huanyang VFD working, so don't use it on your machine verbatim.

I didn't need most of the signals made available by the `hy_vfd` module so I didn't add them to the configuration. You can add them yourself by looking at the HAL meter in LinuxCNC for the names.

**Note:** If you use stepconf a lot, make sure you stop it overwriting your custom config by changing [TODO: Settings]

TODO: Screenshot

## `custom.hal`

```
# Include your customized HAL commands here
# This file will not be overwritten when you run stepconf again

# Load the Huanyang VFD user component
loadusr -Wn spindle-vfd hy_vfd -n spindle-vfd -t 1 -d /dev/ttyUSB0 -p none -r 38400 -s 1

# Enable the VFD
setp spindle-vfd.enable 1

# Map VFD HAL component pins to LinuxCNC pins
net spindle-fwd motion.spindle-forward => spindle-vfd.spindle-forward
net spindle-reverse motion.spindle-reverse => spindle-vfd.spindle-reverse
net spindle-speed-cmd  motion.spindle-speed-out-abs => spindle-vfd.speed-command
net spindle-on motion.spindle-on => spindle-vfd.spindle-on
```

## `custom_postgui.hal`

```
# Include your customized HAL commands here
# The commands in this file are run after the AXIS GUI (including PyVCP panel) starts

TODO: Latest lines
net hy-spindle-at-speed spindle-vfd.spindle-at-speed => pyvcp.spindle-at-speed
net hy-spindle-rpm spindle-vfd.spindle-speed-fb => pyvcp.spindle-speed
net hy-modbus-ok spindle-vfd.hycomm-ok => pyvcp.hycomm-ok
```

## `custompanel.xml`

We want/need to display some info about the VFD in the LinuxCNC interface, so we'll write a PyVCP panel to do so.

This panel is a stripped down version of the default supplied in the original hy-vfd module. There is a downloadable ZIP in the [original forum thread]() containing the complete panel XML if you wish to set up extra fields. Note that you'll have to add more signals in your `.hal` files, and change the signal names in the PyVCP XML.

All I need from the panel is the spindle RPM, a spindle-at-speed indicator and a Modbus comm OK light. It currently looks like this:

TODO: Screenshot

And here's the PyVCP XML to generate it:

```
<?xml version='1.0' encoding='UTF-8'?>
<pyvcp>
	<labelframe text="Huanyang VFD">
	<font>("Helvetica",12)</font>
	<table>
	    	<tablerow/>
    			<tablespan columns="2"/>
    			<tablesticky sticky="nsew" />
    			<label>
    				<text>" "</text>
    				<font>("Helvetica",2)</font>
	    		</label>
		<tablerow/>
			<tablesticky sticky="w" />
			<label>
				<text>"Modbus Communication:"</text>
    			</label>
    			<tablesticky sticky="e" />
 			<led>
 				<halpin>"hycomm-ok"</halpin>
 				<size>"10"</size>
 				<on_color>"green"</on_color>
 				<off_color>"red"</off_color>
 			</led>
		<tablerow/>
			<tablesticky sticky="w" />
			<label>
				<text>"Spindle at speed:"</text>
    			</label>
    			<tablesticky sticky="e" />
 			<led>
 				<halpin>"spindle-at-speed"</halpin>
 				<size>"10"</size>
 				<on_color>"green"</on_color>
 				<off_color>"red"</off_color>
 			</led>
		<tablerow/>
			<label>
				<text>"  "</text>
    			</label>
 	</table>
 	<table>
 		<tablesticky sticky="nsew"/>
  		<tablerow/>
 			<tablesticky sticky="nsew"/>
 		    	<label>
	    			<text>"Spindle Speed (RPM)"</text>
	    			<font>("Helvetica",10)</font>
	    		</label>
	    	<tablerow/>
     			<tablesticky sticky="nsew"/>
    			<label>
    				<text>" "</text>
    				<font>("Helvetica",2)</font>
	    		</label>
	    	<tablerow/>
	    		<tablesticky sticky="nsew"/>
	    	    	<bar>
	    			<halpin>"spindle-speed"</halpin>
	    			<max_>24000</max_>
	    		</bar>
 	</table>
 	</labelframe>
</pyvcp>
```

### `Machine.ini`

We need to get LinuxCNC to load the custom panel and wiring. To do so, modify the machine `.ini` file. This is the `.ini` file inside the folder created by Stepconf. If your machine is called `Allie` like mine, this will be `Alli/Allie.ini`.

Find the `[DISPLAY]` section and add the following line to load the custom control panel (assuming you called the file `custompanel.xml`):

```
PYVCP = custompanel.xml
```

Next, find the `[HAL]` section and add these lines if they're not already present:

```
HALFILE = custom.hal
POSTGUI_HALFILE = custom_postgui.hal
```

## Usage

TODO: Screenshot of LinuxCNC with panel on the right

- Start LinuxCNC
- You should see the custom control panel on the right
- Home all axes to allow manual control if required
- Go to the MDI panel (<kbd>F5</kbd>) and type `M3 S5000` to start the spindle at 5k RPM. Run `M5` to stop **TODO: Does reverse (`M4`) work as well? Might need to change register settings**. The display on the VFD when set to show frequency should show a value close to 5000 RPM.
- To see the spindle-at-speed indicator in action, enter `M3 240000` from stopped to see the `spindle-at-speed` LED stay red until 24k RPM is reached after a couple of seconds. It is important that this works otherwise LinuxCNC won't wait for the spindle to come up to speed before starting a cut.

## Final notes and gotchas

- My spindle would go no lower than 3000 RPM. Change the [whichever the lowest freq register is] value to [new value]. I can get as low as 600 RPM now, not bothered about going lower. TODO: Add this note to the register configs in the VFD config block
- VFD must be on before you open LinuxCNC, otherwise HAL component will not start comms properly (component is loaded at startup and only attempts connection on load)
- Had huge trouble getting VFD to communicate, make sure `spindle-vfd.enable` is set to `1`.
- `Modbus comms ok` LED in PyVCP goes red during run; possibly because bus is busy reporting values back or whatever. We don't really care, you just don't want it red when the spindle is stopped.
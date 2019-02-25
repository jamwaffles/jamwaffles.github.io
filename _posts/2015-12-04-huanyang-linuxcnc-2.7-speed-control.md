---
layout: post
title:  "Spindle speed control using LinuxCNC 2.7 with a Huanyang inverter"
date:   2015-12-04 20:14:47
categories: cnc
image: huanyang-header-2.jpg
---

Huanyang branded VFD drives are ubiquitous on eBay and other sites like AliExpress. I bought one some time ago with a 1.5KW spindle and have been controlling the speed manually with the difficult to use control panel on the front. It is, however, possible to control the VFD from within LinuxCNC using the [`M3` and `M5` commands](http://linuxcnc.org/docs/html/gcode/m-code.html#mcode:m3-m4-m5) (I haven't been able to get `M4`, reverse rotation, working yet). What's also neat is we can get the machine to wait for the spindle to come up to speed before moving to the next line of GCode.

The first thing I tried was [PDM](https://en.wikipedia.org/wiki/Pulse-density_modulation) using signals from the parallel port. This doesn't set the speed accurately _at all_ and the PDM/speed conversion curve is hilariously inaccurate. If you want to try this method for whatever reason, there's a [guide in the LinuxCNC documentation](http://wiki.linuxcnc.org/cgi-bin/wiki.pl?VFD_Digital/Analog_Interface).

Most Huanyang VFDs have an RS-485 two-wire interface, so let's use this to communicate with the drive from LinuxCNC. These inverters supposedly support Modbus but aren't compliant, so a custom HAL component for LinuxCNC is required. Since LinuxCNC 2.7, [this component](http://linuxcnc.org/docs/html/man/man1/hy_vfd.1.html) is now bundled with the default image as a HAL component, so all we need to do is set it up properly. Easy!

# Hardware required

- A computer running LinuxCNC 2.7+ with at least one USB port
- A USB ↔ RS-485 converter. I got one on eBay for less than a fiver. You could use an RS-232 to RS-485 converter too
- Huanyang VFD
- Two core signal (light gauge) wire to hook up between the VFD and converter. I used one of the twisted pairs out of an ethernet cable. The twistedness might help over very long distances as RS-485 is differential. For shop use it doesn't really matter.

# VFD configuration

We first need to change some settings in the VFD. Most of these settings are identical to those defined in [the hy_vfd man page](http://linuxcnc.org/docs/html/man/man1/hy_vfd.1.html) so look there if you need more information. Running `hy_vfd --help` from a terminal will give you the same helptext.

Change the following registers to make the VFD listen on the RS-485 bus for control signals:

- **PD001** `2` (listen for run commands on the RS-485 bus)
- **PD002** `2` (listen for frequency/speed commands on the RS-485 bus)
- **PD164** `3` (baud rate - 38400 baud)
- **PD165** `3` (communication data method to 8N1 RTU)

Check your VFD manual for other values for these registers. I've included a PDF of the manual [here]({{ site.files }}/hy-vfd-manual.pdf) if you've lost the one included with your VFD.

<!-- - My spindle would go no lower than 3000 RPM. Change the [whichever the lowest freq register is] value to [new value]. I can get as low as 600 RPM now, not bothered about going lower. TODO: Add this note to the register configs in the VFD config block -->

# LinuxCNC Configuration

For completeness' sake, I'm making available my entire machine config [here]({{ site.files }}/hy-vfd-config-rs485.zip) to help make configuring the VFD clearer if you need it. Read on for step by step config instructions and make reference to the config files in the download if need be. It's provided purely as an example of what to add to it to get the Huanyang VFD working, so don't use it on your machine verbatim.

I didn't need most of the signals made available by the `hy_vfd` module so I didn't add them to the configuration. You can add them yourself by looking at the HAL meter in LinuxCNC for the names.

**Note:** Using stepconf again will overwrite some of your custom settings. The INI and other config files will have to be edited by hand, which is not that hard. You can always use stepconf to test things without saving and then edit the files manually later.

## `custom.hal`

```
# Include your customized HAL commands here
# This file will not be overwritten when you run stepconf again

# Load the Huanyang VFD user component
loadusr -Wn spindle-vfd hy_vfd -n spindle-vfd -t 1 -d /dev/ttyUSB0 -p none -r 38400 -s 1

#net vfd-comms halui.machine.is-on => spindle-vfd.enable
setp spindle-vfd.enable 1
net spindle-fwd motion.spindle-forward => spindle-vfd.spindle-forward
net spindle-reverse motion.spindle-reverse => spindle-vfd.spindle-reverse
net spindle-speed-cmd  motion.spindle-speed-out-abs => spindle-vfd.speed-command
net spindle-on motion.spindle-on => spindle-vfd.spindle-on
net spindle-at-speed motion.spindle-at-speed => spindle-vfd.spindle-at-speed
```

It's worth explaining this line in more detail:

```
loadusr -Wn spindle-vfd hy_vfd -n spindle-vfd -t 1 -d /dev/ttyUSB0 -p none -r 38400 -s 1
```

- Assumes the serial port is located at `/dev/ttyUSB0` (because I'm using a USB converter here). If you're using a serial port directly, use `/dev/ttys0` or similar.
- `-p none -s 1` assumes the VFD's PD165 register is set to `3`, which is 8N1 for RTU (Remote Terminal Unit) mode. The hy_vfd HAL module doesn't support ASCII modes.
- `-r 38400` sets the communication speed to 38400 baud. You need to make sure PD164 is set to `3` to match this value.

All options for the `hy_vfd` command are explained in [the user manual](http://linuxcnc.org/docs/html/man/man1/hy_vfd.1.html).

## `custom_postgui.hal`

```
# Include your customized HAL commands here
# The commands in this file are run after the AXIS GUI (including PyVCP panel) starts

net spindle-at-speed => pyvcp.spindle-at-speed
net pyvcp-spindle-rpm spindle-vfd.spindle-speed-fb => pyvcp.spindle-speed
net pyvcp-modbus-ok spindle-vfd.hycomm-ok => pyvcp.hycomm-ok
```

## `custompanel.xml`

We want/need to display some info about the VFD in the LinuxCNC interface, so we'll write a PyVCP panel to do so.

This panel is a stripped down version of the default supplied in the original hy-vfd module. There is a downloadable ZIP in the [original forum thread](http://www.cnczone.com/forums/phase-converters/91847-software-8.html#post_704008) containing the complete panel XML if you wish to set up extra fields. Note that you'll have to add more signals in your `.hal` files, and change the signal names in the PyVCP XML.

All I need from the panel is the spindle RPM, a spindle-at-speed indicator and a Modbus comm OK light. It currently looks like this (panel on the right):

![LinuxCNC with custom Huanyang panel screenshot](/assets/images/linuxcnc-spindle.png)

And here's the PyVCP XML to generate it:

```xml
<?xml version='1.0' encoding='UTF-8'?>
<pyvcp>
	<labelframe text="Huanyang VFD">
		<font>("Helvetica",12)</font>
		<table>
			<tablerow/>
			<tablespan columns="2" />
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
				<text>" "</text>
			</label>
		</table>
		<table>
			<tablesticky sticky="nsew" />
			<tablerow/>
			<tablesticky sticky="nsew" />
			<label>
				<text>"Spindle Speed (RPM)"</text>
				<font>("Helvetica",10)</font>
			</label>
			<tablerow/>
			<tablesticky sticky="nsew" />
			<label>
				<text>" "</text>
				<font>("Helvetica",2)</font>
			</label>
			<tablerow/>
			<tablesticky sticky="nsew" />
			<bar>
				<halpin>"spindle-speed"</halpin>
				<max_>24000</max_>
			</bar>
		</table>
	</labelframe>
</pyvcp>
```

It would be cool to have a tachometer type gauge and perhaps some more info, but this shows all the information I need.

### `Machine.ini`

We need to get LinuxCNC to load the custom panel and wiring. To do so, modify the machine `.ini` file. This is the `.ini` file inside the folder created by Stepconf. If your machine is called `Allie` like mine, this will be `Allie/Allie.ini`.

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

- Start LinuxCNC
- You should see the custom control panel on the right
- Home all axes to allow manual control if required
- Go to the MDI panel (<kbd>F5</kbd>) and type `M3 S5000` to start the spindle at 5k RPM. Run `M5` to stop. The display on the VFD when set to show frequency should show a value close to 5000 RPM. You should also be able to use `M4` (reverse rotation), but you'll need to set `PD023` to `1` on the VFD to enable it (untested).
- To see the spindle-at-speed indicator in action, enter `M3 240000` from stopped to see the `spindle-at-speed` LED stay red until 24k RPM is reached after a couple of seconds. It is important that this works otherwise LinuxCNC won't wait for the spindle to come up to speed before starting a cut.

## Final notes and gotchas

- The VFD takes some time to respond to speed commands. **This can be an issue with emergency stops** because the spindle won't stop until about 2 seconds after the button is pressed. I've ruined a few tools because of this.
- VFD must be on before you open LinuxCNC, otherwise HAL component will not start comms properly (component is loaded at startup and only attempts connection on load)
- I had huge trouble getting the VFD to communicate. Simple solution: make sure `spindle-vfd.enable` is set to `1`.
- `Modbus comms ok` LED in PyVCP goes red during run; possibly because bus is busy reporting values back or whatever. We don't really care, you just don't want it red when the spindle is stopped.

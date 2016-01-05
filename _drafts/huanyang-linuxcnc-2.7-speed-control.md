---
layout: post
title:  "Spindle speed control using LinuxCNC 2.7 with a Huanyang inverter"
date:   2014-12-04 20:14:47
categories: cnc
<!-- image: huanyang-linuxcnc.jpg -->
---

- You can sort of control the speed using [crappy PDM like this](http://wiki.linuxcnc.org/cgi-bin/wiki.pl?VFD_Digital/Analog_Interface)
- VFD has an RS-485 bus
- Get a USB -> RS-485 converter for dirt cheap on eBay. Mine looked like this:
	- Pic
- VFD is not modbus compliant
- Someone wrote a HAL component [in this forum thread](http://www.cnczone.com/forums/phase-converters/91847-software.html)
- HAL component modified a bit and **bundled with LinuxCNC!**, docs [here](http://linuxcnc.org/docs/html/man/man1/hy_vfd.1.html)

- VFD register config (mainly inspired from [the docs](http://linuxcnc.org/docs/html/man/man1/hy_vfd.1.html))
	- Bla
	- Bla

TODO: Upload latest config file to OneDrive

## Configuration

- Upload latest configs to OneDrive
- I didn't need all the other pointless value shit, just spindle speed and spindle-at-speed
- Should be reasonably easy to nail in the other values if you need them
- Explain some of the shit
	- Spindle-at-speed will make machine pause until spindle is up to speed before continuing job
- Paste additional lines in `Allie.ini`
- Screenshot and note about disabling changes from stepconf; don't wanna overwrite

You can download my config files [here](). `Machine.ini` contains the settings for my current CNC machine, so don't use those with your machine. It's provided purely as an example of what to add to it to get the Huanyang VFD working.

### `custom.hal`

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

### `custom_postgui.hal`

```
# Include your customized HAL commands here
# The commands in this file are run after the AXIS GUI (including PyVCP panel) starts

TODO: Latest lines
net hy-spindle-at-speed spindle-vfd.spindle-at-speed => pyvcp.spindle-at-speed
net hy-spindle-rpm spindle-vfd.spindle-speed-fb => pyvcp.spindle-speed
net hy-modbus-ok spindle-vfd.hycomm-ok => pyvcp.hycomm-ok
```

### `custompanel.xml`

Not the prettiest code, but it shows me everything I need.

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

This is the `.ini` file inside the folder created by Stepconf. If your machine is called `Allie` like mine, this will be `Alli/Allie.ini`.

Find the `[DISPLAY]` section and add the following line:

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
- You should see this panel on the right
- Home all axes to allow manual control
- `M3 S5000` to test at 5k RPM. `M5` to stop **TODO: Does reverse (`M4`) work as well? Might need to change register settings**
- Do `M3 240000` from stopped to see `spindle-at-speed` LED stay red until 24k RPM reached

## Final notes and gotchas

- My spindle would go no lower than 3000 RPM. Change the [whichever the lowest freq register is] value to [new value]. I can get as low as 600 RPM now, not bothered about going lower.
- VFD must be on before you open LinuxCNC, otherwise HAL component will not start comms properly
- Had huge trouble getting VFD to communicate, make sure `spindle-vfd.enable` is set to `1`.
- `Modbus comms ok` LED in PyVCP goes red during run; possibly becaue bus is busy reporting values back or whatever. We don't really care
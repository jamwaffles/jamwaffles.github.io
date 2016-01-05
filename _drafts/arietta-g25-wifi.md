# USB WiFi with the Arietta G25

Stupidly, I decided not to pick up a WiFi daughterboard for the Arietta G25. I ended up using a USB WiFi adapter instead.

I did some research and found that the Edimax EW-7811Un (available [all over eBay](http://www.ebay.co.uk/sch/Edimax+EW-7811Un)) is well supported by the Raspberry Pi. The Arietta also runs Emdebian, so getting drivers working wasn't too difficult. You will, however, need to build your own kernel.

## Wire up a female USB port to the Arietta

I'll be using the **USB B** port. Wire the plug up as follows:

![Wiring diagram](TODO)

To make things easier, I soldered up a quick USB cable and stuck it in a breadboard:

![USB cable pic](TODO)

## Adding driver support to the kernel

**Maybe you don't need to do this?**

Follow [my Arietta kernel compilation guide](TODO). When you get to the `make menuconfig` stage, look for and enable the following driver:

	[ TODO ]

## Interface configuration

Now you've copied the new kernel over and rebooted, edit `/etc/network/interfaces` to look like this:

	# interfaces(5) file used by ifup(8) and ifdown(8)
	auto lo
	iface lo inet loopback

	pre-up modprobe g_cdc

	auto usb0
	iface usb0 inet static
		address 192.168.2.10
		netmask 255.255.255.0

	allow-hotplug wlan0
	iface wlan0 inet dhcp
		# If you're using a WPA protected AP:
		wpa-ssid [ AP NAME ]
		wpa-psk [ AP PASSWORD ]

**It is very importand that you remove the `gateway` line from `usb0`'s configuration** – we're setting up the WiFi chip to use DHCP, which will mean conflicting gateways when a DHCP lease is given by the router. We want to be able to access the internet, so let DHCP do it's thing.

_Note: `allow-hotplug wlan0` is required for the interface to be brought up at boot. If you don't want to do that, replace the line with `auto wlan0`._
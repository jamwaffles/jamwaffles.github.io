# Mac support for the Arietta G25

You need to recompile the kernel to do this. I have a handy guide [here](TODO) about this.

When it comes to doing the `menuconfig` command, do the following.

## Configure kernel modules

According to [this post](http://blog.zs64.net/2014/06/getting-started-with-the-arietta-g25-board/), open up `menuconfig` and navigate to

	Device Drivers -->
		USB support -->
			USB Gadget Support (at the very bottom of the list)

**Deselect** these (by pressing `N` when focused):

- RNDIS support
- Ethernet Emulation Model (EEM)

Make sure to leave `Ethernet Gadget` **selected**.

Now, **select** these (press `M`):

- Serial Gadget
- CDC Composite Device (Ethernet and ACM)

Before selection:

![Screenshot of default kernel config in ncurses interface](./TODO.png)

After selection:

![Screenshot of USB gadget interface configured with Mac support](./TODO2.png)

## Configure network interface on the Arietta

We'll be using Internet Connection Sharing from the Sharing section of the OSX settings app. This will assign IP addresses on the `192.168.2.0/24` subnet by default, so we'll set a static IP of `192.168.2.10` for the Arietta. We also need to make the CDC module load instead of the default `g_ether` one.

Change `/etc/network/interfaces` like so:

	# interfaces(5) file used by ifup(8) and ifdown(8)
	auto lo
	iface lo inet loopback

	# Load `g_cdc` instead of `g_ether`
	pre-up modprobe g_cdc

	auto usb0
	iface usb0 inet static
	  address 192.168.2.10
	  netmask 255.255.255.0
	  gateway 192.168.2.20

## Configure Mac

Reboot the board and wait until it's booted again. Running `sudo dmesg` on your Mac should show something like this:

	         0 [Level 5] [com.apple.message.domain com.apple.commssw.cdc.device] [com.apple.message.signature AppleUSBCDCACMData] [com.apple.message.signature2 0x525] [com.apple.message.signature3 0xA4AA]
	AppleUSBCDCACMData: Version number - 4.2.2b5, Input buffers 8, Output buffers 16
	AppleUSBCDC: Version number - 4.2.2b5
	Ethernet [AppleUSBCDCECMData]: Link up on en5, 10-Megabit, Full-duplex, No flow-control, Port 1, Debug [0000,0000,0000,0000,0000,0000]

Once that's showed up (you might have to wait for a while), open up Network Preferences. You should see the CDC interface. Configure it as such:

	![Mac CDC static network config](TODO)

## Accessing the internet

If you were hopeful this section contained a magic bullet, it does not. Sorry about that.

I haven't been able to get Internet Connection Sharing nor some kind of `ipfw` rule working in OSX 10.10. My horrible workaround for now is to SSH from my Mac into a local VM, from which I then log in to the Arietta and can ping addresses on the internet. I have a [Linux guide](TODO) on setting this up.

Another, simpler option is to use a USB WiFi adapter. I explain how to set an Edimax one up [here](TODO).
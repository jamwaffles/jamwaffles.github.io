# Arietta G25 on Debian

This guide uses Crunchbang Waldorf in a virtual machine, but should work equally well for any Debian Wheezy based systems, virtual or not.

## Bootable SD card and initial boot

Download `kernel.tar.bz2` and `rootfs.tar.bz2` from [here](http://www.acmesystems.it/download/microsd/Acqua-16oct2014) (mirror this?)

Find an SD card, format using:

```bash
DISK=/dev/sdX

# Create partitions

parted $DISK -s mkpart primary 512B 32MB
parted $DISK -s mkpart primary 32MB 1300MB
parted $DISK -s mkpart primary 1300MB 1800MB

# Format

mkdosfs ${DISK}1 -n kernel

mke2fs -t ext4 ${DISK}2 -L rootfs
mke2fs -t ext4 ${DISK}3 -L data
```

The above guide is made using info from [the official tutorial](http://www.acmesystems.it/microsd_format) and [this post](https://groups.google.com/d/msg/acmesystems/l4Cq0NZLlR8/s2T87jIhUG0J)

Now you've got a partitioned and formatted SD card, mount the partitions somewhere. E.g.:

```bash
mkdir /media/KERNEL
mkdir /media/rootfs

mount /dev/sdX1 /media/KERNEL
mount /dev/sdX2 /media/rootfs
```

You might get permissions issues. It's safe to just `chmod` away or set mount options to make the partitions writable.

`/media/KERNEL` is the first partition, formatted as FAT16. `/media/rootfs` is the second partition, formatted as ext4. This is the `/` folder when the Linux distro is running.

Once mounted, extract the kernel and root filesystem onto the cards first and second paritions

```bash
sudo tar -xvjpSf kernel.tar.bz2 -C /media/KERNEL
sudo tar -xvjpSf rootfs.tar.bz2 -C /media/rootfs
```

Once that's done, change network config to use static IP in a weird subnet. Do this by putting the following in `/media/rootfs/etc/network/interfaces`:

	auto lo
	iface lo inet loopback

	pre-up modprobe g_ether

	auto usb0
	iface usb0 inet static
		address 192.168.10.10
		netmask 255.255.255.0
		gateway 192.168.10.20

Unmount SD card, stick it in the Arietta, plug into host PC and wait for it to boot.

## Configure (Linux) host networking to SSH into the card

The Arietta shows up as `usb0` in the `ifconfig` list.

Configure your PC to communicate with the Arietta by adding this to `/etc/network/interfaces`:

	allow-hotplug usb0
	iface usb0 inet static
	    address 192.168.10.20
	    netmask 255.255.255.0

You might need to do `ifdown usb0` then `ifup usb0` to get it all working.

	ssh root@192.168.10.10

The password is `acmesystems`.

You'll only be able to communicate between the host PC and the Arietta. To get onto the internet, you'll need to go to the next step which sets up NAT.

## Accessing the internet

- NAT (Linux host)

	`eth0` is the external interface, `usb0` is the interface the Arietta exposes

	```bash
	echo 1 > /proc/sys/net/ipv4/ip_forward

	iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
	iptables -A FORWARD -i eth0 -o usb0 -m state --state RELATED,ESTABLISHED -j ACCEPT
	iptables -A FORWARD -i usb0 -o eth0 -j ACCEPT
	```

	Make these rules run at boot:

	- Open `/etc/sysctl.conf` and change `net.ipv4.ip_forward = 0` to `net.ipv4.ip_forward = 1` (might already exist commented out)
	- `apt-get install iptables-persistent`, save IPv4 rules during installation prompt.
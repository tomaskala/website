+++
title = 'Raspbian Emulation in QEMU'
date = 2022-04-29T21:44:01+02:00
+++

Recently, I decided to reinstall my Raspberries, and while doing so, automate
their configuration in Ansible. They were also long-overdue for an upgrade, as
I set them up some time in 2019 when I knew shit about system administration.

I installed the current version of Raspbian and proceeded with running the
Ansible playbook I prepared. Unsurprisingly, there were several bugs, and I had
to rewrite and redeploy it several times. I even locked myself out of network
access and had to physically plug the SD card into my computer to change some
configs a few times.

The whole process of removing the SD card with pliers, plugging it in my
computer, changing a config, and plugging it back, isn't exactly efficient. A
few more times and I'd fry the card. To save the SD card and my patience, I
decided to continue the experiments in QEMU. Once the whole deployment works,
I'll reinstall Raspbian for the final time and configure the system on a real
Raspberry.

Emulating a Raspberry Pi isn't as straightforward as some other systems,
because QEMU doesn't support it natively. Most of the hackery below involves
masquerading the Pi for a different ARM board which QEMU does support.

The guide sets up Raspbian Bullseye in QEMU and enables SSH access to the guest
machine, so that Ansible can be tested.

# Preparation

- Install QEMU.
  ```bash
  $ pacman -S qemu-full qemu-emulators-full
  ```
- Download a QEMU kernel and a DTB file (containing the hardware description)
  from
  [dhruvvyas90/qemu-rpi-kernel](https://github.com/dhruvvyas90/qemu-rpi-kernel).
  The reason for this is that the Raspbian-bundled kernel has been compiled
  specifically for the Raspberry Pi board, which is not supported by QEMU (at
  the time of writing). This site hosts kernels cross-compiled for the [ARM
  Versatile development
  board](https://developer.arm.com/tools-and-software/development-boards),
  which QEMU supports.
- Download the most-recent Raspbian-Lite image from the [official
  website](https://www.raspberrypi.com/). Note that (at the time of writing)
  the kernels in the above link require a 32bit Raspbian.

# Mount and edit the image

The image contains the boot partition and the root partition. We need to mount
both of them.

- Recently, the default `pi` user with the `raspberry` password was removed for
  security reasons. Because we are doing a headless setup, we need to define
  the admin user in a special file inside the boot partition.
- We have to disable loading of additional shared libraries in the root
  partition.

To mount both partitions, run the following.
```bash
$ losetup --show --find --partscan 2022-04-04-raspios-bullseye-armhf-lite.img
/dev/loop1
$ ls /dev/loop1*
/dev/loop1  /dev/loop1p1  /dev/loop1p2
$ mkdir /mnt/{raspbian-boot,raspbian-root}
$ mount /dev/loop1p1 /mnt/raspbian-boot
$ mount /dev/loop1p2 /mnt/raspbian-root
```

Create a file `/mnt/raspbian-boot/userconf.txt` with the following structure:
```ini
<admin-username>:<password-hash>
```
where the password hash can be obtained from
```bash
$ echo '<password>' | openssl passwd -6 -stdin
```

Next, comment out every line inside `/mnt/raspbian-root/etc/ld.so.preload`.

Finally, unmount the image.
```bash
$ umount /dev/loop1p1
$ umount /dev/loop1p2
$ rmdir /mnt/{raspbian-boot,raspbian-root}
$ losetup --detach /dev/loop1
```

# Convert the image

For efficiency, the image is converted from the raw format to a `qcow2` format.
```bash
$ qemu-img convert -f raw -O qcow2 2022-04-04-raspios-bullseye-armhf-lite.img raspbian-bullseye-lite.qcow2
```
This allow us to quickly resize the image so that it will only grow in size
when the guest OS requests so.
```bash
$ qemu-img resize raspbian-bullseye-lite.qcow2 +6G
```

# Run QEMU

The virtual machine is started using the following command.
```bash
$ qemu-system-arm \
    -no-reboot \
    -machine versatilepb -cpu arm1176 -m 256 \
    -kernel kernel-qemu-5.10.63-bullseye \
    -dtb versatile-pb-bullseye-5.10.63.dtb \
    -drive format=qcow2,file=raspbian-bullseye-lite.qcow2 \
    -append "root=/dev/sda2 panic=1 rootfstype=ext4 rw" \
    -nographic \
    -nic user,hostfwd=tcp::5022-:22
```
The parameters stand for

- `-no-reboot`: Exit on error instead of rebooting.
- `-machine versatilepb -cpu arm1176 -m 256`: Set the emulated machine, its CPU
  and the amount of memory (256MB is the maximum for versatilepb).
- `-kernel kernel-qemu-5.10.63-bullseye`: Set the kernel.
- `-dtb versatile-pb-bullseye-5.10.63.dtb`: Set the device tree.
- `-drive format=qcow2,file=raspbian-bullseye-lite.qcow2`: Set the drive image.
- `-append "root=/dev/sda2 panic=1 rootfstype=ext4 rw"`: Set the root partition
  and its file system type.
- `-nographic`: Do not display the QEMU GUI, since we are running Raspbian Lite
  anyway.
- `-nic user,hostfwd=tcp::5022-:22`: Forward the host port 5022 to the guest
  port 22.

# SSH connection

Enable the SSH server in the guest machine.
```bash
$ systemctl enable --now ssh.service
```
It is then possible to connect from the host to the guest over SSH.
```bash
$ ssh <admin-username>@127.0.0.1 -p 5022
```

# Setup bridged networking

By default, QEMU uses user-mode networking with a virtual DHCP server. When a
virtual machine runs its DHCP client, it gets assigned an IP address and is
then able to access the host machine's network stack through masquerading done
by QEMU.

This has a couple of issues, which may or may not be relevant, depending on the
use case.

- Because the network emulation happens in the user space, its performance can
  be quite poor.
- If we want to expose additional services running on the guest machine (like
  we do with SSH above), we must shutdown the machine and relaunch it with
  additional forwarding arguments to QEMU.

A solution is to setup a bridged network. We create a network bridge between
the guest's virtual TAP interface and the host's physical interface. The
virtual machine gets assigned an IP address as if it were a physical device,
and is able to communicate with other devices on the network. Because TAP
interfaces are a kernel feature, the resulting network can achieve much better
performance. Since the virtual machine now appears as any other device on the
network, we can readily access any service it provides, without needing to
setup any port forwarding.

First, we have to create a bridge on the host and bring it up.
```bash
$ ip link add name br0 type bridge
$ ip link set dev br0 up
```

Next, we have to assign an interface to the bridge we just created so that it 
knows where to forward the received frames. For this, the interface needs to be 
up. Here I am assigning the `eth0` interface to the bridge.
```bash
$ ip link set dev eth0 master br0
```

Having set up the bridge, we now instruct QEMU to use it. Since QEMU 1.1, there
is a nifty `qemu-bridge-helper` utility that sets up the TAP device
automagically. Because port forwarding is no longer needed, we can remove the
`-nic user,hostfwd=tcp::5022-:22` flag. To make QEMU use the `br0` bridge, we
launch it like this.
```bash
$ qemu-system-arm \
    ... \
    -net nic -net bridge,br=br0
```

To later remove the bridge, we can run the following.
```bash
$ ip link set dev eth0 nomaster
$ ip link delete dev br0
```

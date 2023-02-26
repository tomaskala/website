---
title: Arch Linux with LVM on LUKS
date: 2023/02/27
---

I've been using Arch Linux for the past several years, but never quite got to 
documenting the exact steps I use for installation. Every time I do a 
reinstall, I have to spend some time re-learning what exactly I have to 
configure to have the system I want. This is my attempt to document the 
installation steps so that I can recall them whenever I need.

At the time of writing, there is the handy 
[archinstall](https://wiki.archlinux.org/title/Archinstall) library, but I 
still prefer the old-school manual installation.

We'll end up with a UEFI-booting system with LVM on LUKS. No GUI is installed 
in this guide, since I do that using one of my repos, depending on whether I 
run [X](https://github.com/tomaskala/suckless) or 
[Wayland](https://github.com/tomaskala/suckmore) 

First, download an image from <https://archlinux.org/download/> and copy it to a 
USB drive, after having verified the file integrity.
```
# cat archlinux-YYYY.MM.DD-x86_64.iso >/dev/sdX && sync
```

# Network configuration

If you are connected over Ethernet using DHCP, the network connection should 
get picked up automatically. For Wi-Fi, authenticate using `iwctl`:
```
# iwctl
[iwd]# device list
[iwd]# station <device-name> scan
[iwd]# station <device-name> get-networks
[iwd]# station <device-name> connect <ssid>
```

# Disk partitioning

Check your drives with
```
# fdisk -l
```
The rest of the guide assumes that Arch is installed to `/dev/sda`. Run `fdisk` 
on this device and start partitioning.
```
# fdisk /dev/sda
```

First, create a 600M EFI partition:

* `n` (new partition)
* `Enter` (accept the default partition type)
* `Enter` (accept the default partition number)
* `Enter` (accept the default first sector)
* `+600M` (partition size)
* `t` (partition type)
* `Enter` (accept the default partition number)
* `ef` (EFI)

Next, create a 1G boot partition:

* `n`
* `Enter`
* `Enter`
* `Enter`
* `+1G`
* `t`
* `Enter`
* `83` (Linux)

Finally, create the LVM partition taking up the remaining space:

* `n`
* `Enter`
* `Enter`
* `Enter`
* `Enter`
* `t`
* `Enter`
* `8e` (Linux LVM)

Check that everything is OK by typing `p`. Write the changes by typing `w`.

There are now three partitions:

1. `/dev/sda1` for EFI. This will be formatted with FAT.
2. `/dev/sda2` for `/boot`. This will be formatted with EXT4.
3. `/dev/sda3` for LVM on LUKS.

To create the file systems for the first two, enter
```
# mkfs.fat -F32 /dev/sda1
# mkfs.ext4 /dev/sda2
```

# LVM on LUKS

Here we'll setup disk encryption using LUKS followed by LVM with several 
partitions. By using LVM on LUKS, we can have multiple logical volumes all 
accessed using a single encryption key. The opposite would be LUKS on LVM, 
which would allow an encrypted volume to span more devices, with the volume 
group visible without decrypting the encrypted volumes.

Setup encryption on the third partition. This will prompt you for a passphrase.
```
# cryptsetup luksFormat /dev/sda3
```

To be able to create the logical volumes and proceed with the installation, we 
need to open the encrypted partition. This will prompt you for the passphrase 
defined in the previous step.
```
# cryptsetup open /dev/sda3 root
```
Here, `root` is arbitrary and only describes where the unlocked partition 
should be mapped. Once opened, it can be accessed in `/dev/mapper/root`.

Initialize a physical volume for use by LVM:
```
# pvcreate --dataalignment 1m /dev/mapper/root
```

Create a volume group in the physical volume we've just created:
```
# vgcreate vg0 /dev/mapper/root
```
The name of the group (`vg0` here) is arbitrary.

Finally, we can create the logical volumes.

1. An 8G swap partition.
2. A 50G file system root partition.
3. A home partition taking up all the remaining space.

```
# lvcreate -L 8G vg0 -n swap
# lvcreate -L 50G vg0 -n root
# lvcreate -l 100%FREE vg0 -n home
```

Each partition needs a file system; I use `ext4`.
```
# mkswap /dev/mapper/vg0-swap
# mkfs.ext4 /dev/mapper/vg0-root
# mkfs.ext4 /dev/mapper/vg0-home
```

The partitions now have to be mounted, along with the `/boot` and EFI 
partitions.
```
# mount /dev/mapper/vg0-root /mnt

# mkdir /mnt/boot
# mount /dev/sda2 /mnt/boot

# mkdir /mnt/boot/efi
# mount /dev/sda1 /mnt/boot/efi

# mkdir /mnt/home
# mount /dev/mapper/vg0-home /mnt/home

# swapon /dev/mapper/vg0-swap
# mkdir /mnt/etc
```

Generate the fstab file.
```
# genfstab -U /mnt >>/mnt/etc/fstab
```

Make `/tmp` a RAM disk for increased speed and reduced SSD wear:
```
# echo 'tmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0' >>/mnt/etc/fstab
```

# Arch installation

First, use `pacstrap` to install the `base` package, the Linux kernel and 
firmware. When that's done, chroot into the newly installed system.
```
# pacstrap -i /mnt base linux linux-firmware
# arch-chroot /mnt
```

At this point, we are working inside the newly installed system. Install some 
additional packages. Based on your CPU manufacturer, select either `amd-ucode` 
or `intel-ucode` in place of `<cpu-ucode>`.
```
# pacman -S <cpu-ucode> sudo vim iwd lvm2 grub efibootmgr
```

Set a hostname of your choice:
```
# echo '<hostname>' >/etc/hostname
```

Make sure the `/etc/hosts` file contains the following lines:
```
127.0.0.1 localhost.localdomain localhost
::1 localhost.localdomain localhost
127.0.0.1 <hostname>.localdomain <hostname>
```

Define your locale by uncommenting it inside `/etc/locale.gen` (in my case, 
`en_US.UTF-8 UTF-8`) and running
```
# locale-gen
# echo 'LANG=en_US.UTF-8' >/etc/locale.conf
```
The changes will take effect after the next login.

Setup system clock by running
```
# ln -s /usr/share/zoneinfo/<timezone> /etc/localtime
# hwclock --systohc --utc
```

Finally, we have to enable encryption in `mkinitcpio` hooks. Make sure that the 
line beginning with `HOOKS=` inside `/etc/mkinitcpio.conf` looks like this:
```
HOOKS=(base udev autodetect keyboard keymap consolefont modconf block lvm2 encrypt filesystems fsck)
```
and that the line beginning with `MODULES=` contains `ext4` in the parentheses. 
After that, run
```
# mkinitcpio -p linux
```

# User management

Here we change the root password and create a user with superuser permissions.
```
# passwd
# useradd -m -G wheel <username>
# passwd <username>
```
Next, make members of the `wheel` group superusers.
```
# EDITOR=vim visudo
```
and make sure that there is a line containing
```
%wheel ALL=(ALL:ALL) ALL
```

# Bootloader configuration

We'll refer to devices by UUIDs instead of bus names, because the device nodes 
may be added in arbitrary order if you have more disk controllers. Run
```
# blkid
```
and look up the UUID corresponding to `/dev/sda3`. Then, make sure that the 
line starting with `GRUB_CMDLINE_LINUX=` inside `/etc/default/grub` looks like 
this:
```
GRUB_CMDLINE_LINUX="cryptdevice=UUID=<uuid>:vg0:allow-discards root=/dev/mapper/vg0-root"
```

Install grub:
```
# grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck
```

Setup grub locale and generate the grub configuration file:
```
# mkdir /boot/grub/locale
# cp /usr/share/locale/en\@quot/LC_MESSAGES/grub.mo /boot/grub/locale/en.mo
# grub-mkconfig -o /boot/grub/grub.cfg
```

# Finishing up

Exit the system chroot, unmount all devices, reboot, and enjoy your new system.
```
# exit
# umount -R /mnt
# swapoff -a
# reboot
```

# Network configuration

The full article comes from the amazing [Insanity 
Industries](https://insanity.industries/post/simple-networking/), so I'll just 
summarize to keep the configuration handy.

To configure wired networking, put the following inside 
`/etc/systemd/network/cable.network`:
```
[Match]
Name=<name of the wired network device> <second one if applicable> [<more ...>]

[Network]
DHCP=yes
IPv6PrivacyExtensions=true

[DHCP]
Anonymize=true
```
Afterwards, run
```
# systemctl enable --now systemd-networkd.service
```

To configure wireless networking, put the following inside 
`/etc/iwd/main.conf`:
```
[General]
EnableNetworkConfiguration=true
AddressRandomization=once

[Network]
EnableIPv6=true
```
Next, configure `iwd` to start only after `udev` has finished renaming the 
network interfaces. Run
```
# systemctl edit iwd.service
```
and enter
```
[Unit]
Requires=sys-subsystem-net-devices-<wireless-device>.device
After=sys-subsystem-net-devices-<wireless-device>.device
```
Afterwards, run
```
# systemctl enable --now iwd.service
```

To disable `iwd` when WiFi is not present, put the following inside 
/etc/udev/rules.d/wifi.rules`:
```
SUBSYSTEM=="rfkill", ENV{RFKILL_NAME}=="phy0", ENV{RFKILL_TYPE}=="wlan", ACTION=="change", ENV{RFKILL_STATE}=="1", RUN+="/usr/bin/systemctl --no-block start iwd.service"
SUBSYSTEM=="rfkill", ENV{RFKILL_NAME}=="phy0", ENV{RFKILL_TYPE}=="wlan", ACTION=="change", ENV{RFKILL_STATE}=="0", RUN+="/usr/bin/systemctl --no-block stop iwd.service"
```

Finally, to setup `systemd-resolved` as the DNS client, run
```
# systemctl enable --now systemd-resolved.service
# ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
```

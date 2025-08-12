---
title: "Creating a bootable FAT32 USB drive on MacOS"
date: 2025-08-12T11:00:44+02:00
---

I needed to update the UEFI firmware on a new machine I had just bought, which 
involved copying the UEFI flash tool and the corresponding `.CAP` file to a USB 
drive. For the update to work, the drive needed to be formatted as FAT32 and 
set to bootable. I only had my MacBook around, and it turns out that the 
default drive formatter does not set the bootable flag.

When you open Finder and right-click the USB drive, you can erase the drive and 
format it as FAT. However, such drive fails to boot. Turns out that the correct 
way to do that is from the terminal:

```bash
$ diskutil list  # Find the disk identifier, say /dev/disk5.
$ diskutil partitionDisk /dev/disk5 MBR fat32 "MYDRIVE" 100%
```

Unlike the graphical utility, this command correctly sets the Master Boot 
Record, making the drive bootable.

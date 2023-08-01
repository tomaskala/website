---
title: A reasonably secure Linux laptop
date: 2023/07/19
---

Recently, my laptop died. To setup a new one, I wanted to play with the 
security settings a bit, and learn some stuff along the way. I had used
full-disk encryption on the old laptop, but that was mostly taken from someone 
else's configuration, and I barely understood the details when I had set that 
up. This time, I wanted to do this right.

I put together a list of things I wanted...

- Full-disk encryption using LUKS2
- Storing the encryption keys on the TPM chip
- Secure boot
- systemd-boot (this has nothing to do with security, but systemd-boot is much 
  more light-weight than GRUB)
- Password-protected firmware (this is necessary for secure boot to make sense, 
  otherwise, I could just enter setup and disable secure boot entirely)

...and spent the following several days reading the Arch wiki, various blog 
posts, and random pieces of documentation. Most of these settings are for fun, 
since my only threat model is protecting my data in case of laptop theft; I 
don't really have to worry about evil maids sneaking up to my hotel room.

I had originally wanted to also encrypt the boot partition, but that's only 
supported by GRUB, and GRUB in turn only fully supports LUKS1. That is, there 
is some preliminary support for LUKS2, but not for the Argon 2 key derivation 
function.

In the end, the [Simple encrypted root with TPM2 and Secure 
Boot](https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#Simple_encrypted_root_with_TPM2_and_Secure_Boot) 
section on the Arch wiki proved the most useful, as it described pretty much 
the same setup that I had in mind. There are a few tweaks I had to make, but 
all in all, it was a surprisingly smooth process.

- I'm using `systemd-boot-update.service` to automatically update systemd-boot 
  after booting if necessary. I was wondering how that plays along with `sbctl` 
  to automatically sign the bootloader after the update. The issue is that, by 
  default, `sbctl` would re-sign the bootloader upon `pacman` update, but that 
  only updates the systemd-boot _installer_. systemd-boot itself would only be 
  updated after the next boot, and that way left unsigned.

  [The documentation literally 
  states](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot#Automatic_signing_with_the_pacman_hook) 
  the exact command needed to ensure that the bootloader gets signed, but it 
  took me a while to realize that `sbctl` saves the output file in its DB and 
  provides it to its pacman hook.
- Since the LUKS key is bound to the TPM PCR 7 (holding the secure boot state), 
  whenever secure boot status is changed, the key gets invalidated. In other 
  words, once I enabled secure boot, I had to manually type the excruciatingly 
  long recovery key instead of having TPM unlock the drive for me. What's 
  needed is to wipe the current key from the TPM slot, and enroll a new key. 
  This is done using the following command
  ```
  # systemd-cryptenroll /dev/sda1 --wipe-slot=tpm2 --tpm2-device=auto
  ```
  (replace `/dev/sda1` by your LUKS partition).

Thanks to storing the LUKS key in the TPM chip, there is no need to enter a 
passphrase, and the drive unlocks automatically. It did seem a little off at 
first, like I was losing some degree of security. I had to convince myself that 
it's OK:

- It's still necessary to enter a login password to, well, log in. That way, 
  assuming a reasonable password choice, the laptop is still locked to 
  outsiders.
- Since the TPM is on the motherboard, removing the drive and putting it into 
  another machine cannot lead to the drive getting unlocked.
- Since the firmware is password-protected, it's not possible to boot from 
  another medium to analyze the drive or tamper with the system.
  - The former is also impossible due to full-disk encryption.
  - The latter is likewise impossible due to secure boot.
- This is almost exactly the security scheme used by Android. Notice that even 
  if you're encrypting your Android system, you're not prompted for a 
  decryption passphrase during system boot.

Of course, as the saying goes, anyone is capable of inventing an encryption 
scheme that they themselves are unable to break, but I feel pretty OK about 
this. Like I said in the beginning, as long as my data is secure from laptop 
theft, I'm good.

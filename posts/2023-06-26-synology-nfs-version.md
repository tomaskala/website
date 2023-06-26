---
title: Disabling old NFS versions on Synology NAS devices
date: 2023/06/26
---

I have a Synology NAS device at home that contains, among others, my music 
collection. To be able to play it remotely, I have the wonderful 
[Navidrome](https://www.navidrome.org/) service running on a Raspberry Pi that 
accesses the music directory over NFS.

Naturally, I want to run the most-recent version of the NFS protocol (that is, 
NFSv4.1). Not only is it more performant and comes with mandatory security 
settings, the server also uses only a single port (TCP & UDP 2049 by default). 
The previous versions required [at least 2 other 
services](https://serverfault.com/questions/1015970/is-rpcbind-needed-for-an-nfs-client).

Synology configuration allows one to configure the _maximum_ NFS protocol 
version, as seen in the image below.

![Synology NFS configuration](/img/nfs_configuration.jpg)

There seems to be no way to disable the older version though? No luck in the 
"Advanced" section either.

![Synology advanced NFS configuration](/img/nfs_advanced_configuration.jpg)

Let's try the manual way. SSH into the NAS and look for an NFS configuration 
file under `/etc/`.
```
$ ssh admin@nas.home.arpa
admin@nas:/$ find /etc -name '*nfs*' 2>/dev/null
/etc/nfs
/etc/nfs/syno_nfs_conf
/etc/systemd/system/multi-user.target.wants/nfs-server.service
```

Ah! Let's see what's inside `/etc/nfs/syno_nfs_conf`.
```
admin@nas:/$ cat /etc/nfs/syno_nfs_conf
udp_read_size=8192
udp_write_size=8192
nfsv4_enable=yes
nfs_unix_pri_enable=1
nfs_custom_port_enable=no
statd_port=0
nlm_port=0
nfs_minor_ver_enable=1
```

Disappointing; that only contains the options we saw are configurable from the 
GUI. Let's look further among the running services. Luckily, they stuffed 
systemd into that thing.
```
admin@nas:/$ systemctl list-units | grep nfs
  ...
  nfs-server.service  loaded active exited  NFS server and services
  ...
```

We only care about the server, so I've omitted the other services we found.
Let's see what the service actually executes:
```
admin@nas:/$ systemctl cat nfs-server.service | grep ExecStart
ExecStartPre=/usr/syno/lib/systemd/scripts/nfsd.sh pre-start
ExecStart=/usr/syno/lib/systemd/scripts/nfsd.sh start
```

Both the `ExecStartPre` and `ExecStart` options run the same script, just with
different parameters. The `pre-start` section only updates the table of 
NFS-accessible file systems:
```
...
pre-start)
    /usr/sbin/exportfs -r
    exit 0
;;
...
```

The `start` section is more interesting, though. It ends with
```
/usr/sbin/nfsd $Version $N -u
```
(note the unquoted variables). The `Version` variable is originally defined as
```
Version="-V 2 -V 3 -V 4"
```
and later updated based on whether NFSv4 and NFSv4.1 are enabled or not. From 
that, we see two things:

1. It's enough to edit this variable to only contain `-V 4.1` _just_ before 
   it's passed to `/usr/sbin/nfsd`.
2. Synology should really learn about Bash arrays and how they can be used to 
   pass around arguments, rather than passing them in an unquoted string. Yes, 
   the script is executed through Bash and not the default `ash` shell, as it 
   begins with `#!/bin/bash`. The shebang should really be `/usr/bin/env bash` 
   for maximum portability, by the way.

The file is only writable by the root user, so it must be edited as such. The 
only issue is that the change might get lost after the next update, so I'll 
have to check again. I _could_ make the file immutable by
```
admin@nas:/$ sudo chattr +i /usr/syno/lib/systemd/scripts/nfsd.sh
```
but that doesn't sound like a great idea.

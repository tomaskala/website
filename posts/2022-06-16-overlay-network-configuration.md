---
title: Overlay network configuration
date: 2022/06/16
---

The next step in my nerdy networking hobby was to expand my [server
configuration](https://tomaskala.com/posts/2022-02-27-server-structure) to
allow remote access to my home network. Naturally, this involved setting up a
VPN and some way to access it from outside the network, among other things.

The motivation is to be able to access my NAS for backups and the nice [web
UI](https://github.com/navidrome/navidrome) that I set up over my music
collection. In future, I'll most likely include more services.

I decided to go a step further and set up a kind of an [overlay
network](https://en.wikipedia.org/wiki/Overlay_network). That way, all my
devices will be able to talk to each other and to any device at home,
regardless of where they are. In addition, I can grant access to my family
members' devices so that they can use any service the network provides, while
being separable from my devices by putting them on different subnets.

# Connecting to the home network

The first thing that needs to be addressed is how to actually access the home
network. There are a few ways to achieve that:

* **Public IP address.** My ISP actually does offer that, both IPv4 and IPv6!
  But you need to pay extra, and if I ever decided to change the ISP (or they
  changed their services), I would lose this option. More importantly, I didn't
  feel like requesting a public IP address for something that's essentially a
  playground.
* **Dynamic DNS.** Another option is to reserve a subdomain of [my
  domain](tomaskala.com) and to configure [dynamic
  DNS](https://en.wikipedia.org/wiki/Dynamic_DNS) for that subdomain. My DNS
  provider allows that (how lucky I am with providers!), but this felt a bit
  too much like relying on external services only to connect to my home.
* **Connecting through another server.** Finally, I settled on this solution. A
  WireGuard peer running at home will connect to my server, just like any other
  peer. Since WireGuard doesn't distinguish between clients and servers (though
  the terminology often slips), all peers are equal. The server will take care
  of routing packets destined to the home network through the correct peer,
  which will act as a gateway.

The gateway is, unsurprisingly, a Raspberry Pi. Normally, one would install
WireGuard on their router, but I'm running a MikroTik device, and their
RouterOS won't support WireGuard until version 7 (which isn't exactly stable at
the time of writing).

The Raspberry must be configured to act as a router. This means that IP
forwarding must be enabled, and the correct firewall rules must be in place.
This is similar to the server configuration described below. Furthermore, a
keepalive setting is necessary to keep the NAT mapping open.

In addition, the `AllowedIPs` section of all peers' WireGuard configs must be
set to allow access to the entire private network range.

# Implementation

The network configuration is implemented as a [systemd
service](https://github.com/tomaskala/infra/blob/master/roles/overlay_network/files/overlay-network.service)
running on my server. The service controls a [shell
script](https://github.com/tomaskala/infra/blob/master/roles/overlay_network/files/overlay-network)
that sets up the network components based on a configuration file described
below. The script really only accepts two commands: one to set up the network,
the other to tear it down.

Because the script only sets up a couple of system options, a service isn't
strictly necessary. However, it provides me with more control over its runtime,
allowing me to easily launch it on startup or stop when necessary. Such kind of
service that only launches a particular program is known as a oneshot service.

# Network structure

The structure of the entire network is configured in a [JSON
file](https://github.com/tomaskala/infra/blob/master/roles/overlay_network/files/overlay-network.json)
that contains the IPv4 and IPv6 ranges of all subnets, IP addresses of the
gateway, and local DNS entries. The control script uses
[jq](https://stedolan.github.io/jq/) to extract the individual entries.

Schematically, the network looks like this (created using
[asciiflow.com](https://asciiflow.com)).
```
                     ┌─────────────────┐
        ┌────────┐ ┌─┤ Internal subnet │
        │        ├─┘ └─────────────────┘
        │ Server │
        │        ├─┐ ┌─────────────────┐
        └────┬───┘ └─┤ Isolated subnet │
             │       └─────────────────┘
     ┌───────┴──────┐
     │ Home gateway │
     └───────┬──────┘
             │      
      ┌──────┴──────┐
      │ Home subnet │
      └─────────────┘
```

* The *Internal subnet* contains my devices with full access to the entire
  network, including full tunneling.
* The *Isolated subnet* is reserved for devices of family members. These are
  trusted in the sense that they can access both the server and the home
  network. They cannot be configured for full tunneling, though (enforced by
  the firewall rules described below). This is so that I don't get banned from
  my VPS provider for network activity beyond my control.
* The *Home gateway* is the Raspberry Pi connected to the server through the
  VPN.
* The *Home subnet* runs the services accessible from all devices in the
  network.

# Network configuration components

The remainder of this posts describes what needs to be done to setup the
network control on the server. The steps are performed in this order when
starting, and in the reverse order when stopping the network service.

## Nftables entries

First, nftables must be configured in the following way (in addition to the
already configured rules; input to the server is already allowed from the
WireGuard interface).

* Allow forwarding packets from *Internal subnet* to the Internet.
* Allow forwarding packets from *Internal subnet* back to *Internal subnet*.
* Allow forwarding packets from *Isolated subnet* back to *Isolated subnet*.
* Allow forwarding packets from the WireGuard interface to the *Home subnet*.
* Drop everything else.

I tried a few different ways, and eventually settled on pre-configuring empty
sets of IP addresses and address ranges, and the above forwarding rules. The
network control script then simply fills the sets with the correct entries when
starting the service, and flushes them when stopping it.

## Local DNS

The next step is to configure the Unbound resolver to resolve local domains to
the correct IP addresses. This is done by creating a file with the local DNS
records inside the `/etc/unbound/unbound.conf.d` directory, whose content is
set to be automatically included in my [Unbound
config](https://github.com/tomaskala/infra/blob/master/roles/unbound/templates/unbound.conf.j2).

There's an unfortunate situation around TLS certificates. Modern browsers sound
all kinds of alarms when they access a domain with no certificate configured,
regardless of whether the IP address is in an [RFC
1918](https://www.rfc-editor.org/rfc/rfc1918)-reserved range or not.

Of course, a TLS certificate for a site only accessible by trusted computers
in a home network or through a VPN is hardly necessary, but tell that to the
browsers. Naturally, it's not possible to obtain a Let's Encrypt certificate
for a private IP address. Using a self-signed certificate is of no help,
because then the browsers just complain about it being untrusted.

I could reserve a special subdomain of my domain for the home network, get a
Let's Encrypt certificate for that, and enjoy my complaint-free web browsing
experience. My domain is a bit too long as it is, though, and going through
this hassle only to make browsers happy is not worth it.

In the end, I simply didn't configure any certificate at all and I hope that
the HTTPS everywhere Firefox mode won't become mandatory. In turn, this allows
me to use the reserved
[home.arpa.](https://datatracker.ietf.org/doc/html/rfc8375) domain. And no, the
`local.` domain that my NAS insists of using is [not suitable for this
use](https://www.ctrl.blog/entry/homenet-domain-name.html).

## IP forwarding

This step simply enables IPv4 and IPv6 forwarding by setting the
`net.ipv4.ip_forward` and `net.ipv6.conf.all.forwarding` kernel parameters
using the `sysctl` utility.

## IP routes

Finally, IP routes are set so that all packets for the *Home subnet* are routed
via the *Home gateway*.

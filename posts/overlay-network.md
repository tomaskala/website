---
title: Overlay network
date: TODO
---

The next step in my nerdy networking hobby was to expand my [server
configuration](https://tomaskala.com/posts/2022-02-27-server-structure) to
allow access to my home network. Naturally, this involves setting up a VPN and
some way to access it from outside the network.

The motivation is to be able to access my NAS for backups and the nice [web
UI](https://github.com/navidrome/navidrome) over my music collection. In
future, I'll most likely include more services.

I decided to go a step further and set up a kind of an [overlay
network](https://en.wikipedia.org/wiki/Overlay_network). That way, all my
devices will be able to talk to each other and to any device at home,
regardless of where they are. In addition, I can grant access to my family
members' devices so that they can use any service the network provides, while
being separated from my devices.

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
  peer. Since WireGuard doesn't distinguish clients and servers (though the
  terminology often slips), all peers are equal. The server will take care of
  routing packets destined to the home network to the correct peer, which will
  act as a gateway.

The gateway is, unsurprisingly, a Raspberry Pi. Normally, one would install
WireGuard on their router, but I'm running a MikroTik device, and their
RouterOS won't support WireGuard until version 7 (which is not exactly stable
at the time of writing).

# TODO: Configuring RPI as a router. Maybe create the ansible role and link it here?

# Implementation

The network configuration is implemented as a [systemd
service](https://github.com/tomaskala/infra/blob/master/roles/overlay_network/files/overlay-network.service)
running on my server. The service controls a [shell
script](https://github.com/tomaskala/infra/blob/master/roles/overlay_network/files/overlay-network)
that sets up the network components based on a configuration file described
below. The scripts really only accepts two commands: one to set up the network,
the other to tear it down.

Because the scripts only sets up a couple of system options, a service isn't
strictly necessary. However, it provides me with more control over its runtime,
allowing me to easily launch it on startup or stop when necessary. Such kind of
service that only launches a particular program is known as a oneshot service.

I shamelessly stole this idea from my colleague Tomas Drtina, whom I hereby
thank kindly.

# Network structure

The structure of the entire network is configured in a [JSON
file](https://github.com/tomaskala/infra/blob/master/roles/overlay_network/files/overlay-network.json)
that contains the IPv4 and IPv6 ranges of all subnets as well as local DNS
entries. The control script uses [jq](https://stedolan.github.io/jq/) to
extract the individual entries.

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

* The *Internal subnet* subnet contains my devices with full access to the
  entire network, including full tunneling.
* The *Isolated subnet* subnet is reserved for devices of family members. These
  are trusted in the sense that they can use the server as a router to get to
  the home network through, as well as access the services running directly on
  the server. They cannot be configured for full tunneling, though (enforced by
  the firewall rules described below). This is so that I don't get banned from
  my VPS provider for network activity beyond my control.
* The *Home gateway* is the Raspberry Pi directly connected to the server.
* The *Home subnet* runs the services accessible from all devices in the
  network.

TODO: Why not keep wireguard keys in the config.
TODO: Changing the internal IP address pool?

Set AllowedIPs to the private subnet for all peers.

# Nftables entries

TODO: Describe the rules that make sure full tunneling is not possible from the
isolated network.

# Local DNS

TODO: The trouble with TLS certificates on private domains.

# IP forwarding

# IP routes

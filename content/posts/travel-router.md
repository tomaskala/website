+++
title = 'Travel Router'
date = 2024-06-08T12:58:28+02:00
+++

For a long time, I wanted to setup a travel router that I could take with me on
a vacation, connect to a hotel Wi-Fi and broadcast a private Wi-Fi for my
devices to connect to. Since I'll be taking several working vacations this
year, it seems like the time has finally come, as I'm not comfortable
connecting my work laptop to a public network. Note that this is pretty much my
personal quirk, because these days, all traffic is secured with TLS and I
access all work resources via a VPN.

The easy way out would be to buy a [GL.iNet](https://www.gl-inet.com/) router,
as they have a whole product line of travel routers that come configured out of
the box. Part of the fun is to play with it though, and configuring one from
scratch is just infinitely more satisfying. Instead, I bought a [MikroTik hAP
ac lite](https://mikrotik.com/product/RB952Ui-5ac2nD-TC) and got to work. There
is nothing specific about this particular model, the only thing I wanted was an
access point with 2 radios so that I could support both 2.4 GHz as well as 5
GHz Wi-Fi. I also didn't want one of the higher end models, since it could
happen that the router gets damaged or lost when travelling.

# Use-case

The image below summarizes what I aim to accomplish. Briefly, I want the router
to connect to a public network (either Wi-Fi or Ethernet, if the hotel room
comes with an Ethernet jack) and to support my devices connected, again, over
Wi-Fi or Ethernet, to the router. The router will double as a station (being
connected to a hotel Wi-Fi) and an access point (broadcasting a private Wi-Fi
for my devices).

The router will be connected to my server over WireGuard, and it will forward
all traffic from the private network through this secure tunnel, so that no
unencrypted traffic ever passes through the hotel network. Note that only the
router is a WireGuard peer; none of my devices need to be connected to the
WireGuard server.

```goat
      +-------------------+
      |                   |
      |  Public Internet  |
      |                   |
      +---------+---------+
                |
                |           Normal traffic
                |
         +------+------+
         |             |
         |  My server  |
         |             |
         +-----+ +-----+
               | |
               | |          WireGuard tunnel
               | |
      +--------+ +--------+
      |                   |
      |  Public Internet  |
      |                   |
      +--------+ +--------+
               | |
               | |          WireGuard tunnel
               | |
       +-------+ +-------+
       |                 |
       |  Hotel network  |
       |                 |
       +-------+ +-------+
               | |
               | |          WireGuard through
               | |          Wi-Fi or Ethernet
       +-------+ +-------+
       |                 |
       |  Travel router  |
       |                 |
       +---+---------+---+
           |         |
       +---+         +--+   Wi-Fi or Ethernet
       |                |
+------+-----+    +-----+------+
|            |    |            |
|  Device 1  |    |  Device 2  |
|            |    |            |
+------------+    +------------+
```

The router is connected to an isolated WireGuard interface (called
`wg-passthru`) on the server that does not have access to the server itself or
any of the other WireGuard interfaces. The only thing it's allowed to do is to
pass traffic through the server to the public Internet.

# Attempt 1: RouterOS

I _almost_ got it to work on RouterOS 7 (which supports WireGuard out of the
box). Although the UI does get confusing (why do I have to configure
routing in three different sections?), it still resembles standard networking
configuration on Linux.

I was able to have the router connect to a wireless network and setup a
WireGuard tunnel to the server. It was possible to both ping the server as well
as access the public Internet.

It was also possible to make it broadcast its own wireless network and connect
my devices to it. After a lot of trial end error, I set up routing correctly so
that the setup in the diagram above worked.

The only remaining issue was that I have to run _another_ VPN to access some of
the servers at work, and tunneling another VPN over WireGuard did not make the
router happy at all. The issue was most likely caused by MTU being too high,
causing packet fragmentation along the way, but I was unable to resolve it.
There are again several different sections where the MTU can be configured in
RouterOS and none of them did the trick. I eventually gave up and moved to...

# Attempt 2: OpenWRT

This provided me with an opportunity to play with yet another piece of tech
that I had been eyeing for a while. Flashing OpenWRT on that thing went mostly
without issues, I followed [this
guide](https://cheat.readthedocs.io/en/latest/mikrotik_openwrt.html). The only
extra step I had to do was to first downgrade from RouterOS 7 to 6, because
MikroTik changed the bootloader in the meantime and the new one did not support
the netboot that OpenWRT requires.

The OpenWRT UI is much leaner than RouterOS. There are not as many
configuration options accessible from LuCI as there are in RouterOS; for more
advanced settings, one has to resort to the CLI and editing configuration
files. However, the settings that LuCI exposes are consistently all in one
place and do not require me to switch between several configuration sections.

It turns out that there is a package implementing pretty much all travel router
functionality:
[travelmate](https://openwrt.org/packages/pkgdata/travelmate). It comes with a
LuCI hook so that a hotel Wi-Fi connection can be set up comfortably from the
UI, and it plays nicely with WireGuard (once installed), taking care of routing
all traffic through the uplink connection. There are even automated scripts for
bypassing captive portals in several prominent hotel chains.

The entire setup took me less than two hours. Setting a lower MTU value to
accommodate for the extra VPN layer turned out to be a non-issue, and I could
enjoy my brand-new travel router.

# Issues

## Avoiding double NAT

At first, I worried that I would need to NAT twice:

1. Once for all the traffic leaving the router towards my server.
2. Second time for all the traffic leaving my server to the public Internet.

This would be a bit inefficient and I looked for a better solution. It turns
out that double NAT isn't necessary, provided that the travel router's internal
subnet is added to the `AllowedIPs` clause of its peer configuration on the
server. Instead of just including the router's WireGuard address like this:
```
AllowedIPs = 10.100.30.10/32
```
I have to also add the subnet which my devices are connected to:
```
AllowedIPs = 10.100.30.10/32, 10.10.10.0/24
```
This creates a routing rule in the server's WireGuard interface which routes
all packets destined for my devices through the tunnel towards the router. That
way, the only NAT rule I need is the one on the server's public interface.

## Speed

Routing all traffic through WireGuard on a small and cheap router (running
OpenWRT instead of the proprietary and optimized MikroTik firmware) comes with
a performance cost.

When connected to a 5 GHz Wi-Fi and running RouterOS 7 without WireGuard, I was
able to reach about 100 Mbps on my laptop. That by itself isn't much, but
remember that the traffic goes from the laptop over a Wi-Fi to the travel
router, over one more Wi-Fi to the main router, and only then to the outside.

With OpenWRT and WireGuard, the speed dropped considerably to about 45 Mbps.
That's a steep decline, but

1. I don't  expect hotel networks themselves to be particularly fast.
2. I really only need to SSH into a few servers or spin up a web application
   for a test run. For that, this is more than enough.

## Captive portals

The travelmate package comes with scripts to bypass captive portals in several
hotel chains, but I don't use those. Instead of writing such a script myself, I
just acknowledge all the conditions the hotel wants me to agree with on my
phone, and then clone its MAC address to the router. From the hotel's point of
view, the device never changed and I can access the Internet freely.

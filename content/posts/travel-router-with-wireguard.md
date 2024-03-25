+++
title = 'Travel Router With Wireguard'
date = 2024-03-24T15:58:28+01:00
draft = true
+++

For a long time, I wanted to setup a travel router that I could take with me 
on a vacation, connect to a hotel Wi-Fi and broadcast my own Wi-Fi for my 
devices to connect to. Since I'll be taking several working vacations this 
year, it seems like the time has finally come, as I'm not comfortable 
connecting to work servers from a public network.

The easy way out would be to buy a [GL.iNet](https://www.gl-inet.com/) router, 
as they have a whole product line of travel routers that come configured out of 
the box. Part of the fun is to play with it though, and configuring one from 
scratch is just infinitely more satisfying. I'm a massive MikroTik fanboy, so I 
bought a [hAP ac lite](https://mikrotik.com/product/RB952Ui-5ac2nD-TC) and got 
to work. There is nothing specific about this particular model, the only thing 
I wanted was an access point with 2 radios so that I could support both 2.4 GHz 
as well as 5 GHz Wi-Fi. I also didn't want one of the higher end models, since 
it could happen that the router gets damaged or lost when travelling.

# Use-case

The image below summarizes what I aim to accomplish. Briefly, I want the router 
to connect to a public network (either Wi-Fi or Ethernet, if the hotel has an 
Ethernet jack) and to support my devices connected, again, over Wi-Fi or 
Ethernet, to the router. Obviously, the router (playing the role of a Wi-Fi 
access point now) should broadcast its own Wi-Fi private to my devices.

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
         +-----+-+-----+                     
               |+|                           
               |+|          WireGuard tunnel 
               |+|                           
      +--------+-+--------+                  
      |                   |                  
      |  Public Internet  |                  
      |                   |                  
      +--------+-+--------+                  
               |+|                           
               |+|          WireGuard tunnel 
               |+|                           
       +-------+-+-------+                   
       |                 |                   
       |  Hotel network  |                   
       |                 |                   
       +-------+-+-------+                   
               |+|                           
               |+|          WireGuard over   
               |+|          Wi-Fi or Ethernet
       +-------+-+-------+                   
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

```
[#] wg set wg2 fwmark 51820
^^^ define a firewall mark on the wg2 interface

[#] ip -4 route add 0.0.0.0/0 dev wg2 table 51820
^^^ the wg table routes all packets to the wg2 interface
[#] ip -4 rule add not fwmark 51820 table 51820
^^^ packets without the mark (not wireguard packets) go to the wg table
[#] ip -4 rule add table main suppress_prefixlength 0
^^^ prefix of length 0 is 0.0.0.0/0, i.e., the default route. this rule routes
    packets using the main table if there aren't specific rules for it (if it 
    didn't use the default route but a configured rule, that rule is respected)

[#] ip -6 route add ::/0 dev wg2 table 51820
[#] ip -6 rule add not fwmark 51820 table 51820
[#] ip -6 rule add table main suppress_prefixlength 0
```

# Router configuration

1. Setup uplink connection (for connecting to the hotel network)
2. Setup local connection (for my devices to connect to)

# WireGuard configuration

1. Create a WireGuard interface
2. Add the server as a WireGuard peer
3. (Not really) Configure firewall

At first, I thought I'd need to NAT all traffic coming from the WireGuard 
interface, because the router is acting as a gateway for all the devices behind 
it. This means that we'd actually be double NATting, because there is another 
NAT rule on the server, making it possible to group multiple devices behind its 
public IP. It turns out that this isn't necessary, provided the travel router's 
internal subnet is added to the `AllowedIPs` clause of its peer configuration 
on the server. Instead of just putting the router's WireGuard address:
```
AllowedIPs = 10.100.30.10/32
```
I also add the subnet which my devices are connected to:
```
AllowedIPs = 10.100.30.10/32, 10.10.10.0/24
```
This creates a routing rule in the server's WireGuard interface, which routes 
any packets destined for my device back through the WireGuard tunnel towards 
the router.

4. Configure routing

Routing 10.10.10.0/24 to `wg0` is a bad idea, because that routes even traffic 
destined to the router (10.10.10.1) to WireGuard. As a consequence, DNS breaks, 
because the router sets itself as the DNS resolver when acting as a DHCP 
server. This led to a very strange situation where I couldn't access any 
website, couldn't ping the router, but could ping my WireGuard server.

# Additional configuration

The above steps are not exhaustive: notably missing is IPv6 configuration, 
router security (firewall, disabling unused services, configuring time 
synchronization, requiring strong crypto, ...), user management, etc. None of 
these settings is specific for a travel router though, and there are plenty of 
guides online for that.

# Issues

## Speed

100 Mbps when connected to a 5 GHz Wi-Fi (no WireGuard), 60 Mbps with WireGuard. 

## Duckduckgo not accessible

This apparently happens with more websites, though I only noticed it here. 
[Duckduckgo](https://duckduckgo.com/) was not accessible when connected to 
WireGuard, even though the domain successfully resolved. After some searching, 
I found this [forum post](https://forum.mikrotik.com/viewtopic.php?t=181476) 
which solved my problem.

In case the post gets taken down, I'll rephrase the issue here. What happens is 
that due to encapsulation, VPN connections have smaller packet size. A large 
packet whose MSS (Maximum Segment Size) exceed that of the VPN connection must 
be fragmented prior to sending. This runs into issues with PMTUD (Path MTU 
Discovery, MTU stands for Maximum Transmission Unit), which is a technique for 
determining the maximum MTU on the path between two hosts, the goal being 
fragmentation avoidance. This works by setting the DF (Don't Fragment) bit in 
an IP packet and sending it to the destination. Any device whose MTU is smaller 
than the packet will drop it and send back an ICMP message "Fragmentation 
Needed". Here we run into issues, because if all packets exceed the size, they 
cannot get fragmented and the whole thing breaks down.

The solution is to add the following mangle rule which will automagically 
change the MSS of an outgoing WireGuard packet to 1300 bytes:
```
/ip firewall mangle 
add out-interface=wg0 protocol=tcp tcp-flags=syn action=change-mss new-mss=1300 chain=forward tcp-mss=1301-65535 passthrough=no
```

## Captive portals

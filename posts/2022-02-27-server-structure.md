---
title: Server structure
date: 2022/02/27
---

In this post, I want to document my server structure. Mostly for myself to have
a reference to come back to, but perhaps someone will find something useful
here. I also want to update this document whenever I add anything new.

I keep my configuration in a [git
repository](https://github.com/tomaskala/infra). This has been evolving
and changing as I set up more stuff, but now, I'm mostly happy with the overall
structure.

At first, the repo was just a bunch of loose configuration files and a long
`README.md` describing how to set the whole thing up. This scaled poorly, and
required me to write a short novel every time I decided to add a new service.

Recently, I made the (painful) switch to [Ansible](https://www.ansible.com/).
Painful, because I really dislike writing YAML for configuration. It always
feels like trying to emulate a proper programming language in a config format
with an ugly syntax and a
[joke](https://www.bram.us/2022/01/11/yaml-the-norway-problem) of a semantics.
On the other hand, I now have the entire configuration specified in a
declarative way, and can go from zero to a fully configured server in a matter
of minutes.

The server itself is a pretty standard VPS running Debian. I tend to name my
devices after Twin Peaks characters, so the server is affectionately called
[Dale](https://en.wikipedia.org/wiki/Dale_Cooper).

Since the server only runs services that I use, I can go crazy securing it,
without caring about whether anyone will be inconvenienced. I mean, *I* will be
inconvenienced, but I've been inconveniencing myself my whole life, so I'm used
to it.

I have a pretty strict
[firewall](https://github.com/tomaskala/infra/blob/master/roles/nftables/templates/nftables_dale.conf.j2)
set up. Debian now uses nftables by default, whose configuration is a joy
compared to iptables. Except for the web server, everything is locked down
behind WireGuard (more on that below).

The rest of the post describes the various services that I have running.

# WireGuard

[WireGuard](https://www.wireguard.com/) is the heart of the entire
infrastructure. It's exactly as performant and easy to configure as advertised,
the precise opposite of OpenVPN. To secure a particular service, I simply
expose it on the WireGuard interface only -- it's like magic. If I ever need to
share some services with friends or family, I simply let them inside the
network.

The primary use-case is to secure the server access. The SSH server is only
accessible from within the VPN, which has the nice side effect of keeping my
logs clean from dumb bots attempting to brute-force their way inside.

In addition, I can set my devices to route all traffic through the VPN tunnel.
Having a secure way to access the internet means that I don't have to feel
dirty every time I use a public network. Of course, some hotels or airports
like to do port blocking, rendering VPN usage impossible. Bypassing that is a
future post and a future side project, though.

Finally, there's the topic of my phone. That's actually the primary reason I
had for setting up the VPN. Due to our corporate security policy, our office
network is monitored, and only traffic to domains blessed by the powers that be
is allowed. That's OK to enforce on company-owned devices like my work laptop.
But there's no way in hell I'll let anyone monitor or limit what I do with my
personal phone, so I keep it connected 24/7 with full tunneling.

# Unbound

I run the [Unbound](https://nlnetlabs.nl/projects/unbound/) DNS resolver,
accessible only inside the VPN. Unbound is exactly the kind of software that I
like: small, extensively tested and audited, has a large community around it,
and does one thing well. My use cases are the following.

## Privacy and security

This one is fairly obvious. I am in full control of the DNS resolver, so I can
set it to never respond with private IP address ranges, to verify DNSSEC
signatures, to send the minimum amount of information to upstream DNS servers,
etc.

I considered setting up DNS over TLS and to pass the queries to another DNS
provider, such as [Quad9](https://www.quad9.net/) or
[Cloudflare](https://www.cloudflare.com/), but so far, I simply recursively
query the root nameservers. Maybe I'll revisit this in the future.

> Update 2022/06/15: I now forward the DNS queries to Quad9 through DNS over
> TLS. It's trivial to configure ([assuming one takes care to validate the
> SNI](https://www.ctrl.blog/entry/unbound-tls-forwarding.html)) and blocks
> potential malware domains from resolving.

## DNS leakage prevention

By default, devices use the default (typically DHCP-provided) DNS servers even
when connected to a VPN. The queries are tunneled through the VPN and then sent
to the DNS server as usual. This means that

1. The DNS provider can still see which domains I access, and can potentially
   block them or hijack the requests.
2. If the network-provided DNS server is only visible inside the network, all
   DNS requests will fail, because they are sent from the other end of the
   tunnel.

The second problem can be bypassed by not routing private IP address ranges
through the WireGuard interface, but this does not solve the first one.

It's trivial to configure WireGuard to use a specific DNS server by adding the
following lines to its configuration:
```
DNS = <server-ip-address-inside-the-vpn>
PostUp = resolvectl dns %i <server-ip-address-inside-the-vpn>; resolvectl domain %i "~."; resolvectl default-route %i true
PreDown = resolvectl revert %i
```
Technically, only the `DNS` line is required, but I'm using `systemd-resolved`,
and without the remaining lines, my computer was still using the DHCP-provided
DNS server. In any case, `resolvconf` must be installed for it to work. The
configuration can be verified on [dnsleaktest.com](https://dnsleaktest.com/).

## Adblocking

Finally, I can prevent certain domains from being resolved. The idea is simple:
provide a list of blocked domains, have the resolver check whether the
currently resolved domain appears in the list, and if so, block it.

That's exactly how [Pi-hole](https://pi-hole.net/) works. I do use Pi-hole on
my home network, but I wanted something more lightweight for the server. Here I
don't really need the (admittedly beautiful) frontend.

The result is a small
[script](https://github.com/tomaskala/infra/blob/master/roles/unbound_blocking/files/fetch-blocklists)
that queries a bunch of blocklists in the `/etc/hosts` file format, converts
each domain into
```
local-zone: "<domain>." redirect
local-data: "<domain>. A 0.0.0.0"
```
and outputs an Unbound-compatible configuration sourced by the main
config. The whole thing runs as a weekly cronjob to ensure the lists are up to
date. By using the `redirect` zone type (as opposed to `deny` or `refuse`), all
subdomains of each domain are dropped as well.

In the past, I attempted for something similar on my computer using the
`/etc/hosts` file. It turns out that the hosts file is [sequentially
scanned](https://unix.stackexchange.com/questions/588184/what-will-happen-if-i-add-1-million-lines-in-etc-hosts)
every time the a request is made, which is quite slow with large blocklists. I
wanted to be sure that nothing like that happens in Unbound. Luckily, Unbound
processes local zones [using a red-black
tree](https://github.com/NLnetLabs/unbound/blob/master/services/localzone.c).

# Nginx

At the moment, [nginx](https://nginx.org/en/) only serves this site and the RSS
reader described below. The configuration is based on the [Mozilla SSL
Configuration Generator](https://ssl-config.mozilla.org/). I went for the
modern configuration, so this site is probably not readable on IE 6 and other
browsers from the stone age. On the other hand, it's perfectly usable in
[Lynx](https://lynx.invisible-island.net/), though you'll miss the nice goblin.

# RSS reader

A minor service, though something I use several times a day. Turns out, RSS is
still not forgotten, and most websites I visit do have a feed. I admit that I
live in a bubble here, because I mostly read blogs of other programmers.

At the moment, I use
[sfeed](https://codemadness.org/sfeed-simple-feed-parser.html). I have a
cronjob that polls the configured websites several times a day, calls the sfeed
HTML conversion utility, and outputs a static webpage.

> Update 2022/06/15: The RSS reader is unused at the moment. I ran into a
> couple of issues with sfeed, and am currently looking for an alternative.
> From time to time, a feed wouldn't get updated, and the frontend wasn't very
> mobile-friendly.

> Update 2023/02/04: I replaced sfeed with 
> [yarr](https://github.com/nkanaev/yarr). This is a delightfully simple feed 
> reader deployed as a standalone binary with an intuitive frontend. I am 
> really happy about it.

# Git

I have all my repositories mirrored to the server. This is mostly for backup in
case GitHub ever decides to fuck me up. Currently, there is no web frontend,
though that might change in the future.

In addition, I synchronize my passwords between my devices over git. I use the
wonderful [pass](https://www.passwordstore.org/) utility for password
management. Even though the passwords are encrypted, I'm still not comfortable
exposing them on the public internet, so this particular repository does not
exist on GitHub.

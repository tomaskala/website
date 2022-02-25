---
title: Server infrastructure
date: TODO
---

In this post, I want to document my server infrastructure. Mostly for myself,
so that I have a reference to come back to, but perhaps someone will find
something useful here. I also want to update this document whenever I add
anything new.

I keep my configuration in a [git
repository](https://github.com/tomaskala/server-config). This has been evolving
and changing as I set up more stuff, but now I'm mostly happy with the format.

At first, the "infrastructure" was a bunch of loose configuration files and a
long README describing how to set the whole thing up. This scaled poorly, and
required me to write a short novel every time I decided to add a new service.

Recently, I made the (painful) switch to [Ansible](https://www.ansible.com/). I
really dislike writing YAML for configuration. It always feels like trying to
emulate a proper programming language in a config format with an ugly syntax
and a [joke](https://www.bram.us/2022/01/11/yaml-the-norway-problem) of a
semantics. On the other hand, I now have the entire configuration specified in
a declarative way, and as long as I keep the Ansible version fixed, it should
remain working.

The server itself is a pretty standard VPS running Debian. I tend to name my
devices after Twin Peaks characters, so the server is affectionately called
[Dale](https://en.wikipedia.org/wiki/Dale_Cooper).

# Security

Since the server only runs services that I use, I can go crazy securing it,
without caring about whether anyone will be inconvenienced. I mean I will be
inconvenienced, but I've been inconveniencing myself my whole life, so I'm used
to it.

I have a pretty strict firewall set up. Debian now uses nftables by default,
whose configuration is a joy compared to iptables. Except for the web server,
everything is locked down behind WireGuard (more on that below).

The SSH server disables all the features that I don't use, such as port, agent
and X11 forwarding. Only public key authentication is allowed, and root login
is disabled. Only newer key exchange, encryption and MAC algorithms are
allowed.

Most of the SSH security settings are actually redundant, since SSH access is
only possible from the VPN. I set this up back when I hadn't used a VPN, and
have since left it unchanged.

# Services

The rest of the post describes the various services that I have running.

## WireGuard

[WireGuard](https://www.wireguard.com/) is the heart of the entire
infrastructure. It's exactly as performant and easy to configure and
advertised, the precise opposite of OpenVPN. If I want to secure a particular
service, I simply expose it only on the WireGuard interface. It's like magic.
If I ever need to share some services with friends or family, I simply let them
inside the network.

The primary use-case is to secure the server access. The SSH server is only
accessible from within the VPN, which has the nice side effect of keeping my
logs clean from dumb bots attempting to brute-force their way inside.

Having a secure way to access the internet also means that I don't have to feel
dirty every time I use a network in a café or a hotel. Of course, some hotels,
airports etc. like to do port blocking, but bypassing that is a future post and
a future side project.

Finally, there's the topic of my phone. That's actually the primary reason I
had for setting up the VPN. Due to our corporate security policy, our work
network is monitored, and only traffic to domains blessed by the powers that be
is allowed. That's is OK to enforce on company-owned devices like my work
laptop. But there's no way in hell I'll let anyone monitor or limit which
websites I visit on my personal phone so I keep it connected to the VPN 24/7.

## Unbound

Inside the VPN, I run the
[Unbound](https://nlnetlabs.nl/projects/unbound/about/) DNS resolver. It's
exactly the kind of software that I like: small, extensively tested, has been
audited, has a large community around it, and does one thing well. There are
several use cases:

### Privacy and security

This one is fairly obvious. I am in full control of the DNS resolver, so I can
set it to never respond with private IP address ranges, verify DNSSEC
signatures, send the minimum amount of information to upstream DNS servers,
etc.

I considered setting up DNS over TLS and to pass the queries to another DNS
provider, such as [Quad9](https://www.quad9.net/) or
[Cloudflare](https://www.cloudflare.com/), but so far, I simply recursively
query the root nameservers. Maybe I'll revisit it in the future.

### Performance

Not that a DNS resolver can be a bottleneck (excluding configuration fuckups),
but it feels nice to squeeze out the maximum from my software. Having a caching
DNS resolver physically close to me means that most DNS queries from my devices
are pretty much instantaneous.

### DNS leakage prevention

By default, devices use the default (typically DHCP-provided) DNS servers even
when connected to a VPN. The queries are tunneled through to the VPN tunnel,
and then sent to the DNS server as usual. This means that the DNS provider can
still see which domains I access, and can potentially block them or hijack the
requests.

WireGuard makes it trivial to configure a DNS server by adding the following
lines to its configuration:
```
DNS = <server-ip-address-inside-the-vpn>
PostUp = resolvectl dns %i <server-ip-address-inside-the-vpn>; resolvectl domain %i "~."; resolvectl default-route %i true
PreDown = resolvectl revert %i
```
Technically, only the `DNS` line is required, but I'm using `systemd-resolved`
and without the remaining lines, my computer was still using the DHCP-provided
DNS server. In any case, `resolvconf` must be installed for it to work.

### Adblocking

Finally, I can prevent certain domains from being resolved. The idea is simple:
provide a list of blocked domains, have the resolver check whether the domain
currently being resolved appears in the list, and if so, block it.

That's exactly how [Pi-hole](https://pi-hole.net/) works. I use Pi-hole on my
home network, but for the server, I wanted something more lightweight, as I
don't really need the (admittedly beautiful) frontend.

The result is a small
[script](https://github.com/tomaskala/server-config/blob/master/roles/unbound/files/fetch-blocklists)
that queries a bunch of blocklists in the `/etc/hosts` file format, converts
each domain into the
```
local-zone: "<domain>." redirect
local-data: "<domain>. A 0.0.0.0"
```
format, and outputs an Unbound-compatible configuration sourced by the main
config. The whole thing runs as a weekly cronjob to ensure the lists are up to
date. By using the `redirect` zone type (as opposed to `deny` or `refuse`), all
subdomains of each domain are dropped as well.

In the past, I attempted to create a similar blocking on my computer using the
`/etc/hosts` file. It turns out that the hosts file is [sequentially
scanned](https://unix.stackexchange.com/questions/588184/what-will-happen-if-i-add-1-million-lines-in-etc-hosts)
every time the a request is made, which is quite slow with large blocklists
like I use. I wanted to be sure that nothing like that happens in Unbound.
Luckily, Unbound [uses a red-black
tree](https://github.com/NLnetLabs/unbound/blob/master/services/localzone.c)
for processing localzones.

Unfortunately, there's only so much a simple DNS solution like this can do to
filter ads, but it's better than nothing.

## Nginx

* This website

## RSS reader

## Git

I have all my repositories mirrored to the server. This is mostly for backup in
case GitHub ever decides to fuck me up. Currently, there is no web frontend,
though that might change in the future.

In addition, I synchronize my passwords between my computers and my phone over
git. I use the wonderful [pass](https://www.passwordstore.org/) utility for
password management. Even though the passwords are encrypted, I'm still not
comfortable exposing them on the public internet, so this particular repository
does not exist on GitHub.

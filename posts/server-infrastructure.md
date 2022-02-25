---
title: Server infrastructure
date: TODO
---

In this post, I want to document my server infrastructure. Mostly for myself,
so that I have a reference to come back to, but perhaps someone will find
something useful here. I also want to update this document whenever I add
anything new to the infrastructure.

I keep my configuration in a [git
repository](https://github.com/tomaskala/server-config). This has been evolving
and changing as I set up more stuff, but now, the overall structure is not
expected to change.

At first, the "infrastructure" was a bunch of loose configuration files and a
long README specifying how to set the whole thing up. This scaled poorly, and
required me to write a short novel every time I decided to add a new service.

Recently, I made the (painful) switch to [Ansible](https://www.ansible.com/). I
really dislike writing YAML for configuration. It always feels like trying to
emulate a proper programming language in an ugly syntax and a
[joke](https://www.bram.us/2022/01/11/yaml-the-norway-problem) of a semantics.
On the other hand, I now have the entire configuration specified in a
declarative way, and as long as I fix the Ansible version, it should remain
working.

The server itself is a pretty standard VPS running Debian. I tend to name my
devices after Twin Peaks characters, so the server is called
[Dale](https://en.wikipedia.org/wiki/Dale_Cooper).

# Security

Since the server only runs services that I use, I can go crazy securing it,
without caring about whether anyone else will be inconvenienced.

I have a pretty strict firewall set up. Debian now uses nftables by default,
whose configuration is a joy compared to iptables.

SSH disables all the features that I don't use, such as port forwarding, agent
forwarding and X11 forwarding. Only public key authentication is allowed, and
root login is disabled. Only newer key exchange, encryption and MAC algorithms
are allowed.

Most of the services are only accessible from behind a VPN, more on that below.
This includes the SSH server, rendering most of its security settings
redundant. I actually set it up back when I hadn't used a VPN. Having a
stricter security can't hurt, however, so I left the config unchanged.

# Services

The rest of the post describes the various services that I have running.

## WireGuard

* Security
* Laptop for security on untrusted networks
* Phone

## Unbound

* Adblocking, auto-update
* News blocking
* No pihole

## Nginx

* This website

## RSS reader

## Git

I have all my repositories mirrored to the server. This is mostly for backup in
case GitHub ever decides to fuck me up. Currently, there is no web frontend for
the repositories, though that might change in the future.

In addition, I synchronize my passwords between my computers and my phone over
git. I use the wonderful [pass](https://www.passwordstore.org/) manager. Even
though they are encrypted, I'm still not comfortable exposing them on the
public internet, so this particular repository does not exist on GitHub.

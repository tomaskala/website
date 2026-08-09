---
title: "Cryptopals - Set 5"
date: 2026-08-09T21:31:54+02:00
draft: true
---

The fourth set of the [cryptopals](https://cryptopals.com/) challenges is different from the previous. It starts by exploring the famous Diffie-Hellman key exchange, followed by playing with the Secure Remote Password (SRP) protocol, and ends with some RSA.

As always, my solutions can be found on [GitHub](https://github.com/tomaskala/cryptopals).

# Lessons learned

TODO

# [Challenge 33](https://cryptopals.com/sets/5/challenges/33)

We begin by implementing the simplest form of the Diffie-Hellman key exchange algorithm, the anonymous Diffie-Hellman. In this scenario, the two sides (Alice and Bob) have no mechanism to authenticate to each other. All they do is exchange parameters in public to derive a shared secret. This form is susceptible to MITM attacks where a third entity (Eve) can capture and edit traffic between Alice and Bob, and derive its own shared secret with each. Eve can then read and relay all traffic between Alice and Bob.

Considering how important Diffie-Hellman is, the algorithm is really simple:

1. Agree on two parameters: `p` (a large prime number) and `g` (a generator of the multiplicative group `Z_p^*`).
2. Alice generates a random number `a mod p`. This is Alice's private key.
3. Bob generates a random number `b mod p`. This is Bob's private key.
4. Alice sends the public key `A = g^a mod p` to Bob.
5. Bob sends the public key `B = g^b mod p` to Alice.
6. Alice computes the shared secret `s = B^a = (g^b)^a = g^(a*b)`.
7. Bob computes the shared secret `s = A^b = (g^a)^b = g^(a*b)`.

At this point, both sides have a shared secret computed using each other's private keys while only revealing the public keys over the unencrypted communication channel. The secret is then run through a hash function (or better yet, a key derivation function) to produce a key to be used in any subsequent cryptographical operations.

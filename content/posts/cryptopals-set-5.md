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
6. Alice computes the shared secret `s = B^a = (g^b)^a = g^(a*b) mod p`.
7. Bob computes the shared secret `s = A^b = (g^a)^b = g^(a*b) mod p`.

At this point, both sides have a shared secret computed using each other's private keys while only revealing the public keys over the unencrypted communication channel. The secret is then run through a hash function (or better yet, a key derivation function) to produce a key to be used in any subsequent cryptographical operations.

# [Challenge 34](https://cryptopals.com/sets/5/challenges/34)

Because the Diffie-Hellman protocol we implemented in challenge 33 is anonymous, it is susceptible to MITM attacks. Neither of the two parties (Alice and Bob) can prove that they are talking to who they think, so Eve can hijack their connection. In this challenge, we implement a particular MITM attack.

The standard MITM attack against anonymous DH key exchange works as follows:

1. Alice sends `p`, `g` and `A = g^a mod p` (the DH parameters and her public key) to Bob.
2. Along the way, Eve captures and drops the packet. Instead, she generates `e_b` (private key to Bob) and sends Bob `p`, `g` and `E_b = g^(e_b) mod p`.
3. Bob replies with his public key `B = g^b mod p`.
4. Eve again captures and drops the packet. This time, she generates `e_a` (private key to Alice) and sends Alice `E_a = g^(e_a) mod p`.

After the hijacked key exchange finishes, the situation is as follows:

1. Alice has `a` (her private key) and `s_a = (E_a)^a = (g^(e_a))^a = g^(a*e_a) mod p` (what she thinks is the shared secret).
2. Bob has `b` (his private key) and `s_b = (E_b)^b = (g^(e_b))^b = g^(b*e_b) mod p` (what he thinks is the shared secret).
3. Eve has `e_a` (her private key for Alice) and `s_a = A^e_a = (g^a)^e_a = g^(a*e_a) mod p` (what Alice thinks is the shared secret).
4. Eve has `e_b` (her private key for Bob) and `s_b = B^e_b = (g^b)^e_b = g^(b*e_b) mod p` (what Bob thinks is the shared secret).

Notice that due to the hijacking, Alice and Bob can no longer communicate, because they each have a different secret. Eve must act as a mediator, decrypting every message from Alice using `s_a`, presumably storing it, and reencrypting it for Bob using `s_b` (and similarly the other way around). The full protocol implemented in the challenge follows the key exchange by using SHA-1 to calculate an AES key from the shared secret and sending an AES-CBC encrypted message between Alice and Bob.

The MITM attack we implement here is slightly different and actually has Eve inject a different parameter instead of generating different keys for Alice and for Bob. That's only a technicality, because we will be playing with parameter injection some more in the next exercise, so it's good to prepare for it. What the protocol looks like is this:

1. Alice sends `p`, `g` and `A = g^a mod p` to Bob.
2. Eve captures and drops the packet. Instead, she sends Bob `p`, `g` and `p` (that is, the prime number `p` is repeated as Alice's public key here).
3. Bob replies with his public key `B = g^b mod p`.
4. Eve again captures and drops the packet. She again sends Alice `p` in place of Bob's public key.

Alice calculates her shared secret as `s = p^a = 0 mod p`. The same holds for Bob: `s = p^b = 0 mod p`. With this parameter injection, Eve can decrypt and read all messages, because she knows they have been encrypted with a key derived from a zero shared secret.

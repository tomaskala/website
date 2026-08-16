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

# [Challenge 35](https://cryptopals.com/sets/5/challenges/35)

We continue playing with parameter injection to the Diffie-Hellman key exchange. This time, we have Eve supply different values of `g`, the group generator, and analyze what effect they have on the shared secret that Alice and Bob agree on.

First, we try `g = 1`. The numbers involved in the key exchange become:

1. Alice's public key: `A = g^a = 1^a = 1 mod p`.
2. Bob's public key: `B = g^b = 1^b = 1 mod p`.
3. Shared secret: `s = A^b = 1^b = 1 mod p` and `s = B^a = 1^a = 1 mod p`.

Next, we try `g = p`. Running the calculations again, we have:

1. Alice's public key: `A = g^a = p^a = 0 mod p`.
2. Bob's public key: `B = g^b = p^b = 0 mod p`.
3. Shared secret: `s = A^b = 0^b = 0 mod p` and `s = B^a = 0^a = 0 mod p`.

Finally, we try `g = p-1`. This one is more interesting. Let's first see what happens when the exponent is 1:

```
g^1 = (p-1)^1 = p-1 mod p
```

Clearly, taking the remainder after dividing `p-1` with `p` is again `p-1`. Let's now try with an exponent of 2:

```
g^2 = (p-1)^2 = (p-1)*(p-1) = p^2 - 2p + 1 = p*p - 2p + 1 = 0*0 - 2*0 + 1 = 1 mod p
```

This generalizes for arbitrary odd or even powers:

```
g^(2k+1) = (p-1)^(2k+1) = (p-1)*(p-1)^(2k) = (p-1)*((p-1)^2)^k = (p-1)*1^k = p-1 mod p

g^(2k) = (p-1)^2k = ((p-1)^2)^k = 1^k = 1 mod p

(k is an arbitrary integer)
```

Eve has to try both secrets to derive the encryption key and pick the one that works.

In each case, Eve can deduce what secret was used to derive the encryption key and decrypt any message she captures. This is mostly an attack with a theoretical value, because as the exercise states, once someone can tamper with the key exchange parameters, chances are they can do something much worse.

# [Challenge 36](https://cryptopals.com/sets/5/challenges/36)

We now move on from Diffie-Hellman and examine the closely related Secure Remote Password (SRP) protocol. It's a client-server protocol whose purpose is again to establish a shared secret between the two parties. What distinguishes it from Diffie-Hellman is the addition of client credentials - an identity and a password. The algorithm was designed so that the password is never revealed to the server. Instead, the server only stores a password-derived cryptographic verifier which is then used to validate the client. If someone steals the verifier, they can mount an offline dictionary attack to try and recover the password. That would allow them to impersonate the server to the client, but not the other way around.

The protocol is kind of involved and the challenge omits a lot of details, but we're not implementing anything production-ready here. It's enough to implement the gist of it to demonstrate how it is related to Diffie-Hellman and to be able to break it in later challenges. What I'll describe below is the minimal version - full details can be found in [RFC-5054](https://datatracker.ietf.org/doc/html/rfc5054). As usual, my implementation doesn't really bother with proper error handling, locks, etc. - we're just playing with cryptography here.

The client and server first agree on common parameters. These include the Diffie-Hellman prime number `p` and generator `g`, and also a value `k`. SRP-6 implemented here uses `k = 3`. The server exposes the following endpoints:

```
register(identity, salt, v):
  store (salt, v) in a lookup table under identity

exchange(identity, A):
  (salt, v) := credentials[identity]
  b := Diffie-Hellman private key
  B := (k*v + g^b) mod p
  u := SHA-256(A || B)
  S := (A * v^u)^b mod p
  K := SHA-256(S)
  session-id := random value
  store (identity, K, salt) in a lookup table under session-id
  return session-id, salt, B

validate(session-id, M1):
  session := sessions[session-id]
  expire sessions[session-id]
  return HMAC-SHA-256(session.key, session.salt) == M1
```

The protocol then proceeds like this:

1. The client derives credentials from its password. Only these credentials will be provided to the server; the password never leaves the client machine.

```
salt := random salt
x := SHA-256(salt || password)
v := g^x mod p
credentials = (salt, v)
```

2. The client calls the `register` endpoint with its identity (for example an email) and the derived credentials.
3. The client later wants to login to the server. It exchanges public keys using the `exchange` endpoint and verifies the login using the `validate` endpoint. The result is a boolean indicating whether the login was successful.

```
a := Diffie-Hellman private key
A := g^a mod p (Diffie-Hellman public key based on a)
session-id, salt, B := server.exchange(identity, A)

u := SHA-256(A || B)
x := SHA-256(salt || password)

S := (B - k*g^x)^(a + u*x) mod p
K := SHA-256(S)

M1 := HMAC-SHA256(K, salt)
server.validate(session-id, M1)
```

The last step is where the algorithm implemented in this challenge differs from the real one. In this setting, the client authenticates to the server, proving that it knows the password. In a real implementation, the server would then authenticate itself to the client and prove that it knows `v` by replying with `M2 = HMAC-SHA256(K, A || M1)`. The two parties would then use the established shared secret `K` to create an encrypted communication channel.

The SRP protocol is quite complex and would deserve a more thorough treatment than this brief description. I might return to it in the future and explore it some more - provide a more realistic implementation and explore its vulnerabilities and security properties.

# [Challenge 37](https://cryptopals.com/sets/5/challenges/37)

It turns out that a naive implementation of the SRP protocol has a fatal flaw. If the client sends a zero (or, equivalently, an integer congruent to the prime number `p`) as its public key, it can trivially log in without knowing the password. Let's see why.

When the server receives the client's public key `A`, it calculates the following:

```
exchange(identity, A):
  (salt, v) := credentials[identity]
  b := Diffie-Hellman private key
  B := (k*v + g^b) mod p
  u := SHA-256(A || B)
  S := (A * v^u)^b mod p
  K := SHA-256(S)
  session-id := random value
  store (identity, K, salt) in a lookup table under session-id
  return session-id, salt, B
```

If `A` is zero, the entire secret becomes `S = (A * v^u)^b mod p = (0 * v^u)^b mod p = 0`. The same holds for `A = n*p`, `n` being an integer, because `mod p` reduces it to zero again. That means that the server calculates the shared secret as `K = SHA-256(0)`. The verification endpoint then reduces to this:

```
validate(session-id, M1):
  session := sessions[session-id]
  expire sessions[session-id]
  return HMAC-SHA-256(SHA-256(0), session.salt) == M1
```

Because the client has (by design) access to the salt, it can send the string `M1 := HMAC-SHA-256(SHA-256(0), salt)` for verification, which trivially passes.

This is a critical flaw, because it allows an attacker to impersonate an arbitrary registered client without knowing its password. The attacker can simply send the client's identifier and a zero public key for the exchange, and then login using a constant hash.

# [Challenge 38](https://cryptopals.com/sets/5/challenges/38)

# [Challenge 39](https://cryptopals.com/sets/5/challenges/39)

# [Challenge 40](https://cryptopals.com/sets/5/challenges/40)

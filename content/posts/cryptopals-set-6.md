---
title: "Cryptopals - Set 6"
date: 2026-08-26T20:50:02+02:00
draft: true
---

The sixth set of the [cryptopals](https://cryptopals.com/) challenges exclusively focuses on RSA and DSA, meaning that the attacks feature more mathematics than before. It's worth it though, because some of the tasks model attacks that can break real cryptography.

As always, my solutions can be found on [GitHub](https://github.com/tomaskala/cryptopals).

# Lessons learned

- Never use RSA without padding. The attacker can manipulate the ciphertext in a way that affects the underlying plaintext ([Challenge 41](#challenge-41httpscryptopalscomsets6challenges41)).
- Padding isn't there just for fun, it needs to be thoroughly checked to make sure it's exactly according to the specification. Also don't use small exponents just to speed up the computations, and while you're at it, don't use obsolete padding schemes ([Challenge 42](#challenge-42httpscryptopalscomsets6challenges42)).
- Be careful about the ranges used to calculate cryptographical parameters. Small values make it easy to enumerate all possibilities and reverse calculations, leaking secret values ([Challenge 43](#challenge-43httpscryptopalscomsets6challenges43)).
- Once again, never reuse nonces. In DSA, a reused nonce allows recovering the private key from a pair of signatures ([Challenge 44](#challenge-44httpscryptopalscomsets6challenges44)).
- DSA is sensitive to parameter hijacking ([Challenge 45](#challenge-45httpscryptopalscomsets6challenges45)).

# [Challenge 41](https://cryptopals.com/sets/6/challenges/41)

We are given a server with three endpoints:

1. `key()`: Return the server's RSA public key.
2. `encrypt(plaintext)`: Encrypt an arbitrary plaintext using RSA.
3. `decrypt(ciphertext)`: Check if the ciphertext was decrypted before. If it was, return an error. Otherwise, decrypt it and return the plaintext.

The server uses textbook RSA encryption, that is, directly converts the message into a number and perform RSA on that (without any padding). Anyone who submits a ciphertext gets the corresponding plaintext back. As a weak mitigation, the server stores every ciphertext upon encryption and refuses to decrypt it again. The assumption here is that once the legitimate user decrypts the ciphertext, nobody else can. Can they?

Turns out they can. Because the messages are unpadded and encrypted as they are, any operation on the ciphertext directly affects the plaintext. The attacker can capture a ciphertext `c` and change it into

```
c' = ((s^e mod N) * c) mod N
```

where `s` is an arbitrary random number greater than 1. The original ciphertext `c` was computed from the plaintext message `m` as

```
c = m^e mod N
```

so `c'` becomes

```
c' = ((s^e mod N) * c) mod N = ((s^e mod N) * (m^e mod N)) mod N = (s^e * m^e) mod N = (s*m)^e mod N
```

or, in other words, the encryption of a different plaintext `m' = s*m`. Because `s > 1`, the ciphertext `c'` differs from `c`, so the server's `decrypt` endpoint accepts it without any issue, and returns the plaintext `m'`. The attacker can easily reverse the math, and recover the original plaintext `m` by calculating

```
m = s^(-1) * m' mod N = s^(-1) * s * m mod N
```

where `s^(-1)` is the multiplicative inverse of `s` modulo `N`.

# [Challenge 42](https://cryptopals.com/sets/6/challenges/42)

The focus of this challenge is a famous attack on the RSA signature algorithm under certain conditions, discovered by Daniel Bleichenbacher. Until now, we were working with RSA encryption - the secret message is encrypted using the public key and decrypted using the private key. With signature, it's the other way around - the publisher of the message signs it with their private key, and anyone who wants to verify the signature does so using the public key.

In reality, we don't encrypt or sign the entire messages, because RSA limits the message length to be at most as long as the key size. Instead, we encrypt either a symmetric key (when encrypting) or sign the message's hash (when signing). Moreover, we don't just plug in the key or the hash into the RSA formulas (this would be the textbook RSA shown to have all kinds of issues). Instead, the message is padded so that it cannot be directly affected by operations on the ciphertext.

Bleichenbacher's attack is valid in a particular scenario where the padding algorithm is PKCS#1 v1.5, the signature checking function doesn't check the padding properly, and the key's public exponent is 3, a value commonly used in the past. Let's investigate what that means.

When the public exponent is 3, the RSA encryption (or, in this case, signature verification) reduces to a simple cubing:

```
c := m^e mod N = m^3 mod N
```

When the message is sufficiently small, cubing it won't exceed the modulus N, meaning that the modulo operation is not applied and the key isn't used at all. Nowadays the most common value of e is 2^16 + 1 = 65537, but historically e=3 was often used to speed up the computation. It isn't unsafe by itself, but when it meets the other bugs described below, it opens an attack vector.

The PKCS#1 v1.5 padding algorithm (no longer recommended, but still sometimes implemented for backwards compatibility) looks like this:

```
padded-message := 0x00 0x01 0xff ... 0xff 0x00 ASN.1 HASH
```

Where

- `ASN.1` contains information about what hash function was used encoded in the [ASN.1](https://en.wikipedia.org/wiki/ASN.1) format.
- `HASH` contains the digest of the message being signed calculated according to an algorithm described in the `ASN.1` part.
- The padding `0xff ... 0xff` contains enough bytes to make `padded-message` as long as the modulus `N`.

Some signature verification implementations do not check the padding properly. In particular, they don't make sure that the `HASH` part is right-aligned, i.e., that no further bytes follow after it (or equivalently, that there is the correct number of the `0xff` bytes). What they permit is the following

```
invalid-padded-message := 0x00 0x01 0xff ... 0xff 0x00 ASN.1 HASH GARBAGE
```

Arbitrary bytes can follow the `HASH` part and the verification function doesn't check them. It turns out that we can utilize them to forge a signature for an arbitrary message without knowing the private key; as long as the public exponent is `e = 3`. Let's see how.

The attacker wishes to forge a signature for a message `m` using a particular hash algorithm (I went for SHA-1 - although it's now known to be broken, it was widely used when the attack was published). They prepare a buffer as long as the modulus `N` (the correct size). They will then fill it like this:

```
buffer := 0x00 0x01 PADDING 0x00 ASN.1 HASH EMPTY
```

Depending on what the verification algorithm checks for, the `PADDING` part can be left out entirely, filled with a single `0xff` byte, or filled with eight `0xff` bytes. The `ASN.1` part encodes the hash function used as usual in the PKCS#1 v1.5 padding, and `HASH = SHA-1(m)` in my case. The `EMPTY` part can contain anything as long as the entire buffer is as long as `N`.

Now the attacker converts the buffer into a big integer. This causes the `0x00 0x01 PADDING 0x00 ASN.1 HASH` parts to appear in the higher-order digits, and the `EMPTY` part in the lower-order digits. They then calculate the integer cube root of this number rounded up, and convert the result back into a byte buffer. The cube root must be rounded up to ensure that when cubed again, the top bytes contain the forged values. When the verifier encrypts the message (which for `e = 3` means cubing it), the initial bytes of the resulting buffer will contain the values provided by the attacker. The `GARBAGE` part will contain a total mess, because our message was very likely not a perfect cube, so calculating a cube root did not result in an exact value. Because the verifier doesn't check whether `HASH` is right-justified (as it should), they won't notice though.

This only works if there's enough space in the buffer, that is, for large enough keys. My attack with SHA-1 broke when I tried it on a 1024-bit key, because there wasn't enough space. It works for a key size of 2048 bits an higher though. Notice that the attacker didn't even need the public key, just knowing the key size is enough. The attack becomes impractical for larger values of `e` than 3, because the larger the exponent, the more `GARBAGE` space is needed to contain the rounding error. That much space would require key sizes far larger than what's used in practice.

# [Challenge 43](https://cryptopals.com/sets/6/challenges/43)

This and the two following challenges center around DSA - Digital Signature Algorithm. Nowadays the algorithm has been deprecated and more modern alternatives based on elliptic curves are preferred. DSA itself isn't broken, but the most commonly used key size of 1024 bits is weak now, and larger sizes aren't widely supported.

DSA uses three parameters called `p` (a large prime number), `q` (a somewhat smaller prime number) and `g`. Their generation is somewhat involved, so the challenge is nice enough to give us pre-computed values. It involves three operations, denoting the private key by `x`, public key by `y`, a message to be signed by `m` and a hash function by `H` (typically SHA-1 - DSA is old):

```
generate-keys(p, q, g):
  x := random choice from [1, ..., q-1]
  y := g^x mod p
  return (x, y)

sign(p, q, g, x, m):
  k := random choice from [1, ..., q-1]
  r := (g^k mod p) mod q

  if r == 0:
    repeat with a different k

  s := (k^(-1) * (H(m) + x*r)) mod q

  if s == 0:
    repeat with a different k

  return (r, s)

verify(p, q, g, y, r, s, m):
  verify 0 < r < q and 0 < s < q
  w := s^(-1) mod q
  u1 := H(m) * w mod q
  u2 := r*w mod q
  v := (g^u1 * y^u2 mod p) mod q
  return v = r
```

Note the number `k` generated in the signing operation. This value is a nonce generated per message, and must never be repeated. That's for the next task though; for now, we focus on something else.

Notice the calculation of `s` in the signing operation can be reversed, allowing an attacker to calculate the private key `x` from a known `k`:

```
x = (r^(-1) * (s*k - H(m))) mod q
```

In this task, we are given a known message `m`, its signature `(r, s)` and a public key `y` to verify the signature. However, the signing operation contained a bug and only generated `k` as a random choice from `[1, ..., 2^16]`. Our goal is to calculate the private key `x`.

There are two ways to calculate a candidate for each possible `k` in the range:

1. A slower method that calculates a possible private key `x` based on the reversed equation above. From that, a public key is calculated as `g^x mod p` and compared with the known public key `y`.
2. A faster method that calculates a possible `r` from the currently enumerated `k` and once it matches the known one, use that `k` to calculate the private key `x`. This can be calculated iteratively by repeatedly multiplying `g` by itself and applying the modulo operations.

Regardless of which method we use, we can quickly crack the private key when the nonce is known to be small.

# [Challenge 44](https://cryptopals.com/sets/6/challenges/44)

Another in the series of challenges showing why reusing a nonce breaks cryptography. In DSA, the value `k` must be generated unique per message; otherwise, anyone can recompute the private key `x` from a message `m` and its signature `(r, s)`.

From the signing operation, the `s` part of the signature is calculated as

```
s = (k^(-1) * (H(m) + x*r)) mod q
```

By its construction, the parameter `r` is the same when calculated using the same nonce `k`, which can serve as an indicator that the nonce was repeated. If we plug in `m1`, `m2`, `s1` and `s2` into the equation for `s` and rearrange, we get

```
x = r^(-1) * (k*s1 - H(m1)) = r^(-1) * (k*s2 - H(m2)) mod q
```

After solving for `k` and simplifying, we get

```
k = (H(m1) - H(m2)) * (s1 - s2)^(-1) mod q
```

With this `k`, we can calculate the private key `x` in exactly the same way as in the previous challenge:

```
x = (r^(-1) * (s1*k - H(m1))) mod q = (r^(-1) * (s2*k - H(m2))) mod q
```

# [Challenge 45](https://cryptopals.com/sets/6/challenges/45)

This challenge has us consider a hypothetical protocol utilizing DSA, where the client is allowed to propose values of the `p`, `q` and `g` parameters. Kind of like TLS or SSH where the two parties agree on common algorithms. This would be unsafe, because a MITM attack could force the client to propose unsafe parameters. The challenge gives two examples.

First, any `g` congruent to 0 modulo `p`. In this case, a message signature is calculated as

```
k := random choice from [1, ..., q-1]
r := (g^k mod p) mod q = 0
s := (k^(-1) * (H(m) + x*r)) mod q = (k^(-1) * H(m)) mod q
```

Verification is done according to

```
w := s^(-1) mod q
u1 := H(m) * w mod q
u2 := r*w mod q = 0
v := (g^u1 * y^u2 mod p) mod q = 0
return v = r
```

We see that the verification always passes, because both `r` and `v` are always zero.

A more interesting situation arises when `g` is congruent to 1 modulo `p`, for instance `g = p+1`. I had to think about this for a while, because the challenge isn't very clear on this. Under these parameters, the public key is always 1: `y = g^x mod p = (p+1)^x mod p = 1`. The challenge didn't make any sense, because the verifier is `v = (g^u1 * y^u2 mod p) mod q = 1`, and the `r` parameter is `r = (g^k mod p) mod q = 1`, so the whole thing reduced to the previous case. What the challenge has in mind but doesn't bother to mention is something else.

The server in this hypothetical protocol has its private key `x` and public key `y` already generated using correct DSA parameters `(p, q, g)`, and they remain constant (like in TLS). The MITM attack hijacks the session, forces the client to use `(p, q, p+1)` instead, and then wants to forge a signature that verifies under the given public key `y`. That is, we want to calculate `r` and `s` such that `verify(p, q, p+1, y, r, s, m)` defined in Challenge 43 passes for any message `m`.

Verification passes if `r = v`, where

```
v := (y^u2 mod p) mod q
u2 := r*w mod q = r * s^(-1) mod q
   => s = r * u2^(-1) mod q
```

We don't really care what `u2` is here. The forgery then works like this, renaming `u2` to `z` to get the same equations the challenge drops on us:

1. We choose an arbitrary value `z`.
2. Calculate `r = (y^z mod p) mod q`.
3. Calculate `s = r * z^(-1) mod q`.

This signature will pass for the given private key `y`, and what's interesting, it doesn't depend on the message itself. Any message will pass under this forged signature.

# [Challenge 46](https://cryptopals.com/sets/6/challenges/46)

As the instructions say, this challenge is a bit of a toy problem, but it sets the stage for the upcoming two challenges. It again shows us why pure number-theoretic encryption is dangerous, or in other words, why it's unsafe to do textbook RSA.

We are given an oracle function that accepts an RSA-encrypted ciphertext, decrypts it, and answers whether the number representing the plaintext is odd or even. Using only repeated queries to this oracle, we can decrypt the entire ciphertext. All because in textbook RSA, a message is just a number, so any mathematical operations performed on the ciphertext directly affect the plaintext.

First of all, the challenge contains an error: it claims that the RSA modulus is a prime number. That's nonsense, because the modulus is explicitly defined as the product of two prime numbers. What they mean is that the modulus is an _odd_ number (unless one of the primes was 2, which is a pathological case). Also, multiplying the ciphertext by `2^e mod N` doubles the _plaintext_, not the ciphertext. With that out of the way, let's see how to attack the oracle.

In RSA, the message `m` is encrypted into the ciphertext `c` using the public key `(e, N)` according to

```
c = m^e mod N
```

Multiplying the ciphertext by any number directly affects the plaintext. Specifically for this challenge, multiplying `c` by `2^e mod N` doubles the plaintext:

```
2^e * c mod N = 2^e * m^e mod N = (2*m)^e mod N
```

If we feed the ciphertext multiplied by `2^e mod N` into the oracle function, we learn 1 bit of information about the plaintext, depending on what the oracle answers:

1. Oracle says the plaintext is even. That means that `2*m mod N` is even, or in other words that the modulo operation did not wrap around. Therefore `2*m < N`, or equivalently, `m < N/2`.
2. Oracle says the plaintext is odd. That means that `2*m mod N` is odd. The number `2*m` obviously cannot be odd, being a multiple of two. That means the modulo operation must have wrapped around, so that the number representing the plaintext is `2*m - N` (a difference of an even and an odd number is odd). This implies `2*m >= N`, or equivalently, `m >= N/2`.

Putting the equality into the "odd" branch is somewhat arbitrary, because `2*m = N` cannot happen: `2*m` is by definition even, and `N` being a product of two prime numbers is always odd (unless one of the primes is 2, which is an edge case that doesn't happen in reality).

Before querying the oracle, all we knew was `0 <= m < N`. After the query, the oracle gave us 1 bit of information, improving our estimate to either `0 <= m < N/2` or `N/2 <= m < N`.

We can repeatedly query the oracle in a process similar to binary search by iteratively doubling the plaintext and tightening the interval, until we eventually recover the plaintext in `log2(N)` steps.

# [Challenge 47](https://cryptopals.com/sets/6/challenges/47)

# [Challenge 48](https://cryptopals.com/sets/6/challenges/48)

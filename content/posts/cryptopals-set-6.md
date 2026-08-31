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
- Once again, never reuse nonces. In DSA, a reused nonce allows recovering the private key from a pair of signatures (([Challenge 44](#challenge-44httpscryptopalscomsets6challenges44))).

# [Challenge 41](https://cryptopals.com/sets/6/challenges/41)

We are given a server with three endpoints:

1. `key()`: Return the server's RSA public key.
2. `encrypt(plaintext)`: Encrypt an arbitrary plaintext using RSA.
3. `decrypt(ciphertext)`: Check if the ciphertext was decrypted before. If it was, return an error. Otherwise, decrypt it and return the plaintext.

The server uses textbook RSA encryption, that is, directly converts the message into a number and perform RSA on that (without any padding). Anyone who submits a ciphertext gets the corresponding plaintext back. As a weak mitigation, the server stores every ciphertext upon encryption and refuses to decrypt it again. The assumption here is that once the legitimate user decrypts the ciphertext, nobody else can. Can they?

Turns out they can. Because the messages are unpadded and encrypted as they are, any operation on the ciphertext directly affects the plaintext. The attacker can capture a ciphertext `C` and change it into

```
C' = ((S^E mod N) * C) mod N
```

where `S` is an arbitrary random number greater than 1. The original ciphertext `C` was computed from the plaintext `P` as

```
C = P^E mod N
```

so `C'` becomes

```
C' = ((S^E mod N) * C) mod N = ((S^E mod N) * (P^E mod N)) mod N = (S^E * P^E) mod N = (S*P)^E mod N
```

or, in other words, the encryption of a different plaintext `P' = S*P`. Because `S > 1`, the ciphertext `C'` differs from `C`, so the server's `decrypt` endpoint accepts it without any issue, and returns the plaintext `P'`. The attacker can easily reverse the math, and recover the original plaintext `P` by calculating

```
P = S^(-1) * P' mod N = S^(-1) * S * P mod N
```

where `S^(-1)` is the multiplicative inverse of `S` modulo `N`.

# [Challenge 42](https://cryptopals.com/sets/6/challenges/42)

The focus of this challenge is a famous attack on the RSA signature algorithm under certain conditions, discovered by Daniel Bleichenbacher. Until now, we were working with RSA encryption - the secret message is encrypted using the public key and decrypted using the private key. With signature, it's the other way around - the publisher of the message signs it with their private key, and anyone who wants to verify the signature does so using the public key.

In reality, we don't encrypt or sign the entire messages, because RSA limits the message length to be at most as long as the key size. Instead, we encrypt either a symmetric key (when encrypting) or sign the message's hash (when signing). Moreover, we don't just plug in the key or the hash into the RSA formulas (this would be the textbook RSA shown to have all kinds of issues). Instead, the message is padded so that it cannot be directly affected by operations on the ciphertext.

Bleichenbacher's attack is valid in a particular scenario where the padding algorithm is PKCS#1 v1.5, the signature checking function doesn't check the padding properly, and the key's public exponent is 3, a value commonly used in the past. Let's investigate what that means.

When the public exponent is 3, the RSA encryption (or, in this case, signature verification) reduces to a simple cubing:

```
c := m^E mod N = m^3 mod N
```

When the message is sufficiently small, cubing it won't exceed the modulus N, meaning that the modulo operation is not applied and the key isn't used at all. Nowadays the most common value of E is 2^16 + 1 = 65537, but historically E=3 was often used to speed up the computation. It isn't unsafe by itself, but when it meets the other bugs described below, it opens an attack vector.

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

Arbitrary bytes can follow the `HASH` part and the verification function doesn't check them. It turns out that we can utilize them to forge a signature for an arbitrary message without knowing the private key; as long as the public exponent is `E = 3`. Let's see how.

The attacker wishes to forge a signature for a message `m` using a particular hash algorithm (I went for SHA-1 - although it's now known to be broken, it was widely used when the attack was published). They prepare a buffer as long as the modulus `N` (the correct size). They will then fill it like this:

```
buffer := 0x00 0x01 PADDING 0x00 ASN.1 HASH EMPTY
```

Depending on what the verification algorithm checks for, the `PADDING` part can be left out entirely, filled with a single `0xff` byte, or filled with eight `0xff` bytes. The `ASN.1` part encodes the hash function used as usual in the PKCS#1 v1.5 padding, and `HASH = SHA-1(m)` in my case. The `EMPTY` part can contain anything as long as the entire buffer is as long as `N`.

Now the attacker converts the buffer into a big integer. This causes the `0x00 0x01 PADDING 0x00 ASN.1 HASH` parts to appear in the higher-order digits, and the `EMPTY` part in the lower-order digits. They then calculate the integer cube root of this number rounded up, and convert the result back into a byte buffer. The cube root must be rounded up to ensure that when cubed again, the top bytes contain the forged values. When the verifier encrypts the message (which for `E = 3` means cubing it), the initial bytes of the resulting buffer will contain the values provided by the attacker. The `GARBAGE` part will contain a total mess, because our message was very likely not a perfect cube, so calculating a cube root did not result in an exact value. Because the verifier doesn't check whether `HASH` is right-justified (as it should), they won't notice though.

This only works if there's enough space in the buffer, that is, for large enough keys. My attack with SHA-1 broke when I tried it on a 1024-bit key, because there wasn't enough space. It works for a key size of 2048 bits an higher though. Notice that the attacker didn't even need the public key, just knowing the key size is enough. The attack becomes impractical for larger values of `E` than 3, because the larger the exponent, the more `GARBAGE` space is needed to contain the rounding error. That much space would require key sizes far larger than what's used in practice.

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

# [Challenge 46](https://cryptopals.com/sets/6/challenges/46)

# [Challenge 47](https://cryptopals.com/sets/6/challenges/47)

# [Challenge 48](https://cryptopals.com/sets/6/challenges/48)

---
title: "Cryptopals - Set 6"
date: 2026-08-26T20:50:02+02:00
draft: true
---

The sixth set of the [cryptopals](https://cryptopals.com/) challenges exclusively focuses on RSA and DSA, meaning that the attacks feature more mathematics than before. It's worth it though, because some of the tasks model attacks that can break real cryptography.

As always, my solutions can be found on [GitHub](https://github.com/tomaskala/cryptopals).

# Lessons learned

- Never use RSA without padding. The attacker can manipulate the ciphertext in a way that affects the underlying plaintext ([Challenge 41](#challenge-41httpscryptopalscomsets6challenges41)).

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

# [Challenge 43](https://cryptopals.com/sets/6/challenges/43)

# [Challenge 44](https://cryptopals.com/sets/6/challenges/44)

# [Challenge 45](https://cryptopals.com/sets/6/challenges/45)

# [Challenge 46](https://cryptopals.com/sets/6/challenges/46)

# [Challenge 47](https://cryptopals.com/sets/6/challenges/47)

# [Challenge 48](https://cryptopals.com/sets/6/challenges/48)

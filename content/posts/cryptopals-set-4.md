---
title: "Cryptopals - Set 4"
date: 2026-07-22T20:27:59+02:00
draft: true
---

The fourth set of the [cryptopals](https://cryptopals.com/) challenges begins by revisiting the CTR and CBC modes of operation that we saw in [Set 2](/posts/cryptopals-set-2) and [Set 3](/posts/cryptopals-set-3). After that, we will implement and break some hash functions - exciting stuff!

As always, my solutions can be found on [GitHub](https://github.com/tomaskala/cryptopals).

# [Challenge 25](https://cryptopals.com/sets/4/challenges/25)

An unknown plaintext has been encrypted using AES-CTR. We can only see the ciphertext and the nonce, not the encryption key. We are also given the following oracle function:

```
edit(ciphertext, offset, new-plaintext):
  - decrypt the ciphertext using the unknown encryption key and the known nonce
  - replace the plaintext with new-plaintext starting at the specified offset
  - encrypt the resulting plaintext using the same unknown encryption key and the same known nonce
  - return the new ciphertext
```

Using only the ciphertext and the `edit` function, we can recover the plaintext.

Suppose we call `ciphertext' := edit(ciphertext, 0, 'A')`. The two ciphertexts differ only in the zeroth byte:

- `ciphertext  = plaintext  XOR keystream` where `plaintext = [b0 b1 b2 ... bN]`
- `ciphertext' = plaintext' XOR keystream` where `plaintext' = [A b1 b2 ... bN]`

If we XOR the zeroth bytes of the two ciphertexts together, we get

```
ciphertext[0] XOR ciphertext'[0] = (b0 XOR keystream[0]) XOR ('A' XOR keystream[0]) = b0 XOR 'A'
```

We see that by again XORing this with the byte `A`, we recover the zeroth byte of the plaintext. We can simply repeat this along the entire ciphertext, modifying one byte at a time. Alternatively, we can speed this up by working with blocks of data, writing and XORing perhaps 16 bytes at a time, or even doing it in one operation and replacing the entire plaintext. We could even get rid of the final XOR with `A` by writing the zero byte instead of `A`, because XORing anything with zero doesn't change the value.

The task models a situation where an encrypted data storage supports edits on a given offset while keeping the data encrypted. The problem is that the nonce is reused between the writes, so all encryption operations use the same keystream. As we saw in the previous set, reusing the nonce has catastrophic consequences.

One possible defense against the attack would be to keep a monotonic write counter and using it as the nonce. That way, every write operation uses a different nonce, and by extension a different keystream.

# [Challenge 26](https://cryptopals.com/sets/4/challenges/26)

# [Challenge 27](https://cryptopals.com/sets/4/challenges/27)

# [Challenge 28](https://cryptopals.com/sets/4/challenges/28)

# [Challenge 29](https://cryptopals.com/sets/4/challenges/29)

# [Challenge 30](https://cryptopals.com/sets/4/challenges/30)

# [Challenge 31](https://cryptopals.com/sets/4/challenges/31)

# [Challenge 32](https://cryptopals.com/sets/4/challenges/32)

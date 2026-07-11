---
title: "Cryptopals - Set 3"
date: 2026-07-10T22:18:00+02:00
draft: true
---

The third set of the [cryptopals](https://cryptopals.com/) challenges starts with the famous CBC padding oracle attack. It then continues with several challenges focused on the CTR mode, which transforms a block cipher into a stream cipher. Finally, we will see why it's a bad idea to use non-cryptographically-secure random generators when doing cryptography. Let's get started!

My solutions can again be found on [GitHub](https://github.com/tomaskala/cryptopals).

# [Challenge 17](https://cryptopals.com/sets/3/challenges/17)

We will implement a famous attack that completely destroys the CBC mode of operation, which we have started breaking in the [previous set](/posts/cryptopals-set-2).

We begin by implementing an oracle that supports two operations:

1. `encrypt()`: Encrypt an unknown plaintext in CBC mode and return the IV and the ciphertext.
2. `padding-valid(iv, ciphertext)`: Accept an IV and a ciphertext, decrypt it internally, and report whether or not its padding is valid.

Neither the encryption key nor the plaintext is ever revealed to us. We use the PKCS#7 padding implemented in the previous sets, but any padding would work. As we will see, we can recover the entire plaintext only by repeatedly querying whether a suitably crafted input has a valid padding.

## Background

The oracle simulates an API that returns different kind of error messages based on whether the padding is wrong or not. We can imagine that there is logic such as
```
endpoint(encrypted-cookie):
  cookie, ok = unpad(decrypt(encrypted-cookie))
  if not ok:
    return "invalid padding"

  user-profile, ok = parse(cookie)
  if not ok:
    return "invalid cookie"

  ... do something with user-profile ...
```

We pass a suitably crafted ciphertext, and receive a different response based on whether the underlying plaintext's padding is valid or not. Because of how we modify the ciphertext, the plaintext will almost certainly become corrupted and fail to parse. That's OK though; all we care about is knowing whether the padding is valid (for example `\x03\x03\x03`) or not (for example `\x01\x02\x03`).

If the endpoint didn't return different error messages for the two cases, we could still utilize timing information - correct padding also has to parse the cookie, so it would take slightly longer than the padding validation by itself.

## Attack

Let's get back to Wikipedia's CBC decryption image: ![CBC-decryption](CBC_decryption.svg)
The attack will be repeated for the individual blocks, so it's enough to focus on the first section where we XOR the IV with the decryption function's output. We will denote the output of the decryption function by `X`, so that in the first part of the picture, we have `X = decrypt(ciphertext, key)` and `IV XOR X = plaintext`. We will calculate the plaintext bytes from the end: start with `plaintext[15]`, then `plaintext[14]`, all the way to `plaintext[0]`. Then we repeat for the next block with the first ciphertext block substituted for the IV, and keep going until we reach the end.

We iterate over all 256 possible values a byte can attain, and set the last byte of the IV to that value. For each value, we call the oracle to see whether the padding is valid. Once we find a `b` such that `padding-valid(IV[0:15] || b, ciphertext)` returns `true`, we stop iterating. At this point, we know the following:

- `padding-valid(IV[0:15] || b, ciphertext) = true` - that's what the oracle just told us.
- `IV XOR X = plaintext` - that's just what we defined `X` to be.
- `X[15] XOR b = 0x01` - that's because the oracle told us the padding is valid, and we are changing just the last byte. Note that there is a small gotcha that we are now ignoring for simplicity.
- `X[15] = b XOR 0x01` - this follows from the previous equality.

At this point, we can recover the last byte of the plaintext block. Because `plaintext = IV XOR X`, we can calculate `plaintext[15] = IV[15] XOR X[15] = IV[15] XOR b XOR 0x01`.

Before decrypting the rest of the block, let's deal with the gotcha that I talked about. It can only happen when calculating the last byte of the plaintext (regardless of the block), so we won't need to worry about it later. If the second to last byte of the plaintext block is `0x02`, we might first find a `b` such that it sets the last byte of the plaintext to `0x02` instead of the `0x01` that we want, producing a valid padding (`\x02\x02` is a valid PKCS#7 padding). This is easy to check though - whenever we are calculating the last byte and obtain a valid padding, we try to scramble the second to last byte of the IV and check the padding once more. If the padding becomes invalid, we know that we have reached a case of `<not-0x02>0x02`, and we have to keep iterating `b` until we find one that sets the last byte of the plaintext to `0x01`.

Let's now calculate the second to last byte of the plaintext block; all the others will be done in a similar way. We start by setting the last IV byte to such a value that the last plaintext byte becomes `0x02`. We can do that:

- We want `IV[15] XOR X[15] = 0x02`.
- This is equivalent to `IV[15] = X[15] XOR 0x02`.
- Because of how we defined `X`, this is `IV[15] = IV[15] XOR plaintext[15] XOR 0x02`, and we have calculated the value `plaintext[15]` in the previous step.

That's almost it. Now we again iterate over all possible `b` between 0 and 255, set `IV[14]` to `b` and stop once the padding oracle tells us that the padding is valid. By repeating the previous step's calculations, we get `plaintext[14] = IV[14] XOR X[14] = IV[14] XOR b XOR 0x02`. We repeat this for the rest of the block, fully decrypting it.

Once we are finished, we continue with the next block, substituting the previous ciphertext block for the IV. For each block, we perform 16 x 256 calculations, so this recovers the plaintext in a linear time with respect to the length of the ciphertext. Pretty neat!

# [Challenge 18](https://cryptopals.com/sets/3/challenges/18)

This task is a preparation for the following two. We implement the CTR mode, which transforms a block cipher into a stream cipher. Perhaps unintuitively, it doesn't actually encrypt the plaintext. Instead, it encrypts an incrementing state, forming blocks of a key stream. This key stream is then XORed with the plaintext, forming the ciphertext (reminiscent of the [one-time pad](https://en.wikipedia.org/wiki/One-time_pad)). The advantage is that we don't need to bother with any padding - when the plaintext ends, we just stop XORing it with the key stream.

The question is how to form the state. If we simply started at 0 and incremented for each byte (or a block), then two plaintexts would get XORed with exactly the same key stream. This is very bad, as the next two challenges will show. Instead, the state consists of two parts concatenated together:

1. The nonce ("number used only once"), which must be unique for each message we encrypt; otherwise, they would be XORed with the same key stream.
2. The counter, which increments for each block.

The other nice thing is that we don't need to write a separate decryption function. Because XOR is symmetric, we can just encrypt the ciphertext with the same key stream to get back the plaintext.

# [Challenge 19](https://cryptopals.com/sets/3/challenges/19)

# [Challenge 20](https://cryptopals.com/sets/3/challenges/20)

# [Challenge 21](https://cryptopals.com/sets/3/challenges/21)

# [Challenge 22](https://cryptopals.com/sets/3/challenges/22)

# [Challenge 23](https://cryptopals.com/sets/3/challenges/23)

# [Challenge 24](https://cryptopals.com/sets/3/challenges/24)

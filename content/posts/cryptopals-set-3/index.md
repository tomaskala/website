---
title: "Cryptopals - Set 3"
date: 2026-07-16T17:16:03+02:00
---

The third set of the [cryptopals](https://cryptopals.com/) challenges starts with the famous CBC padding oracle attack. It then continues with several challenges focused on the CTR mode, which transforms a block cipher into a stream cipher. Finally, we will see why it's a bad idea to use non-cryptographically-secure random generators when doing cryptography. Let's get started!

My solutions can again be found on [GitHub](https://github.com/tomaskala/cryptopals).

# Lessons learned

We continue in learning how broken block ciphers can be. Then we learn how a block cipher can be converted into a stream cipher. Finally, we learn to be very careful around randomness in cryptography.

- Don't use block ciphers in the CBC mode, the ciphertext can be decrypted by utilizing API or timing side-channels ([Challenge 17](#challenge-17httpscryptopalscomsets3challenges17)).
- Any block cipher can be converted into a stream cipher by using the CTR mode of operation, though this isn't the only possible mode ([Challenge 18](#challenge-18httpscryptopalscomsets3challenges18)).
- If you use a stream cipher, you must never reuse the nonce to encrypt multiple messages. This would allow the attacker to decrypt the messages if they know, guess or can analyze something about their contents ([Challenge 19](#challenge-19httpscryptopalscomsets3challenges19), [Challenge 20](#challenge-20httpscryptopalscomsets3challenges20)).
- Use a high-entropy randomness source. Even a cryptographically-secure random generator cannot save you if the attacker can bruteforce the entropy source ([Challenge 22](#challenge-22httpscryptopalscomsets3challenges22), [Challenge 24](#challenge-24httpscryptopalscomsets3challenges24)).
- Don't use non-cryptographically-secure random generators for cryptography. Their operations can be reversed and their state cloned given enough output. This allows the attacker to generate exactly the same secrets as we would ([Challenge 23](#challenge-23httpscryptopalscomsets3challenges23)).
- Although it is technically possible to use a random generator's output as a keystream, don't do it ([Challenge 24](#challenge-24httpscryptopalscomsets3challenges24)).

# [Challenge 17](https://cryptopals.com/sets/3/challenges/17)

We will implement a famous attack that completely destroys the CBC mode of operation, which we have started breaking in the [previous set](/posts/cryptopals-set-2).

We begin by implementing an oracle that supports two operations:

1. `encrypt()`: Encrypt an unknown plaintext in CBC mode and return the IV and the ciphertext.
2. `padding-valid(iv, ciphertext)`: Accept an IV and a ciphertext, decrypt it internally, and report whether or not its padding is valid.

Neither the encryption key nor the plaintext is ever revealed to us. We use the PKCS#7 padding implemented in the previous sets, but any padding would work. As we will see, we can recover the entire plaintext only by repeatedly querying whether a suitably crafted input has a valid padding.

## Background

The oracle simulates an API that returns different kind of error messages based on whether the padding is wrong or not. We can imagine that there is some logic such as
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

We pass a suitably crafted ciphertext, and receive a different response based on whether the underlying plaintext's padding is valid or not. Because of how we modify the ciphertext, it will almost certainly decrypt to some nonsense and fail to parse. That's OK though; all we care about is knowing whether the padding is valid (for example `\x03\x03\x03`) or not (for example `\x01\x02\x03`).

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

The nice thing is that we don't need to write a separate decryption function. Because XOR is symmetric, we can just encrypt the ciphertext with the same key stream to get back the plaintext.

# [Challenge 19](https://cryptopals.com/sets/3/challenges/19)

Challenge 19 has us do manually what Challenge 20 has us then automate, so I'm just going to skip right to that.

# [Challenge 20](https://cryptopals.com/sets/3/challenges/20)

We are given a list of ciphertext that have been each encrypted in the CTR mode. Unfortunately, all encryptions shared the same key and nonce, effectively using the same exact key stream for each. Reusing the encryption key isn't a problem, but as its name suggests, the nonce must never be reused for different messages. We will see how that allows us to recover the plaintexts.

We are given something like this:
```
ciphertext1 = plaintext1 XOR keystream
ciphertext2 = plaintext2 XOR keystream
ciphertext3 = plaintext3 XOR keystream
ciphertext4 = plaintext4 XOR keystream
```

Because the key stream is always the same, all the bytes in the i-th column have been XORed with the same key byte. Does that remind you of anything? That's almost exactly how we broke the Vigenère cipher in the [first set](/posts/cryptopals-set-1). The key doesn't repeat here, but otherwise, we can again recover it byte by byte by considering the individual columns. The only problem is that the further we go, the less data we have: the shorter strings will end, leaving us with only a handful of longer strings to work with. As such, we will typically miss the last few bytes. We can still recover the beginning almost perfectly though.

The lesson here is that if you reuse a nonce for encrypting multiple messages in the CTR mode, your encryption can be trivially broken.

# [Challenge 21](https://cryptopals.com/sets/3/challenges/21)

In this challenge, we implement the famous Mersenne Twister random number generator. Rather than trying to explain how it works, I'll just link its home page with the reference implementation and test vector: <https://www.math.sci.hiroshima-u.ac.jp/m-mat/MT/emt.html>. We will use it in the following challenges to show how unsafe random number generation can break your cryptography.

# [Challenge 22](https://cryptopals.com/sets/3/challenges/22)

We use the current timestamp as the seed to our pseudorandom number generator and show that it can be easily recovered from an observed random value. This attack works against any random number generator, not just the Mersenne Twister. Even using a cryptographically-secure random number generator wouldn't help - the seed simply doesn't have enough entropy. The attacker can simply bruteforce through the (relatively few) possible seeds, run the generator, and compare the generated values. Once they have the seed, they can generate exactly the same random values as us. If we use them to for example create an AES encryption key, we obviously have a problem.

To calculate the entropy, suppose the following:

1. We seed the generator with the current timestamp at the `T1`.
2. The attacker observes the generated value at time `T2`; `T2 > T1`.

Assume we use the usual Unix timestamp that measures the number of non-leap seconds elapsed since 00:00:00 UTC, January 1 1970. The attacker then needs to iterate over all seconds in the interval `[T1, T2]`, instantiate a new MT19937 generator seeded with the current second, and compare its output with the captured random value. That's `T2 - T1 + 1` values in total, whose entropy is `log2(T2 - T1 + 1)` bits. Even if they wait 24 hours before capturing the random output, that's a laughable `log2(86400) ~ 16.4` bits of entropy.

This only works if the attacker knows we are using the MT19937 generator. In practice, they can either guess this based on the language our service is written in (check the standard library and see what generator is used), or try several common generators.

I didn't want the tests to take a long time, so instead of sleeping several seconds and using the Unix timestamp as the seed like the task suggested, I converted everything to milliseconds.

# [Challenge 23](https://cryptopals.com/sets/3/challenges/23)

In this challenge, we see what does it mean that a random number generator isn't cryptographically secure.

## Background

The length of Mersenne Twister state array is 624 32-bit numbers. After initialization, it works by repeating these two phases:

1. Generate 624 pseudorandom numbers by iterating through the state array, applying a tempering operation on each element, and returning the result.
2. Apply a twisting operation on the state array, completely recalculating it.

By observing the full run of 624 generated numbers (before a twist is applied), we can recover the state array. At this point we can clone the generator and keep producing exactly the same output as the original one. If the Mersenne Twister generator is used to generate encryption keys or any other cryptographic material, the attacker can simply capture enough output, clone the generator, and then generate the same keys.

It's improbable that the attacker starts collecting the random data right after the twisting operation has been applied. Instead, they will likely start somewhere inside the twisting period. As long as they capture 2 x 624 generated numbers, they are guaranteed to observe one full run though. They can then recover the state array, make their generator output a number, and compare it to the next captured number. By iterating this process, they will eventually match the output, confirming that the recovered state array is correct.

## Attack

The tempering operation works like this:

```
y0 := state[index]
index := index + 1

y1 := y0 XOR (y0 >> 11)
y2 := y1 XOR ((y1 << 7) AND 0x9d2c5680)
y3 := y2 XOR ((y2 << 15) AND 0xefc60000)
y4 := y3 XOR (y3 >> 18)

return y4
```

We see that it consists of two kinds of operations:

1. XOR a value with itself, shifted to the right.
2. XOR a value with itself, shifted to the left and ANDed with a constant.

Both these operations are reversible. Once we find the reverse, we can apply them to `y4` in reverse order to recover `y0`.

### Inverting the right shift

Let's start with reverting the right shift: `y1 := y0 XOR (y0 >> s)`. At first, it looks like we are losing some information - by shifting a value to the right by `s`, we throw away the `s` least-significant bits. If that was all we were doing, then yes, we would be throwing something away. However, what we are doing on top is XOR this with the original value. Consider this example:

```
Tempering:

      s                = 11 (decimal)
      y0               = 10010110 11011001 00110101 00011101 (binary)
      y0 >> s          = 00000000 00010010 11011011 00100110 (binary)
y1 := y0 XOR (y0 >> s) = 10010110 11001011 11101110 00111011 (binary)
                         ^^^^^^^^ ^^^
                         The s most-significant bits are the same as in y
```

We are given `y1` and `s`, and have to recover `y0`. We see that by being XORed to `s = 11` zeros, the first `s = 11` bits of `y0` get copied to `y1`. The following `s = 11` bits of `y0` are XORed with the first `s = 11` bits of `y0` (because of the shift), so by XORing them again with the same values, we recover the next `s = 11` bits of `y0`. We keep going in this way until the entire `y0` has been recovered. Continuing the example (denoting the recovered bits by `^`):

```
Untempering:

x0 := y1                = 10010110 11001011 11101110 00111011
                          ^^^^^^^^ ^^^
x0 >> s                 = 00000000 00010010 11011001 01111101
x1 := y1 XOR (x0 >> s)  = 10010110 11011001 00110111 01000110
                          ^^^^^^^^ ^^^^^^^^ ^^^^^^
x1 >> s                 = 00000000 00010010 11011011 00100110
x2 := y1 XOR (x1 >> s)  = 10010110 11011001 00110101 00011101
                          ^^^^^^^^ ^^^^^^^^ ^^^^^^^^ ^^^^^^^^
```

The algorithm can be expressed as follows:

```
revert-right-shift(y, s):
  x = y
  for i = 0, ..., 32 / s + 1:
    x = y XOR (x >> s)
  return x
```

### Inverting the left shift

Next, let's look at how to invert the left shift: `y1 := y0 XOR ((y0 << s) AND c)`. This looks scary because the XORed value is further scrambled by ANDing it with a constant, but the approach is almost the same. Let's again look at an example with the same `y0`:

```
Tempering:

      s                      = 7
      c = 0x9d2c5680         = 10011101 00101100 01010110 10000000
      y0                     = 10010110 11011001 00110101 00011101
      y0 << s                = 01101100 10011010 10001110 10000000
      (y0 << s) AND c        = 00001100 00001000 00000110 10000000
y1 := y0 ^ ((y0 << s) AND c) = 10011010 11010001 00110011 10011101
```

Again, we are given `y1`, `s` and `c`, and have to recover `y0`. Similarly to the previous case, we see that the `s = 7` least-significant bits of `y0` get XORed with zeros, getting copied. We use a similar approach and keep shifting the `s = 7` bits, eventually recovering the full `y0`. We just need to take care to AND them with the constant `c` before XORing. Continuing the example (again denoting the recovered bits by `^`):

```
Untempering:

x0 := y1                       = 10011010 11010001 00110011 10011101
                                                             ^^^^^^^
x0 << s                        = 01101000 10011001 11001110 10000000
(x0 << s) AND c                = 00001000 00001000 01000110 10000000
x1 := y1 XOR ((x0 << s) AND c) = 10010010 11011001 01110101 00011101
                                                     ^^^^^^ ^^^^^^^^
x1 << s                        = 01101100 10111010 10001110 10000000
(x1 << s) AND c                = 00001100 00101000 00000110 10000000
x2 := y1 XOR ((x1 << s) AND c) = 10010110 11111001 00110101 00011101
                                             ^^^^^ ^^^^^^^^ ^^^^^^^^
x2 << s                        = 01111100 10011010 10001110 10000000
(x2 << s) AND c                = 00011100 00001000 00000110 10000000
x3 := y1 XOR ((x2 << s) AND c) = 10000110 11011001 00110101 00011101
                                     ^^^^ ^^^^^^^^ ^^^^^^^^ ^^^^^^^^
x3 << s                        = 01101100 10011010 10001110 10000000
(x3 << s) AND c                = 00001100 00001000 00000110 10000000
x4 := y1 XOR ((x3 << s) AND c) = 10010110 11011001 00110101 00011101
                                 ^^^^^^^^ ^^^^^^^^ ^^^^^^^^ ^^^^^^^^
```

The algorithm can be expressed as follows:

```
revert-left-shift(y, s, c):
  x = y
  for i = 0, ..., 32 / s + 1:
    x = y XOR ((x << s) AND c)
  return x
```

## Mitigation

The challenge asks us what would happen if the tempered output was transformed with a cryptographic hash function before returning. Because the whole point of a cryptographic hash function is to not be reversible, this would solve the problem. At the same time, the hashing operation would slow the algorithm down. It also feels like patching a non-cryptographically secure algorithm (by design) to become one. Instead, it would be better to use a generator designed from the start to be cryptographically-secure.

# [Challenge 24](https://cryptopals.com/sets/3/challenges/24)

The last challenge has two parts. In the first one, we use the MT19937 generator's output as a keystream and XOR it with a plaintext to form a ciphertext, kind of like a poor man's stream cipher. There are several problems with this:

1. We saw in the previous challenge that given enough output, the MT19937 generator can be reversed. The attacker could simply feed the cipher a known plaintext, XOR it again with the ciphertext, obtain the key stream, and recompute the original seed from that.
2. The generator uses 32-bit seeds, and 2^32 values can be easily bruteforced.

The challenge makes this even easier by only using a 16-bit seed. Given a plaintext and a ciphertext pair, we can easily try out all the 2^16 possible values, decrypt the ciphertext with the candidate seed, and compare with the plaintext. The challenge actually has us prepend a random prefix before encrypting, but that just means we compare the suffixes instead of the full strings.

In the second part, we use the MT19937 generator to generate a random password reset token, using the Unix timestamp as the seed. Similarly to Challenge 22, there just isn't enough entropy in the current time. We can quickly try out all the values between now and a reasonable value in the past (I went for [now - 60 x 60 x 24 seconds, now]), generate a token with that seed, and compare with the actual token.

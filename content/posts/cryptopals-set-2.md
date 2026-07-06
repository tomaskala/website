---
title: "Cryptopals - Set 2"
date: 2026-07-06T16:40:28+02:00
draft: true
---

The second set of the [cryptopals](https://cryptopals.com/) challenges focuses on block ciphers. All attacks take advantage of padding mistakes or a weak mode of operation, so the fact that the tasks utilize AES isn't important. The lesson here is that no matter how secure your underlying block cipher is, you can still introduce catastrophic security holes by messing up how you combine the blocks together.

Most of the tasks focus on thoroughly breaking the ECB mode, which is the simplest mode of operation imaginable (discussed [before](/posts/cryptopals-set-1)). Towards the end, we also start breaking the CBC mode, which will then be the focus of several challenges in set 3.

As before, my implementation can be found on [GitHub](https://github.com/tomaskala/cryptopals).

# [Challenge 09](https://cryptopals.com/sets/2/challenges/9)

The ninth challenge has us implement the PKCS#7 padding scheme, which is a particular way of padding a message with extra bytes to be a multiple of the cipher's block size.

The PKCS#7 padding scheme works by appending N copies of the byte N, so that `length(message) + N` becomes a multiple of the block size. For example, to pad the message `HELLO` to length 8, we need 3 bytes, and the result will be
```
HELLO\x03\x03\x03
```

The only thing to watch out for is that even when the message length already is a multiple of the block size, we still need to add one full block of padding. This is because if the message happened to end with a valid padding, the unpadding routine would strip it, corrupting the message.

Because we will need an unpadding function later, I went ahead and implemented it as well.

# [Challenge 10](https://cryptopals.com/sets/2/challenges/10)

In the ninth challenge, we implement the [CBC mode of operation](https://en.wikipedia.org/wiki/Block_cipher_mode_of_operation#Cipher_block_chaining_(CBC)). Compared to ECB, the CBC mode no longer makes the individual blocks independent by XORing the previous ciphertext with the current plaintext. The first plaintext block which has no previous ciphertext instead uses a "fake ciphertext" called the initialization vector (IV).

Although it seems like an improvement over ECB, we will later see that the CBC mode is also completely broken, because it allows the attacker to manipulate the plaintext, and under some circumstances, even decrypt it.

# [Challenge 11](https://cryptopals.com/sets/2/challenges/11)

One more preparation task before we start breaking crypto. Here we implement an oracle that randomly encrypts an input we give it under the ECB or CBC mode. It also prepends a random prefix and appends a random suffix to the input before encrypting; their lengths are always between 5 and 10 bytes. Our task is to detect which mode was used by only looking at the ciphertext. This is called a chosen plaintext attack, because we can choose which plaintext the oracle encrypts.

An oracle represents the system we are attacking - we can ask it questions about an input and receive answers, but it has access to information we don't (for example the encryption key).

To detect which mode of operation was used, we take advantage of the fact that ECB always encrypts the same plaintext block to the same ciphertext block. Because AES uses block size of 16 bytes and the first 5-10 bytes are occupied by the random prefix, we pass in 3 x 16 equal bytes (for example the letter 'A'). The first block is completely scrambled by the random prefix, so we throw it away. We then look at the following two blocks of ciphertext. If they are equal, we know the encryption mode was ECB.

We could make the oracle also return which mode was used to be able to unit test it. I ended up just running the detector many times, counting the frequencies of both modes, and checking that they were more or less equal.

# [Challenge 12](https://cryptopals.com/sets/2/challenges/12)

# [Challenge 13](https://cryptopals.com/sets/2/challenges/13)

# [Challenge 14](https://cryptopals.com/sets/2/challenges/14)

# [Challenge 15](https://cryptopals.com/sets/2/challenges/15)

# [Challenge 16](https://cryptopals.com/sets/2/challenges/16)

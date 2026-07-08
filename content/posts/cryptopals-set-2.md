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

We implement an oracle that accepts a plaintext, appends an unknown string to it, encrypt the result under the ECB mode, and returns the resulting ciphertext. It turns out that without knowing the encryption key, we can recover the unknown string by repeated calls to the oracle with suitably crafted input. It works like this:

1. Determine the cipher's block size.

    We know that the oracle is using AES whose block size is 16 bytes, but this makes the solution more general. We try a range of values (I went for 2-64), create a buffer twice as large filled with the letter 'A', and append 'B' to it. We then feed this buffer to the oracle, and use our ECB detection code from Challenge 08. The reason we append 'B' to the buffer of A's is to cover for the case where the unknown suffix happened to start with 'A', messing up our count by one.

2. Build a mapping between encrypted blocks and plaintext bytes.

    Knowing the block size, we can now create a bytestring filled with 'A' that's exactly one letter shorter than the block size. If we feed it to the oracle, it will append the unknown suffix making the first byte appear in the last position of the block. It will then return the corresponding ciphertext. It turns out that we can determine this first byte by a simple dictionary lookup.

    The dictionary will look like this:
    ```
    ciphertext(AAAAAAAAAAAAAAAA) -> A
    ciphertext(AAAAAAAAAAAAAAAB) -> B
    ciphertext(AAAAAAAAAAAAAAAC) -> C
    ...
    ```
    repeating for all 256 possible bytes.

    When we later call the oracle with an input 1 byte shorter, we can isolate the first block and lookup the ciphertext in this dictionary, obtaining the first letter of the unknown suffix.

3. Recover the unknown suffix one byte at a time.

    Rather than attempt to explain this, it might be helpful to see what happens in four interesting scenarios. To make it shorter, we will assume block size of 8 bytes. The unknown suffix is `UNKNOWNSUFFIX`, with padding shown as `P`.

    1. Decrypting the first byte
    ```
    learning the mapping:
    AAAAAAA?
    UNKNOWNS
    UFFIXPPP

    query to the oracle: AAAAAAA
    complete plaintext:  AAAAAAAU NKNOWNSU FFIXPPPP
                         ^^^^^^^^
                         ciphertext of this is the key to the learned mapping
    ```

    2. Decrypting the second byte
    ```
    learning the mapping:
    AAAAAAU?
    NKNOWNSU
    FFIXPPPP

    query to the oracle: AAAAAA
    complete plaintext:  AAAAAAUN KNOWNSUF FIXPPPPP
                         ^^^^^^^^
                         ciphertext of this is the key to the learned mapping
    ```

    3. Decrypting the eight byte (the last in the first block)
    ```
    learning the mapping:
    UNKNOWN?
    SUFFIXPP

    query to the oracle: <empty>
    complete plaintext:  UNKNOWNS UFFIXPPP
                         ^^^^^^^^
                         ciphertext of this is the key to the learned mapping
    ```

    4. Decrypting the ninth byte (the first in the second block)
    ```
    learning the mapping:
    NKNOWNS?
    UFFIXPPP

    query to the oracle: AAAAAAA
    complete plaintext:  AAAAAAAU NKNOWNSU FFIXPPPP
                                  ^^^^^^^^
                                  ciphertext of this is the key to the learned mapping
                         ^^^^^^^^ drop this, we have already processed the first block
    ```

    We see that the padding with A's becomes irrelevant when learning the mapping between the encrypted blocks and the plaintext bytes. It's only necessary at the beginning when we do not yet have a full block's worth of decrypted plaintext. We can build the dictionary key as
    ```
    key = oracle(bytestring[length(bytestring)-block-size:length(bytestring)])[0:block-size]

    where bytestring = (<padding> || <decrypted part of the suffix> || b)
          padding is a string of A's block-size long
          b iterates between 0 and 255 (inclusive)
    ```

    Finally, we need to come up with a formula to determine how many A's to include in the query to the oracle. After a bit of thinking, I came up with
    ```
    block-size - length(decrypted-bytes) - 1 mod block-size
    ```
    This works with the four scenarios above:
    1. `8 - 0 - 1 mod 8 = 7 mod 8 = 7`
    2. `8 - 1 - 1 mod 8 = 6 mod 8 = 6`
    3. `8 - 7 - 1 mod 8 = 0 mod 8 = 0`
    4. `8 - 8 - 1 mod 8 = -1 mod 8 = 7`
    The interpretation is that we need to start with `block-size` A's when we haven't yet decrypted anything, subtract the number of decrypted bytes (because we keep needing fewer A's as we decrypt), subtract 1 (because we need to iterate the last byte), and take the modulo by `block-size` (because we never need more than one full block.

The neat thing here is that because we can query for one byte at a time and all the bytes are independent of each other, the complexity of the attack is linear with respect to the suffix length, not exponential. For each suffix byte, we only need to iterate over 256 possible bytes.

# [Challenge 13](https://cryptopals.com/sets/2/challenges/13)

We are given an API that, given an email address, returns an encrypted URL-encoded cookie that authenticates a user with that email as a regular user. The API itself is well-written and properly escapes all special characters, so we can't just inject arbitrary input to it. Still, because the cookie is encrypted under the ECB mode, we can edit it to instead authenticate as the admin. That is, change
```
AES-ECB(email=foo@bar.com&uid=10&role=user)
```
into
```
AES-ECB(email=foo@bar.com&uid=10&role=admin)
```
without ever decrypting it.

I decided to implement the URL encoding properly using Go's [net/url.Values](https://pkg.go.dev/net/url@go1.26.5#Values) type. This is the correct thing to do, but it complicated the task, because its ordering is non-deterministic (the `Value` type is an alias for `map[string][]string`). I decided to cover two cases - one where the encoding follows the ordering given in the task (`email=foo@bar.com&uid=10&role=user`) and another that I observed (`email=foo@bar.com&role=user&uid=10`). The email was always in the first position, though it wouldn't be difficult to cover more cases.

The attack again takes advantage of the ECB mode encrypting the same blocks to the same ciphertext. This time, we will craft a suitable email input and cut the resulting ciphertext into blocks. We will then rearrange them and obtain a ciphertext representing an admin cookie. I didn't bother with the email input being a valid email address, but it would be trivial to change this.

1. Ordering `email=foo@bar.com&uid=10&role=user`

We need to create one block that begins with `admin` and another block that ends with `role=`. We will then use them to assemble an admin cookie. The `admin` and `role=` strings must be at the block boundaries, because we cannot just slice into the middle of a block - that would completely scramble the contents.

The following two email queries lead to the cookies displayed below them (divided into blocks for readability):
```
email = AAAAAAAAAAadmin
                 block1           block2           block3
cookie = AES-ECB(email=AAAAAAAAAA admin&uid=10&rol e=userPPPPPPPPPP)

email = AAAAAAAAAAAAA
                 block4           block5           block6
cookie = AES-ECB(email=AAAAAAAAAA AAA&uid=10&role= userPPPPPPPPPPPP)
```
We will assemble the admin cookie by combining blocks 1, 5, 2 and 3:
```
admin-cookie = block1 || block5 || block2 || block3
             = email=AAAAAAAAAA AAA&uid=10&role= admin&uid=10&rol e=userPPPPPPPPPP
```

2. Ordering `email=foo@bar.com&role=user&uid=10`

The idea is similar, but we need a slightly different input because of the different ordering:
```
email = AAAAAAAAAAadmin
                 block1           block2           block3
cookie = AES-ECB(email=AAAAAAAAAA admin&uid=10&rol e=userPPPPPPPPPP)

email = AAAA
                 block4           block5
cookie = AES-ECB(email=AAAA&role= user&uid=10PPPPP)
```
The admin cookie is this:
```
admin-cookie = block4 || block2 || block3
             = email=AAAA&role= admin&uid=10&rol e=userPPPPPPPPPP
```

# [Challenge 14](https://cryptopals.com/sets/2/challenges/14)

This challenge is a more difficult variation of Challenge 12. This time, the oracle also prepends a random prefix to the input string before encrypting. Before, the oracle did
```
suffix-oracle(input-string) = AES-ECB(input-string || target-suffix, unknown-key)
```
This time, it does
```
prefix-suffix-oracle(input-string) = AES-ECB(random-prefix || input-string || target-suffix, unknown-key)
```

We know neither the random prefix nor its length. Same as in Challenge 12, we want to retrieve `target-suffix` by repeatedly querying the oracle with a suitably crafted `input-string`. Our goal here is to reduce the challenge to Challenge 12, so that we can reuse our attack.

This would be really easy if we happened to know the length of `random-prefix` and it was a multiple of the block size. We could simply call our attack from Challenge 12 with an oracle function that would look like this:
```
oracle(input-string) = prefix-suffix-oracle(input-string)[prefix-length:]
```
The prefix length being a multiple of the block size is important, and slicing it away otherwise wouldn't work. That's because the bytes exceeding the block size would get encrypted into the same block as the first part of the input string, completely scrambling it, and passing the "AAAAA..." input would no longer work correctly.

Let's now generalize slightly. We will still assume the length is known, but now it's no longer a multiple of the block size. We need to pass enough padding to `prefix-suffix-oracle` from Challenge 12 to reach a block boundary. We will do
```
oracle(input-string) = prefix-suffix-oracle(padding || input-string)[prefix-length + padding-length:]
```
where `padding` is an arbitrary bytestring of `padding-length` bytes, and `padding-length` is `block-size - prefix-length mod block-size`. That is, we need as much padding as there is missing from the prefix length to reach the block size.

All that remains is to find the prefix length. We do this by passing two equal blocks to the oracle, taking again advantage of the fact that ECB encrypts the same plaintext to the same ciphertext. We will then iterate over the ciphertext and detect the position where a block equal to the following block begins. This by itself would again work only if the prefix length was a multiple of the block size, so we will prepend with a padding whose length iterates between 0 and 15 (the AES block size - 1, inclusive). Schematically:
```
prefix-suffix-oracle(padding || AAAAAAAAAAAAAAAA AAAAAAAAAAAAAAAA || S)
where padding is a string of P's padding-length long
      padding-length iterates between 0 and 15 (inclusive)
```
We append an S after the repeated blocks ("separator") just in case the target string begins with the letter A. The prefix length is then `start - padding-length`, where `start` is the index in the ciphertext where the first `AAAAAAAAAAAAAAAA` block begins.

This works under two assumptions:
1. We already know that the block size is 16 (the AES block size). We could instead try a few common values here.
2. The random prefix contains no subsequent repeated blocks. If it did, we could instead detect the repetition starting from the end of the ciphertext. If even the unknown suffix repeated blocks, we would just collect all repetition starts and try them one by one.

# [Challenge 15](https://cryptopals.com/sets/2/challenges/15)

This challenge simply has us implement a PKCS#7 unpad function, which I already implemented in Challenge 09. The function must signal when the padding is invalid; this is something we will use later in Set 3 to implement a CBC padding oracle attack.

# [Challenge 16](https://cryptopals.com/sets/2/challenges/16)

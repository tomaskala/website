---
title: "Cryptopals - Set 1"
date: 2026-07-05T22:58:20+02:00
---

Having worked in cybersecurity for some time now, I thought it might be a good idea to brush up on my cryptography knowledge. I don't know any better resource to get hands on experience than the amazing [cryptopals crypto challenges](https://cryptopals.com/). It's a set of progressively harder cryptographical problems where we implement real-world cryptosystems, play with them, explore their strengths and weaknesses, and ultimately break them. 

I actually attempted to solve them a few years ago, but only got to set 4 before finding something else to do and forgetting about it. This time I decided to document my progress - partly to take note of what I've learned, and partly to keep myself accountable.

My implementation can be found on [GitHub](https://github.com/tomaskala/cryptopals). Overall, I'm aiming for readability rather than idiomatic Go. I mostly don't bother with returning errors and instead panic whenever an assumption isn't met. Similarly, I don't mind allocating memory where a real implementation would accept a pre-allocated buffer.

Because the first set serves as an introduction, there isn't that much to learn from it, so this post is rather short. This will change in the upcoming sets once we get to break some actual cryptography!

# Lessons learned

This set is an introduction, so there aren't that many.

- If you do anything involving cryptography, it's good to get familiar with your language's standard library. For example by doing the cryptopals challenges!
- Don't use ciphers from ancient Rome ([Challenge 03](#challenge-03httpscryptopalscomsets1challenges3)) or from the renaissance ([Challenge 06](#challenge-06httpscryptopalscomsets1challenges6)).
- Don't use block ciphers in the ECB mode, it can be trivially detected ([Challenge 08](#challenge-08httpscryptopalscomsets1challenges8)).

# [Challenge 01](https://cryptopals.com/sets/1/challenges/1)

I think the first challenge just wants us become familiar with our language's standard library and how to call hex- and base64- decoding and encoding functions. It also reminds us to always perform all cryptographical operations on raw bytes instead of strings - we do not want any encoding to get in the way. From cryptography's point of view, all data it operates on are just numerical values, and the fact that they can (sometimes) be interpreted as human-readable strings is just a coincidence.

# [Challenge 02](https://cryptopals.com/sets/1/challenges/2)

The second challenge has us extend the XOR operation (acting on a pair of bytes) to work on same-length buffers.

# [Challenge 03](https://cryptopals.com/sets/1/challenges/3)

The third challenge breaks the [Caesar cipher](https://en.wikipedia.org/wiki/Caesar_cipher), which simply XORs each byte of the plaintext with the same byte (the key). This is trivially broken using frequency analysis if we can guess what language the plaintext is written in.

I downloaded Alice's Adventures in Wonderland from Project Gutenberg, calculated a frequency map of each character, and used it to score each string obtained by XORing the ciphertext with a byte from the range 0-255. The byte maximizing the score of the resulting plaintext is very likely the key.

# [Challenge 04](https://cryptopals.com/sets/1/challenges/4)

The fourth challenge just has us apply the solution to the previous challenge to find out which string in a list was encrypted with the Caesar cipher. This is done by finding the highest-scored key for each one, and then from these, taking the highest-scored string. This assumes that there is only a single Caesar-encrypted string in the list, and that the highest score is always correct (that is, that the frequency map and scoring function are correct).

# [Challenge 05](https://cryptopals.com/sets/1/challenges/5)

The fifth challenge extends the Caesar cipher into the [Vigenère cipher](https://en.wikipedia.org/wiki/Vigen%C3%A8re_cipher). The Vigenère cipher uses an entire string as the key, sliding it along the plaintext and XORing together bytes on corresponding positions. So far, we just encrypt a string given a key, but...

# [Challenge 06](https://cryptopals.com/sets/1/challenges/6)

...the sixth challenge has us break the Vigenère cipher. This isn't difficult, but it's the first challenge that requires more than just a for loop. The solution works like this:

1. Determine the likely key size.

    We do this by considering all possible key size within reasonable bounds (the challenge suggests going between 2 and 40. Zero doesn't make sense, and 1 would recover the Caesar cipher). For each candidate size, we take the two successive blocks and calculate their normalized Hamming distance. The size minimizing this distance is probably the correct one.

    This works because the Hamming distance of bytestrings `a` and `b` is calculated as the population count in `a XOR b`. Because both `plaintextA` and `plaintextB` were XORed with the same key, this becomes
    ```
    a XOR b = (plaintextA XOR key) XOR (plaintextB XOR key) = (plaintextA XOR plaintextB) XOR (key XOR key) = plaintextA XOR plaintextB
    ```
    because XORing anything with itself zeroes it out. The idea here is that when we have the correct key size, we are XORing together plaintext strings from (in this case) the English language. Because English doesn't use all the characters randomly and instead exhibits structure, there will be matching characters which have zero Hamming distance, lowering the resulting score.

    We need to normalize the Hamming distance (divide by the candidate size), because without it, longer blocks would necessarily accumulate more differences than shorter ones. Dividing by the candidate size ensures that the number of differences remains unaffected by the block length considered.

2. Transpose the ciphertext.

    This is a fancy way of saying that we assemble a block of bytes on positions 0, keysize, 2 x keysize, ..., then 1, 1 + keysize, 1 + 2 x keysize, ..., then 2, 2 + keysize, 2 + 2 x keysize, ..., and so on. Schematically, we take the bytestring XORed with the repeating key `key`
    ```
    abcdefghijklmnopqr
    XOR
    keykeykeykeykeykey
    ```
    and transform it into blocks of the form
    ```
    adgjmp <- XORed with k
    behknq <- XORed with e
    cfilor <- XORed with y
    ```

3. Solve as a sequence of Caesar ciphers.

    Because we know that all the bytes in a given column were encrypted by XORing with the same byte, we can find that byte by utilizing the solution to Challenge 03. This allows us to build the key independently byte by byte.

The annoying thing is that the result is highly sensitive to the choice of block lengths in step 1. Even when my solution was correct, I had to play with the block size a bit to detect the correct key length, which affects the remainder of the procedure.

# [Challenge 07](https://cryptopals.com/sets/1/challenges/7)

In the seventh challenge, we finally abandon character-based ciphers. Given our language's AES implementation, we implement the simplest and the most broken mode of operation, the [Electronic Code Book (ECB) mode](https://en.wikipedia.org/wiki/Block_cipher_mode_of_operation#Electronic_codebook_(ECB)).

A block cipher such as AES works on blocks of a particular size (for AES, this is 16 bytes). Given a block of bytes, the cipher will perform an operation (encryption or decryption) on this block and produce another block as the result. Because we are typically interested in working with inputs longer than the cipher's block size, we need a way to extend the operation to longer inputs. A mode of operation describes how to repeatedly apply the cipher's single block operation to inputs longer than the block size.

There are a number of modes of operations, some of which we will explore in future challenges.

ECB is the simplest possible method. We take the input bytestring, split it into blocks, apply the cipher on each block independently, and concatenate the result. For now, we only implement the decryption under this scheme. In the second challenge set, we will see that the ECB mode is completely broken and should never be used.

One notable weakness is that by considering each block independently, the same plaintext blocks will always be encrypted to the same ciphertext blocks. This property gives rise to the famous [ECB penguin](https://words.filippo.io/the-ecb-penguin/).

# [Challenge 08](https://cryptopals.com/sets/1/challenges/8)

In the last challenge of the first set, we are given a list of AES-encrypted ciphertexts and are asked to find which of them was encrypted using the ECB mode. Because the AES cipher has a block size of 16 bytes, we split every ciphertext into 16-byte blocks and count how many times they occur in the ciphertext. The ciphertext where we observe a repeated block is the one encrypted using ECB.

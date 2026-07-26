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

We reimplement the oracle function from Challenge 16, but this time, we encrypt the cookie using AES-CTR. That is, we are given a function

```
ciphertext(input) = AES-CTR(prefix || sanitize(input) || suffix)
```

We again have to edit `ciphertext(input)` so that `;admin=true;` appears in the plaintext.

In Challenge 16, we relied on the fact that editing a ciphertext block under CBC mode performs the same edits in the next ciphertext block (though it completely scrambles the edited block). With the CTR mode, the task is even simpler. Because the ciphertext is constructed by XORing the plaintext with a keystream, any edits we perform on the ciphertext affect the plaintext on the same positions.

We pass an input of the form `AadminAtrueA`, and then edit the ciphertext to change the three A's into `;`, `=` and `;`, respectively. Because the prefix length is 32, we change the ciphertext as follows:

```
ciphertext[32+0] := ciphertext[32+0] XOR 'A' XOR ';'
ciphertext[32+6] := ciphertext[32+6] XOR 'A' XOR '='
ciphertext[32+11] := ciphertext[32+11] XOR 'A' XOR ';'
```

XORing with the A's effectively clears out the plaintext on that position, and again XORing with the desired character places it there.

# [Challenge 27](https://cryptopals.com/sets/4/challenges/27)

One more task to break the CBC mode before we move on to hashing. In this scenario, we are given the following API:

```
key := generate-key()
iv := key

encrypt(plaintext):
  return AES-CBC(plaintext, key, iv)

decrypt(ciphertext):
  plaintext := AES-CBC(ciphertext, key, iv)
  if invalid-ascii(plaintext):
    return error("invalid plaintext: %s", plaintext)
```

There are two issues with it:
1. It reuses the key for the IV. This is the point of the challenge - sometimes, applications reuse the key for IV to save some space and not have to send it alongside the ciphertext. As we will see, this is dangerous, as it allows an attacker to recover the key.
2. When it detects an invalid plaintext (non-printable ASCII characters in this case), it reports the plaintext. This can happen for example when the application doesn't sanitize its error messages before presenting them to the user.

The attack works like this. A regular user calls the `encrypt` endpoint to encrypt a bytestring at least 3 blocks long. An attacker captures the ciphertext, edits it in a suitable way, and sends it to the `decrypt` endpoint. Because the edit messed up the ASCII characters, the endpoint returns an error which includes the decrypted value. This is under the assumption that when the invalid plaintext doesn't carry any sensitive information. However, the attacker carefully crafted the ciphertext in a way that the plaintext reported in the error allows recovering the encryption key.

Suppose the attacker captures a ciphertext consisting of 4 blocks (we use one more than the task suggests, because we would otherwise mess up the padding and had to recompute it).

```
C1 || C2 || C3 || C4
```

They will change it into `C1 || 0 || C1 || C4` and send for decryption. This triggers the error handler, giving back

```
invalid plaintext: P1 || P2 || P3 || P4
```

Remembering how the CBC mode works, we have the following:

```
P1 := IV XOR decrypt(C1) = key XOR decrypt(C1)
P2 := C1 XOR decrypt(C2) = C1 XOR decrypt(0)
P3 := C2 XOR decrypt(C3) = 0 XOR decrypt(C1) = decrypt(C1)
```

By XORing P1 with P3, we get `P1 XOR P3 = (key XOR decrypt(C1)) XOR decrypt(C1) = key`, recovering the encryption key.

# [Challenge 28](https://cryptopals.com/sets/4/challenges/28)

The challenge has us implement the SHA-1 hash function that we will use in the next challenge. We can't just call a standard library function, because we will need to modify the SHA-1 state. I simply took the implementation from the [Go standard library](https://pkg.go.dev/crypto/sha1@go1.26.5) and copied the relevant bits to my project.

We also implement a simple form of keyed hashing, where the secret key is prefixed to the message: `mac := SHA-1(K || M)`. This is notably vulnerable to length-extension attacks. Almost as if it predicted what comes next...

# [Challenge 29](https://cryptopals.com/sets/4/challenges/29)

In this challenge we implement a length extension attack against the SHA-1 hash. Note that SHA-1 is now [completely broken](https://shattered.io/) and shouldn't be used in production, although this challenge focuses on a different kind of attack.

Previously, we have implemented a simple (and broken) keyed hash as

```
mac := SHA-1(K || M)
```

where `K` is the secret key and `M` is the authenticated message.

The SHA-1 works by iteratively modifying a state of 5 32-bit integers denoted `H`. It starts with a constant state `H`, and then iterates over 512-bit-sized batches of the message, applying `H := SHA-1-compression-function(batch, H)`. This way, we can feed the hash function pieces of data one at a time, only requesting the digest once we are finished. To ensure that the total length of the message is a multiple of 512 bits, it is padded before calculating the digest. The digest then becomes the latest value of the state `H`.

Because of the iterative scheme, the hash function is vulnerable to length extension attacks. Suppose we calculate `mac := SHA-1(K || M1)` and send it alongside the message `M1`. If the attacker gets hold of the MAC and the message, they can initialize a new SHA-1 hash function, set its state `H` to the captured value `mac`, and continue hashing arbitrary messages. All that without knowing the secret key `K`. They only need to recalculate the padding - it wasn't a part of the message `M`, but it was used when calculating the final state `H = mac`.

Suppose the attacker wants to extend the message `M` with an additional block `M2`. Without also re-calculating the MAC, the recipient will notice that the MAC doesn't match and reject the message. The whole idea of using a keyed hash function and keeping the key `K` private is for an attacker not to be able to calculate the hash. Yet the length extension attack allows the attacker to do that without ever knowing the key. It works like this:

1. Capture `(mac, M1)`.
2. Initialize the SHA-1 hash function by setting its state `H` to `mac`. At this point, the hash function is set exactly as if it has just calculated `SHA-1(K || M1 || padding)`.
3. Feed the extra block `M2` to the hash function and calculate the digest `new-mac`.
4. Calculate the original padding value `padding`. For this we need to know the lengths of `K` and `M1`. We know the entire message `M1`, so its length is also known. We need to guess the length of the key `K`, but we can just try a range of reasonable values until we get the recipient to accept the message.
5. Create the modified message `new-message := M1 || padding || M2`.
6. Return `(new-mac, new-message)`.

Because of the padding, the new message will be slightly scrambled. However, that might not be a problem, for example if it denotes URL query values. The recipient might simply split them using a separator and iterate over the resulting key-value pairs. Our injected `M2` block might then contain a string such as `admin=true`, and the fact that the previous pair became `key=value<padding-nonsense>` might not be that important.

The question is how to defend against a length extension attack. The possibilities include:
1. Appending the key instead of prepending it: calculate `mac := SHA-1(M || K)` instead of `mac := SHA-1(K || M)`. This is the simplest fix, but it trades one vulnerability for another. If the attacker finds a hash collision `SHA-1(M) = SHA-1(N)` for two different messages `M` and `N`, then it follows that `SHA-1(M || K) = SHA-1(N || K)`. As such, it's more of a theoretical exercise and not something suitable for production use.
2. Using another hash function that isn't vulnerable to length extension attacks, such as SHA-3.
3. Preferably, using HMAC, a scheme immune to length extension attacks, even if the underlying hash function is vulnerable to them. We will see it a little later.

# [Challenge 30](https://cryptopals.com/sets/4/challenges/30)

We repeat exactly the same length extension attack as in Challenge 29, but against the MD4 hash function. MD4 is even more broken than SHA-1 and should never be used, but the purpose of this exercise is just to demonstrate that it is also vulnerable to length extension attacks.

# [Challenge 31](https://cryptopals.com/sets/4/challenges/31)

# [Challenge 32](https://cryptopals.com/sets/4/challenges/32)

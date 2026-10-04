---
title: "Cryptopals - Set 7"
date: 2026-09-20T13:22:38+02:00
draft: true
---

TODO: Introduction

As always, my implementation can be found on [GitHub](https://github.com/tomaskala/cryptopals).

# Lessons learned

- When CBC-MAC is used, the IV must remain fixed. If you allow the attacker to control the IV, they gain full control over the first block of the message ([Challenge 49](#challenge-49httpscryptopalscomsets7challenges49) Part 1).
- CBC-MAC is vulnerable to length-extension attacks ([Challenge 49](#challenge-49httpscryptopalscomsets7challenges49) Part 2).
- Cryptographic hash functions and MACs serve entirely different purposes. Using one in place of the other is a very bad idea ([Challenge 50](#challenge-50httpscryptopalscomsets7challenges50)).
- Compressing a plaintext before encrypting it sounds like a good idea, but it can actually leak information, enabling an attacker to discover a piece of the plaintext under certain scenarios. See the [CRIME](https://en.wikipedia.org/wiki/CRIME) and [BREACH](https://en.wikipedia.org/wiki/BREACH) attacks ([Challenge 51](#challenge-51httpscryptopalscomsets7challenges51)).

# [Challenge 49](https://cryptopals.com/sets/7/challenges/49)

The challenge focuses on CBC-MAC, a way to use block encryption in the CBC mode as a keyed hash algorithm. It works like this:

1. Take the plaintext P.
2. Encrypt P under CBC with the key K, yielding a ciphertext C.
3. Keep only the last ciphertext block which is the MAC.

The challenge has two parts in which we explore some of the CBC-MAC vulnerabilities.

## Part 1: Attacker-controlled IV

Suppose that a banking application communicates with a backend by sending transactions of the form

```
message || IV || MAC
```

The message looks like

```
from=<sender-ID>&to=<recipient-ID>&amount=<number>
```

Assume that the message is properly URL-encoded, so that no special characters may appear in the user-provided values. The client and the server have a previously agreed-upon key K that they use for signing and verification. The server exposes two endpoints:

1. `submit(recipientID, amount)`: An authenticated user submits a recipient ID and an amount, and gets back a transaction of the form above with `sender-ID` equal to the user's account. That is, the user can (obviously) only initiate transactions from their own account.
2. `validate(transaction)`: The server accepts a transaction of the form `message || IV || MAC`. If the signature is correct, it performs the transaction. Otherwise, it rejects it with an error.

In this part of the challenge, the `submit` endpoint generates a per-message IV and sends it along with the transaction. This is a problem, because by giving the attacker control over the IV, they can fully control the first block of the message. Posing as the attacker, we will use this to forge a transaction that will transfer $1,000,000 from a victim's account to ours. The attack works if all user IDs have the same length. These would typically be database IDs where this property holds; I will use the strings `attckr` and `victim` for readability.

We start by calling the `submit` endpoint as expected with our account ID and the expected amount: `submit("attckr", 1000000)`. This gives us a transaction in the following form (assuming AES-CBC, so the key, IV and MAC are all 16 bytes long:

```
from=attckr&to=attckr&amount=1000000 || IV || MAC
```

As a reminder, AES-CBC works like this:

```
C_0 = IV
C_i = AES(P_i XOR C_(i-1))
```

That is, every plaintext block is XORed with the preceding ciphertext block before encrypting, with the IV used for the first block. The MAC then becomes the last ciphertext block `C_n`.

We will craft a new transaction where we substitute the `from` account to the victim. By itself, this would fail the signature validation, because the message has changed from the one that was signed. However, because we are in control of the IV, we can tweak it enough to cancel out our edits to the message, yielding the same MAC as before. The transaction we craft is therefore

```
from=victim&to=attckr&amount=1000000 || IV' || MAC
```

The tampered IV' is created by XORing together the bytes of the original IV, the attacker ID and the victim ID on the positions corresponding to the ID in the message:

```
first block: from=victim&to=a
         IV: abcdefghijklmnop
-----------------------------
        IV': abcdeXXXXXXlmnop

where XXXXX = fghijk XOR attckr XOR victim
```

The MAC calculation then proceeds as

```
C_0 = abcdeXXXXXXlmnop
C_1 = AES(from=victim&to=a XOR abcdeXXXXXXlmnop)
```

XORing together `victim` with `XXXXXX = fghijk XOR attckr XOR victim` cancels out the `victim` bit, leaving in place `fghijl XOR attckr` exactly as if validating the original message block `from=attckr&to=a` for which the MAC is valid.

Leaving the IV in control of the attacker gives them full control over the first block, so when CBC-MAC is used, the IV must remain fixed. This doesn't correct all CBC-MAC vulnerabilities though, as part 2 shows us.

## Part 2: Length-extension attack

Clearly, giving the attacker control over the IV is a bad idea, so we fix it to all zeroes. CBC-MAC is still vulnerable to a length extension attack though, which we will now exploit. The transaction system from part 1 now processes several transactions from the same account in a single message for efficiency. The transaction now looks like this:

```
from=<sender-ID>&tx_list=<transaction-list> || MAC
```

The transaction list consists of semicolon-separated pairs `<recipient-id>:<amount>`. The entire message is also URL-encoded, meaning that the semicolons and colons are replaced by their escaped representations. For example, a message sending $1000 to `rec1` and $2000 to `rec2` from `sndr` would be encoded as

```
from=sndr&tx_list=rec1%3A1000%3Brec2%3A2000 || MAC
```

The setting is the same as before. We as an attacker have captured the message above and want to change it to get some free money. Specifically, we want to append `;atck:100000` (before URL-encoding) and tamper the message enough to make the MAC validate. All we have access to is the captured message and an endpoint that can construct a similar message from our own account. That is, for an arbitrary transaction list, we can construct a message

```
from=atck&tx_list=<transaction-list> || MAC
```

Note that the beginning of the message is fixed - we can (of course) only send money from our own account.

Here's some ASCII art showing what we have captured on the left, and what we would like to append on the right.

```
from=sndr&tx_lis t=rec1%3A1000%3B rec2%3A2000PPPPP │ | ----glue---- | %3Batck%3A100000 ◄─── payload
           │                │                │     │            │                │                 
           ▼                ▼                ▼     │            ▼                ▼                 
  IV=0 ─► XOR    ┌───────► XOR    ┌───────► XOR    │ ┌───────► XOR    ┌───────► XOR                
           │     │          │     │          │     │ │          │     │          │                 
           ▼     │          ▼     │          ▼     │ │          ▼     │          ▼                 
     K ─► AES ───┘    K ─► AES ───┘    K ─► AES ───┼─┘    K ─► AES ───┘    K ─► AES                
                                             │     │                             │                 
                                             ▼     │                             ▼                 
                                            MAC    │                            MAC'
```

The five `P` characters at the end of the last captured block is the padding, itself not a part of the captured message. The `glue` block is there to ensure our message aligns on a block boundary, and its value is entirely arbitrary. We see from the diagram that the way to calculate `MAC'` (the hash we want) is

```
MAC' = AES(payload XOR AES(glue XOR MAC))
```

We cannot directly calculate this, because we don't know the encryption key `K`. The challenge mentions that the attack would be much easier if we had full control over the first block returned from the client endpoint, so let's try that. We could then construct a message like this:

```
| -- block1 -- | %3Batck%3A100000 ◄─── payload
           │                │                 
           ▼                ▼                 
  IV=0 ─► XOR    ┌───────► XOR                
           │     │          │                 
           ▼     │          ▼                 
     K ─► AES ───┘    K ─► AES                
                            │                 
                            ▼                 
                           MAC''
```

Its MAC is calculated as

```
MAC'' = AES(payload XOR AES(block1 XOR IV)) = AES(payload XOR AES(block1 XOR 0)) = AES(payload XOR AES(block1))
```

By comparing the equations for `MAC'` and `MAC''`, we see that by setting `block1 := glue XOR MAC`, we calculate `MAC'`, which is what we wanted all along.

There are two problems with this:

1. We don't have control over the first block, it's always fixed to `from=atck%tx_lis`.
2. Even if we did, the second block wouldn't be equal to our payload. At best, it would be `t=atck%3A100000`. It's missing the URL-encoded semicolon (`%3B`) to separate our payload from the legitimate message.

Problem 1 actually helps us. Because the first block is fixed, we can revert the equation for `block1` and calculate the value for `glue`:

```
block1 := glue XOR MAC <=> glue := block1 XOR MAC
```

We will circumvent problem 2 by sending two recipients, which will ensure a semicolon is present:

```
message := client([{"recipient": "atck", "amount": 1}, {"recipient": "atck", "amount": 100000}])
```

This will result in a message like

```
block1           block2           block3
from=atck%tx_lis t=atck%3A1%3Batc k%3A100000
```

Putting it all together, we need to craft a message like this:

```
|---------- captured message + padding ----------| |-- client endpoint message -|
from=sndr&tx_lis t=rec1%3A1000%3B rec2%3A2000PPPPP (block1 XOR MAC) block2 block3 || MAC''
```

Here `MAC` comes from the initial message we captured and `MAC''` comes from the attacker's query to the client endpoint.

This challenge took me a while, the whole process is pretty convoluted. The success of this attack depends on the server implementation. The padding that has to be included in the tampered message might trigger an error, but the server might also be benevolent and just skip entries it cannot successively parse. This was the same back in the SHA-1 length extension attack in [Set 4](/posts/cryptopals-set-4).

# [Challenge 50](https://cryptopals.com/sets/7/challenges/50)

This challenge focuses on the difference between cryptographic hash functions and MACs, specifically between the guarantees they provide. In short:

- Cryptographic hash functions are public (i.e., there's no secret key involved) that are collision-resistant. It is very hard to find two different strings that hash to the same value.
- MACs are keyed functions that provide message unforgeability. As long as the key is secret, it is very hard to create a valid signature for a message.

CBC-MAC is (as the name suggests) a MAC function but not a cryptographic hash function. We will demonstrate this by creating a valid string that hashes to a given value.

We are given this snippet of JavaScript:

```
alert('MZA who was that?');\n
```

It hashes to `296b8d7cb78a243dda4d0a61d33bbdd1` under CBC-MAC with the key `YELLOW SUBMARINE` and an all-zero IV. Our goal is to create a different JavaScript snippet that alerts `Ayo, the Wu is back!` and hashes to the same value.

Basically we need to take the string `alert('Ayo, the Wu is back!');` and tweak it enough to make it hash to the correct while while ensuring it remains a valid JavaScript snippet. The easiest way is to append a JS comment and hide all the tampering in there.

Schematically, what we will build is something like this:

```
   p1                  p2                                        p3         p4              
 | alert('Ayo, the | | Wu is back!');/* | | PPPPPPPPPPPPPPPP | | <glue> | | **************/P |
          │                  │                    │                │              │        
          ▼                  ▼                    ▼                ▼              ▼        
 IV=0 ─► XOR       ┌──────► XOR        ┌───────► XOR       ┌────► XOR     ┌────► XOR       
          │        │         │         │          │        │       │      │       │        
          ▼        │         ▼         │          ▼        │       ▼      │       ▼        
    K ─► AES ──────┘   K ─► AES ───────┘    K ─► AES ──────┘ K ─► AES ────┘ K ─► AES       
                                                  │                               │        
                                                  ▼                               ▼        
                                                  c                               m
```

The blocks `p1` and `p2` hold the message we want to create and open a comment to hide the tampering in. Because `p2` ends exactly on a block boundary, a full padding block follows. Then block `p3` will contain some garbage bytes (to be determined) that ensure the hash is correct, and `p4` ends the comment. Note that `p4` is one byte shorter than the block size to ensure that it is the last block; if we added one more asterisk, it would have to follow with one full block of padding, which we don't want. We also denote the hash of the padded message by `c`, and the full hash by `m`. We want `m` to be equal to the provided hash `296b8d7cb78a243dda4d0a61d33bbdd1`.

Written out, `m` is calculated as

```
m = E_K(p4 XOR E_K(p3 XOR c))
```

Here `E_K` denotes AES encryption under the key `K`. Denoting the corresponding decryption operation by `D_K`, we can solve this equation for `p3` and obtain exactly the form we need to set it to:

```
p3 = c XOR D_K(p4 XOR D_K(m))
```

The full message is then

```
alert('Ayo, the Wu is back!');/* || <padding> || p3 || p4
```

# [Challenge 51](https://cryptopals.com/sets/7/challenges/51)

This challenge models the [CRIME](https://en.wikipedia.org/wiki/CRIME) security vulnerability in TLS, in which a compression side channel is opened that leaks information about secret cookies. If an attacker recovers an authentication cookie, they can steal the user session and impersonate them.

The attacker must be capable of two things in order to successfully launch the attack:

1. Inject chosen plaintext: The attacker can input arbitrary data on behalf of the user into a request. They will use it to take more and more accurate guesses about what the secret cookie's value is.
2. Observe the size of the compressed and encrypted request: The attacker can measure how well their injected data compressed, and use that to improve their cookie guess.

In practice, the attacker manipulates the victim's browser into sending a request with the attacker-controlled payload attached, for example using JavaScript or even an HTML tag. Because the victim's browser sends the request, the correct cookie gets automatically attached. The attacker then just passively observes the request size and infers the cookie from that.

For a concrete example, suppose that the user's request looks like this:

```
POST / HTTP/1.1
Host: hapless.com
Cookie: sessionid=TmV2ZXIgcmV2ZWFsIHRoZSBXdS1UYW5nIFNlY3JldCE=
Content-Length: len(<payload>)
<payload>
```

where `<payload>` is attacker-controlled. This request is first compressed and then encrypted by the TLS protocol before being sent to the user.

If an attacker submits a payload of `Cookie: sessionid=T`, it should compress somewhat better than `Cookie: sessionid=S`, because it's a substring of what has actually appeared in the response already. The compression algorithm can just replace it with a back-reference to a string already occurring in the response. As such, the response length of a prefix of the true cookie will compress better than when an invalid cookie value is inputted. That's the whole idea of the attack.

The challenge has two parts. The first one utilizes a stream cipher for encryption, and the second makes the attack a bit more difficult by switching to a block cipher. Let's see both.

## Stream cipher

In this scenario, the server returns a response using this endpoint:

```
oracle(request):
  key := random bytes
  nonce := random bytes
  return aes-ctr(compress(format-request(request)), key, nonce)
```

The attacker can't just start trying out all bytes and hope to match the cookie, because if they happened to pass, say, `ess`, it would match in both `hapless.com` and in `sessionid`. The compression algorithm would replace the string with a back-reference, and then either `ess.` or `essi` would appear to be valid cookie values. Instead, the attacker must anchor the payload to the correct place by starting with a prefix known to match the cookie. I went with `Cookie: sessionid=`.

The attack proceeds by iteratively trying out all 256 possible bytes, appending them to the anchor, and querying the oracle. The byte minimizing the response length is the correct one, so it gets appended to the recovered cookie, and we proceed with the next byte. The iteration stops once we reach a newline separator.

## Block cipher

The endpoint now changes to

```
oracle(request):
  key := random bytes
  iv := random bytes
  return aes-cbc(pad(compress(format-request(request))), key, iv)
```

Using a block cipher makes the attack slightly more complicated, because the padding messes up our size measurements. Even if we manage to save 1 byte by taking the correct guess and compressing it, the result will still have the same length, because it will be padded to the same multiple of 16 bytes as a wrong guess would. The only exception is one byte below the block boundary. A wrong guess there will exactly match it, so another full block of padding is needed. On the other hand, a correct guess will compress perfectly, requiring only a single byte of padding to be added.

We keep prepending an increasing number of random bytes to the payload; these should compress poorly and as such each add one to the compressed length. Eventually they will push the payload one byte below the block boundary where our correct guess results in a shorted payload.

# [Challenge 52](https://cryptopals.com/sets/7/challenges/52)

# [Challenge 53](https://cryptopals.com/sets/7/challenges/53)

# [Challenge 54](https://cryptopals.com/sets/7/challenges/54)

# [Challenge 55](https://cryptopals.com/sets/7/challenges/55)

# [Challenge 56](https://cryptopals.com/sets/7/challenges/56)

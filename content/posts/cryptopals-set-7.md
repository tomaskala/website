---
title: "Cryptopals - Set 7"
date: 2026-09-20T13:22:38+02:00
draft: true
---

TODO: Introduction

As always, my implementation can be found on [GitHub](https://github.com/tomaskala/cryptopals).

# Lessons learned

- When CBC-MAC is used, the IV must remain fixed. If you allow the attacker to control the IV, they gain full control over the first block of the message. ([Challenge 49](#challenge-49httpscryptopalscomsets7challenges49) Part 1).

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

# [Challenge 51](https://cryptopals.com/sets/7/challenges/51)

# [Challenge 52](https://cryptopals.com/sets/7/challenges/52)

# [Challenge 53](https://cryptopals.com/sets/7/challenges/53)

# [Challenge 54](https://cryptopals.com/sets/7/challenges/54)

# [Challenge 55](https://cryptopals.com/sets/7/challenges/55)

# [Challenge 56](https://cryptopals.com/sets/7/challenges/56)

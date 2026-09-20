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

# [Challenge 50](https://cryptopals.com/sets/7/challenges/50)

# [Challenge 51](https://cryptopals.com/sets/7/challenges/51)

# [Challenge 52](https://cryptopals.com/sets/7/challenges/52)

# [Challenge 53](https://cryptopals.com/sets/7/challenges/53)

# [Challenge 54](https://cryptopals.com/sets/7/challenges/54)

# [Challenge 55](https://cryptopals.com/sets/7/challenges/55)

# [Challenge 56](https://cryptopals.com/sets/7/challenges/56)

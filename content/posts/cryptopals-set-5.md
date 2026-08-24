---
title: "Cryptopals - Set 5"
date: 2026-08-24T16:40:54+02:00
---

The fifth set of the [cryptopals](https://cryptopals.com/) challenges is different from the previous, because we now switch from symmetric to asymmetric cryptography. We start by exploring the Diffie-Hellman key exchange and a closely related protocol, Secure Remote Password. Towards the end we implement and explore RSA; this is a bridge to the following set where we will see RSA much more.

As always, my solutions can be found on [GitHub](https://github.com/tomaskala/cryptopals).

# Lessons learned

- Diffie-Hellman is very simple to express, given how important it is ([Challenge 33](#challenge-33httpscryptopalscomsets5challenges33)).
- Anonymous Diffie-Hellman (without any authentication of the two sides) is susceptible to MITM attacks. The MITM can hijack the connection, decrypt and re-transmit messages, or even inject custom parameters ([Challenge 34](#challenge-34httpscryptopalscomsets5challenges34), [Challenge 35](#challenge-35httpscryptopalscomsets5challenges35)). Particular values can make the shared secret trivially guessable ([Challenge 35](#challenge-35httpscryptopalscomsets5challenges35)).
- Although based on Diffie-Hellman, the SRP (Secure Remote Password) protocol is quite complicated ([Challenge 36](#challenge-36httpscryptopalscomsets5challenges36)). Its purpose is to have a client and a server agree on a shared secret after the client proves that it knows a password, without revealing it to the server.
- A naively implemented SRP protocol has a fatal flaw ([Challenge 37](#challenge-37httpscryptopalscomsets5challenges37)). It allows an attacker to impersonate an arbitrary client without knowing their password by sending a zero public key.
- If the SRP protocol didn't mix in the client's password into the server public key, it would reduce to a complicated version of the Diffie-Hellman key exchange and allow an attacker to impersonate the server and run an offline dictionary attack against the client's password ([Challenge 38](#challenge-38httpscryptopalscomsets5challenges38)).
- RSA is also quite simple to express given its importance, although the math is more involved ([Challenge 39](#challenge-39httpscryptopalscomsets5challenges39)). Correctly implementing it is however very difficult.
- Textbook RSA without padding must never be used. If a message is encrypted as it is, it leaks information to the attacker. When the public exponent is small enough, the attacker can gather enough information to decrypt the message. ([Challenge 40](#challenge-40httpscryptopalscomsets5challenges40)).

# [Challenge 33](https://cryptopals.com/sets/5/challenges/33)

We begin by implementing the simplest form of the Diffie-Hellman key exchange algorithm, the anonymous Diffie-Hellman. In this scenario, the two sides (Alice and Bob) have no mechanism to authenticate each other. All they do is exchange parameters in public to derive a shared secret. This form is susceptible to MITM attacks where a third entity (Eve) can capture and edit traffic between Alice and Bob, and derive its own shared secret with each. Eve can then read and relay all traffic between Alice and Bob. We will see the MITM attack in the following two exercises; for now, let's just implement the key exchange.

Considering how important Diffie-Hellman is, the algorithm is really simple:

1. Agree on two parameters: `p` (a large prime number) and `g` (a generator of the multiplicative group `Z_p^*`).
2. Alice generates a random number `a mod p`. This is Alice's private key.
3. Bob generates a random number `b mod p`. This is Bob's private key.
4. Alice sends the public key `A := g^a mod p` to Bob.
5. Bob sends the public key `B := g^b mod p` to Alice.
6. Alice computes the shared secret `s = B^a = (g^b)^a = g^(a*b) mod p`.
7. Bob computes the shared secret `s = A^b = (g^a)^b = g^(a*b) mod p`.

At this point, both sides have a shared secret computed using each other's private keys while only revealing the public keys over the unencrypted communication channel. The secret is then run through a hash function (or better yet, a key derivation function) to produce a key to be used in any subsequent cryptographical operations.

# [Challenge 34](https://cryptopals.com/sets/5/challenges/34)

Because the Diffie-Hellman protocol we implemented in challenge 33 is anonymous, it is susceptible to MITM attacks. Neither of the two parties (Alice and Bob) can prove that they are talking to who they think, so Eve can hijack their connection. In this challenge, we implement a particular MITM scenario.

The standard MITM attack against anonymous DH key exchange works as follows:

1. Alice sends `p`, `g` and `A = g^a mod p` (the DH parameters and her public key) to Bob.
2. Along the way, Eve captures and drops the packet. Instead, she generates `e_b` (private key to Bob) and sends Bob `p`, `g` and `E_b = g^(e_b) mod p`.
3. Bob replies with his public key `B = g^b mod p`.
4. Eve again captures and drops the packet. This time, she generates `e_a` (private key to Alice) and sends Alice `E_a = g^(e_a) mod p`.

After the hijacked key exchange finishes, the situation is as follows:

1. Alice has `a` (her private key) and `s_a = (E_a)^a = (g^(e_a))^a = g^(a*e_a) mod p` (what she thinks is the shared secret).
2. Bob has `b` (his private key) and `s_b = (E_b)^b = (g^(e_b))^b = g^(b*e_b) mod p` (what he thinks is the shared secret).
3. Eve has `e_a` (her private key for Alice) and `s_a = A^e_a = (g^a)^e_a = g^(a*e_a) mod p` (what Alice thinks is the shared secret).
4. Eve has `e_b` (her private key for Bob) and `s_b = B^e_b = (g^b)^e_b = g^(b*e_b) mod p` (what Bob thinks is the shared secret).

Notice that due to the hijacking, Alice and Bob can no longer communicate, because they each have a different secret. Eve must act as a mediator, decrypting every message from Alice using `s_a`, presumably storing it, and reencrypting it for Bob using `s_b` (and similarly the other way around). The full protocol implemented in the challenge follows the key exchange by using SHA-1 to derive an AES key from the shared secret and sending an AES-CBC encrypted message between Alice and Bob.

The MITM attack we implement here is slightly different and actually has Eve inject a different parameter instead of generating different keys for Alice and for Bob. That's only a technicality, because we will be playing with parameter injection some more in the next exercise, so it's good to prepare for it. What the protocol looks like is this:

1. Alice sends `p`, `g` and `A = g^a mod p` to Bob.
2. Eve captures and drops the packet. Instead, she sends Bob `p`, `g` and `p` (that is, the prime number `p` is repeated as Alice's public key here).
3. Bob replies with his public key `B = g^b mod p`.
4. Eve again captures and drops the packet. She again sends Alice `p` in place of Bob's public key.

Alice calculates her shared secret as `s = p^a = 0 mod p`. The same holds for Bob: `s = p^b = 0 mod p`. With this parameter injection, Eve can decrypt and read all messages, because she knows they have been encrypted with a key derived from a zero shared secret.

# [Challenge 35](https://cryptopals.com/sets/5/challenges/35)

We continue playing with parameter injection to the Diffie-Hellman key exchange. This time, we have Eve supply different values of `g`, the group generator, and analyze what effect they have on the shared secret that Alice and Bob agree on.

First, we try `g = 1`. The numbers involved in the key exchange become:

1. Alice's public key: `A = g^a = 1^a = 1 mod p`.
2. Bob's public key: `B = g^b = 1^b = 1 mod p`.
3. Shared secret: `s = A^b = 1^b = 1 mod p` and `s = B^a = 1^a = 1 mod p`.

Next, we try `g = p`. Running the calculations again, we have:

1. Alice's public key: `A = g^a = p^a = 0 mod p`.
2. Bob's public key: `B = g^b = p^b = 0 mod p`.
3. Shared secret: `s = A^b = 0^b = 0 mod p` and `s = B^a = 0^a = 0 mod p`.

Finally, we try `g = p-1`. This one is more interesting. Let's first see what happens when the exponent is 1:

```
g^1 = (p-1)^1 = p-1 mod p
```

Clearly, taking the remainder after dividing `p-1` with `p` is again `p-1`. Let's now try with an exponent of 2:

```
g^2 = (p-1)^2 = (p-1)*(p-1) = p*p - 2p + 1 = 0*0 - 2*0 + 1 = 1 mod p
```

This generalizes for arbitrary odd or even powers:

```
g^(2k+1) = (p-1)^(2k+1) = (p-1)*(p-1)^(2k) = (p-1)*((p-1)^2)^k = (p-1)*1^k = p-1 mod p

g^(2k) = (p-1)^2k = ((p-1)^2)^k = 1^k = 1 mod p

(k is an arbitrary integer)
```

Eve has to try both secrets to derive the encryption key and pick the one that works.

In each case, Eve can deduce what secret was used to derive the encryption key and decrypt any message she captures. This is mostly an attack with a theoretical value, because as the exercise states, once someone can tamper with the key exchange parameters, chances are they can do something much worse.

# [Challenge 36](https://cryptopals.com/sets/5/challenges/36)

We now move on from Diffie-Hellman and examine the closely related Secure Remote Password (SRP) protocol. It's a client-server protocol whose purpose is again to establish a shared secret between the two parties. What distinguishes it from Diffie-Hellman is the addition of client credentials - an identity and a password. The algorithm was designed so that the password is never revealed to the server. Instead, the server only stores a password-derived cryptographic verifier which is then used to validate the client. If someone steals the verifier, they can mount an offline dictionary attack to try and recover the password. That would allow them to impersonate the server to the client, but not the other way around.

The protocol is kind of involved and the challenge omits a lot of details, but we're not implementing anything production-ready here. It's enough to implement the gist of it to demonstrate how it is related to Diffie-Hellman and to be able to break it in later challenges. What I'll describe below is the minimal version - full details can be found in [RFC-5054](https://datatracker.ietf.org/doc/html/rfc5054). As usual, my implementation doesn't really bother with proper error handling, locks, etc. - we're just playing with cryptography here.

The client and server first agree on common parameters. These include the Diffie-Hellman prime number `p` and generator `g`, and also a value `k`. SRP-6 implemented here uses `k = 3`. The server exposes the following endpoints:

```
register(identity, salt, v):
  store (salt, v) in a lookup table under identity

exchange(identity, A):
  (salt, v) := credentials[identity]
  b := Diffie-Hellman private key
  B := (k*v + g^b) mod p
  u := SHA-256(A || B)
  S := (A * v^u)^b mod p
  K := SHA-256(S)
  session-id := random value
  store (identity, K, salt) in a lookup table under session-id
  return session-id, salt, B

validate(session-id, M1):
  session := sessions[session-id]
  expire sessions[session-id]
  return HMAC-SHA-256(session.key, session.salt) == M1
```

The protocol then proceeds like this:

1. The client derives credentials from its password. Only these credentials will be provided to the server; the password never leaves the client machine.

```
salt := random salt
x := SHA-256(salt || password)
v := g^x mod p
credentials = (salt, v)
```

2. The client calls the `register` endpoint with its identity (for example an email) and the derived credentials.
3. The client later wants to login to the server. It exchanges public keys using the `exchange` endpoint and verifies the login using the `validate` endpoint. The result is a boolean indicating whether the login was successful.

```
a := Diffie-Hellman private key
A := g^a mod p (Diffie-Hellman public key based on a)
session-id, salt, B := server.exchange(identity, A)

u := SHA-256(A || B)
x := SHA-256(salt || password)

S := (B - k*g^x)^(a + u*x) mod p
K := SHA-256(S)

M1 := HMAC-SHA256(K, salt)
server.validate(session-id, M1)
```

The last step is where the algorithm implemented in this challenge differs from the real one. In this setting, the client authenticates to the server, proving that it knows the password. In a real implementation, the server would then authenticate itself to the client and prove that it knows `v` by replying with `M2 = HMAC-SHA256(K, A || M1)`. The two parties would then use the established shared secret `S` to create an encrypted communication channel.

Let's calculate the shared secret `S` on both sides to ensure they both end up with the same value.

1. The client calculates

```
S = (B - k*g^x)^(a + u*x) = (k*v + g^b - k*g^x)^(a + u*x) = (k*g^x + g^b - k*g^x)^(a + u*x) = (g^b)^(a + u*x) = (g^b)^a * (g^b)^(u*x) = g^(a*b) * g^(b*u*x) mod p
```

2. The server calculates

```
S = (A * v^u)^b = A^b * (v^u)^b = (g^a)^b * v^(u*b) = g^(a*b) * (g^x)^(u*b) = g^(a*b) * g^(b*u*x) mod p
```

Clearly both values match, so the two sides agree on the same shared secret.

The SRP protocol is quite complex and would deserve a more thorough treatment than this brief description. I might return to it in the future and explore it some more - provide a more realistic implementation and explore its vulnerabilities and security properties.

# [Challenge 37](https://cryptopals.com/sets/5/challenges/37)

It turns out that a naive implementation of the SRP protocol has a fatal flaw. If the client sends a zero (or, equivalently, an integer congruent to the prime number `p`) as its public key, it can trivially log in without knowing the password. Let's see why.

When the server receives the client's public key `A`, it calculates the following:

```
exchange(identity, A):
  (salt, v) := credentials[identity]
  b := Diffie-Hellman private key
  B := (k*v + g^b) mod p
  u := SHA-256(A || B)
  S := (A * v^u)^b mod p
  K := SHA-256(S)
  session-id := random value
  store (identity, K, salt) in a lookup table under session-id
  return session-id, salt, B
```

If `A` is zero, the entire secret becomes `S = (A * v^u)^b mod p = (0 * v^u)^b mod p = 0`. The same holds for `A = n*p`, `n` being an integer, because `mod p` reduces it to zero again. That means that the server calculates the HMAC key as `K = SHA-256(0)`. The verification endpoint then reduces to this:

```
validate(session-id, M1):
  session := sessions[session-id]
  expire sessions[session-id]
  return HMAC-SHA-256(SHA-256(0), session.salt) == M1
```

Because the client has (by design) access to the salt, it can send the string `M1 := HMAC-SHA-256(SHA-256(0), salt)` for verification, which trivially passes.

This is a critical flaw, because it allows an attacker to impersonate an arbitrary registered client without knowing its password. The attacker can simply send the client's identifier and a zero public key for the exchange, and then login using a constant hash.

# [Challenge 38](https://cryptopals.com/sets/5/challenges/38)

This challenge has us implement an intentionally weakened version of the SRP protocol, and then shows that it's vulnerable to MITM attackers pretending to be a server. Specifically, they can obtain enough information to launch a dictionary attack against the hash and try to recover the client's password.

The server protocol now looks like this (the changed line is highlighted):

```
register(identity, salt, v):
  store (salt, v) in a lookup table under identity

exchange(identity, A):
  (salt, v) := credentials[identity]
  b := Diffie-Hellman private key
  B := g^b mod p                      // Was (k*v + g^b) mod p
  u := SHA-256(A || B)
  S := (A * v^u)^b mod p
  K := SHA-256(S)
  session-id := random value
  store (identity, K, salt) in a lookup table under session-id
  return session-id, salt, B

validate(session-id, M1):
  session := sessions[session-id]
  expire sessions[session-id]
  return HMAC-SHA-256(session.key, session.salt) == M1
```

The client performs the following calculations:

```
salt := random salt
x := SHA-256(salt || password)
v := g^x mod p
credentials = (salt, v)


server.register(identity, salt, v)

... the client wants to log in now ...

a := Diffie-Hellman private key
A := g^a mod p (Diffie-Hellman public key based on a)
session-id, salt, B := server.exchange(identity, A)

u := SHA-256(A || B)
x := SHA-256(salt || password)

S := B^(a + u*x) mod p                // Was (B - k*g^x)^(a + u*x) mod p
K := SHA-256(S)

M1 := HMAC-SHA256(K, salt)
server.validate(session-id, M1)
```

To check that this works, let's calculate the shared secret `S` on both sides.

1. The client calculates

```
S = B^(a + u*x) = B^a * B^(u*x) = (g^b)^a * (g^b)^(u*x) = a^(a*b) * g^(b*u*x) mod p
```

2. The server calculates

```
S = (A * v^u)^b = A^b * (v^u)^b = (g^a)^b * v^(u*b) = g^(a*b) * (g^x)^(u*b) = g^(a*b) * g^(b*u*x) mod p
```

We see that both end up with the same value.

Essentially, the server's public key `B` becomes simply the Diffie-Hellman public key corresponding to its private key `b`. That way, it loses any dependency on the client's password through `v`. This is the flaw that allows a MITM attacker to recalculate the client's hash `M1` from an arbitrary password, thus being able to launch a dictionary attack. It works like this:

The attacker deploys a fake server with an arbitrary (but fixed) private key `b`, its corresponding public key `B`, and a salt value `salt`. When the client calls the fake server's `exchange` endpoint, the server stores the client's public key `A`. Similarly, when the `validate` endpoint is called, the client's hash `M1` is stored.

To test whether a candidate password `P` from the dictionary is the client's real password, the attacker has to recalculate the client's hash using this password. That's

```
M1' = HMAC-SHA256(K, salt)

where K = SHA-256(S)
      S = B^(a + u*x) mod p
      u := SHA-256(A || B)
      x := SHA-256(salt || P)
```

This seems like a dead end, because `S` depends on the client's private key `a` which the attacker doesn't have. However, because the protocol has been simplified, the Diffie-Hellman math kicks in, and we can calculate

```
S = B^(a + u*x) = B^a * B^(u*x) = (g^b)^a * B^(u*x) = (g^a)^b * B^(u*x) = A^b * B^(u*x) mod p
```

We can simply plug in the captured value of `A` into the formula and recover the shared secret. All the other quantities are known - `b` has been selected, `B` calculated from `b`, `u` calculated from `A` and `B`, and `x` calculated from the fixed salt and the candidate password `P`. The attacker can repeat this process, testing any password `P` from a dictionary.

This calculation wouldn't be possible in the full SRP protocol. In that case, `S` is calculated as `S = (B - k*g^x)^(a + u*x) mod p` and the Diffie-Hellman mathematics that allowed the attacker to get rid of the client's secret `a` no longer applies.

This challenge shows why it's important to mix in the client's password into the key exchange. Without it, the SRP protocol reduces to a more complex version of the Diffie-Hellman key exchange.

# [Challenge 39](https://cryptopals.com/sets/5/challenges/39)

We now implement the famous RSA algorithm. Or rather, try to - although the algorithm is trivial to express mathematically, a robust implementation is incredibly tricky. Our naive version will work, but will be hopelessly broken for any real use. Still, it's useful to understand what's happening under the hood.

## How does it work?

To generate an RSA key, we do the following:

1. Choose two large prime numbers `p` and `q`. These must be kept secret. In reality, this step isn't as easy as randomly generating two primes - careful measures must be taken to ensure they are sufficiently large, not too close to each other, etc.
2. Compute `N := p*q`. The value `N` is used as the modulus for all further calculations, or in other words, all computations are happening modulo `N`. The bit length of `N` is the key length.
3. Compute `eta := (p-1)*(q-1)`. This is the product of `phi(p) = p-1` and `phi(q) = q-1`, the Euler totient functions of `p` and `q`. The totient function counts the numbers smaller than its argument that are coprime to it. Because we evaluate it for prime numbers only, it becomes one less than the number.
4. Choose an integer `e` between 1 and `eta` coprime with `eta`. In practice, a constant value is used here, often `e := 2^16 + 1 = 65537`. We use `e := 3` here; this will enable some attacks later.
5. Determine `d` as the multiplicative inverse of `e` modulo `eta`. This can be calculated by solving the equation `d*e = 1 mod eta` using the extended Euclidean algorithm.
6. The public key consists of `(e, n)` while the private key consists of `(d, n)`.

To encrypt a message `m < n` represented as a number using the public key `(e, n)`, we calculate

```
c := m^e mod n
```

To decrypt a message `c` represented as a number using the private key `(d, n)`, we calculate

```
m := c^d mod n
```

## Why does this work?

A sketch is below, though this is by no means a formal proof.

We will need two theorems which I will just state here, and one small lemma which I will prove. The RSA functionality then follows from those.

### [Fermat's little theorem](https://en.wikipedia.org/wiki/Fermat%27s_little_theorem)

Let `p` be a prime number. If an integer `a` is coprime with `p`, then `a^(p-1) = 1 mod p`.

### [Bézout's identity](https://en.wikipedia.org/wiki/B%C3%A9zout%27s_identity)

Let `a` and `b` be integers. Then there exist integers `A` and `B` such that `gcd(a,b) = A*a + B*b`.

### Euclid's lemma

Let `a`, `b` and `c` be integers such that `a` divides `c`, `b` divides `c` and `gcd(a,b) = 1`. Then `a*b` divides `c`.

_Proof:_

Because `a` divides `c`, there exists an integer `k` such that `c = k*a`. Similarly, `b` divides `c`, so there exists an integer `l` such that `c = l*b`.

Next we apply Bézout's identity to get `1 = gcd(a,b) = A*a + B*b` for some integers `A` and `B`.

Multiplying both sides by `c`, we get `c = c*A*a + c*B*b`. Substituting our assumptions about divisibility, we obtain `c = l*b*A*a + k*a*B*b = a*b*(l*A + k*B)`, or in other words, `a*b` divides `c`.

### RSA proof sketch

We set `d` to be a multiplicative inverse of `e` mod `eta = (p-1)*(q-1)`, so `d*e = 1 mod (p-1)*(q-1)`. Another way to state this is `d*e = 1 + k*(p-1)*(q-1)` for any integer `k`. We use this to calculate

```
(m^e)^d = m^(e*d) = m^(1 + k*(p-1)*(q-1)) = m * (m^(p-1))^(k*(q-1))
```

We know that `m < n = p*q`. Suppose that `m` is coprime to `p`. That means we can apply Fermat's little theorem to get

```
m * (m^(p-1))^(k*(q-1)) = m * 1^(k*(q-1)) = m mod p
```

If on the other hand `m` was not coprime to `p` (i.e., was a multiple of `p` and therefore `m = 0 mod p`), we would have

```
m * (m^(p-1))^(k*(q-1)) = 0 * (0^(p-1))^(k*(q-1)) = 0 = m mod p
```

Because the number `q` has the same properties as `q`, we also get `(m^e)^d = m mod q`.

Now we need to combine the results `(m^e)^d = m mod p` and `(m^e)^d = m mod q` into `(m^e)^d = m mod n`.

Another way to restate the results is to say that `p` divides `(m - (m^e)^d)` and also `q` divides `(m - (m^e)^d)`. Because `p` and `q` are coprime, we can apply Euclid's lemma to obtain `n = p*q` divides `(m - (m^e)^d)`, or equivalently, `(m^e)^d = m mod n`.

## Is this safe?

To decrypt a message, an attacker has to calculate the private key `d`, for which they need `(p-1)*(q-1)`. This can be calculated from the public key `(e, n)` only by factoring `n` into `p*q`. No known polynomial algorithm exists, although it is possible to break smaller key sizes. Famously, RSA is also [not quantum-resistant](https://en.wikipedia.org/wiki/Shor's_algorithm).

Nowadays, public key algorithms based on elliptic curves are preferred due to their smaller key sizes providing a comparative security level, although they are also not quantum-resistant.

# [Challenge 40](https://cryptopals.com/sets/5/challenges/40)

We implement Håstad's broadcast attack against a naive RSA implementation with a small public exponent (E=3 from the previous challenge). Why naive? Because directly exponentiating a message converted to a number works only on paper, this is the so-called textbook RSA. In reality, a [padding scheme](https://en.wikipedia.org/wiki/Optimal_asymmetric_encryption_padding) must be used to introduce randomness into the otherwise deterministic RSA encryption and to make it resistant against chosen plaintext attacks. This [StackOverflow answer](https://crypto.stackexchange.com/questions/52504/deciphering-the-rsa-encrypted-message-from-three-different-public-keys) nicely summarizes what's wrong with textbook RSA.

## Background

To perform the attack, we will need the Chinese Remainder Theorem (CRT). Suppose we have `n_1, ..., n_k` pairwise coprime integers greater than 1. The CRT states that for any integers `a_1, ..., a_k`, the system of equations

```
x = a_1 mod n_1
  ...
x = a_k mod n_k
```

has a solution of the following form

```
x = sum_{i=1}^k a_i * N_i * m_i mod N

where N = n_1 * ... * n_k
      N_i = N / n_i
      m_i is the multiplicative inverse of N_i mod n_i
```

This is nicely summarized in [Ben Lynn's number theory course](https://crypto.stanford.edu/pbc/notes/numbertheory/crt.html).

## The attack

Suppose the attacker can coerce a naive RSA implementation with E=3 into encrypting the same plaintext `m` 3 times, each to a different public key. This gives them

1. `c_0`: encryption of `m` against the public key `(3, n_0)`
2. `c_1`: encryption of `m` against the public key `(3, n_1)`
3. `c_2`: encryption of `m` against the public key `(3, n_2)`

Due to how RSA works, this presents the attacker the following system of equations:

```
c_0 = m^3 mod n_0
c_1 = m^3 mod n_1
c_2 = m^3 mod n_2
```

Assuming that `n_0`, `n_1` and `n_2` are pairwise coprime (which they should be with a very high probability - otherwise, they would share a prime factor), the attacker can use the CRT to calculate

```
m^3 =  c_0 * N_0 * m_0 + c_1 * N_1 * m_1 + c_2 * N_2 * m_2 mod N
```

Here `N` is again `n_0 * n_1 * n_2`.

By calculating the integer cube root of `m^3`, they can recover the plaintext message `m`.

This attack demonstrates why it's necessary to use a padding whenever RSA is used. RSA padding introduces randomness, so that every encryption produces a different ciphertext even when the same plaintext is encrypted. In this scenario, each equation would get a different `m^3` and the attack would fail.

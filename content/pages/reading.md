+++
title = 'Reading'
date = 2024-07-27T13:11:24+02:00
norss = true
+++

Below are some technology books that I've read over the years which helped me 
in my career, or influenced me in some other way.

# Computer networks

Despite working in the field, I didn't receive much formal education in 
computer networks at my university, so I had to learn the theory myself.

## Larry Peterson & Bruce Davie - Computer Networks: A Systems Approach

This is the first book everyone recommends for learning about computer 
networks. It follows the standard OSI model from the bottom up, much like
the material is taught in schools.

I felt like the higher in the model the book went, the less specific the 
authors were, as if they were experts on the lower layers but not so much on 
the upper ones. This is partly due to the multitude of protocols available in 
the application layer. The book has to balance between diving deep into
a few key protocols, or doing a quick pass over many.

One thing I did not like is that the authors often got sidetracked by
describing obsolete protocols from the 70's. Likewise, tedious explanations of 
how JPEG, MP3 and other encodings work felt out of place.

Still, I probably owe most of my networking knowledge to this book. I read it 
cover to cover shortly after being assigned to a traffic analysis project with 
not much prior domain knowledge, and benefited from it incredibly.

## Jim Kurose & Keith Ross - Computer Networking: A Top-Down Approach

This is the second networking book I read, and I think that's exactly the 
way it should be read. As the name suggests, the book goes from the top down 
in the OSI model, starting from the application layer. To make that work 
though, the authors need to quickly go over the transport layer, because one 
needs to know about ports and reliable transmission in order to discuss how 
HTTP works. In general, one has to borrow concepts from the lower layers in 
order to explain the higher layers, so the whole thing of going top-down 
doesn't really work.

This was OK when I read it as the second book, but would be really confusing 
for a beginner. The book served as an excellent refresher for concepts I 
learned in the Peterson & Davie book though.

# Computer science

I find all the mathematics behind computers amazingly cool. I have studied it a 
lot, both at the university and by myself, and I even look for science fiction 
books with computability concepts. Computability and complexity theory, formal 
languages, logic and graph theory are to this day my favorite mathematical 
domains.

## Charles Petzold - Code: The Hidden Language of Computer Hardware and Software

This is what I wish my hardware courses were. A pretty short book that takes 
us on a journey from propositional logic and logical circuits over the inner 
workings of the CPU and memory all the way to how an entire computer works. 

One thing I remember in particular is that I've always wondered where the 
translation from the assembly (or, equivalently, the machine code) to some sort 
of an electrical signal occurs. This books explains that there is no such 
translation, and that the machine code is exactly equal to the signal.

## Charles Petzold - The Annotated Turing

Another delightful and short book, this is an annotated version of Alan 
Turing's paper "On Computable Numbers, with an Application to the 
Entscheidungsproblem", originally published in 1936. The paper is supplied with 
numerous notes, explanations, corrections, and also historical background in an 
attempt to make it more approachable.

This is the paper that introduced what later became known as the Turing 
Machine, which serves as the theoretical foundation of all computers. However, 
Alan Turing did not explore them for this purpose; instead, his goal was to 
resolve the Entscheidungsproblem, which can be summarized as "Can there be 
a mechanical procedure that would, for any logical statement, output whether 
this statement is universally valid?"

# Programming languages

I got interested in programming language internals around the time I started 
learning Haskell, as is typical. I wrote a few toy Lisp interpreters and even 
production-ready network protocol parsers, but I never got around to 
implementing a full programming language before reading the following book.

## Robert Nystrom - Crafting Interpreters

This has to be the most beautiful book that I've ever read. The amount of work 
that went into creating all the diagrams and code sections is absolutely 
mind-blowing, and I highly recommend reading the author's blog where he 
describes his writing approach.

Two fully working interpreters for a scripting language called Lox are 
described. One in Java, which is a simple tree-walking interpreter, that 
although full-fledged, suffers from performance issues stemming from chasing 
pointers in the AST all around the memory.

The other interpreter, written in C, solves this problem by instead compiling 
Lox into a bytecode and interpreting that using a virtual machine. Notably, 
being written in C, the interpreter also needs a working garbage collector, 
which we got for free in the previous Java implementation.

Lox itself, as well as the second interpreter, are heavily inspired by Lua, 
probably my all-time favorite language. The second interpreter also shows how 
to implement several data structures typically used in an interpreter, simply 
because C doesn't provide them.

# Software engineering

Finally, there are some books related to the general software engineering 
practices.

## Martin Kleppmann - Designing Data-Intensive Applications

This book helped me not feel so lost in modern scalable applications. I 
particularly like the viewpoint that most systems - caches, storage, message 
brokers - can be viewed as databases, just each with different requirements and 
trade-offs.

It's impossible to go in depth, given how many different systems there are, but 
the book does a pretty good job of describing the principles. I learned about 
what components a scalable application consists of, how they interact, what can 
go wrong, and when (not) to use them. By understanding the building blocks and 
having the vocabulary, I can quickly get familiar with new applications and 
know what to look for when diagnosing issues.

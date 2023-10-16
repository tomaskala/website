+++
title = 'My Website!'
date = 2022-02-19T10:17:43+01:00
+++

Welcome to my website. This is its "initial commit".

I've been toying with the idea of creating a simple site where I could document
my hobby projects and other interesting bits of technology that I come across.
Emphasis on the *simple*. There is no JavaScript or tracking involved: I have
no way of telling whether anyone actually reads this, and I don't care.

> Update 2023-10-16: I have since switched the website to Hugo, so this post no 
> longer reflects the state of the website. I'll leave it up to document what 
> it looked like in the past.

The entire system of building this site is also as simple as I could make it.

I write my posts in markdown. They are converted to HTML using 
[pandoc](https://pandoc.org/). The [index](/) is generated using a simple 
[shell 
script](https://github.com/tomaskala/website/blob/8399f06389fe54cebd9b84871a79acd85c8b4fc2/fill-index), 
before being converted to HTML as well. Finally, the entire website is rsync'd 
to my server and presented to you using nginx. This whole affair is controlled 
through a trivial 
[Makefile](https://github.com/tomaskala/website/blob/14244da168693efa9a36530b445feb483742f13e/Makefile).

After writing a new post, the whole process is as simple as
```bash
$ cd ~/website
$ make
$ make sync
```

Since I have exactly zero experience in web design, I use a modified version of
[susam's spcss](https://github.com/susam/spcss) for the stylesheet. It is
remarkably simple, looks nice, and supports both light and dark themes.

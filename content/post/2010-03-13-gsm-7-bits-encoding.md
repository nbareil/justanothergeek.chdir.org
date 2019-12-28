---
categories:
 - gsm
 - scapy
 - android
date: "2010-03-13T11:14:00Z"
title: GSM 7 bits encoding
---

I implemented some GSM protocol parts in
[scapy](http://secdev.org/projects/scapy/) so I had to implement the
infamous "7 bits alphabet".

This is used for SMS encoding for example, the principle is simple: each
character is coded on 7 bits, which means that inside one byte, there
are two (parts of) characters.

My google-fu was not sufficient to find a readable implementation so I
gave it a try:

``` {.prettyprint}
def decode_gsm7bits(x):
    shift=0
    remain=0
    s=''
    if not x:
        return s
    for byte in x:
        i = (ord(byte) << shift) | remain
        remain = (i >> 7)
        i = i & 0x7f
        s+=chr(i)
        shift = (shift+1)%7
        if shift == 0:
            s+=chr(remain)
            remain=0
    if s[-1] == '\x00': # padding issue
        s=s[:-1]
    return s

def encode_gsm7bits(x):
    shift=0
    remain=0
    srclen  = len(x)
    i=0
    stream=''
    mask=0
    while i < srclen:
        if i+1 == srclen:
            next = 0
        else:
            next = ord(x[i+1]) << (7-shift)
        cur  = (ord(x[i]) >> shift) | next
        stream += chr(cur & 0xff)
        i+=1
        shift = (shift+1)%7
        if shift == 0:
            mask=0
            i+=1
    return stream
```

As far as I can tell, it works like a charm: I successfully manage to
send raw messages to mobiles :)\
As soon as possible, I will post the GSM layers on [scapy's
trac](http://trac.secdev.org/scapy/).


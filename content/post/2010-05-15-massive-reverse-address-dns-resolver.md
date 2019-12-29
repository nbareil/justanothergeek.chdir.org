---
categories:
 - dns
 - async
 - scan
 - nodejs
date: "2010-05-15T09:26:00Z"
title: Massive reverse address DNS resolver
description: Dummy code to scan wide netblocks in NodeJS
---

Just for the record (and [newsoft](http://news0ft.blogspot.com/) :),
here is a basic reverse DNS bruteforce implemented with
[Node.js](http://nodejs.org/): thanks to this awesome event-based
library, it is possible to write powerful tools in a few Javascript
lines!

The following code will resolve a /24 netblock in less than 5 seconds.

``` {.prettyprint .lang-js}
#! /usr/bin/nodejs

var baseaddr = '88.191.98.';

var sys = require('sys');
var dns = require('dns');
var events = require('events');

function reverse_addr(addr) {
    var e = new events.EventEmitter();
    dns.reverse(addr, function(err, domains) {
        if (err) {
            if (err.errno == dns.NOTFOUND)
                e.emit('response', addr, 'NOTFOUND');
            else
                e.emit('error', addr, err);
        } else
            e.emit('response', addr, domains);
    });
    return e;
}

for (var i = 0 ; i < 255 ; i++) {
    var currentaddr = baseaddr+i;

    reverse_addr(currentaddr).addListener('error', function (addr, err) {
        sys.debug(addr + ' failed: ' + err.message);
    }).addListener('response', function(addr, domains) {
        sys.puts(addr + ' = ' + domains);
    });
}
```

There is no retry mechanism if the remote server returns a `SERVFAIL`
but this is left as exercise to the reader…


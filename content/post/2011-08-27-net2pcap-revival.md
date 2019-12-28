---
categories:
 - network
 - capture
 - security
 - project
date: "2011-08-27T14:54:00Z"
title: net2pcap revival
---

[net2pcap](http://www.secdev.org/projects/net2pcap/) is a packet capture
tool written by [Philippe Biondi](http://secdev.org/) back in 2003. It
was designed to be as secure as possible in order to be run in hostile
environment. To do so, its code is minimalist without any complicate
feature, the result is 406 lines of simple C. On top of its security, it
is also the most reliable tool I have ever used on high traffic link
regarding packet loss, even dumpcap does not perform better.\
\
Unfortunately, feature requests and bugs were lost in the [middle of
hundreds of spams in Phil's bug
tracker](http://trac.secdev.org/secdev/report/). To not lost patches, I
have set up a [net2pcap
repository](https://github.com/nbareil/net2pcap) on github. **This is
not a fork,** this is still maintained in collaboration with Phil, this
is just a way to relieve him of the maintenance burden.\
\
For those interested in the project, [the following patches were already
applied](https://github.com/nbareil/net2pcap/commits/master):\
\
-   Privileges drop
-   Chroot
-   Compatible with 64 bits architecture
-   Large file support on x86\_32

If you have any feature request or bug report, [feel free to submit a
ticket](https://github.com/nbareil/net2pcap/issues)!


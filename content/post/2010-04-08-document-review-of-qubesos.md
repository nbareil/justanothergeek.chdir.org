---
categories:
 - sandbox
 - linux
 - virtualization
 - xen
 - security
date: "2010-04-08T15:03:00Z"
title: Document review of Qubes OS
---

Qubes OS
--------

[You](http://theinvisiblethings.blogspot.com/2010/04/introducing-qubes-os.html)
[must
have](http://tech.slashdot.org/story/10/04/07/1754208/Researcher-Releases-Hardened-OS-Qubes-Xen-Hits-40?)
[heard](http://linuxfr.org/2010/04/07/26705.html)
[about](http://twitter.com/alexsotirov/statuses/11796459373) it,
[Invisible Things Lab](http://invisiblethingslab.com/) released their
own operating system, named [Qubes OS](http://www.qubes-os.org/) (If you
ask me, I would have refer to it as a Linux distribution instead). Their
distribution focuses on security isolation and is based on their
virtualization experience (for the record, Joanna and Rafal are the
people behind most of the virtualization vulnerabilities found in the
previous years).

> **Disclaimer**: I do not had the occasion to test the system, this
> post is only based on my reading of their (great) [QubesOs
> architecture
> paper](http://www.qubes-os.org/files/doc/arch-spec-0.3.pdf) (version
> 0.3). I did not read the source code or whatever so be careful with
> what is following :)

### Target of the distribution

Maybe I am guessing wrong, but this distribution seems to be really
dedicated for classified environments. Even if it is usable by anyone,
some concepts make me believe this work will be sold to government or
military people because it full-fills most of the requirements. Anyway,
this is awesome to release it to the public, in an Open Source licence.

I am sure that this release will be really helpful for the people
involved in "[SEC&SI
challenge](http://www.ssi.gouv.fr/site_article91.html)" organized by the
french government. This research project is dedicated to the
construction of a secure Desktop platform (Linux based) usable by my
grandma.

### What is new?

There is nothing new by itself: only components already available in the
community have been used (Linux kernel, Xen, Xorg, LUKS, device mapper,
etc.), few code have been developed.

The beauty of their solution is that every techniques used are
individually known but nobody had the idea to put them together like
they did. Bravo!

### The big picture

User activities can be identified in multiple security levels: web
browsing, banking, corporate work, social networking, e-shopping, etc.

Each activity represents a security domain: banking activities are more
critical than social networking (right?). Usually, on most of operating
systems, every activities are in the same "space": if you are
compromised while browsing [youtube.com](#sec-1.3), the attacker can
access to your sensitive data (bank account or corporate email).

So QubesOS resolves this problem by running each domain into a virtual
machine (called *AppVM* in QubesOS terminology), the virtualization
solution they chose is Xen. They explain why they chose Xen instead of
KVM in their architecture guide.

Thanks to the Xen hypervisor, each AppVM is isolated and cannot have
access to other ressources than its own.

### Architecture

#### Multimedia

-   Display\

    Until Qubes OS, every Linux distribution providing "multi level
    security" use one X server running on the Host (in Dom0) and each
    virtual machine uses the display thanks to:

    -   VNC-over-ssh. Problem: VNC client and server have not really
        been audited and they are crippled of security issues.
    -   X11 forwarding. Problem: There is basically no security control
        in X11, a X client can do anything on other windows like
        capturing or injecting keystrokes, snooping other
        applications, etc. This is problematic when windows do not have
        the same security level.

    A lesser used alternative is the use of one Xorg server per virtual
    machine: each security level is inside a virtual terminal. However,
    unless there is a video card per X session, every servers share the
    same hardware resource so a vulnerability in Xorg would impact other
    Xorg servers.

    The innovation of Qubes OS is to not use any of theses methods. Each
    AppVM runs a Xorg instance (with a "dummy graphic driver", which I
    guess is not tied to any hardware device) and a *AppVM Window
    Manager*.

    The dom0 domain runs the "real" Xorg server tied to the graphic card
    and multiple *AppViewers*, each *AppViewer* communicates with one
    *AppVM Window Manager* (which is inside a *AppVM*) via the Xen Ring
    buffer protocol. The task of each *AppViewer* is to proxify input
    devices to the right *AppVM* (depending on who has the focus). Each
    virtual machine uses a homemade input xorg-driver called
    `xf86-input-mfndev` (which gets its input from the ring buffer).

    Each *AppVM Window Manager* sends notifications to its associated
    *AppViewer*. The events monitored are: creation of new window,
    content refresh or change of window focus.

    When an *AppViewer* receives a *content refresh* notification, it
    requests to the *AppVM Window Manager* its *composition buffer* (the
    bitmap of the window content in other words). It receives theses
    bytes from the ring buffer and displays it on the screen.

    The optimization, which is still being investigate, is to ask the
    address of the composition buffer instead of the sending the
    raw bitmap. This is possible because the dom0 has access to the
    address space of every *AppVM* so it can directly use the bytes to
    render it without involving a double-copy.

    However, I do not know if this optimization would be sufficient to
    handle video playback: the paper suggests that the user can watch
    video on youtube so it seems to work, but I don't see how. Even on
    my "normal" desktop, the system goes slow if I simply disable
    Xvideo overlay.

-   Audio\

    Audio support is not yet implemented but will be certainly based on
    the same principle than the "composition buffer": audio stream will
    be "written" in a buffer readable by *AppViewer*.

    That way, a dom0 daemon just has to mix every *AppViewer* audio
    streams and eventually sends the final stream to the sound card.

-   Clipboard\

    "Applicative clipboard" (in opposition to X11 clipboard mechanism)
    operations are supported between *AppVM*. The user has to press a
    special shortcut (S-C-v) which is intercepted by the dom0 and not
    passed to *AppVM*. At this point, the *AppViewer* triggers a command
    on the virtual machine, sending the content of the cursor selection
    through the Xen ring buffer. The bytes are then stored in a volatile
    file on dom0.

    When the special *paste shortcut* is pressed, the dom0 injects the
    stored result via the ring buffer again and emulates the
    paste action.

#### Storage architecture

*AppsVMs* share the same "base filesystem" in order to not waste disk
space. For that matter, each domain mounts a read-only block device and
mounts, on top of it, a copy-on-write block device (thanks to the
kernel's device-mapper) accessible only to the *AppVM*.

Each time an *AppVM* is started, the copy-on-write volume is deleted in
order to have a clean environment. Persistent data (like user documents)
are stored in another private volume which is restored at *AppVM*
creation time.

Every block devices are exported by the *Storage Domain*. This
abstraction layer is needed to make possible file-sharing between
*AppVMs* (thanks to a homemade cryptographic protocol).

We can see that the *Storage Domain* has great powers. To counterbalance
it, cryptography was used.

The "base read-only block device" is signed (on a per-block basis). The
private key is available only to the TPM and the dom0.

Application specific volumes (the copy-on-write overlay and the
persistent block device) are encrypted (with LUKS) with a key available
only to *AppVMs* and the dom0.

Thanks to this design, a compromission of the *Storage Domain* would be
worthless because any attempt to modify data would be detected and
persistent files are encrypted so an attacker would be disappointed :)

#### Network architecture

Most of the remote vulnerabilities found in the Linux kernel have been
discovered in device drivers like network adapters. Because any bug
found in the kernel puts in danger the whole system, it would be great
to find a way to isolate theses drivers.

Thanks to recent CPU features, it is now possible to do such thing:
Intel VT-d technology permits to safely give to a virtual machine access
to a hardware device.

In other words, QubesOS now delegates the PCI wireless card to an
*AppVM*, called *Network domain*. At this point, if a vulnerability is
found in the wifi driver, only the virtual machine is compromised.

The *Network domain* is the border router: every *AppVM* routes its
traffic through it. One of its task is also to enforce traffic policy:
*AppVMs* are not allowed to communicate between each other, only HTTPS
flows are allowed for the banking domain, only VPN traffic is allowed
for corporate domain, etc.

### Conclusion

On the paper, Qubes OS seems really well designed and robust from a
security point of view. By glancing at the screenshots, the user
experience seems good. I don't know how good/bad are the performances:
memory usage must be really high (because AFAIK, Xen does not implement
the "[Kernel Samepage
Merging](http://thread.gmane.org/gmane.comp.emulators.kvm.devel/31003)"
feature available in KVM since 2.6.32).

But, anyway, congratulations to "Invisible Things Lab" for this great
architecture!


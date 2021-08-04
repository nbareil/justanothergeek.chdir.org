---
date: "2012-01-24T16:16:00Z"
title: Linux security in 2011, or my LKML's yearly digest
description: This is my bookmarks about Linux kernel security in 2011.
---

### Linux security in 2011, or LKML's yearly digest

**Disclaimer**: I have nothing to do with the following, all credits go
to their respective authors. I'm just publishing my 2011's bookmarks
about Linux kernel security with a one line summary based on my
(possibly wrong) understanding\
Do not hesitate to correct me (gently if possible :)) in comments or
mail.

-   [False boundaries of (certain)
    capabilities](http://forums.grsecurity.net/viewtopic.php?f=7&t=2522):
    Brad Spengler describes 19 capabilities (of 35) which can be used to
    regain full privileges. Coincidentally, [Vasily Kulikov discovered a
    “funny” behavior of
    CAP\_NET\_ADMIN](http://thread.gmane.org/gmane.linux.kernel/1105168/focus=1107204)
    which permit to load any modules available in /lib/modules/ instead
    of limiting to network related modules only, AFAIK, this
    vulnerability was closed but the fix got reverted some weeks later
    because of some userspace breakages.
-   [PaX team introduced a new range of
    stuff](http://lwn.net/Articles/461811/) using the [new GCC plugin
    infrastructure](http://lwn.net/Articles/457543/). At compile-time,
    pro-active code is automatically added to potentially dangerous
    paths:
    -   `constify_plugin.c` enforces read-onlintroduces new constraints
        (`__do_const` and `__no_const`) enforcing read-only permissions
        at compilation-time and run-time. PaX then makes usage of these
        new constraints by patching most of the “ops structures”. The
        plugin also automatically protects structures where all members
        are function pointers, this patching on-the-fly is required
        because patching directly the source kernel would never be
        integrated upstream.
    -   `stackleak_plugin.c` adds instrumentation code before
        `alloca()` calls. This code checks that stack-frame size does
        not overlap with kernel task size. It circumvents techniques
        described in ["Large memory management vulnerabilities" by Gaël
        Delalleau](http://cansecwest.com/core05/memory_vulns_delalleau.pdf)
        (2005) and ["The stack is back" by Jon
        Oberheide](http://jon.oberheide.org/files/infiltrate12-thestackisback.pdf) (2012).
    -   GCC 4.6 introduced [named address
        spaces](http://gcc.gnu.org/onlinedocs/gccint/Named-Address-Spaces.html).
        It was initially specified for embedded processors but PaX team
        uses this feature to represent user and kernel space.
        `checker_plugin.c` thus introduces `__user`, `__kernel` and
        `__iomem` namespaces to spot non-legit flows between
        address spaces.
    -   `kallocstat_plugin.c` produces statistics about the size given
        in parameter to various memory allocation functions
    -   `kernexec_plugin.c` enforces non-executable pages like the
        `KERNEXEC` PaX feature, but without huge performance impact
        on AMD64.
-   [pagexec also managed to compile Linux Kernel with
    clang](http://thread.gmane.org/gmane.comp.compilers.clang.devel/13365)
    by patching both Linux and clang. Now that gcc integrated plugins,
    it is less interesting  but llvm was the solely compiler with easy
    access to its internal structure, allowing external applications to
    perform static analysis...
-   A [user space interface to kernel Crypto-API was submitted to kernel
    developers](http://article.gmane.org/gmane.linux.kernel.cryptoapi/5304),
    an interesting use-case was to offer a way to deport key material
    between processes. Imagine process A in possession of private keys
    and another one, B, actually performing encryption / decryption
    stuff part. The idea was to initialize a “crypto socket” in A and
    pass this file descriptor to B (via a classic ancillary message).
-   Pseudo-files in `/proc/<pid>/` have a different security model than
    “normal” files because of its ephemeral nature: checks need to
    happen during each system call and not at `open()` time because
    permissions can change at anytime. [Halfdog
    discovered](http://www.halfdog.net/Security/2011/SuidBinariesAndProcInterface/)
    (and [Kees Cook reported it to
    LKML](http://thread.gmane.org/gmane.linux.kernel/1097206)) that not
    all files were protected accordingly. If a program opens
    `/proc/self/auxv` and keeps this file descriptor opened. Then, even
    after a `execve()` of a setuid binary, the file descriptor would
    still be available, leaking information! Fixing this vulnerability
    has been a long road and a pretty solution came up with the
    introduction of `revoke()`, a new syscall invalidating
    file descriptors. Unfortunately, the thread didn’t survive and ideas
    were lost... (by the way, it is funny that this kind of problem
    resuscitated in CVE-2012-0056 lately...)
-   As one goes along, `execve()` became almost magical, it had to
    support Set-User-Id, capabilities, and file capabilities. Each
    feature added complexity and different legacy behaviors to maintain.
    Instead of dropping these POSIX features, OpenWall 3.0 took a
    different approach by removing Suid binaries from its base install,
    thus preventing execve’s voodoo. This change is just a line in Owl’s
    changelog but is in fact a major achievement: it required them to
    re-architecture important software like crontab or [user management
    tools](http://www.openwall.com/tcb/).\
    `/bin/ping` is setuid-root because it opens a raw socket and injects
    its packet on the wire directly. [A new socket type, `PROT_ICMP`,
    was developed by Openwall
    team,](http://git.kernel.org/?p=linux/kernel/git/torvalds/linux.git;a=commit;h=c319b4d76b9e583a5d88d6bf190e079c4e43213d)
    it makes possible to send ICMP Echo messages without special
    privileges (caller’s GID has to be included in a range stored in a
    sysctl key). It is interesting to note that only replies (based on
    ICMP identifier field) are sent to userspace, not the whole ICMP
    traffic like in Mac OS X.
-   [TCP Initial Sequence number is now a 32-bits random number using
    MD5](http://git.kernel.org/?p=linux/kernel/git/torvalds/linux.git;a=commit;h=6e5714eaf77d79ae1c8b47e3e040ff5411b717ec).
    ISN was previously the concatenation of 24 random bits (MD4 of TCP
    end points with a secret rekeyed every 5 minutes) and an 8 bits
    counter (number of times secret key was regenerated)
-   Vasilily tried to push upstream [additional checks for
    `copy_{to,from}_user()`](http://permalink.gmane.org/gmane.linux.kernel.cross-arch/10430)
    (by checking if requested size fits boundaries fixed at compile
    time), this patch was a cut down version of `PAX_USERCOPY` but was
    NACKed by Linus asking him for more “balance and sanity”. However,
    he didn’t reject the idea itself, saying that a cleaner version
    might be accepted...


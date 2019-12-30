---
categories:
 - kernel
 - security
date: "2011-01-03T22:48:00Z"
title: Linux Security, one year later...
description:
---

This post (tries to) describe what happened in 2010 about GNU/Linux
security. What this post is not is a long list of vulnerabilities, there
are [some people doing it way better](http://xor.wordpress.com/) that
me.

The first part of this post is dedicated to new vulnerability classes
where the second one focuses on the defensive side, analyzing
improvements made to the Linux kernel. Before closing this post, some
selected quotes will be presented, pointing the finger at some of the
Linux failures.

This post being (very) long and being syndicated by a few "planets", I
will cut this post on my feed, even if I know that [a lot of people
dislikes this
behavior](http://sid.rstack.org/blog/index.php/392-ca-m-enerve).

[]()
Yang: New attacks, new vulnerability classes
============================================

Thanks to the generalization of userspace hardening in common Linux
distribution (packages compiled with most of the protection options like
[`stack-protector`](http://www.trl.ibm.com/projects/security/ssp/),
[`PIE`](http://en.wikipedia.org/wiki/Position-independent_code),
[`FORTIFY_SOURCE`](http://gcc.gnu.org/ml/gcc-patches/2004-09/msg02055.html),
writing of SELinux rules), vulnerability researchers had to find a
milder field : the kernel.

In 2009, Tavis Ormandy and [Julien Tinnes](http://www.cr0.org/) made a
lot of noise with their *NULL pointer dereference* vulnerabilities.\
Pro-active measures were developed to mitigate this kind of bug but the
play of the cat and mouse never stopped to to bypass theses protections.

Bypassing of `mmap_min_addr`
----------------------------

Let's remind that this protection consists of denying the allocation of
memory pages below a limit, called `mmap_min_addr`
(`/proc/sys/vm/mmap_min_addr`). Thus, it prevents an attacker to drop
off his shellcode at address 0-or-something and then triggering the NULL
pointer dereference.

A lot of methods were found in 2009 to bypass this restriction (*Update:
as pointed by Dan Rosenberg, the first one is not a
`mmap_min_addr bypass` at all*) , whereas this year was less fruitful
with ~~two~~ one technique~~s~~:

-   **~~Bug \#1~~: Disabling frontier**: The kernel has to validate each
    user-provided pointer to check if it is coming from user or
    kernel space. This is done by `access_ok()` with a simple comparison
    of the address against a limit.\
    Sometimes, the kernel needs to use function normally designed to be
    called by userspace, and as such, theses functions checks the
    provenance of the pointer... which is embarrassing because the
    kernel only provides kernel pointers.\
    So the kernel goes evil and cheats by manipulating the boundary via
    `set_fs()` in order to make `access_ok()` always successful. At this
    moment and until the kernel undoes its boundary manipulation, there
    is no more protection against malicious pointers provided by
    userland.\
    [Nelson Elhage](http://blog.nelhage.com/) found a brilliant way to
    get root: he triggers an assertion failure (via a `BUG()` or an
    `Oops`) that makes the kernel terminating the process with the
    `do_exit()` function. One Linux feature is to be able to notify the
    parent when one of its thread dies, the notification mechanism is as
    simple as writing a zero at a given address.\
    Normally of course, this address is checked to be inside the parent
    address space but if `do_exit()` was triggered in a context where
    the boundary was faked, that means that `access_ok(ptr)` will always
    return true.\
    This is what Nelson did by registering a pointer belonging to the
    kernel space for the notification and then triggered a NULL pointer
    dereference to enter into a "temporary" context. Boom!
-   **Bug \#2: Memory mapping**: Tavis Ormandy discovered that when a
    process was instantiated, [a carefully home made ELF binary could
    make the VDSO page be mapped one page below
    `mmap_min_addr`](http://thread.gmane.org/gmane.linux.kernel/1074552).
    This is particularly interesting on *Red Hat Entreprise Linux*'
    kernel because it is configured with `mmap_min_addr` equals to 4096
    (`PAGE_SIZE`).\
    In other words, the VDSO page can be mapped on addresses 0 to 4096.
    In theory, that means the VDSO page could be used to "bounce" from a
    NULL pointer dereference.

Then in the end of 2010, this was the rediscovery of the impact of
uninitialized variables, but in the kernel this time.

Uninitialized kernel variables
------------------------------

A typical vulnerable code looks like the following:

    struct { short a; char b; int c; } s;

    s.a = X;
    s.b = Y;
    s.c = Z;

    copy_to_user(to, &s, sizeof s);

The problem here is that we don't pay attention to the *padding* byte
added by the compiler between `.b` and `.c`. This is needed in order to
align structure members addresses on a CPU word.

The direct consequence in the kernel case is that `copy_to_user()`
obviously copies the structure as a whole and not "member by member",
padding included.\
The user process can thus get the value of this uninitialized byte,
which can be totally useless, or as sensible as a key fragment.

### The obvious fix?

The fix seems relatively simple, by adding a preliminary
`memset(&s, '\0', sizeof s)`. But this not that trivial because C99
states that the compiler is free to optimize the following cases:

-   Consider the `memset()` as superfluous as each structure member is
    assigned later, and thus removing it.
-   Later, the padding byte can be overridden when `.b` is assigned. C99
    does not protect this byte in any way so if the compiler can
    optimize its code by doing a `mov [ptr], eax` instead of
    `mov     [ptr], ax`, he is free to do it.

Furthermore, this `memset-ification` can be troublesome in fast paths
like in the BPF filtering engine. netdev developers considered the
[array initialization too expensive to be
added](http://git.kernel.org/?p=linux/kernel/git/stable/linux-2.6.36.y.git;a=commit;h=2bd84dce08a6a782925f5e34c2e87ad957c57007)
(even if this is as small as 16\*4 bytes).\
Instead, they had to write a "BPF checker", validating the legitimacy of
instructions accessing the array.

### Impact of uninitialized variables

This kind of bug [was already demonstrated dangerous in
userland](https://www.blackhat.com/presentations/bh-europe-06/bh-eu-06-Flake.pdf)
and this is even worse in kernel land!\
However, motivating kernel developers to fix theses issues was not the
easy part for some of them. For instance, the [netdev maintainer's
scepticism](http://thread.gmane.org/gmane.linux.network/177506/focus=177549)
lead Dan Rosenberg to make a [blistering
answer](http://lists.grok.org.uk/pipermail/full-disclosure/2010-November/077321.html)
with the publication of an exploit on *full-disclosure*. A few days
later, [he admitted having published this exploit because he was
doubting about the impact of this particular
vulnerability](http://permalink.gmane.org/gmane.comp.security.bugtraq/45315).

But this stays anecdotal (isn't it?) and kernel developers actively
[contributed to fix dozens occurrences of this kind of
bug](http://search.gmane.org/?query=uninitialized+memory&author=&group=gmane.linux.kernel&sort=date&DEFAULTOP=and&xP=Zuniniti%09Zmemori&xFILTERS=Glinux.kernel---A).

### Kernel stack expansion

In 2005, [Gaël Delalleau already discussed how interesting it was to
make the stack and the heap collide in user
land](http://cansecwest.com/core05/memory_vulns_delalleau.pdf). In
November 2010, Nelson Elhage, [Ksplice founder](http://ksplice.com/),
found a variant, but for the kernel this time.

The memory allocated to the kernel is minimal, a kernel task can not
have more than two physical pages for its local variables (its stack).
But this is merely a convention given the fact there is no enforcement
against abnormal expansion like a guard page.\
Next to the task's stack (so after the "two pages") is the location of
its `thread_info` structure, a critical element containing data and
function's pointers... which would be really interesting to overwrite!\
To happen, you have to [find a task where you can control his stack
usage](http://cve.mitre.org/cgi-bin/cvename.cgi), like an array where
its size is somehow user controlled. Eventually, this expansion will
transcend the two-pages-limit and will offer you a way to overwrite some
values in `thread_info` structure. A [concrete exploitation of this
flaw](http://jon.oberheide.org/blog/2010/11/29/exploiting-stack-overflows-in-the-linux-kernel/)
overwrites one of the function's pointers to redirect to a shell code.

Ying: New protections
=====================

Bug fixes
---------

This year will not be the one of the change of Linus mentality towards
security bugs but we catch up with it thanks to the efforts of security
teams of various Linux distributions (Red hat, SuSe and Ubuntu mainly).

It seems that they closely follow kernel mailing lists looking for
sensible commits with a security impact. For each report, a CVE number
is assigned, the kind of thing soooo useful for an admin because it
permits some kind of traceability and to know (more or less) how pierced
our servers are :)\
Eugene Teo maintains an [atypical git repository which tags every
CVE](http://git.kernel.org/?p=linux/kernel/git/eugeneteo/linux-2.6-cve-tagged.git;a=summary).
This is particularly useful in audits for quickly identifying
vulnerabilities available for a given version. This is somewhat the
*whitehat equivalent* of [kernel exploit
lists](http://xrayoptics.by.ru/database/localroot/lista_exploits_kernel.txt)
used by hackers.

Proactive security
------------------

A lot of contributions were made to the kernel to improve its security
proactively. Theses works try to make kernel exploitation more
cumbersome, because frankly, we have to admit that the relative easiness
to exploit a NULL pointer dereference is embarrassing :)

For instance, to understand the interest of this kind of proactive
measures, let's look back to Nelson's vulnerabilities: to be successful,
[Dan's
exploit](http://permalink.gmane.org/gmane.comp.security.full-disclosure/76457)
had to combine three vulnerabilities to transform a denial of service
into a privilege escalation.

This [defense in
depth](http://en.wikipedia.org/wiki/Defense_in_depth_(computing)) shows
us how expensive it becomes to exploit a given vulnerability. This is
what we keep saying: there will always a vulnerability somewhere in our
system, so our only option is to try to make its exploitation insane.

But let's see what are theses proactive measures...

### Permission hardening

Brad Spengler, author of [grsecurity](http://grsecurity.net/), has long
been vocal on the fact that too much information were leaked to user
land. In consequence, grsec includes a lot of restrictions to prevent
theses information leaks. But what are we talking about?

`/proc`, `/sys` and `/debug` pseudo-filesystems contain files revealing
kernel addresses, statistics, memory mapping, etc.\
Except in debugging session, theses information are totally useless and
meaningless. Nevertheless, most of theses files are world readable by
default. This is godsend if you are an attacker: no need to bruteforce
kernel addresses (and we know that bruteforcing this kind of thing in
kernel land is never a good idea)!

Dan Rosenberg and Kees Cook (of the Ubuntu security team) worked hard to
merge theses restrictions into the official upstream tree:

-   [`dmesg_restrict`](http://news.gmane.org/find-root.php?message_id=%3c1289273338.6287.128.camel%40dan%3e):
    access to kernel log buffer (used by `dmesg(8)`) now require
    `CAP_SYS_ADMIN` capability.
-   Removal of addresses in
    [`/proc/timer_list`](http://permalink.gmane.org/gmane.linux.kernel/1064008),
    [`/proc/kallsyms`](http://git.kernel.org/?p=linux/kernel/git/torvalds/linux-2.6.git;a=commit;h=59365d136d205cc20fe666ca7f89b1c5001b0d5a), etc.
    Upstream developers tried hard to not merge theses patches thinking
    it was useless (because addresses are also readable in
    `/boot/System.map`) and above all, it would greatly complicate the
    work of maintainers reading bug report. That is why [netdev
    maintainer netdev clearly NAKed this kind of
    patches](http://thread.gmane.org/gmane.linux.network/177739/focus=2076).
    The zen and patience of Dan Rosenberg has to be highlighted here!\
    Alternatives were suggested by both parties:\
    -   Since merely removing addresses from `/proc` files would break
        the ABI and thus a lot of scripts, it was proposed to replaced
        them by a dummy value (`0x000000`) if the reader
        was unprivileged.
    -   Changing access permissions to theses files, this "simple"
        change had a [nasty effect on an ancient version of klogd
        causing the machine to not boot
        anymore](http://git.kernel.org/?p=linux/kernel/git/torvalds/linux-2.6.git;a=commitdiff;h=33e0d57f5d2f079104611be9f3fccc27ef2c6b24).
        This lead to the revert of the patch unfortunately: Never break
        userspace!
    -   `XOR` displayed addresses with a secret value.
    -   Etc.

The solution "retained" (there is never a formal "Yes this is it", you
have to write the code and then this is discussed...) is the first one:
replacing addresses by arbitrary values if reader not privileged.\
However, in order to prevent code duplication, the special [*format
specifier*
`%pK`](http://news.gmane.org/find-root.php?message_id=%3c1292692835.10804.67.camel%40dan%3e)
was added to `printk()`. Depending on the `kptr_restrict` sysctl, this
specifier will restrict access to pointers.

For the occasion, [the new capability
`CAP_SYSLOG`](http://permalink.gmane.org/gmane.linux.kernel.lsm/12185)
was created for this purpose.

A lot of work is still needed however, for example, thanks [to his new
fuzzer](http://codemonkey.org.uk/2010/12/15/system-call-fuzzing-continued/),
Dave Jones [discovered that the loader of ACPI table was
word-writable:](http://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2010-4347)
anybody could load a new ACPI table if `debugfs` was mounted, oops :)

### Marking kernel memory read only

Actually, the Linux kernel does not use all possibilities offered by the
processor for its own memory management: read-only segments are not
really marked as so internally. Things could be improved like what is
now done in user space: data shall not be executable, code shall be
read-only, etc.

This is still a work in progress, but developers try to [remediate
theses issues](http://thread.gmane.org/gmane.linux.kernel/1058823). To
be successful, a few actions are needed:

-   [Really use hardware permission for the `.ro.data`
    segment](http://git.kernel.org/?p=linux/kernel/git/x86/linux-2.6-tip.git;a=commitdiff;h=65187d24fa3ef60f691f847c792e8eaca7e19251).
    Because for the moment, permissions for this segment are purely
    virtual despite the ".ro" in its name.
-   Function pointers never modified shall be marked as `const`-ant
    whenever possible. Indeed, one of the simplest method to exploit a
    kernel vulnerability is to overwrite a function pointer to jump in
    attacker area.\
    Once a variable is marked `const`, it is moved into the previously
    seen `.ro.data` (you can guess that this move is only useful if the
    zone is really read only in hardware). Off course, it will not be
    possible to `const`-ify every function pointers, there will still be
    room for an attacker but this is not a reason to do nothing...
-   Disabling some entry points leading to `set_kernel_text_rw()` (the
    "kernel" equivalent of `mprotect()`) in order to not let attacker to
    change permissions after all.

A priori, developers do not seem opposed to this patch and they would be
even happy to merge it in order to [optimize virtualized
guests](http://article.gmane.org/gmane.linux.kernel/1058954).

### Disabling module auto-loading

Most of the vulnerabilities target code paths barely used. This could,
by the way, be the reason why bugs are still found.

Linux distributions don't have other option than compiling every
features and drivers to have a unique universal kernel. To not bloat the
memory, this is done via modules with a way to load them on demand.

This auto-loading feature is particularly interesting for attackers:
they just have to request an X.25 socket to have its associated module
loaded, ready to be exploited.

Dan Rosenberg (again!) [proposed to automatically load modules only if
the triggering process is
privileged](http://article.gmane.org/gmane.linux.kernel/1058922). Even
if this restriction is already inside grsecurity patches, this "feature"
was considered too dangerous for distributions and was NAKed to prevent
any breakage :-/

### `UDEREF` support for AMD64 (finally)

PaX developers have always been clear: AMD64 Linux systems will never
been as secure as their i386 cousin. This statement is due to the lack
of the segmentation.

However, they did their best to [implement
`UDEREF`](http://grsecurity.net/pipermail/grsecurity/2010-April/001024.html)
anyway.

As a reminder, `UDEREF` prevents the kernel to use memory owned by user
land without stating it explicitly. This features offers protection
against *NULL pointer dereferences* bugs.

On i386, this is easily done by using segmentation logic. But on AMD64,
this stays a (dirty) hack by moving the user space zone at another place
and change its permissions.

The problem is that we just shift the issue: now, instead of deferencing
a null pointer, attacker now has to influence the kernel to dereference
another address, but as pageexec said, if we are at this point, this
should the last of our concern :)\
As if this wasn't enough, this hack "wastes" 5 bits of addressing
(leaving 42 bits for the process) and some bits of d'ASLR by the way...\
The icing on the cake is that the performance are impacted for each
transition user-to-kernel and kernel-to-user because of the TLB flush.

Network security?
-----------------

Network security is not really "sexy" enough to receive the same level
of contributions to the Linux kernel, maybe because researchers prefers
to work on offensive things.\
Besides the [Netfilter rewrite (called nftable) started last
year](http://lwn.net/Articles/324989/), not so many things happened. One
of the few things remarkable was the implementation of [TCP Cookie
Transactions](http://kernelnewbies.org/Linux_2_6_33#head-2c3c3a8cb87d5b7a6f1182e418abf071cda22c8c)
et improvements to "old" syncookies.

When a system is overloaded, TCP syncookies are used to not store states
until the connection is really opened. This "old-school" protection was
designed to evade from SYN flood attacks. Nowadays, this is merely
pointless since today's DoS saturate the network bandwidth instead of
the kernel memory.\
Anyway, this is not a reason to do nothing :)

Previously, SYNcookies were considered as "has to be used in last
resort" because TCP options carried by the first SYN packet were lost
since the kernel was not saving it (congestion bit, *window scaling* or
*selective acknowledgement*).

This is not true anymore: [the kernel now codes theses
information](http://git.kernel.org/?s=4dfc2817025965a2fc78a18c50f540736a6b5c24)
into the 9 lower bits of the TCP Timestamp's SYN-ACK option when
replying.\
This means that syncookie is not harmful anymore for performances and
can be used safely, despite what says the
[tcp(7)](http://www.kernel.org/doc/man-pages/online/pages/man7/tcp.7.html)
manpage (a bug was submitted to update the description).

Kernel confessions
==================

While reading lists, I came across some interesting confessions:

[The capabilities
drama](http://permalink.gmane.org/gmane.linux.kernel.lsm/12196) :
> Quite frankly, the Linux capability system is largely a mess, with big
> bundled capacities that don't make much sense and are hideously
> inconvenient with the capability system used in user space (groups).\
> -hpa

[Too many patches to review for the -stable
branch](http://permalink.gmane.org/gmane.linux.kernel/1068774) :\
> &gt; &gt; I realise it wasn't ready for stable as Linus only pulled it
> in\
> &gt; &gt; 2.6.37-rc3, but surely that means this neither of the
> changes\
> &gt; &gt; should have gone into 2.6.32.26.\
> &gt; Why didn't you respond to the review??\
> \
> I don't actually read those review emails, there are too many of them.

Conclusion
==========

A lot of good things happened in the Linux kernel last year thanks to
the people cited in this post. Moreover, it is interesting to see that
most of theses features have been written by security researchers and
not "upstream kernel developer" (except Ingo Molnar who proved a lot of
good will each time).\
This may be the explanation why each patch merged was the fruit of
never-ending threads (we can applause [their
patience](http://thread.gmane.org/gmane.linux.kernel/1015999/focus=1018279))...\
This is only now that I start understanding how much Brad Spengler was
right when he [declared war against LSM](http://grsecurity.net/lsm.php).
Do "Security" subsystem maintainers should leave their ivory tower and
start understanding the real life of a syadmin? The kind of guy who
don't have time to update every servers to the latest git version, nor
to write SELinux which, by the way, would be useless once a kernel
vulnerability is found.\
Anyway, this is only the opinion of a guy involved in the [security
circus](http://article.gmane.org/gmane.linux.kernel/706950)...

However, we can still be happy to see theses changes finally merged. And
with some luck, we can hope that someday, `mmap_min_addr` will not be
bypassable... And that proactive features will require researchers to
combine multiple vulnerabilities to exploit one flaw.\
I don't say that there will be no more bugs, perish the throught, but I
hope that the exploitation cost will be so high that only a tiny
fraction of attacker will be able to do it.\
At this point, security researchers will have to dive into "logic bugs",
like [Taviso's vulnerabilities
`LD_PRELOAD`/`LD_AUDIT`](http://seclists.org/fulldisclosure/2010/Oct/257)
which were bypassing most of available hardening protections.


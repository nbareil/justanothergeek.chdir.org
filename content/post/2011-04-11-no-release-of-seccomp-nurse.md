---
categories:
 - sandbox
 - linux
 - seccomp
date: "2011-04-11T11:37:00Z"
title: no-release of seccomp-nurse
---
<div
style="border-radius: 6px; background-color: #FAF8EF; -moz-box-shadow: #F6EECD 0px 0px 200px inset; -o-box-shadow: #F6EECD 0px 0px 200px inset; box-shadow: #F6EECD 0px 0px 200px inset; -webkit-border-radius: 6px;-moz-border-radius: 6px;border-collapse: separate;
border-spacing: 1.428em;padding: 1.428em;">

<span
style="text-transform: uppercase; letter-spacing: .04em; color: #5D2A07;">**This
post in a nutshell**</span>\
This was a draft since [my presentation at
Ekoparty](http://chdir.org/~nico/papers/seccomp-nurse10/), I will force
myself to not procrastinate this time. **This post announces the
no-release of seccomp-nurse** (it is not a release because it is still
an advanced proof of concept). Quick links:
-   [seccomp-nurse homepage](http://chdir.org/~nico/seccomp-nurse/)
-   [seccomp-nurse sources](http://github.com/nbareil/seccomp-nurse/)
-   [screencast: sandboxing the python
    interpreter](http://www.youtube.com/watch?v=EUSxAJE9xqI)

</div>

\
[seccomp-nurse](http://github.com/nbareil/seccomp-nurse/) is a generic
sandbox environnement for Linux, which doesn't require any
recompilation. Its purpose is to run legit applications in hostile
environment, I repeat, it is not designed to run malicious binary.\
\
[]() **How does it work?** The following figure describes the
architecture of seccomp-nurse. You can see two processes, one running
the untrusted code and the trusted one. The trusted process is charge of
intercepting syscalls and checking if the action is allowed.\
<div class="separator" style="clear: both; text-align: center;">

[![](http://chdir.org/~nico/seccomp-nurse/seccomp-nurse-architecture.png)](http://chdir.org/~nico/seccomp-nurse/seccomp-nurse-architecture.png)

</div>

\
\
\
***How do we intercept syscalls? ***By using a x86\_32 hack. If you
remember [my previous post, I described how the GNU Libc was executing
syscalls](http://justanothergeek.chdir.org/2010/02/how-system-calls-work-on-recent-linux.html):
by making an indirect call in VDSO. seccomp-nurse overrides this page in
order to call our own function instead of performing the syscall. Our
handler retrieves CPU registers and directly sends them to the trusted
process through a socket. The trusted process checks its policy engine,
like: "can this process open this file?"\
\
***If action is allowed, how to execute it? ***SECCOMP only permits 4
syscalls, how to do? Well. SECCOMP flag is limited to the thread scope,
that means that if a process has two threads, one can be sandboxed
(which will be called untrustee) and the other (called trustee) is free
to do whatever it wants, furthermore, if threads share everything, any
action done in one thread has an impact on the other. This is pretty
cool! But so dangereous!\
\
Indeed, everything is shared, only the CPU registers are not shared
between threads, that's all! The trustee must consider its environment
as hostile: its code must not do on memory access, only registers can be
used. That's why [this part is written in
assembly](https://github.com/nbareil/seccomp-nurse/blob/master/companion.s)
in order to control every instructions. It has been designed to be the
simplest possible because this is the keystone of the sandbox, the
security of the system relies on it.\
\
This routine is completely dummy and has no intelligence at all,
everything is done in the trusted process, the trustee understands only
theses commands:\
-   Execute this syscall
-   Raise a SIGTRAP (for debugging purpose)
-   Native exit
-   Poke/Peek memory

***How are exchanged the information between both processes? ***Thanks
to a POSIX shared memory, marked as read-only for the untrusted process.
That way, when the trusted process wants to delegate a syscall, it
writes the values of all registers in this shared memory and notifies
the trustee to execute it. With this mechanism, there is no race
condition: every syscall arguments are copied so they cannot be modified
after the policy check.\
\
***Limitations: ***Because of our way of intercepting syscalls, we can
only run dynamically linked binaries on 32 bits, using the GNU Libc. It
is hoped that the situation will improve greatly in the following
weeks... Stay tuned!\
\
***Performances: ***Hahem. I don't know. Each time the untrustee makes a
syscall, our sandbox makes a lot of back and forth between both
processes (one back and forth = at least one read, one write).\
\


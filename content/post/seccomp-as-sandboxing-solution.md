---
categories:
 - sandbox
 - linux
 - syscall
 - seccomp
date: "2010-03-04T14:10:00Z"
title: SECCOMP as a Sandboxing solution ?
description: SECCOMP is a Linux feature introduced in 2.6.23 to run untrusted executables.
---

### Sandboxing technology?

SECCOMP is a Linux feature introduced in 2.6.23 (2005) by [Andrea
Arcangeli](http://www.cpushare.com/blog/andrea/), initially designed for
grid computing applications. The idea was to sell CPU times to the
public by running untrusted binaries.

When a process goes into SECCOMP mode, it can only do 4 syscalls:
`read`, `write`, `_exit` and `sigreturn`. The kernel will enforce this
limitation by killing (by a SIGKILL signal) the process if an
unauthorized system call is made.

The security warranty here is pretty strong: the only way to evade the
protection is to use file descriptors already opened or access to shared
memory.

SECCOMP is the perfect solution for a sandbox because the kernel attack
surface is really small! For the record, in the whole kernel security
history, no vulnerability was ever found in theses syscalls.

The downside of this feature is its limitation! Once in SECCOMP mode, it
is impossible to do anything except some arithmetics. Another SECCOMP
problem is that the action of entering in SECCOMP mode is voluntary: the
program needs to issue itself a `prctl()` call with appropriate
arguments: that means the application needs to be developed
specifically.

The purpose of a sandbox is to run untrusted binaries without requiring
sources modifications. Currently, there are two main problems:

-   Enter in SECCOMP mode
-   Prevent the untrusted process from issuing system call

Both problems need to be solved without requiring a recompilation. How
to do it despite this constraint?

### Entering in SECCOMP mode

Basically, we need to inject a call to `prctl()` into a given process.
The best known method is to write directly into the memory of the
process by using the `ptrace()` interface.

Beside the evident problems of portability and the inherent difficulties
of injecting instructions in a process, this solution was not
investigated because of its hackish nature.

Instead, let's take a look at a simple binary:

``` {.src .src-txt}
$ objdump -f a.out
a.out:     file format elf32-i386
architecture: i386, flags 0x00000112:
EXEC_P, HAS_SYMS, D_PAGED
start address 0x080482e0
```

The entry point of the binary, `0x080482e0`, is the `_start` routine
provided by the compiler and shown here:

``` {.src .src-asm}
080482e0 <_start>:
 80482e0:       31 ed                   xor    ebp,ebp
 80482e2:       5e                      pop    esi
 80482e3:       89 e1                   mov    ecx,esp
 80482e5:       83 e4 f0                and    esp,0xfffffff0
 80482e8:       50                      push   eax
 80482e9:       54                      push   esp
 80482ea:       52                      push   edx
 80482eb:       68 b0 83 04 08          push   0x80483b0
 80482f0:       68 c0 83 04 08          push   0x80483c0
 80482f5:       51                      push   ecx
 80482f6:       56                      push   esi
 80482f7:       68 94 83 04 08          push   0x8048394
 80482fc:       e8 c7 ff ff ff          call   80482c8 <__libc_start_main@plt>
```

It initializes the stack and then calls the "init function" of the GNU
libc which will eventually execute the `main()` function. At this point,
the program is effectively ran.

The interesting property of this routine is how the libc function is
called: by using the Procedure Linkage Table (PLT). In a few words, that
means the linker will have to resolve the symbol.

Thanks to the `LD_PRELOAD` feature, it's possible to overload ELF
symbols. This is how we are issuing the `prctl()` call: by overriding
the `__libc_start_main` function and calling it on our own to be totally
transparent, here is how it's done:

    typedef int (*main_t)(int, char **, char **);
    main_t realmain;

    int __libc_start_main(main_t main,
                          int argc,
                          char *__unbounded *__unbounded ubp_av,
                          ElfW(auxv_t) *__unbounded auxvec,
                          __typeof (main) init,
                          void (*fini) (void),
                          void (*rtld_fini) (void), void *__unbounded
                          stack_end)
    {
            void *libc;
            int (*libc_start_main)(main_t main,
                                   int,
                                   char *__unbounded *__unbounded,
                                   ElfW(auxv_t) *,
                                   __typeof (main),
                                   void (*fini) (void),
                                   void (*rtld_fini) (void),
                                   void *__unbounded stack_end);

            libc = dlopen("libc.so.6", RTLD_LOCAL  | RTLD_LAZY);
            if (!libc)
                    ERROR("  dlopen() failed: %s\n", dlerror());
            libc_start_main = dlsym(libc, "__libc_start_main");
            if (!libc_start_main)
                    ERROR("     Failed: %s\n", dlerror());

            realmain = main;
            void (*__malloc_initialize_hook) (void) = my_malloc_init;
            return (*libc_start_main)(wrap_main, argc, ubp_av, auxvec,
            init, fini, rtld_fini, stack_end);
    }

In a nutshell:

1.  The first parameter of the function is the address of the `main`
2.  We open the libc library object
3.  We find the location of the original `__libc_start_main`
4.  We save the original `main` function into a global variable
5.  We call the original `__libc_start_main` by replacing the original
    `main` by our own (`wrap_main`) shown here:

<!-- -->

    int wrap_main(int argc, char **argv, char **environ)
    {
            if (prctl(PR_SET_SECCOMP, 1, 0, 0) == -1) {
                    perror("prctl(PR_SET_SECCOMP) failed");
                    printf("Maybe you don't have the CONFIG_SECCOMP support built into your kernel?\n");
                    exit(1);
            }

            (*realmain)(argc, argv, environ);
    }

At this point, the original `main()` is called and the program is
executed under SECCOMP. The drawback of this method is its
incompatibility with statically linked binary. In this case, the
`_start` routine calls directly `__libc_start_main` function without
using the PLT.

The big vulnerability here is the case of a malicious binary with a
`_start` routine not calling `__libc_start_main`, in that case, the
`prctl()` would not be done and the program would run without
sandboxing. This issue was ignored for the moment but it will require
some thought...

There is still the option of modifying the memory with some `ptrace()`
calls or [rewriting some memory mapping thanks to the method of
Sebastian Krahmer presented in
lasso](http://c-skills.blogspot.com/2010/02/runtime-hot-patching-processes-wo.html).

### Interception of syscalls

Now that the application is running under SECCOMP, it's not possible
anymore to do a syscall (except `read`, `write`, `_exit` and
`sigreturn`). Because we made the assumption that the sandboxed program
was not designed to run SECCOMP, we have to prevent it from issuing such
forbidden call.

Thus, we need to intercept the syscall before the kernel, process it if
possible and emulate the kernel behavior. The interception of syscalls
is usually done, again, with the `ptrace()` interface, the main drawback
of this method is the lack of debugging mean: because all debuggers use
`ptrace` and a process can only be traced once, that means that each bug
would be a nightmare.

Furthermore, the `ptrace` interface is known to be crippled and a lot of
security bugs have been found, fortunately, this was from the tracer
side, but there was some advisories where the tracee could harm the
tracer process.

Another solution was investigated based on the analysis of the syscall
handling in the Libc. We saw in my [previous post "How system calls work
on
Linux?"](http://justanothergeek.chdir.org/2010/02/how-system-calls-work-on-recent-linux.html)
that the GNU Libc was making syscalls by doing a `call *%gs:0x10` (where
0x10 is variable).

#### Hijacking VDSO

In order to intercept (legit) sycalls, we need to intercept the previous
`call` instruction. This is easy, we have to overwrite the pointer
stored at the address `%gs:0x10` and redirect the process to our own
function.

This what we do immediatly after turning on SECCOMP:

    static void hijack_vdso_gate(void) {
            asm("mov %%gs:0x10, %%ebx\n"
                "mov %%ebx, %0\n"

                "mov %1, %%ebx\n"
                "mov %%ebx, %%gs:0x10\n"

                : "=m" (real_handler)
                : "r" (handler)
                : "ebx");
    } __attribute__((always_inline));

From now on, every syscalls are trapped by our handler, even the one
which are "allowed" by SECCOMP.

#### Demultiplexing syscalls

The purpose of the handler is to look at the syscall requested, see if
we need to honor it ourself (because it's a forbidden syscall) or run
the original VDSO's function.

Our handler needs to be carefully written in order to not mess up with
the registers: our function **must not** modify any register. That is
the reason why it was written in assembly:

    void handler(void) {
            /* syscall_proxy() is the "forbidden syscalls" handler */
            void (*syscall_proxy_addr)(void) = syscall_proxy;

            asm("cmpl $4, %%eax\n"
                "je do_syscall\n"

                "cmpl $3, %%eax\n"
                "je do_syscall\n"

                "cmpl $0xfc, %%eax\n"
                "jne wrapper\n"

                "movl $1, %%eax\n"
                "jmp do_syscall\n"

                "wrapper:\n"
                "                   call *%0\n"
                "                   jmp out\n"

                "do_syscall:\n"
                "                   call *%1\n"
                "out:               nop\n"

                : /* output */
                : "m" (syscall_proxy_addr),
                  "m" (real_handler)); /* real_handler is the original
                                        * VDSO function, performing 
                                        * effectively the syscall 
                                        */
    }

Each time the libc makes a syscall, we either perform the action
directly or we call our "syscall proxy". More on that later...


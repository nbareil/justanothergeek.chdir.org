---
categories:
 - linux
 - kernel
 - exploit
date: "2010-02-23T12:26:00Z"
title: No more ASLR bypass on Linux 2.6.30
---

While trying to exploit a local setuid application, I had the
unhappiness (as an attacker) to see that the security of the ASLR Linux
kernel has increased, removing a whole method of exploitation. But let's
begin from the start:\
The minimalist vulnerable example could be this `vuln.c`:\
``` {.src .src-c}
#include <stdio.h>
#include <unistd.h>

int main( int argc, char *argv[] )
{
        char buf[4];

        printf("%#p\n", &buf);
        strcpy( buf, argv[1] );
        return 0;
}
```

Because of the *Address Space Layout Randomization* (ASLR), this bug is
tough to exploit: if the binary is compiled with the right options and
the kernel is configured to fully randomize the address space, it
becomes impossible to guess where the buffer is, nor the location of the
functions' libraries.\
But there was a trick (firstly published by [Jon Erickson in his
book](http://www.amazon.com/Hacking-Art-Exploitation-Jon-Erickson/dp/1593271441)):
the randomization is computed at `exec*()` time, the seed used to
generate the entropy was rekeyed every X milliseconds with the PID and
the `jiffies` variable (which is the number of clock interruptions since
the boot), it was known to be cryptographically weak but it was good
enough for daemons: remotely, it's not possible to guess either the PID
or `jiffies` (except in case of a format string vulnerability or an
information leak).\
But locally, the entropy was just useless: a minimalistic process which
would just `exec*()` another one would get the same memory layout
because both program has the same PID and the jiffies would not be
updated.\
Practically, even on a fully randomized system, it was possible to guess
the addresses, here is the minimalistic program just printing the
address of its buffer and executing the vulnerable binary (which itself
prints its buffer address):\
``` {.src .src-c}
#include <unistd.h>

int main(int argc, char **argv) {
        char dummy[4] = "AAA";

        printf("%#p\n", dummy);
        execl("./vuln", dummy, NULL);
}
```

The following Python code based on `expect` runs the exploit multiple
times and compute the differences between the addresses of `./vuln` and
`./exploit` :\
``` {.src .src-python}
#! /usr/bin/python

import pexpect

while True:
    child = pexpect.spawn('./exploit')
    child.sendeof()

    a=int(child.readline()[:-2], 16)
    b=int(child.readline()[:-2], 16)

    print 'offset=%#x' % (b-a)
    child.expect(pexpect.EOF)
```

Let's do it:\
    lenny32:/tmp$ uname -a
    Linux lenny32 2.6.26-2-686 #1 SMP Wed Aug 19 06:06:52 UTC 2009 i686 GNU/Linux
    lenny32:/tmp$ cat /proc/sys/kernel/randomize_va_space
    2
    lenny32:/tmp$ ./guess_offset
    offset=0x10
    offset=0x148160
    offset=0x10
    offset=0x10
    offset=0x10
    offset=0x1bf9d0
    offset=0x10
    offset=0x1d91f0
    offset=0x10
    offset=-0x2ba2a0
    offset=0x3d050
    offset=0x10
    offset=0x10
    offset=0x10
    offset=-0x19a990
    offset=0x10
    offset=0x10
    offset=0x10
    offset=0x10
    offset=0x10
    offset=0x10
    offset=0x10
    KeyboardInterrupt

Most of the time, we can see that the offset is equals to `0x10`, great!
But on a 2.6.32 kernel, the result is totally different:\
    $ ./guess_offset
    offset=0x4fddb0
    offset=0x69f330
    offset=0x137e40
    offset=0x6b49f0
    offset=0x407600
    offset=0x14cf50
    offset=0x3f4930
    offset=0x4d0f80
    offset=0x107d20
    offset=0x1969b0
    offset=0x1ae360
    offset=0x409b30

In other words, it's now impossible to guess the address space layout
with this method.\
When was patched the function in charge of the randomness,
[`get_random_int()`](http://lxr.linux.no/linux+v2.6.32/+code=secure_ip_id)?
Let's use `git-blame` in order to annotate each source line with its
modification date and commit:\
    % git blame -L 1688,1709 drivers/char/random.c
    8a0a9bd4 DEFINE_PER_CPU(__u32 [4], get_random_int_hash);
    ^1da177e unsigned int get_random_int(void)
    ^1da177e {
    8a0a9bd4  struct keydata *keyptr;
    8a0a9bd4  __u32 *hash = get_cpu_var(get_random_int_hash);
    8a0a9bd4  int ret;
    8a0a9bd4 
    8a0a9bd4  keyptr = get_keyptr();
    26a9a418  hash[0] += current->pid + jiffies + get_cycles();
    8a0a9bd4 
    8a0a9bd4  ret = half_md4_transform(hash, keyptr->secret);
    8a0a9bd4  put_cpu_var(get_random_int_hash);
    8a0a9bd4 
    8a0a9bd4  return ret;
    ^1da177e }
    ^1da177e 

Arg! It was patched in commit
[`8a0a9bd4`](http://git.kernel.org/?p=linux/kernel/git/torvalds/linux-2.6.git;a=commit;h=8a0a9bd4db63bc45e3017bedeafbd88d0eb84d02)
by Linus Torvalds in response to
[CVE2009-3238](http://cve.mitre.org/cgi-bin/cvename.cgi?name=2009-3238)
in May 2009. The first released kernel carrying this patch is the 2.6.30
in June 2009.

Actually, I'm not aware of any generic trick to achieve the same goal
(now that [information leaks on /proc entries have been fixed
too](http://git.kernel.org/?p=linux/kernel/git/torvalds/linux-2.6.git;a=commit;h=f83ce3e6b02d5e48b3a43b001390e2b58820389d)).


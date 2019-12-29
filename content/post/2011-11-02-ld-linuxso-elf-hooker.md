---
categories:
 - sandbox
 - glibc
 - elf
date: "2011-11-02T16:30:00Z"
title: ld-linux.so ELF hooker
description: I release a new tool, ldshatner, to inject code at runtime without the LD_PRELOAD hack
---
<div
style="-moz-border-radius: 6px; -moz-box-shadow: #F6EECD 0px 0px 200px inset; -o-box-shadow: #F6EECD 0px 0px 200px inset; -webkit-border-radius: 6px; background-color: #faf8ef; border-collapse: separate; border-radius: 6px; border-spacing: 1.428em; box-shadow: #F6EECD 0px 0px 200px inset; padding: 1.428em;">

<span
style="color: #5d2a07; letter-spacing: 0.04em; text-transform: uppercase;">**TL;DR**</span>\
[Stéphane](https://plus.google.com/108914619478390609767) and
[myself](https://plus.google.com/114289168433047035840) are releasing ag
new tool injecting code at runtime, just between the ELF loader and
target binary. It is an alternative to `LD_PRELOAD`, just a little bit
more intrusive but 100% reliable :)\
<div style="text-align: center;">

 [Sources were released on
Github](https://github.com/sduverger/ld-shatner)

</div>


\
<span style="font-family: inherit;">\
</span>\
<span style="font-family: inherit;">When a binary is execve(), the
kernel extracts from the ELF headers the interpreter to be launched,
usually  </span><span
style="font-family: 'Courier New', Courier, monospace;">/lib/ld-linux.so.2</span><span
style="font-family: inherit;">. </span><span
style="background-color: transparent; font-family: inherit;">The kernel
creates a new process and prepares the environment (arguments and
auxiliary data). The target ELF entry point is set in auxiliary vector
of type "ENTRY".</span>\
<span style="background-color: transparent; font-family: inherit;">\
</span>\
<span style="font-family: inherit;">Then the kernel opens the requested
interpreter, maps the memory regions and start its execution at ld's ELF
entry point. Then the loader analyzes the target ELF file, performs its
loader work and sets EIP to target ELF entry point (extracted from
auxv). At this point, main()'s program is eventually executed.</span>\
<span style="font-family: inherit;">\
</span>\
<span style="font-family: inherit;">Our goal was to permit the execution
of code for abitrary dynamically linked binary without patching each of
them. So our interest moved on <span
style="background-color: transparent;">the loader, the common point
between most executables. Thus, we decided to patch a normal ld in order
to inject code. M</span></span><span
style="background-color: transparent;">y awesome colleague, </span><span
style="background-color: transparent; font-family: inherit;">Stéphane
Duverger (the [ramooflax](https://github.com/sduverger/ramooflax)
author!) and myself wrote
</span>[ld-shatner](https://github.com/sduverger/ld-shatner). <span
style="background-color: transparent; font-family: inherit;">Its task is
to patch </span><span
style="background-color: transparent; font-family: 'Courier New', Courier, monospace;">ld-linux.so</span><span
style="background-color: transparent; font-family: inherit;"> file
accordingly:</span>\
\
<div class="separator" style="clear: both; text-align: center;">

</div>

<div class="separator" style="clear: both; text-align: center;">

</div>

<div class="separator" style="clear: both; text-align: center;">

</div>

1.  <span style="background-color: transparent;"><span
    style="font-family: inherit;">After ELF header, we shift "ELF
    program header" a few pages away</span></span>
2.  <span style="font-family: inherit;"><span
    style="background-color: transparent;">In this new section, we
    inject a "loader routine"
    ([hooked.s](https://github.com/sduverger/ld-shatner/blob/master/hooked.s))
    and</span><span style="background-color: transparent;"> embedded
    code to be executed at runtime</span></span>
3.  <span
    style="background-color: transparent; font-family: inherit;">After
    having been saved in our section, ld's ELF entry point
    is </span><span
    style="background-color: transparent; font-family: inherit;">overwritten
    to jump directly on our routine. This routine </span><span
    style="background-color: transparent; font-family: inherit;">extracts
    from auxiliary vectors the target ELF entry point and </span><span
    style="background-color: transparent;"><span
    style="font-family: inherit;">overwrites it with a pointer to our
    embedded code (</span><span
    style="font-family: 'Courier New', Courier, monospace;">func()</span><span
    style="font-family: inherit;"> in </span>[the
    payload](https://github.com/sduverger/ld-shatner/blob/master/obj.c)<span
    style="font-family: inherit;">).</span></span>
4.  <span style="background-color: transparent;"><span
    style="font-family: inherit;">Original ld's entry point is called
    and ld works as usual</span></span>
5.  <span style="font-family: inherit;"><span
    style="background-color: transparent;">Eventually, it calls entry
    point set in auxiliary vector (which</span><span
    style="background-color: transparent;"> was replaced by a pointer to
    our payload)</span></span>
6.  <span style="background-color: transparent;"><span
    style="font-family: inherit;">Embdded code runs</span></span>
7.  <span style="font-family: inherit;"><span
    style="background-color: transparent;">It returns to our routine
    which finally jumps on original target</span><span
    style="background-color: transparent;"> entry point</span></span>


<span style="background-color: transparent;">Some pictures before/after
ld-shatner voodoo:</span>


  ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  [![ld-shatner voodo](https://docs.google.com/drawings/pub?id=134woIW7XWxLXnXc-8vNTcUyhuOqD-zt8IoQYKivDDh0&w=1501&h=979)](https://docs.google.com/drawings/pub?id=134woIW7XWxLXnXc-8vNTcUyhuOqD-zt8IoQYKivDDh0&w=1501&h=979)
  
  ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

### Screenshot

``` {style="background-color: #f8f8f8; color: #444444; font-family: 'Bitstream Vera Sans Mono', Courier, monospace; font-size: 11px; font: normal normal normal 12px/normal 'Bitstream Vera Sans Mono', Courier, monospace; padding-bottom: 0px; padding-left: 0px; padding-right: 0px; padding-top: 0px; white-space: pre-wrap; width: 74em; word-wrap: break-word;"}
$ make clean all
$ cp /lib/ld-linux.so.2 /bin/ls .
$ ./ld-shatner ld-linux.so.2 obj.elf
$ sudo cp ld-hook.so /lib/
$ ./interpatch ls
$ ./ls 
ld-hook <---------------------- output of obj.elf
[...]
```

\
(Ok, we cheat for the moment because we have to patch ls binary but we
will not have to do that eventually)\
### So what?

My ultimate goal for ld-shatner is to use this method for starting
applications in my sandbox
project, [seccomp-nurse](http://chdir.org/~nico/seccomp-nurse/). For the
moment, I rely on LD\_PRELOAD feature but this approach is... hackish
and I have to work around some bugs because of this special context...


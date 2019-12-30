---
categories:
 - sandbox
 - vulnerability
 - seccomp
 - kernel
date: "2010-08-25T14:09:00Z"
title: What is really the attack surface of the kernel running a SECCOMP process?
description: Were our SECCOMP expectations right?
---

In a previous post, [I said the attack surface of the kernel for processes running SECCOMP was really
low](http://justanothergeek.chdir.org/2010/03/seccomp-as-sandboxing-solution/).
To confirm this assumption, each [vulnerability affecting the 2.6 kernel](http://secunia.com/advisories/product/2719/) was reviewed.\
\
Only those triggerable from a SECCOMPed process were kept. On 440
vulnerabilities, 13 were qualified:\
\
  Impact                                        Description                                             Architecture   Reference
  --------------------------------------------- ------------------------------------------------------- -------------- ---------------------------------------------------------------------------------------------------------------------------------------
  <span style="color: #ff1a00;">HIGH</span>     infinite loop triggering signal handler                 **i386**       [CVE-2004-0554](http://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2004-0554)
  <span style="color: #ff7400;">MEDIUM</span>   `audit_syscall_entry` bypass                            amd64          [CVE-2009-0834](http://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2009-0834)
  <span style="color: #ff7400;">MEDIUM</span>   `SECCOMP` bypass                                        amd64          [CVE-2009-0835](http://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2009-0835)
  <span style="color: #ff7400;">MEDIUM</span>   Non-sign extension of syscall arguments                 s390           [CVE-2009-0029](http://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2009-0029)
  <span style="color: #ff7400;">MEDIUM</span>   EFLAGS leak on context switch                           amd64/i386     [CVE-2006-5755](http://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2006-5755)
  <span style="color: #ff7400;">MEDIUM</span>   Nested faults                                           amd64          [CVE-2005-1767](http://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2005-1767)
  <span style="color: #ff7400;">MEDIUM</span>   Not handling properly certain privileged instructions   s390           [CVE-2004-0887](http://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2004-0887)
  <span style="color: #73880a;">LOW</span>      Fix register leak in 32 bits syscall audititing         amd64          [81766741f](http://git.kernel.org/?p=linux/kernel/git/torvalds/linux-2.6.git;a=commitdiff;h=81766741fe1eee3884219e8daaf03f466f2ed52f)
  <span style="color: #73880a;">LOW</span>      64-bit kernel register leak to 32-bit processes         amd64          [24e35800c](http://git.kernel.org/?p=linux/kernel/git/x86/linux-2.6-tip.git;a=commitdiff;h=24e35800cdc4350fc34e2bed37b608a9e13ab3b6)
  <span style="color: #73880a;">LOW</span>      Register leak                                           amd64          [CVE-2009-2910](http://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2009-2910)
  <span style="color: #73880a;">LOW</span>      DoS by using malformed LDT                              amd64          [CVE-2008-3247](http://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2008-3247)
  <span style="color: #73880a;">LOW</span>      DoS on floating point exceptions                        powerpc HTX    [CVE-2007-3107](http://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2007-3107)
  <span style="color: #73880a;">LOW</span>      DoS on 32-bit compatibility mode                        amd64          [CVE-2005-1765](http://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2005-1765)

\
In other words, if you are running a pure 32 bits environment, our
initial intuition was almost good with two bugs so far (in 2004 and
2006). However, on AMD64, I wouldn't bet.\
\
**Disclaimer**: Off course, theses numbers are meaningless because of
the [non-disclosure policy of the kernel's developpers](http://lwn.net/Articles/400141/).


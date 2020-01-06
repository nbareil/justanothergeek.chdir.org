---
date: 2019-01-06
title: XXX
description: XXX
---

## The problem

Unless you are an anti-virus vendor, [@Neo23x0](https://twitter.com/cyb3rops/)
or a passionated one-man shop malware researcher, the management of Yara rules
quickly become messy in a team environment as everything becomes eventually
inconsistent:

- rule naming: `MyBigCorp_Emotet`, `Emotet`, `Emotet_20`, or `Incident_SANDWICH`?
- use of tags: Should it be the malware family or a higher-level classification (RAT, Ransomware)?
- use of namespaces
- "*coding style*": where should go the curly braces? Tab or spaces?
- filenames: `.yara` or `.yar` ?
- meta variables: What are the mandatory fields? Should the hash be a md5 or
  sha1? Should there be a score or a confidence level, numeric or appreciative?
- use of modules: should we stick to the default Yara modules?
- etc.

To this, add all the rules you can collect in OSINT, Virustotal, vendors leaks,
etc.

Eventually, you get a folder of 500+ Yara files, that's where your nightmare
begins. End of 2017, we could not move anymore: some rules were crashing our
engines, we had too many duplicated rules, too many inconsistent variables; In
other words, our technical debt was too high: it was time to give some ❤️ to our
tooling suite and level up.

At that time, on top of my memory, [plyara](https://github.com/plyara/plyara)
was the only Yara parser available, it was written in Python using
[Ply](https://www.dabeaz.com/ply/) and quite popular.

## Remove duplicates

Our first application use case was to remove all duplicates from our ruleset. To
do that, we needed to compute a kind of hash for each Yara rule, should be
trivial right?

Yeah except that people were copying and pasting OSINT rules into their own
repository while also changing line orders, fiddling with spaces here and there:
a simple string comparison was not going to make it. For reasons I honestly don't
remember but something related to a design choice (so not fixable without
breaking everything), plyara was not going to make it at that time (Today,
plyara is 👍). 

We ate the dust for a few months, even tried to see [how hard would it be to implement one parser ourselves](https://github.com/nbareil/yaraparser-go)
(answer: too hard for me) until @Northern-Lights released his [yara parser](https://github.com/Northern-Lights/yara-parser) in Go.

So we wrote something like what [@Neo23x0 published recently in a gist](https://gist.github.com/Neo23x0/577926e34183b4cedd76aa33f6e4dfa3).

## Enforcing a standard coding style

Consistent rules also benefit having a unified coding style, like `gofmt`, you
will never have a debate about space or bracing position. It will also make your
life much easier if you need to grep/sed/awk for a massive quick fix across your
ruleset.

We chose again the
[yara-parser](https://github.com/Northern-Lights/yara-parser) library because
his author had already prepared a `Serialize()` method for each data
structure. It was just missing a global `Serialize()` method, which was quickly
implemented in [PR #9](https://github.com/Northern-Lights/yara-parser/pull/9).

## Improve consistency



## What's next?

### Performance penalty

What is the impact of my new Yara rule?
https://gist.github.com/Neo23x0/e3d4e316d7441d9143c7
https://twitter.com/cyb3rops/status/1194330847844950017
https://twitter.com/wxs/status/1179840939440906240
https://twitter.com/wxs/status/1082379340493582342

### Tagging for different usage

https://github.com/VirusTotal/gyp ->  AST can be serialized as [a Protocol Buffer](https://github.com/VirusTotal/gyp/blob/master/pb/yara.proto), which facilitate its manipulation in other programming languages.

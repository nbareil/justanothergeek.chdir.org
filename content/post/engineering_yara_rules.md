---
date: 2020-01-06
title: Engineering Yara rules
description: Unless you are an anti-virus vendor, the management of Yara rules
  quickly become messy in a team environment as everything becomes eventually
  inconsistent. This post introduces how we tackled these issues...
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

So we wrote something like what [@Neo23x0 published recently in a gist](https://gist.github.com/Neo23x0/577926e34183b4cedd76aa33f6e4dfa3) (using plyara).

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

To channel the creativity of rules authors regarding their use of meta
variables, tags or filename, we implemented Python tests (using plyara!) in
our TravisCI environement. That way, consistency tests are ran for each push or pull
request to our main Git repository.

They can also be set as an enforcing gate (i.e. if the tests fail, no merge) but
we decided to not enable it as we like to be able to push to master.

The Python tests look like these ones:

```
class YaraTester(unittest.TestCase):
    ...

    def test_invalid_extension_filename(self):
        for fname in glob.glob('**/*'):
            if not os.path.isfile(fname):
                continue
            if not fname.endswith('yara'):
                self.fail('"%s"\'s filename does not comply: please only use .yara' % (fname))
                
    def test_unknown_meta(self):
        rules = self._parse_our_yarafiles()
        for rule in rules:
            for meta in rule.get('metadata', []):
                metaname = ''.join(meta.keys())
                if metaname not in ALLOWED_META_VAR:
                    self.fail('rule "%s" is using not allowed variable name: "%s"' % (rule['rule_name'], metaname))

    def test_insufficient_meta(self):
        rules = self._parse_our_yarafiles()
        varnames=set()
        for rule in rules:
            for meta in rule.get('metadata', []):
                metaname = ''.join(meta.keys())
                varnames.add(metaname)
            for mandatory in MANDATORY_VAR_NAMES:
                if mandatory not in varnames:
                    self.fail('rule "%s" misses mandatory meta "%s"' % (rule['rule_name'], mandatory))
            if not ('reference' in varnames or 'reference_hash' in varnames):
                    self.fail('rule "%s" misses a reference or a hash' % (rule['rule_name']))

    def test_valid_tags(self):
        rules = self._parse_our_yarafiles()
        for rule in rules:
            for tag in rule.get('tags', []):
                if tag not in ALLOWED_TAGS:
                    self.fail('rule "%s" uses non-whitelisted tag: "%s"' % (rule['rule_name'], tag))
```

Now, our rules are uniform and easier to manage. What are our next steps?

## What's next?
### Improve our safety confidence

You can kill your detection sensor if your Yara rule is badly written (like with
unbounded regexps). Today, it is kind of a big bet 🎲: you push your rule and 🤞
that it won't clash with another rule.

@Neo23x0 and @wxs have continuously written
[a](https://twitter.com/cyb3rops/status/1194330847844950017)
[lot](https://twitter.com/wxs/status/1179840939440906240)
[about](https://twitter.com/wxs/status/1082379340493582342)
[Yara performances](https://gist.github.com/Neo23x0/e3d4e316d7441d9143c7).

But for the moment, it not easily actionable:

1. technically speaking, you have to be smart with the regexp parsing or write
   good enough regexp to match regexps.
1. what is true today won't necessarily be true tomorrow: as @wxs said, these 
   optimization rules are constantly changing across libyara's releases.

In the meantime, another approach would be to [benchmark rules like Golang](https://golang.org/pkg/testing/#hdr-Benchmarks)
to see the impact of each rule addition.

### Tagging for different usage

All Yara rules are not made equal:

- Their usage may be various: low signal rules (base64 strings, embedded MZ) or
  high signal (Pirpi's obfuscation algorithm, packing routine). Usually, this is
  addressed using a score meta variable.

- Their scope may differ: some are designed for file categorization (like magic
  types), malware on-disk detection, forensics/artefacts discovery, live memory
  dump, sandbox, some for Linux, etc. Usually, this is dealt with tags.

Yet, I feel like we miss a high-level tool/process that do the shuffling
automatically. Based on a catalog of Yara files, this tool would automatically
create:

- `aggregated_sandbox_rules_detection.yara`: All high signal detection rules
  actionable by sandboxes

- `aggregated_forensics.yara`: Low and high signal rules for files.

- ...

While this is technically easy to do, it relies on correctly tagged rules and
that's where things are messy: How many rules are written (with their famous
`$mz at 0` condition) to only match files while they could also support process
memory easily?

### Moving to gyp

The VirusTotal team wrote an [official Go library for parsing YARA
rules](https://github.com/VirusTotal/gyp/), gyp, very
similarly to yara-parser. Its killer feature is that parsed rules can be
serialized as [a Protocol Buffer](https://github.com/VirusTotal/gyp/blob/master/pb/yara.proto), this
facilitates massively its manipulation in other programming languages.

I guess we will eventually migrate to this library...

### MISP integration

I wish to integrate more Yara to our MISP instance: we are currently pushing our
malware samples to an instance and also storing *some* rules to it. Yet, we
don't link both: it would be neat that when you upload a sample, MISP scans it
automatically by all stored Yara rules and same thing when you upload a new Yara
rule.

I am sure everything is already available in MISP to make it happen, it just
needs to be glued together...


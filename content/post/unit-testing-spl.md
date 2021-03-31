---
date: 2021-03-18
title: Unit-testing the Splunk Processing Language
description: XXX
---

In my previous post [Githubify the SOC](https://justanothergeek.chdir.org/2020/10/githubify-the-soc/), I declared my undying love to continuous integration and deployment capabilities applied to Detection Engineering. Now, let's put the theory into practice! And maybe the best in class to inspire is Microsoft Azure Sentinel.

Have you seen the Github Checks in place for adding rules into [Azure/Azure-Sentinel](https://github.com/Azure/Azure-Sentinel) along their [Azure Sentinel Pipeline](https://dev.azure.com/azure/Azure-Sentinel/_build/results?buildId=20904&view=results) ? 😍

That's some kind of serious CI/CD practices! How could we apply the same thing for our on-prem deployment?

# Goals

In a "classic" software shop , developpers rely on two levels of testing:
1. Unit-tests, usually achieved in a few seconds. Coupled with basic tests for an immediate feedback (similarly to the checks done by your IDE: syntax checks, undefined functions, etc.)
1. Integration tests for more thorough scenarios, taking a few minutes to complete

In the context of Detection Engineering (i.e. _Writing detection rules for a SIEM_):

1. Unit-tests would be checking that:
  - The syntax is valid
  - We are not using fields that do not exist
  - The styling guideline is respected
  - There is [no performance trap](https://docs.splunk.com/Documentation/Splunk/8.1.2/Search/Quicktipsforoptimization)
2. While integration tests would check that:
  - We are correctly alerting for a True Positive
  - False-Positives are under-control
  - We are not adding a hit to the platform performance
  - We are paying attention to [delayed events](https://opstune.com/2016/12/13/siem-tricks-dealing-with-delayed-events-in-splunk/)

Today, this post will address only the unit-testing's part, applied to Splunk.

# Step 1, parsing Splunk's Search Processing Language

Splunk's Search Processing Language (aka SPL) is a very powerful and expressive query language. It is a very pleasant language to use, especially when you come from [Elastic Query DSL](https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl.html).

The language is very permissive, almost everything is optional: fields separator, usage of quotes, no types (string or integer, nobody cares), positions of arguments, etc.

Initially, early 2020, I expected to have a lot of robust SPL parsers available in the opensource but... nope (well there is a caveat here, follow me).

I found two projects:
- https://github.com/salspaugh/splparser: 
- https://github.com/ffly1985/splunk_antlr_spl

## splparser

Here I am trying [salspaugh/splparser](https://github.com/salspaugh/splparser), developped in 2013, and to add confidence, its README states up-front "_It is capable of parsing 66 of the most common approximately 132 SPL commands_".

Of course, its Python distribution is broken (quite expected for a project with its last commit 4 years ago) but quickly fixed, I ran it on our dataset of queries and it failed on the first query because of one unsupported function. I had 0️⃣ knowledge of PLY/LEX/YACC and [adding a SPL command looked abysal to me](https://github.com/salspaugh/splparser/commit/8511b66e78c26fddaacc52f630bc41c31df1e989).

🤬

I rage-quitted, thinking it was a 💩 project and moved one. BIG MISTAKE retrospectively but 🤷‍♂️  sorry @salspaugh to have doubted you. More on that later.

## splunk_antlr_spl

[splunk_antlr_spl](https://github.com/ffly1985/splunk_antlr_spl) implements SPL using [ANTLR4](https://github.com/antlr/antlr4), it was clearly incomplete but the experience to modify the ANTLR4 language was soooo nice that I could quickly hack it for my needs and [kept trying](https://github.com/ffly1985/splunk_antlr_spl/compare/master...airbus-cert:master) while reading [The Definitive ANTLR 4 Reference](https://www.amazon.com/dp/1934356999/).

Eventually I had to butchered most of the code to support enough SPL commands to parse our complete dataset. This fork lives in https://github.com/airbus-cert/splunk_antlr_spl

It works mostly fine, but it has one big problem: it is unbearingly slow. This is not surprising as I am a total n00b in ANTL4 (or even in the parsing field).

For example, parsing 338 rules takes 20 minutes. (**Update**: *While I was writing those lines, and because I could not accept releasing such crappy tool, I optimized my ANTLR4 syntax to make it faster.*)

So it was not option to have such slow tests in our CI/CD. This post is also an opportunity for me to do some kind of introspection and see if it was worth doing it, I was curious to see what were the commands missing from [salspaugh/splparser](https://github.com/salspaugh/splparser) to be used in our dataset and... Only three tiny commands are missing 😢

On the other hand, the learning curve of ANTLR4 is so smooth that I had my first version in less than 5 days, and I wonder how long it would have take me to learn Lex, Yacc, its PLY integration and the time to implement these 3 commands and create a PR to [salspaugh/splparser](https://github.com/salspaugh/splparser). 🤷

## Plan B

When there is no perfect solution satisfying all constraints, it is time to workaround with hackish solutions.

And the grossest, but quickest, way to do some basic checks is to use regular expressions all the way around. As an example, I shared an example of our setup on Twitter:

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">Thanks, we added this unit test to our CI/CD and... it was much needed indeed 😅 <a href="https://t.co/4dI2rTebLV">pic.twitter.com/4dI2rTebLV</a></p>&mdash; Nicolas Bareil (@nbareil) <a href="https://twitter.com/nbareil/status/1364142702372257792?ref_src=twsrc%5Etfw">February 23, 2021</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

As a take away, here is an extract from our code base: [test_statically_spl.py](https://gist.github.com/nbareil/452845cc310557caa6e19a0379dc4ed5#file-test_statically_spl-py)

This Twitter discussion re-ignited my desire to level up our SPL parsing and I recently discovered a new project, [kotlaluk/spl-parser](https://github.com/kotlaluk/spl-parser).

This time, the project relies on an official Splunk feature, [`splunk btool` can generate the search and datatypes BNF, no need to reinvent the wheel in fact!](https://community.splunk.com/t5/Archive/Splunk-Query-Grammar/m-p/425022#M75397). Such epiphany!

Thanks to Lukáš's work ([pseudo_bnf.lark](https://github.com/kotlaluk/spl-parser/blob/master/spl_parser/grammars/pseudo_bnf.lark)), it is possible to use a generic parser like [lark](https://github.com/lark-parser/lark) to achieve what we want to do.

# Step 2: Now what?

Now that we have a parsing engine, we need to take a step back and write a high-level library that will abstract the details of the low-level parsing and expose only the "big picture".

Stay tuned.

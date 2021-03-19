---
date: 2021-03-18
title: Unit-testing the Splunk Processing Language
description: XXX
---

In my previous post [Githubify the SOC](https://justanothergeek.chdir.org/2020/10/githubify-the-soc/), I declared my undying love to continuous integration and deployment capabilities applied to Detection Engineering. Now, let's put the theory into practice!

# Goals

The first goal is to be sure SIEM queries "compile", ideally, we would be checking that:
- The syntax is valid
- We are not using fields that do not exist
- The styling guideline is respected
- There is [no performance trap](https://docs.splunk.com/Documentation/Splunk/8.1.2/Search/Quicktipsforoptimization)

That's the equivalent of unit-tests in Software Engineering: by using statical analysis, these tests would run at a blazing speed and offer an instantaneous feedback loop to the developpers. 

While integration tests would check that:
- We are correctly alerting for a True Positive
- False-Positives are under-control
- We are not adding a hit to the platform performance
- We are paying attention to [delayed events](https://opstune.com/2016/12/13/siem-tricks-dealing-with-delayed-events-in-splunk/)

Today, this post will start with the unit-testing's part and I will choose Splunk as the platform of choice.

# Step 1, parsing Splunk's Search Processing Language

Splunk's Search Processing Language (aka SPL) is a very powerful and expressive query language. It is a very pleasant language to use, especially when you come from [Elastic Query DSL](https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl.html).

The language is very permissive, almost everything is optional: fields separator, usage of quotes, no types (string or integer, nobody cares), positions of arguments, etc.

Initially, early 2020, I expected to have a lot of robust SPL parsers available in the opensource but... nope (well there is a caveat here, follow me).

I found two projects:
- https://github.com/salspaugh/splparser: 
- https://github.com/ffly1985/splunk_antlr_spl

## splparser

Here I am trying [splparser](https://github.com/salspaugh/splparser), developped in 2013, and to add confidence, its README states up-front "_It is capable of parsing 66 of the most common approximately 132 SPL commands_".

Of course, its Python distribution is broken (quite expected for a project with its last commit 4 years ago) but quickly fixed, I ran it on our dataset of queries and it failed on the first query because of one unsupported function. I had 0️⃣ knowledge of PLY/LEX/YACC and [adding a SPL command looked abysal to me](https://github.com/salspaugh/splparser/commit/8511b66e78c26fddaacc52f630bc41c31df1e989).

🤬

I rage-quitted, thinking it was a 💩 project and moved one. BIG MISTAKE retrospectively but 🤷‍♂️  sorry @salspaugh to have doubted you. More on that later.

## splunk_antlr_spl

[splunk_antlr_spl](https://github.com/ffly1985/splunk_antlr_spl) implements SPL using [ANTLR4](https://github.com/antlr/antlr4), it was clearly incomplete but the experience to modify the ANTLR4 language was soooo nice that I could quickly hack it for my needs and [kept trying](https://github.com/ffly1985/splunk_antlr_spl/compare/master...airbus-cert:master) while reading [The Definitive ANTLR 4 Reference](https://www.amazon.com/dp/1934356999/).

Eventually I had to butchered most of the code to support enough SPL commands to parse our complete dataset. This fork lives in https://github.com/airbus-cert/splunk_antlr_spl

It works mostly fine, but it has one big problem: it is unbearingly slow. This is not surprising as I am a total n00b in ANTL4 (or even parsing).

For example, parsing 338 rules takes 20 minutes.

##

# Step 2: Now what?



  



# The goal

Have you seen the Github Checks in place for adding rules in [Azure/Azure-Sentinel](https://github.com/Azure/Azure-Sentinel)? 😍

![image](https://user-images.githubusercontent.com/115087/111625753-826b4880-87ed-11eb-9c51-5ae142aaa68e.png)

Their [Azure Sentinel Pipeline](https://dev.azure.com/azure/Azure-Sentinel/_build/results?buildId=20904&view=results)

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
- There is no performance trap

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

Initially, early 2020, I expected to have a lot of robust SPL parsers available in the opensource but... nope.

I found:
- https://github.com/salspaugh/splparser




# The goal

Have you seen the Github Checks in place for adding rules in [Azure/Azure-Sentinel](https://github.com/Azure/Azure-Sentinel)? 😍

![image](https://user-images.githubusercontent.com/115087/111625753-826b4880-87ed-11eb-9c51-5ae142aaa68e.png)

Their [Azure Sentinel Pipeline](https://dev.azure.com/azure/Azure-Sentinel/_build/results?buildId=20904&view=results)

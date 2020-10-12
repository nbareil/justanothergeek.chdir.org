---
date: 2020-10-13
title: Githubify the SOC
description: XXX
  XXX
---

*Full disclosure: This post was in draft for months, and I recently stumbled upon [Anton's blog post](https://medium.com/anton-on-security/can-we-have-detection-as-code-96f869cfdc79) and [Augusto Paes de Barros' answer](http://blog.securitybalance.com/2020/09/ddlc-detection-development-life-cycle.html) so I decided to just release my original draft, it is not an answer to anyone, peace ✌️ :)*


The few SOCs I know are suffering from their growth: expanding team, legacy detection rules, backward incompatible changes in engine's update or uncontrolled performance. Eventually, the ruleset keeps growing in a pure "fire and forget" mode. 

Worse, SOCs need an easy way to accept contributions from various parts of the organization without putting in danger your detection pipeline: in the best of the worlds, anybody could submit and deploy a detection rule and let it be handed over to the RUN team. Yet, the current situation is extremely fragile: a bad query could overload your SIEM, a wrong filter and here is a storm of false positives to bulk-close, etc.

Said differently, these symptoms can be expressed as: non-scalable lifecycle, bad quality assurance, regressions, fragility to changes. Basically the kind of problems that *state-of-the-art developpers* have fixed in the last decade with the introduction of agile principles: continuous integration and deployment, end-to-end accountability, unit testing and a strong focus on the end user.

What is the solution? Take [*The Phoenix Project*](https://www.amazon.com/Phoenix-Project-DevOps-Helping-Business/dp/0988262592)  book, replace all references to "developpers" with "SOC" and voila, you have your roadmap. 

# Needs

To [*githubify the SOC*](https://medium.com/@johnlatwc/the-githubification-of-infosec-afbdbfaad1d1), we are still in need of a complete pipeline: a consistent process from the idea of a detection rule to its deployment in the SIEM.

Individual components exist:
- [Sigma](https://github.com/Neo23x0/sigma) for writing the SIEM query
- [ADS](https://medium.com/palantir/alerting-and-detection-strategy-framework-52dc33722df2) to document the alert and give the rationale behind the detection
- [Elastic's detection-rules](https://github.com/elastic/detection-rules) or  [Splunk stories](https://github.com/splunk/security-content/blob/develop/stories/credential_dumping.yml) merge the query and the context in one file directly ingestable by their engine.
- Github for collaborative editing, peer-reviewing, rollback, continuous integration and deployment

Yet, we are missing this little something that will glue everything together; Elastic [Detection engine](https://www.elastic.co/blog/elastic-siem-detections) looks promising but it misses the Github workflow and is limited to Elastic's stack obviously (*full disclosure: It is not really a cons in fact since I don't believe in "universal" solutions anyway, it could be another blog post*).

# Detection as code's

If I had a magic wand, I wish we would realize Donald Knuth's dream: literate programming where the detection logic would be embedded in the document (in ADS format). And actually, it looks like (in this [screenshot](https://redcanary.com/wp-content/uploads/image2-18.png)) that [Red Canary](https://redcanary.com/blog/breathing-life-detection-capability/) is doing exactly that for years, gg!

Lately, I discovered [Panther](https://github.com/panther-labs/panther) which looks 🤩, but as far as I googled it, the Windows event logs use case is not ready yet (I wonder what happened to [panther#1101](https://github.com/panther-labs/panther/issues/1101)). And there is the very promising [Grapl](https://github.com/grapl-security/grapl)!

Imagine if, instead of writing SPL in your Splunk, you would write normal Python code that would be automatically executed by an AWS Lambda when a new `.evtx` is uploaded in a S3 bucket? Instead of having to learn a specific SIEM's silo and get around its quirks and limitations, you would use normal Python, its libraries, interfaced with other tools and servies and  you could leverage all the progress made by the Agile thinkers in the last decade: unit testing, performance profiling, easy refactoring of code, code deployment, typing system, code analytics, telemetry, etc.

Furthermore, coupled with [Jupyter](https://jupyter.org), we may have amazing capabilities. I never had the chance to test Azure Sentinel yet, but its [Notebooks seem to be spot on](https://docs.microsoft.com/en-us/azure/sentinel/notebooks).

In this utopia, I guess it would be great for detecting (or punctual hunting) but it would be insufficient for investigations: As nothing is indexed, when there is an incident to investigate, how would you do? Retrieve the raw .evtx from the S3 bucket and reprocess it somehow into a Splunk instance for further inspection?





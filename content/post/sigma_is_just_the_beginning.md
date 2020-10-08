---
date: 2020-10-13
title: Sigma is just the beginning
description: XXX
  XXX
---

On the engineering side,  the SOCs I know are now suffering from a non-scalable rules' lifecycle, bad quality assurance and regressions. The kind of problems that *state-of-the-art developpers* fixed in the last decade with the introduction of agile principles: continuous integration and deployment, end-to-end accountability, unit testing and a strong focus on the end user.

SOCs need an easy way to accept contributions from various parts of the organization without putting in danger your detection pipeline: in the best of the worlds, anybody could submit and deploy a detection rule and let it be handed over to the RUN team. Yet, the current situation is extremely fragile: a bad query could overload your SIEM, a wrong filter and here is a storm of false positives to bulk-close, etc.

What is the solution? Take [*The Phoenix Project*](https://www.amazon.com/Phoenix-Project-DevOps-Helping-Business/dp/0988262592)  book, replace all references to "developpers" with "SOC" and voila, you have your roadmap. 

# Needs

To [*githubify the SOC*](https://medium.com/@johnlatwc/the-githubification-of-infosec-afbdbfaad1d1), we are still in need of a complete pipeline: a consistent process from the idea of a detection rule to its deployment in the SIEM.

Individual components exist:
- [Sigma](https://github.com/Neo23x0/sigma) for writing the SIEM query
- [ADS](https://medium.com/palantir/alerting-and-detection-strategy-framework-52dc33722df2) to document the alert and give the context
- [Elastic's detection-rules](https://github.com/elastic/detection-rules) or  [Splunk stories](https://github.com/splunk/security-content/blob/develop/stories/credential_dumping.yml)) for describing (lightly) the context and the query.
- Github for collaborative editing, peer-reviewing, rollback, continuous integration and deployment

But we are missing this little something that will glue everything together; Elastic [Detection engine](https://www.elastic.co/blog/elastic-siem-detections) looks promising but misses the Github workflow and is limited to Elastic's stack obviously (*full disclosure: It is not really a cons in fact since I don't believe in "universal" solutions anyway*).

If I had a magic wand, I wish we would have Donald Knuth's dream: literate programming where the detection implementation would be embedded in the document (in ADS format). Could [Jupyter](https://jupyter.org) be an actual answer? I never had the chance to test Azure Sentinel yet, but [Microsoft seems to have took this path for hunting](https://docs.microsoft.com/en-us/azure/sentinel/notebooks).



Litterate programming, jupyter, ADS, [red canary](https://redcanary.com/blog/breathing-life-detection-capability/), [Splunk stories](https://github.com/splunk/security-content/blob/develop/stories/credential_dumping.yml), Elastic [Detection engine](https://www.elastic.co/blog/elastic-siem-detections) and its [detection-rules](https://github.com/elastic/detection-rules)

---
date: 2020-10-13
title: Sigma is just the beginning
description: XXX
  XXX
---

On the engineering side,  the SOCs I know are now suffering from a non-scalable rules' lifecycle, bad quality assurance and regressions. The kind of problems that *state-of-the-art developpers* fixed in the last decade with the introduction of agile principles: continuous integration and deployment, end-to-end accountability, unit testing and a strong focus on the end user.

SOCs need an easy way to accept contributions from various parts of the organization without putting in danger your detection pipeline: in the best of the worlds, anybody could submit and deploy a detection rule and let it be handed over to the RUN team. Yet, the current situation is extremely fragile (in the [Taleb's sense](https://www.amazon.com/Antifragile-Things-That-Disorder-Incerto/dp/0812979680): a bad query could overload your SIEM, a wrong filter and here is a storm of false positives to bulk-close, etc. Take [*The Phoenix Project*](https://www.amazon.com/Phoenix-Project-DevOps-Helping-Business/dp/0988262592)  book, replace all references to "developpers" with "SOC" and voila, the book is still spot on.

# Needs

To [*githubify the SOC*](https://medium.com/@johnlatwc/the-githubification-of-infosec-afbdbfaad1d1), we are still in need of a solid pipeline. There are a few bricks here and there ([Sigma](https://github.com/Neo23x0/sigma), [ADS](https://medium.com/palantir/alerting-and-detection-strategy-framework-52dc33722df2),  Elastic [detection-rules](https://github.com/elastic/detection-rules),  [Splunk stories](https://github.com/splunk/security-content/blob/develop/stories/credential_dumping.yml)), but I guess we are missing a little something that will glue everything together (Elastic [Detection engine](https://www.elastic.co/blog/elastic-siem-detections) looks promising).

Sigma is a solid project with a huge userbase, widely used to share detection rules in a technology agnostic format. As such, it is a very convenient input for the SOCs. Unfortunately, from what I see, their use is limited to a "read-only" mode, SOCs takes Sigma rules as input, transcribe it in their SIEM technology (using the sigma converter or not) and integrate it into their custom Use Case format.

Why?

From a pure SOC point of view, I don't believe in an universal format. For most, our time is limited so if your company uses Splunk, you will become a Splunk Ninja 👤  and you won't take the time to learn advanced features of Sigma, unless your business relies on it (examples: MSSP, freelancer or consultant).



Litterate programming, jupyter, ADS, [red canary](https://redcanary.com/blog/breathing-life-detection-capability/), [Splunk stories](https://github.com/splunk/security-content/blob/develop/stories/credential_dumping.yml), Elastic [Detection engine](https://www.elastic.co/blog/elastic-siem-detections) and its [detection-rules](https://github.com/elastic/detection-rules)

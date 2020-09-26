---
date: 2020-10-13
title: Sigma is just the beginning
description: XXX
  XXX
---

On the engineering side,  the SOCs I know are now suffering from a non-scalable rules' lifecycle, bad quality assurance and regressions. The kind of problems that *state-of-the-art developpers* fixed in the last decade with the introduction of continuous integration and deployment, end-to-end accountability, unit testing and a strong focus on the end user.

There is also the professionnalisation of the SOC with all kind of specialization: there are those dedicating their time to detection engineering, others actually responding to alerts, others developping tools or capabilities, etc. Specialization is good but if you don't pay attention, specialization will also limit the scope of one individual towards their organizaion: detection rule not actionnable by the incident handler, tool not adapted, etc.

There is a need of having an easy way to accept contributions from various parts of the organization without putting in danger your detection pipeline: The current situation is extremely fragile (in the [Taleb's sense](https://www.amazon.com/Antifragile-Things-That-Disorder-Incerto/dp/0812979680): a bad query could overload your SIEM, a wrong filter and here is a storm of false positives to bulk-close, etc. Take [*The Phoenix Project*](https://www.amazon.com/Phoenix-Project-DevOps-Helping-Business/dp/0988262592)  book, replace all references to "developpers" with "SOC" and voila, the book is spot on.

Litterate programming, jupyter, ADS, [red canary](https://redcanary.com/blog/breathing-life-detection-capability/)

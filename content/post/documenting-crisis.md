
In July 2020, I was excited to read [Christopher Glyer's thoughts](https://twitter.com/cglyer/status/1286832534958084096) on how Mandiant is documenting their incidents.

At $WORK, we have been working on this point since 2013, continually improving our "documentation standard" crisis after crisis, <abbr title="Return of experience">RETEX</abbr> after RETEX. The road has been bumpy but now, we are quite happy with it as we have not changed it much for a couple of years.

Let's describe the context first:
- When talk about crisis, we talk about the incident response to an APT: there is an attacker on the network, the :poop: has hit the fan.
- Tens of people are mobilized into ad-hoc cross-functional teams

At the creation of the investigation cell, an *Incident Commander* (IC) ([FEMA terminology](https://www.fema.gov/sites/default/files/2020-07/fema_nims_doctrine-2017.pdf)) is appointed, her mission is to:
- Direct analysts, define the analysis strategy
- Review and challenge the work
- Centralize the findings, document and report
- Be the single point of contact (PoC) for the rest of the world

Two documentation platforms are used:
- Etherpad, a kind of rustical Google Docs: Each task has its own "pad", this is the jumble of the analysts, they have just one rule: each pad must have a TLDR at its top with the conclusions. Generally, analysts put the output of their forensics tools, "grep" results of log files to support their conclusion.
- A wiki

Every morning, a Standup Meeting with all analysts is , the agenda is:
- **Presentation by the IC of the key findings of the day before**: each analyst shares the same situational awareness, it is also the opportunity for  analysts to speak up if their findings was forgot or if it was wrongly interpreted.
- **"Top-bottom" information cascade**: Executives or business teams can share interesting insights about the attack from a business point of view, they can also have specific inquiries or fears to be cleared. 
- **Review of the tasks done yesterday**:

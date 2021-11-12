---
date: 2021-11-12
title: What if we used Jupyter as a SOAR?
description: 
---

Today, rightfully, [all the rage is on XDR and on the broken promises of SOAR](https://twitter.com/anton_chuvakin/status/1458563366025265153) and I fully support that feeling: your mileage may vary but, from my experience, developping something sustainable within a SOAR is an endeaveor:
- Runtime dependency is a nightmare: this playbook requires this version of this third-party Python library while another playbook wants another version, the deployement and management of dependencies is YOLO
- Wide domain failure: one small playbook can impact the global platform because of a syntax error, there is no concept of isolation (who said container?)
- The 80s called and they want their development practices back: There is no versionning, there is no auditability of a playbook updated in the UI
- The SOAR is not at the service of the analyst but more the opposite: An analyst is not empowered to adapt a playbook, they can only use whatever was given to them by the BUILD team.
- Unscoped platform: Should the SOAR do the case management? Ticketing system? Or should it be an orchestration-only platform?

Instead of adopting a new way of working, what if we tried to compose with already existing basic bricks to implement something similar? Yeah I know it sounds boring but that's usually the best way to succeed.

The *linga franca* of Infosec is probably Python, and the best way to use it collaboratively is Jupyter(Hub). Let's experiment that!

# JupyterHub as a SOAR

The detection rules are stored in Splunk as *Saved Searches*, they generate Notable Events on matches.

## Dispatcher notebook

Independently, a crontask executes [papermill](https://github.com/nteract/papermill) every minutes, it instantiates the **dispatcher Jupyter notebook**:
1. It fetches the notable events that were generated the minute before
1. For each notable event:
   1. We retrieve the context of the alert
      - which detection strategy matched?
      - what is the sourcetype of the matching event?
      - what is the SPL that matched?
   1. Based on the context, we try to identify and instantiate a specialized Jupyter notebook to process this alert. If not, we instantiate a generic Jupyter notebook.
   1. Once the notebook's execution is finished, we send an email to the incident analyst's team (ticketing system) with a link to the Jupyter notebook. 

## Specific notebook

When the *Incident Analyst* receives the ticket, they access to our [JupyterHub instance](https://jupyter.org/hub) and can immediately review the playbook:
- The playbook is written using the structure of the [Palantir Alerting and Detection Strategy Framework](https://blog.palantir.com/alerting-and-detection-strategy-framework-52dc33722df2), this means the analyst has the whole context behind the detection and the Response section is already implemented in Python
- If the predefined Response is not enough, analysts are free to modify the Jupyter Notebook and perform their queries accordingly. As long as everything is done in the notebook, everything is traced and auditable. At this point, all the changes are local to this specific case, if the analyst thinks there is room for improvement for future alerts:
   - They can commit the changes to the "*referential Jupyter notebooks repository*" using the classic Github workflow.
   - They send a link of this specific investigation notebook to the *BUILD team* for inspiration, they will be able to see exactly how the analyst resolved the investigation and what is missing from the "*reference notebook*".

From here, sky is the limit, it is not implemented yet, but we could imagine more follow-up actions like closing and commenting the case in the ticketing system from the notebook automatically. Thanks to the richness of the Jupyter's widgets, it is easy to implement user friendly actions.

This way of working is also a forcing function to implement as much Python as possible, in this frame, my team developped a Python library called  certpy  that is basically the API of the team: every tools used are interfaced in this library and its input and output is consistent along the modules.

Airflow


Eventually, I wonder if the solution is to forbid the use of any fancy feature from the SOAR and limit its use to **only** call REST API that are implemented as ServerLess function, like one AWS Lambda function backed by a Container image. While this is appealing, it would not make make the platform as "self-service" as we would like.
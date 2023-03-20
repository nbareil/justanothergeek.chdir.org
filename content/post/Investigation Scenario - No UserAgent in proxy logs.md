+++
title = "Investigation scenario: No User-Agent in the proxy logs"
date = 2023-03-04
categories = ["InvestigationPath"]
description = "Chris Sanders proposed the following scenario: Proxy logs indicate a host on your network made a few HTTP requests with no User Agent string (field is empty). What do you look for to investigate why this is happening and whether an incident has occurred?"
+++


## Context

Chris Sanders proposed on Twitter the following scenario:

> Proxy logs indicate a host on your network made a few HTTP requests with no User Agent string (field is empty). What do you look for to investigate why this is happening and whether an incident has occurred?

Credit: https://twitter.com/chrissanders88/status/1630581503506935811

## One investigation path

In my experience, HTTP requests without User-Agent are **very very** frequent on a Corporate network (like more than 20% of the global traffic, YMMV), I will act like it is not the case :)

I would split the actions into these steps:
1. Situational Awareness
1. Focus on the destination domain name/IP address
1. Pivot on the domain name in the logs
1. Investigate the endpoint

### Situational Awareness

1. To have a sense of urgency in processing this alert, **how often does this behavior happen?**
	1. how many hosts and users share the same behavior?
1. **Get a vague timeline**: When did this behaviour start/end?

### Focus on the destination domain name and IP address

Perform a reputation check on the contacted Domain name or IP address:

1. VirusTotal
1. RiskIQ
1. Domain Categorisation in Websense/Bluecoat/Netskope/Forcepoint
1. Whois - 🚩 if the domain was recently created
1. PassiveDNS - 🚩 if  the domain name shows parking behavior

### Pivot on the domain name in the logs

Pivot on the domain name in our proxy logs:
1. How many clients did connect to it?  🚩 if there is less than 0.01% of the fleet
1. How many requests and bytes were sent per client and day?  🚩 if one client is sending more than X hits per day (X being a reasonable value for beaconing activities, like one request every 3 minutes) or uploading more than Y bytes
1. What are the median values of `bytes_in` and `bytes_out` of the HTTP request?
1. Is there any other suspicious User-Agent for this domain?
1. Any IDS alert linked to the IP address/domain names.

### Investigate the endpoint

On the endpoint that made the request:
1. **Identify the usual users of this host** from Active Directory logs (Kerberos tickets from this host) and local endpoint logs (4624)
1. If the proxy uses authentication, **was the suspicious HTTP request made by one of the "usual users"** of the endpoint? 🚩 if not consistent, it may mean that credentials are hard coded in the calling process
1. Perform a [light triage of the host (see below)](#light-triage)
	1. Identify the process connecting to the suspicious website using Sysmon EventID 3 or 22. If not available, try with `netstat -ano` in case a connection is established, if found:
		1. Dump immediately this process (using  EDR or `procdump`) and park it for later analysis if needed.
		1. Make a copy of the executable involved
		1. Apply the "[Triage Executable](#triage-executable)" section below
	1. If we can not identify the process
		1. Review the result of `autoruns` and review the most recently updated entries.
		1. Perform an AV full-scan (or better, a Yara disk scan)
		1. If the initial domain name/IP address was known in VirusTotal to be associated with a specific malware family, apply this knowledge to the possible artifacts on the systems
		1. Collect all .evtx and apply [Chainsaw](https://github.com/WithSecureLabs/chainsaw) with your own Sigma ruleset
1. Review all AV and SOC detections in the past 30 days



## Light triage

I would use the capabilities of my EDR, but without one, in this situation, a light triage data should be composed of:
- Raw Registries, or the output of [autoruns](https://learn.microsoft.com/en-us/sysinternals/downloads/autoruns), or Sysmon RegistryEvents
- A process list with the opened files and sockets, or the output of [handle](https://learn.microsoft.com/en-us/sysinternals/downloads/handle)
- List of network connections: Sysmon EventID 3 and 22, or `netstat -ano`
- Collect Security and Sysmon EVTX
- Get the Quarantine folder and AV logs of the host
	- Symantec
		- `C:\Windows\System32\winevt\logs\Symantec Endpoint Protection Client.evtx`
		-  `C:\ProgramData\Symantec\Symantec Endpoint Protection\*\Data\Logs`
	- TrendMicro
		- `c:\system\trend\osce\misc\pccnt35.log`
	- McAfee
		- `c:\Quarantine\`
	- Microsoft Defender
		-  `Powershell Get-MpThreatDetection`
		- `C:\ProgramData\Microsoft\Windows Defender\Quarantine`

## Triage executable

1. Apply all private and [public](https://github.com/Neo23x0/signature-base) Yara rules on this executable -> Contain the machine if any red flag is spotted
2. Send the executable to your private sandbox (cuckoo)
	1. If no network connections to the suspicious website can be observed, either the binary is packed, or it may require special arguments in parameter.
3. Search the hash of the file on VirusTotal:
	1. Read carefully the Community section first, especially those from [Nextron-Systems's thor](https://www.virustotal.com/gui/user/thor), they will tremendously help in your triaging :)
	2. Is the binary signed by a trusted authority?
4. Get the prevalence of this executable on the fleet

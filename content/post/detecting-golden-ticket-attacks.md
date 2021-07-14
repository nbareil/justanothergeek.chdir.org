---
title: Detecting Golden Ticket attacks
date: 2021-07-14
description: In this post, I described a new reliable technique to detect Golden Ticket attacks in
   Active Directory environments thanks to a recent EventID introduced in Windows 10.
---

# Technical Context

The Graal for an attacker is to compromise the [KRBTGT](https://adsecurity.org/?tag=krbtgt) secret, the master key encrypting everything in the Active Directory.

Once in its possession, adversaries are free to perform "**[Golden Ticket](https://adsecurity.org/?tag=goldenticket)**"  ([T1558.001](https://attack.mitre.org/techniques/T1558/001/)) attack later on. In a nutshell, this technique allows the attacker to create new Kerberos Ticket Granting Tickets (TGT) on the fly, directly from their laptop.

## Catch me if you can

From a defender's perspective, the publicly available detection techniques are limited, basically matching the default values of Mimikatz. From our experience, they are quite unreliable because of... Legacy infrastructure 🤐.

Nonetheless, in theory, the detection strategy is straightforward: *For each successful authentication (EventID 4624), verify that a prior TGT and TGS were issued and logged correctly by a Domain Controller*.

But in practice:
- Obviously, you can not apply these checks for **all** connections because it would kill your SIEM.
- Maintaining a list of Administrators/VIP is generally not sustainable nor effective for various non-technical reasons.
- Doing the filtering based on username is not effective as the adversary can add high privileges to normal Domain Users or even to non-existing users.

TL;DR: We were stuck.

## The unlocking factor: EventID 4627

Microsoft introduced in Windows 10 and 2016 a new event message: [Event ID 4627](https://docs.microsoft.com/en-us/windows/security/threat-protection/auditing/event-4627) is emitted after successful authentication. As a companion to Event ID 4624, it lists the group membership of the logged-in user.

This subtle event unlocks everything: Without having to rely on usernames' watchlist, we can narrow down authentications of specific groups (such as Domain Administrators) immediately.

## The scenario

Using the awesome [DetectionLab](https://github.com/clong/DetectionLab) 💙, I ran the following scenario:
1. I acquire the KRBTGT secret
1. I create a Golden Ticket for a non-existing user `404user`
1. From a "compromised" workstation, I `dir \\dc\c$` to verify everything worked.

Eventually, here are the matching logs:

![](/images/detecting_golden_ticket_logs.png)

The interesting part is the EventID 4627:

```
<EventData> 
    <Data Name="SubjectUserSid">S-1-0-0</Data> 
    <Data Name="SubjectUserName">-</Data> 
    <Data Name="SubjectDomainName">-</Data> 
    <Data Name="SubjectLogonId">0x0</Data> 
    <Data Name="TargetUserSid">S-1-5-21-1563626495-2931527320-2379504161-500</Data> 
    <Data Name="TargetUserName">404user</Data> 
    <Data Name="TargetDomainName">windomain.local</Data> 
    <Data Name="TargetLogonId">0x8ff9c1</Data> 
    <Data Name="LogonType">3</Data> 
    <Data Name="EventIdx">1</Data> 
    <Data Name="EventCountTotal">1</Data> 
    <Data Name="GroupMembership">
        %{S-1-5-21-1563626495-2931527320-2379504161-513}
        %{S-1-1-0}
        %{S-1-5-32-544}
        %{S-1-5-32-545}
        %{S-1-5-32-554}
        %{S-1-5-2}
        %{S-1-5-11}
        %{S-1-5-15}
        %{S-1-5-21-1563626495-2931527320-2379504161-512} <---- Added by Mimikatz
        %{S-1-5-21-1563626495-2931527320-2379504161-520} <---- Added by Mimikatz
        %{S-1-5-21-1563626495-2931527320-2379504161-518} <---- Added by Mimikatz
        %{S-1-5-21-1563626495-2931527320-2379504161-519} <---- Added by Mimikatz
        %{S-1-5-21-1563626495-2931527320-2379504161-572} <---- Added by Mimikatz
        %{S-1-16-12288}
    </Data> 
    </EventData> 
</Event>
```

Now that we have all the pieces in mind, let's build a Detection Strategy.


# Strategy Abstract

This alerting & detection strategy will function as follows:

1. Filter "*Group Membership Information*" (EventID 4627) matching a monitored group
1. For each match, check if a TGT (EventID 4768) were issued accordingly
1. Alert 🚨 if no TGT can be found

## Step 1: Filter Group Membership Information


```
search index=*winevent* 4627
      EventID=4627
      LogonType IN (3, 10)
      TargetUserName!="*$"
      (512 GroupMembership="*-512}*") OR
          (544 GroupMembership="*-544}*") OR
          (519 GroupMembership="*-519}*")
          ...
| makemv tokenizer="%\{(.*?)\}" GroupMembership
| mvexpand GroupMembership
| search GroupMembership IN (
         "*-512",
         "*-544",
         "*-519",
         ...
         )
| search NOT GroupMembership IN ("S-1-5-32-544")
| table _time, host, TargetLogonId, TargetUserName, GroupMembership
```

This search will return all connections of "interesting" groups.

## Step 2 and 3: Check if a prior TGT was emitted 

So we have a list of sensitive connections, now we want to check that a TGT was requested priorly for each of them.

```
no_tgt = set()
logged_users = set(df['TargetUserName']) # df is the result of the SPL before
for user in logged_users:
    spl = f'search index=*winevent* 4768 EventID=4768 {user} TargetUserName="{user}"'
    spl += f''
    df = certpy.siem.session.search_df(spl, days=1)
    if df.size == 0:
        sys.stderr.write(f"ALERT on {user}, no TGT was requested\n")
        no_tgt.add(user)
```

(Extracted from our Jupyter notebook running the ADS)

## Blind spots and Assumption
### Blind spots

A blind spot may occur under the following circumstances:
- If the attacker is connecting to a server older than Windows 10 and 2016 (because Event 4627 is not available).
- The attacker may use NTLM to authenticate (This is offtopic as this would not be a Golden Ticket attack)

### Assumption

This strategy relies on the following assumptions:
- The ESAF is clean.

## False Positives

The following events will result in a false positive:
- If there is a loss of *Windows Event Logs* (if one Domain Controller stops sending its events, or there is an ingestion problem), we may be unable to find a TGT legitimately emitted and may generate an erroneous alert.

## Validation

To validate this ADS:

1. On a DC, acquire the KRBTGT secret: `mimikatz.exe "privilege::debug" "lsadump::dcsync /user:windomain\KRBTGT" exit`
1. On a workstation:
    1. `klist purge`
    1. ``mimikatz.exe "kerberos::golden /domain:windomain.local /user:404user /aes256:1234abcde /sid:S-1-5-21-1563626495-2931527320-2379504161 /ptt"``
    1. `dir \\dc\c$`


## Alert Priority

High
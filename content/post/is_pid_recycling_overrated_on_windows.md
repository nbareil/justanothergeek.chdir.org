---
date: 2020-07-13
title: Is ProcessID recycling ♻️  on Windows over-rated ?
description: I have always heard that PID recycling was a thing on Windows and 
   they should be taken with a grain of 🧂. Are PID collisions an exception or the rule?
---


I have always heard that ProcessID recycling was a thing on Windows and they should be taken with a grain of 🧂 . Is this statement over-rated? Are collisions an exception or the rule? Coming from a Linux background, I have always postponed this question but recently, I had to have a definitive answer.

It is easy to verify this hypothesis at company scale thanks to sysmon, let's aggregate all `ProcessCreate`  by the (PID, host) tuples and count the number of different ProcessGuids, this gives this picture (using log scale):

![Splunk query|690x193](/images/collisions_count.png)

For reference, here is the SPL:
```spl
index=*wineventlog* sourcetype=*Sysmon* EventID=1
| fields host, ProcessId, ProcessGuid
| eval tuple_host_pid=host.ProcessId
| stats distinct_count(ProcessGuid) AS collisions_count BY tuple_host_pid
| where collisions_count > 1
| stats count AS times BY collisions_count
| sort collisions_count
```

This query was ran on >100k production assets over the last 15 minutes:
- 75k times, one PID collided twice
- 135 times, one PID collided 11 times
- 3 times, one PID collided 21 times

So yeah, PID recycling is really a thing! And this behaviour is not a bug but a "[documented feature](https://devblogs.microsoft.com/oldnewthing/20110106-00/?p=11813)":

> I later learned that the Windows NT folks do try to keep the numerical values of process ID from getting too big.
> Earlier this century, the kernel team experimented with letting the numbers get really huge, in order to reduce the rate at which process IDs get reused, but they had to go back to small numbers, not for any technical reasons, but because people complained that the large process IDs looked ugly in Task Manager. (One customer even asked if something was wrong with his computer.)
>
> 📕 source: https://devblogs.microsoft.com/oldnewthing/20110106-00/?p=11813

To be kept in mind in our queries!

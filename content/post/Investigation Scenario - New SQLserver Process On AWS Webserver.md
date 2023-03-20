+++
title = "Investigation scenario: New SQLServer on an AWS Webserver"
date = 2023-03-13
categories = ["InvestigationPath"]
description = "Chris Sanders proposed the following scenario: One of your web servers hosted in the Amazon cloud launched a new process named sqlserver.exe. What do you look for to investigate whether an incident occurred?"
+++

## Context

Chris Sanders proposed on Twitter the following scenario:

> One of your web servers hosted in the Amazon cloud launched a new process named sqlserver.exe. What do you look for to investigate whether an incident occurred?

Credit: https://twitter.com/chrissanders88/status/1628050893315899393

## My investigation path

- What is this executable?
- Who dropped that executable?
- How was this executable dropped?
- Who is responsible for the execution of this file?
- Any difference in handling with AWS context?

### What is this executable?

When I read SQLServer, I think automatically of Microsoft SQL Server. However,
the official binary name is `SQLSERVR.EXE` (pay attention to the missing `E`)
so it may be an attempt to masquerade a piece of malware... Or can it be a
legitimate binary from a barely known company?

#### Curiosity time

It would not change the course of the investigation, but first, I was curious to
see if there was any tool signed with an "*Original Name*" of `sqlserver.exe`.

We are lucky enough to have a kind of copy of VirusTotal's metadata in Splunk, let's query it:

```
search sqlserver.exe Signed  
| spath "additional_info.sigcheck.product" 
| spath "additional_info.sigcheck.verified"
| spath "additional_info.sigcheck.original name"
| spath "submission_names{}"
| search "additional_info.sigcheck.verified"=Signed
| search "additional_info.sigcheck.original name" = "sqlserver.exe"
| spath "md5"
| dedup "md5"
| table "md5" "additional_info.sigcheck.original name" "submission_names{}"
```

Only 2 samples match that description:

| md5	| original name	| submission_names |
|----|-----|-------|
|40593f27c042bf07c86a659b8745999d	| sqlserver.exe	| dhserver, sqlserver.exe, sqlserver.exe.E908FD29_F7EC_46D3_A5F5_ED4B563EB5AA|
| c6b9b0d924476e5154c1e49e4e1aa4f0	| sqlserver.exe	| dhserver, sqlserver.exe, SqlServer.exe|


Both executables are from Unisys Corporation:

```
  sigcheck: {
       copyright: Copyright © 2016, Unisys Corporation, All Rights Reserved
       counter signers: COMODO SHA-1 Time Stamping Signer; UTN-USERFirst-Object; The USERTrust Network?
       counter signers details: [ [+]
       ]
       description: ODBC Data Access
       file version: 58.1.189.8008
       internal name: dhserver
       link date: 10:49 PM 7/12/2016
       original name: sqlserver.exe
       product: ODBC Access
       signers: Unisys Corporation; Symantec Class 3 SHA256 Code Signing CA; VeriSign
       signers details: [ [+]
       ]
       signing date: 10:53 PM 7/12/2016
       verified: Signed
     }
```

So the conclusion is that unless we are actively working on with Unisys, or
unless the server is linked to a development environment, this executable is
worrisome.

#### Hash reputation

If we have the hashes of this file from the initial alert, or any
telemetry means like Sysmon EventID 1, native EventID 4688, or from the EDR, we
apply the [Triage Executable routine](/2023/03/Investigation-scenario-No-User-Agent-in-the-proxy-logs#triage-executable).


#### Data acquisition

Depending on the available means, we collect the executable:
- If there is an EDR, we perform a file acquisition with it
- Otherwise, we make an EBS snapshot and extract the binary from it
- Last resort, we acquire the file manually by connecting to the remote machine, making
  sure we are authenticating using Kerberos (and not NTLM which may leave credentials in
  memory).

For this scenario, we will assume that there is no evidence that the executable
is legitimate. My next move is to understand how this binary was planted.

## How was this executable dropped on disk? And by whom?

We need to understand how this executable ended up on the host, file creation
information can be gathered by:

- Sysmon Event ID 11 (FileCreate)
- EDR Telemetry
- Checking the *Zone.Identifier* Alternate Data Stream to see if this file was
  downloaded from Internet
- MFT creation times and owner

### What if it was coming from the web server?

As we know that a web server is running, possibly over the Internet, it is possible
that the executable was created following the exploitation of a vulnerable Web
application:
- Spot HTTP requests in the Apache/IIS logs with a `bytes_in` in the range of
  the executable's file size
- Filter out IP addresses using GreyNoise to remove the Internet noise
  - Stack the target URL and see if any rarely used resource is accessed by a limited number of IP addresses

### Investigation fallback

If the previous steps come back blank, we can also go the heavy way and build a
timeline of the MFT and registry hives to get the activities observed in the
timeframe of the file creation: It may lead for example to the discovery of
Windows Service registered around the file creation and so on.

Once we understand how the file was created, we need to know which account was behind
this action: What were the credentials in use? From where the user was connected?

Around the time of the file creation, we investigate:
- Event ID 4624
- RDP Connections:
  - Microsoft-Windows-TerminalServices-RemoteConnectionManager: Event ID 1149
  - Microsoft-Windows-TerminalServices-LocalSessionManager: Event 21


## Who is responsible for the execution of this file?

Now we know how the executable was created, we also have to understand how it
is executed as well:
- What is the parent process of `sqlserver.exe`?
- Based on the registry timeline, can we spot the creation or modification of a
  Run key? Or a Windows Service?
- Alternatively, we can use
  [autoruns](https://learn.microsoft.com/en-us/sysinternals/downloads/autoruns)
  to spot new entries

Now that we have a good understanding of what happened to this single machine,
we have to care about the surrounding environment, AWS.

## AWS Context
### Exposed to the Internet

If the EC2 instance is on an Internet-enabled VPC, and if we assume the server
was compromised, it will be worth hunting for any Webshell deployed on the
host.

One of the most relevant resources in this endeavor is to use the "[Mitigating Web
Shells](https://github.com/nsacyber/Mitigating-Web-Shells)" strategy defined by
the NSA and ASD teams: They describe Yara rules as well as detection heuristics.

### IAM 

Working with AWS is easy... once you understand IAM and its ramification. I
strongly recommend reading [Effective IAM](https://effectiveiam.gumroad.com/l/ZSCFy)
by Stephen Kuenzli to get a grasp on it.

There are (at least?) two ways to authenticate in IAM:
- *Instance profiles*: You assign a role to an EC2 instance or Lambda
  implicitly, everything is handled under the hood by AWS and you don't need
  to handle API keys and so on.
- Explicit API keys: You create a user, assign a role to it and generate an API
  key/id. Finally, you put that credentials into a "secret" file on your disk and
  this is where attackers may have an interest in stealing them to move laterally.


#### Instance profile

To get the role policy for this host, we need to understand that:
1. An EC2 instance is associated with an instance profile
1. An instance profile is linked to a role
1. A role is linked to a policy
1. The policy registers what the role is allowed to do


##### Get the instance profile

Let's assume we know the Instance ID of the compromised host:


```
$ aws ec2 describe-instances                  \
        --region eu-west-1                    \
        --instance-ids i-01a840fe4d183f01b    \
        --query 'Reservations[*].Instances[*].IamInstanceProfile'
[
  [
    {
      "Arn": "arn:aws:iam::1234567890:instance-profile/foobar_instance_profile",
      "Id": "AIPAUYIIQRRERETH2BTWBT9"
    }
  ]
]
```

##### Get the role name

```
$ aws iam get-instance-profile                            \
        --region eu-west-1                                \
        --instance-profile-name foobar_instance_profile   \
        --query 'InstanceProfile.Roles[*].RoleName'
[
    "foobar_role"
]
```

##### Get the role policy name

```
$ aws iam list-role-policies -region eu-west-1 --role-name foobar_role
{
    "PolicyNames": [
        "foobar_policy"
    ]
}
```

##### Get the role policy

```
$ aws iam get-role-policy        \
        --region eu-west-1       \
        --role-name foobar_role  \
        --policy-name foobar_policy
{
    "RoleName": "foobar_role",
    "PolicyName": "foobar_policy",
    "PolicyDocument": {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": "secretsmanager:GetSecretValue",
                "Resource": "arn:aws:secretsmanager:eu-west-1:1234567890:secret :prod/foobar/ssl_certificate_key-abcde"
            },
            {
                "Effect": "Allow",
                "Action": "secretsmanager:GetSecretValue",
                "Resource": "arn:aws:secretsmanager:eu-west-1:1234567890:secret :prod/foobar/deploy_keys-C4B23"
            },
            {
                "Action": [
                    "elasticfilesystem:Describe*",
                    "elasticfilesystem:List*"
                ],
                "Effect": "Allow",
                "Resource": "arn:aws:elasticfilesystem:eu-west-1:1234567890:file-system/fs-0ab23231b"
            }
        ]
 
 }
}
```


### Explicit API key

On top of the instance profile, it is possible that some API keys were stored on the
host and possibly stolen and reused by an attacker.

Using AWS CloudTrail logs, we review all API calls from the IP address of the
victim EC2.

For each new credential discovered, we review the role policy for each of them
like we did in the previous section to see the possible extent of the
compromission.

### Lateral movement

If money is not a problem for your organization, you may be lucky to have VPC
Flow logs enabled. In that case, it will be very helpful to discover any
lateral movement from the compromised machine elsewhere.


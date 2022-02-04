---
categories:
 - howto
 - ssh
date: "2011-07-06T14:34:00Z"
title: HOWTO authenticate ssh server through certificates
description: This is a HOWTO use ssh CA mechanism to authenticate servers.
---

In August 2010, OpenSSH 5.6 added support for certificate authentication
([release notes](http://www.openssh.org/txt/release-5.6)),
unfortunately, no documentation really exists at the moment (you are on
your own with
[sshd\_config(1)](http://www.openbsd.org/cgi-bin/man.cgi?query=sshd_config&sektion=5), [ssh-keygen(1)](http://www.openbsd.org/cgi-bin/man.cgi?query=ssh-keygen&apropos=0&sektion=0&manpath=OpenBSD+Current&arch=i386&format=html) and [ssh\_config(1)](http://www.openbsd.org/cgi-bin/man.cgi?query=ssh&apropos=0&sektion=0&manpath=OpenBSD+Current&arch=i386&format=html),
good luck with that).  This is a surprising because this feature is
awesome for system administrators, even for a small deployment.

Certificates allow you to sign user or host keys. In other words:
- Thanks to a unique file (CA certificate) on the server, it can accept any (signed) user keys transparently
- If every servers' host keys are signed, clients only need to carry the CA to authenticate every servers of your network, which means no more "The authenticity of host foobar can't be established. Fingerprint is..." message

Here is the HOWTO for the latter case.

<div
style="-moz-border-radius: 6px; -moz-box-shadow: #F6EECD 0px 0px 200px inset; -o-box-shadow: #F6EECD 0px 0px 200px inset; -webkit-border-radius: 6px; background-color: #faf8ef; border-collapse: separate; border-radius: 6px; border-spacing: 1.428em; box-shadow: #F6EECD 0px 0px 200px inset; padding: 1.428em;">

<span style="color: #5d2a07; letter-spacing: 0.04em; text-transform: uppercase;">**Geek summary: Sign SSHd host key** </span>
```
$ ssh-keygen -f ~/.ssh/cert_signer
$ scp foobar.example.org:/etc/ssh/ssh_host_rsa_key.pub foobar.pub
$ ssh-keygen -h                             \ # sign host key
             -s ~/.ssh/cert_signer          \ # CA key
             -I foobar                      \ # Key identifier
             -V +1w                         \ # Valid only 1 week
             -n foobar,foobar.example.org   \ # Valid hostnames
             foobar.pub                       # Host pubkey file
$ scp foobar-cert.pub foobar.example.org:/etc/ssh/ssh_host_rsa_key-cert.pub
```

On foobar.example.org, add `HostCertificate /etc/ssh/ssh_host_rsa_key-cert.pub"` in `sshd_config` and reload sshd.
Now, configure the ssh client to use this authority:
```
$ (  echo -n '@cert-authority * '; \
     cat ~/.ssh/cert_signer.pub ) > ~/.ssh/known_hosts_cert
$ ssh -oUserKnownHostsFile=~/.ssh/known_hosts_cert foobar.example.org
```
</div>

At this point, you can connect to every servers without any annoying messages. You don't even have to care when the server is replaced
without conserving its old ssh keys.

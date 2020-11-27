---
date: 2020-11-17
title: Decoding C2 Traffic in Python
description: 

---

# The scene :movie_camera:  

You have discover a C2 client on the network communicating on Internet, the threat actor is using a home made RAT with a custom protocol and by chance, you have a full packet capture capability in place.

This post will describe how to transform the C2 PCAP into a human transcript.

# Theory :vs: Life

First of all, let's clarify some assumptions.

- Packet loss is a real problem. Given TCP has been solving this problem :ok_hand: since the 80s, nobody actually cares about TCP retransmissions, chunk overlaps, urgency flags. But when you are reading a PCAP, you have to same support a full TCP engine to take care of it.
- IP Fragmentation happens! Especially when you monitor old OS like Windows XP/2003... Deal with it!
- HTTP/1.1 introduced HTTP persistent connections; two HTTP requests can be issued inside the same TCP connection.
- Multiplexing: Two C2 commands can be "in flight" in parallel (example: one uploading a file, the other executing `netstat -ano`).
- Traffic captured between two Bluecoat proxies prevents you from filtering out on IP addresses.

# Learning by failing  :wastebasket:

The first time I approached the problem, I implemented it using [scapy](https://scapy.net/), with a **very basic** TCP engine (*full disclosure: it routinely entered into infinite loop: writing a bugfree TCP/IP stack is hard*) and then I faced difficulty handling the HTTP Request/response paradigm in non-convoluted ways ([Answering Machine](https://scapy.readthedocs.io/en/latest/api/scapy.ansmachine.html) was too lightweight, [Automaton](https://scapy.readthedocs.io/en/latest/api/scapy.automaton.html) was too heavy).

Round  :one: :orange_circle: Packet loss  --- :red_circle:   HTTP/1.1 --- :red_circle: Proxy

The second time, I kept it simple: delegate the TCP/IP parsing to a robust tool such as Wireshark/tshark and abuse their "*Follow TCP session*" feature. Obviously, these tools are clearly not designed for that purpose and automating the session tracking was hackish. Now that I am thinking about it, I wonder if a libshark does exist, maybe it would have ease everything? 🤷‍♂️

Round :two: :green_circle: Packet loss  --- :red_circle:   HTTP/1.1 --- :red_circle: Proxy 

The third time, I decided to stop using tools not designed for the job and I met [tcpflow](https://github.com/simsong/tcpflow). This simple tool performs TCP/IP refragmentation/reassembly, extracts the Layer 7 payload and write each one-way flow on disk, you end up with gazillions of files. It is like a folder full of C2 streams but without metadata, ordering, without understanding of the HTTP request/response paradigm: a cluster mess.

Round :three: :green_circle: Packet loss  --- :red_circle:   HTTP/1.1 --- :red_circle: Proxy

Now, the gloves are off, we cannot half-bake it finally, it is time to do some real programming! 


# Final round: Doing it right
## Partners in crime

First, I need to introduce two old buddies:
- [libnids](https://github.com/MITRECND/libnids): Released in 2003, it emulates the IP stack of Linux 2.0.x (state of the art... in 2003) and is based on an asynchronous event notification (quite novel at its time). Libnids offers IP defragmentation and TCP stream assembly.
- [libhtp](https://github.com/OISF/libhtp): The HTTP Parsing library developed and used by Suricata among other security projects.

And the best part? MITRE has contributed bindings for Python: [pynids](https://github.com/MITRECND/pynids.git) and [htpy](https://github.com/MITRECND/htpy). Yummi! Kudos to MITRE, especially [@wxsBSD](https://twitter.com/wxs) !

## Integrating these dinosaurs in 2020 :t_rex: :sauropod: :crocodile:

I wont' bore you with all my failures trying to compile these relics on a recent Linux distribution but I spent waaaaay too much time (oh by the way, thank you Debian very much). Instead, I will directly share with you "what works":

**protip**: Use the following dockerfile :package: , it just works:

{{< gist nbareil 07307dee653ef3400cd3ece0c7a35799 "Dockerfile" >}}

## Just do it

Here is the skeleton I usually copy/paste when starting a new decoder:


{{< gist nbareil 07307dee653ef3400cd3ece0c7a35799 "template-decode-c2-traffic.py" >}}

Both libraries use asynchronous event notifications so it is quickly demanding to maintain both state engines at the same time when you make a change in the code. So take your time and it will eventually work :slight_smile:

Or, if your C2 uses HTTP connections, consider using as a template:

1. Filter the HTTP sessions you want to track in [request_headers_ready](#L28) based on IP addresses, URL, hostname, etc.
1. Inspect the HTTP request in [request_complete_callback](#L70)
1. Inspect the HTTP response in [request_complete_callback](#L96)

And you are dialed: you have a rock solid fondation to build your C2 dissector! 

Round :four: :green_circle: Packet loss  --- :green_circle:   HTTP/1.1 --- :green_circle: Proxy

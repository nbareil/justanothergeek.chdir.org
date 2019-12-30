---
categories:
 - paranoia
 - security
 - web
date: "2011-09-25T20:07:00Z"
title: Introducing a bit of Web paranoia into my habits...
description: How do I use Google Chrome? What are my must-have extensions?
---

When I'm not slacking in Emacs, I now spend most of my time in Google
Chrome. Almost everything I do is in the "cloud" (I hate this buzz
word): mail, blog, chats, voip and even version control.\
\
With the explosion of "social buttons" everywhere, I became really more
paranoid than before about my privacy. And when I see [new Facebook
'Frictionless
sharing'](http://www.readwriteweb.com/archives/read_in_facebook_social_news_apps.php) feature,
I don't regret my move. What did I do? Simple, I'm just using dedicated
browser profiles for each task:\
\
-   The most sensitive: the one I use **only** for my mail account and
    nothing else. I even think to use the [clever proxy hacks mentionned
    by Chris
    Evans](http://scarybeastsecurity.blogspot.com/2011/04/fiddling-with-chromiums-new-certificate.html) to
    only authorized outbound connections to my mail provider. I didn't
    do it yet because it would prevent me from reading HTML mails
    linking to external image (OK this is not a big loss and a potential
    privacy issue but useful sometimes). This is a dedicated profile
    because if you have access to mails, you have access to every web
    sites (ie "I lost my password")
-   Then there is my main profile (using it for Google
    Reader, [Google+](https://plus.google.com/114289168433047035840),
    [Twitter](https://twitter.com/nbareil/) and Facebook). My biggest
    fear is to be tracked because of social buttons or because I clicked
    a link somewhere. So I changed my habit and instead of clicking, I
    drag and drop interesting pages to my sandbox profile
-   The sandbox profile is where I do searches, browsing web pages, etc.
    It is configured to never send anything, or to store information
    on disk. I never use this profile to log on a website and if I have
    to do that, I get back to the main profile.

To do this efficiently, when I boot, I spawn these browsers with
specific profile directory (using --user-data-dir  Chrome option) and
they are never closed. My window manager is configured to display the
sandbox and my main profile side-by-side on the same workspace in order
to switch rapidly.


For each profile, I use these Chrome extensions:

-   [Keep My Opt-Outs](https://chrome.google.com/webstore/detail/hhnjdplhmcnkiecampfdgfjilccfpfoe) and [IBA Opt-Out](https://chrome.google.com/webstore/detail/gbiekjoijknlhijdjbaadobpkdhmoebb),
    enabling [Do-Not-Track header](http://en.wikipedia.org/wiki/Do_not_track_header) equivalent
-   [FlashBlock](https://chrome.google.com/webstore/detail/gofhjkjmkpinhpoiabjplobcaignabnl) to
    disable Flash by default
-   [Disconnect](https://chrome.google.com/webstore/detail/jeoacafpbcihiomhlakheieifhpjdfeo) to
    disable social buttons
-   [AdBlock](https://chrome.google.com/webstore/detail/gighmmpiobklfepjocnamgkkbiglidom)

This setup works really well for me, I'm using it for more than 6 months
now and it's cool :)

The next step is to use dedicated UIDs for each profile, I didn't do it
yet because there is no "perfect solution" because of Xorg design: any
X11 client can mess with other X11 client...



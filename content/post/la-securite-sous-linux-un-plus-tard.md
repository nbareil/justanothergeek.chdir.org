---
categories:
 - linux
 - kernel
 - security
 - french
date: "2010-12-28T15:43:00Z"
title: La sécurité sous Linux, un an plus tard...
---

*Sorry english folks: this post is in french, ~~but it will be
translated soon~~, [translated and updated post is available
here](http://justanothergeek.chdir.org/2011/01/linux-security-one-year-later.html).*

Plus qu'une longue liste de vulnérabilités, ce post a pour objectif de
décrire ce qu'il s'est passé en 2010 dans l'écosystème de la sécurité
sous GNU/Linux.

La première partie est dédiée aux nouvelles classes de vulnérabilité. La
deuxième partie se concentre sur la défense avec l'analyse des
différentes améliorations tendant à améliorer la sécurité de nos
systèmes. Enfin pour terminer ce post, il y aura quelques citations de
développeurs noyau assez révélatrices.

Ce post étant plutôt très long et puisque je suis syndiqué sur plusieurs
"planets", je préfère le couper, [désolé
Sid](http://sid.rstack.org/blog/index.php/392-ca-m-enerve) :)

[]()
Yang: Nouvelles classes de vulnérabilité
========================================

Grâce à la popularisation des différents mécanismes de protection
userspace dans les distributions "grand public" (compilation des paquets
avec les différentes options de durcissement
([`stack-protector`](http://www.trl.ibm.com/projects/security/ssp/),
[`PIE`](http://en.wikipedia.org/wiki/Position-independent_code),
[`FORTIFY_SOURCE`](http://gcc.gnu.org/ml/gcc-patches/2004-09/msg02055.html),
écriture des règles d'accès SELinux), les chercheurs de vulnérabilité
ont dû trouver un nouveau terrain de jeu plus clément : celui du noyau.
Grâce aux démonstrations de Tavis Ormandy et [Julien
Tinnes](http://www.cr0.org/), 2009 avait été marqué par les
vulnérabilités du type *NULL pointer dereference*. Des fonctionnalités
pro-actives avaient été développées pour *mitiger* l'impact de ce genre
de bug mais le jeu du chat et de la souris ne s'est jamais arrêté afin
de trouver de nouveaux moyens de contourner ces protections.

Contournement de `mmap_min_addr`
--------------------------------

Pour rappel, la protection principale du noyau contre cette classe de
vulnérabilité est d'interdire l'allocation d'une page de mémoire si son
adresse virtuelle est en dessous de `mmap_min_addr`
(`/proc/sys/vm/mmap_min_addr`), cela afin d'éviter qu'un attaquant n'y
dépose son shellcode et déclenche un déréférencement de pointeur NULL.

Beaucoup de moyens de contourner cette vérification avaient été trouvés
en 2009, pourtant encore deux méthodes de contournement ont été publiées
cette année :

-   Lorsque le noyau utilise des pointeurs manipulés par l'userland, il
    vérifie qu'ils pointent bien depuis/vers une zone utilisateur. C'est
    le rôle d'`access_ok()` de vérifier qu'une adresse est en dessous de
    la frontière userspace/kernelspace.\
    De temps en temps, le noyau utilise des fonctions normalement
    dédiées à l'espace utilisateur, or ces dernières vérifient que les
    adresses manipulées sont bien dans l'espace *userland*, ce qui
    n'arrange pas le noyau parce qu'il aimerait utiliser les fonction
    pour lui-même (avec des adresses *kernelspaces*).\
    Afin de contourner cette vérification, le noyau manipule la
    "frontière" à l'aide de `set_fs()` avant l'appel à la fonction puis
    la rétablit au retour, ni vu ni connu. Cela signifie que
    temporairement, pendant l'exécution de la fonction, aucune
    vérification ne sera effectuée.\
    [Nelson Elhage](http://blog.nelhage.com/) a brillamment trouvé
    comment exploiter cette particularité : lorsque le noyau traite un
    *Kernel Oops* ou un `BUG()`, il termine le processus ayant généré
    l'exception à l'aide de `do_exit()`. Cette fonction peut notifier la
    mort du processus à d'autres threads en écrivant 0 à une adresse
    arbitraire contrôlée par `access_ok()`.\
    L'exploit consiste dès lors à déclencher une exception pendant le
    traitement d'une fonction tournant avec `access_ok()` désactivé.
    Lorsque l'exception sera déclenché, `do_exit()` sera appelé et
    puisqu'`access_ok()` sera désactivé, la valeur 0 sera écrite à une
    adresse arbitraire. Boom ! Première méthode.
-   Deuxième méthode maintenant. Tavis Ormandy a constaté qu'à la
    création des mapping mémoires, [le VDSO pouvait être projeter une
    page en dessous de
    `mmap_min_addr`](http://thread.gmane.org/gmane.linux.kernel/1074552),
    ce qui est particulièrement intéressant pour les noyaux Redhat
    puisque `mmap_min_addr` == 4096.\
    En théorie, cela signifie qu'une exploitation déférencement de
    pointeur `NULL` devrait utiliser les octets du VDSO pour rebondir.

En fin d'année 2010, cela a été la redécouverte des problèmes de
variables non initialisées, mais dans le noyau cette fois-ci.

Variables non-initialisées
--------------------------

Un code vulnérable typique ressemble à cela :

    struct { short a; char b; int c; } s;

    s.a = X;
    s.b = Y;
    s.c = Z;

    copy_to_user(to, &s, sizeof s);

Le problème ici est qu'on ne fait pas attention à l'octet de *padding*
ajouté par le compilateur entre `.b` et `.c` afin d'aligner la structure
sur un mot processeur. En pratique, cela signifie que le processus
userspace peut récupérer un octet de mémoire "aléatoire".

### Correctif

Le correctif pourrait sembler assez simple, avec l'ajout d'un
`memset(&s, '\0', sizeof s)`, néanmoins, les choses ne sont pas aussi
faciles puisque d'après la norme C99, le compilateur est libre
d'optimiser les cas suivants :

-   Considérer que le `memset()` est superflu et le supprimer puisque
    chaque membre de la structure est initialisé
-   Plus tard, écraser l'octet de padding en faisant une assignation
    dans `.b`

De plus, dans le cas des [filtres
BPF](http://git.kernel.org/?p=linux/kernel/git/stable/linux-2.6.36.y.git;a=commit;h=2bd84dce08a6a782925f5e34c2e87ad957c57007),
les développeurs de `netdev` ont considérés que forçer l'initialisation
d'un tableau (de 16 mots de 32 bits) étaient beaucoup trop couteux, car
appelé pour chaque paquet. À la place, ils ont écrit un vérificateur de
code BPF afin de vérifier que chaque accès au tableau était valide.

### Impact

Ce type de bug a déjà [été démontré dangereux en espace
utilisateur](https://www.blackhat.com/presentations/bh-europe-06/bh-eu-06-Flake.pdf)
et ses conséquences sont pires dans le noyau, pourtant, il a fallu
donner quelques coups dans la fourmillière pour faire bouger les choses
; Comme ce fût le cas face au [scepticisme du mainteneur de
netdev](http://thread.gmane.org/gmane.linux.network/177506/focus=177549)
: [la réponse de Dan
Rosenberg](http://lists.grok.org.uk/pipermail/full-disclosure/2010-November/077321.html)
a été cinglante avec la publication d'un exploit sur *full-disclosure*,
même si plus tard, il a avoué avoir publié cet exploit car il [doutait
de sa
criticité](http://permalink.gmane.org/gmane.comp.security.bugtraq/45315).

Malgré cet épisode, les développeurs noyau ont bien pris en compte ce
type de vulnérabilité et des [dizaines de correctifs ont été
appliqués](http://search.gmane.org/?query=uninitialized+memory&author=&group=gmane.linux.kernel&sort=date&DEFAULTOP=and&xP=Zuniniti%09Zmemori&xFILTERS=Glinux.kernel---A)
depuis.

### Expansion de la pile noyau

En 2005 déjà, [Gaël Delalleau discutait de l'intérêt de faire se
rencontrer la pile et le tas en espace
utilisateur](http://cansecwest.com/core05/memory_vulns_delalleau.pdf),
en novembre 2010, Nelson Elhage, l'auteur de
[Ksplice,](http://ksplice.com/) remettait au goût du jour cette attaque
pour le noyau.

La mémoire allouée pour le noyau lui-même est minimale : une tâche noyau
ne peut avoir au plus que deux pages mémoire pour ses variables locales
(sa pile). Mais cette limitation est juste "conventionnelle"
puisqu'aucun méchanisme n'empêche la tâche de s'étendre, il n'y a pas de
page de garde par exemple.\
En pratique, si nous sommes capables de faire "grossir" la pile d'une
tâche noyau au delà de ses deux pages réglementaires (voir
[CVE-2010-3848](http://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2010-3848)
pour un exemple concret), la pile va recouvrir la structure
`thread_info` de la tâche courante.

En [écrasant certains pointeurs de
fonction](http://jon.oberheide.org/blog/2010/11/29/exploiting-stack-overflows-in-the-linux-kernel/)
disponibles à l'intérieur de cette structure, nous sommes capables de
détourner le flot d'éxécution.

Ying: Nouvelles protections
===========================

Correction de bugs
------------------

Cette année ne sera pas l'année du changement de mentalité de Linus
Torvalds concernant les bugs de sécurité, mais on s'y rapproche grâce
aux efforts des équipes de Redhat, SuSe ou Ubuntu.

Il semblerait qu'elles suivent de près les listes de diffusion du noyau
afin d'identifier des commits "sensibles" et un numéro de CVE est
assigné. Eugene Teo maintient d'ailleurs un [repository git avec tous
les CVE
taggés](http://git.kernel.org/?p=linux/kernel/git/eugeneteo/linux-2.6-cve-tagged.git;a=summary),
ce qui est particulièrement utile lors d'audits puisqu'il est facile
d'identifier les vulnérabilités d'un noyau donné. C'est un petit peu
l'équivalent *whitehat* des [listes d'exploits par
noyau](http://xrayoptics.by.ru/database/localroot/lista_exploits_kernel.txt)
utilisé par les pirates.

Sécurité proactive
------------------

De nombreuses contributions ont été faites dans le noyau Linux pour
améliorer sa sécurité en amont. Beaucoup de chantiers ont été commençés
afin de rendre la tâche beaucoup plus compliquée aux développeurs
d'exploits. Par exemple, si on revient sur les vulnérabilités de Nelson
Elhage, [l'exploit de Dan
Rosenberg](http://permalink.gmane.org/gmane.comp.security.full-disclosure/76457)
aura nécessité la combinaison de trois vulnérabilités pour transformer
un DoS en élévation de privilèges.

Cette défense en profondeur permet de voir à quel point il devient
coûteux d'exploiter certaines vulnérabilités. Mais revenons sur les
chantiers qui ont eu lieu en 2010.

### Renforcement des permissions

Brad Spengler l'a répété de nombreuses fois les années précédentes :
beaucoup trop d'informations sont disponibles à l'utilisateur. C'est la
raison pour laquelle son patch grsecurity restreint au maximum les
droits d'accès sur les fichiers spéciaux du noyau.

En effet, on retrouve dans ces fichiers les adresses d'objets du noyau,
ce qui est très pratique lorsqu'on exploite une vulnérabilité puisque
cela évite de faire du bruteforce, ce qui est rarement une bonne chose à
faire en kernel land :)

Dan Rosenberg et Kees Cook ont donc oeuvrés pour intégrer ces
restrictions dans la branche officielle :

-   [dmesg\_restrict](http://news.gmane.org/find-root.php?message_id=%3c1289273338.6287.128.camel%40dan%3e):
    l'accès à `dmesg(8)` nécessite désormais `CAP_SYS_ADMIN`.
-   Suppression des adresses dans
    [`/proc/timer_list`](http://permalink.gmane.org/gmane.linux.kernel/1064008),
    [`/proc/kallsyms`](http://git.kernel.org/?p=linux/kernel/git/torvalds/linux-2.6.git;a=commit;h=59365d136d205cc20fe666ca7f89b1c5001b0d5a), etc.
    Les développeurs officiels ne voient pas d'un très bon oeil ces
    patches qui à leurs yeux, sont inutiles et compliqueront la tâche de
    débugging en cas de problème, c'est la raison pour laquelle le
    [mainteneur de netdev s'est clairement opposé à appliquer ce genre
    de
    transformation](http://thread.gmane.org/gmane.linux.network/177739/focus=2076).
    On peut d'ailleurs féliciter le zen et patience de Dan Rosenberg !\
    Les solutions qui ont été proposées sont :
    -   Puisqu'on ne peut pas simplement supprimer les adresses car cela
        casserait l'ABI, mettre des adresses nulles.
    -   Changer les permissions d'accès au fichier (mais [cela casse
        certains logiciels
        anciens](http://git.kernel.org/?p=linux/kernel/git/torvalds/linux-2.6.git;a=commitdiff;h=33e0d57f5d2f079104611be9f3fccc27ef2c6b24))
    -   XOR-er les adresses avec une valeur secrète

La solution qui semble la mieux engagée est le remplacement des adresses
par une valeur arbitraire lorsque le lecteur ne dispose pas de privilège
suffisant. Mais pour éviter la duplication de code, le [*format
specifier*
`%pK`](http://news.gmane.org/find-root.php?message_id=%3c1292692835.10804.67.camel%40dan%3e)
a été implémenté : en fonction de la variable sysctl `kptr_restrict`,
l'adresse sera affichée ou non.

À l'occasion de ces restrictions, une [nouvelle capability
`CAP_SYSLOG`](http://permalink.gmane.org/gmane.linux.kernel.lsm/12185) a
été créé. C'est ce privilège qui conditionne l'accès aux adresses.

Beaucoup de travail reste encore à faire. Grâce à [son nouveau
fuzzer](http://codemonkey.org.uk/2010/12/15/system-call-fuzzing-continued/),
Dave Jones a
[découvert](http://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2010-4347)
que n'importe quel utilisateur pouvait charger une nouvelle table ACPI
si `debugfs` était monté à cause de permissions laxistes.

### Marquage en lecture seule

Un chantier pas encore terminé à ce jour est le [marquage de certaines
zones mémoires en lecture
seule](http://thread.gmane.org/gmane.linux.kernel/1058823), pour cela,
plusieurs actions sont nécessaires :

-   [Mettre de réelle permission matérielle sur le segment
    `.ro.data`](http://git.kernel.org/?p=linux/kernel/git/x86/linux-2.6-tip.git;a=commitdiff;h=65187d24fa3ef60f691f847c792e8eaca7e19251).
    Pour le moment, les permissions sont purement virtuelles, ce patch
    permet de marquer physiquement la page en lecture seule (ceci étant
    contrôlé par le CPU)
-   Marquer les pointeurs de fonctions comme `const`-ant lorsque cela
    est possible. Une des techniques les plus simples pour exploiter une
    vulnérabilité noyau est d'écraser un pointeur de fonction, le
    passage de ces pointeurs en constante permet de déplacer ces
    variables dans la zone `.ro.data` et donc empêcher la réécriture.
    Bien sûr, il restera toujours des pointeurs de fonction en écriture,
    mais ce n'est pas une raison pour ne rien faire…
-   Désactivation des points d'entrée vers `set_kernel_text_rw()` afin
    de ne pas laisser un attaquant changer la permission d'une page.

À priori, les développeurs ne semblaient pas opposés à ce patch et ils
seraient même plutôt heureux de l'intégrer pour faire des [optimisations
de virtualization](http://article.gmane.org/gmane.linux.kernel/1058954).

### Empêcher le chargement automatique des modules

La pluspart des vulnérabilités exploitées touchent des parties de code
assez peu utilisées, c'est d'ailleurs peut-être la raison pour laquelle
on y trouve des bugs.

En général, les distributions n'ont pas d'autres choix que de compiler
le noyau avec toutes les fonctionnalités, le tout en module afin de pas
se retrouver avec un noyau monolithique de 30 Mo en mémoire.

Afin que ce soit transparent, le noyau est capable de charger
automatiquement en mémoire le module chargé de réaliser l'opération
demandée, ce qui est plutôt une bonne chose pour les attaquants : il
suffit de demander le support de X.25 pour qu'il soit chargé, prêt à
être exploité.

Dan Rosenberg (encore !) a [proposé de charger automatiquement les
modules uniquement si le processus déclencheur est
root](http://article.gmane.org/gmane.linux.kernel/1058922). Cette
restriction est déjà présente dans la suite de patches grsecurity mais
cette limitation est jugée impactante pour les distributions et a donc
été refusé de peur de casser l'existant :-/

### Support de `UDEREF` sur architecture AMD64

Les développeurs de PaX ont toujours été clairs que les systèmes AMD64
ne seraient jamais aussi bien protégés que sur i386 à cause du manque de
la segmentation.

Néanmoins, ils font du *best-effort* et nous le prouve encore avec
l'[implémentation
d'`UDEREF`](http://grsecurity.net/pipermail/grsecurity/2010-April/001024.html)
pour cette architecture.

Pour rappel, `UDEREF` empêche le noyau d'utiliser de la mémoire
userspace sans l'avoir demandé explicitement. Cette fonctionnalité
empêche ainsi l'exploitation de *NULL pointer dereferences*.

Sur i386, c'est plutôt facile en utilisant la segmentation. Mais sur
AMD64, c'est plutôt une bidouille plutôt sale : déplacer la zone de
mémoire userspace et la marquer comme non-exécutable.

Le problème, c'est qu'on ne fait que le déplacer : désormais, plutôt que
déréférencer un pointeur nul, il faudrait influencer le noyau pour
déréférencer une autre adresse (mais comme le dit pageexec, si on en
arrive là, c'est le dernier de nos soucis).\
Ensuite, on perd 5 bits d'adressage donc un processus voit son espace
d'adressage réduit à 42 bits et un peu d'ASLR au passage...\
Et cerise sur le gateau, chaque transition user-to-kernel et
kernel-to-user subit le coût d'un vidage de la TLB (dû au déplacement de
la zone mémoire).

Réseau
------

La sécurité réseau est à l'image des soumissions sur le sujet dans les
conférences : ce n'est malheureusement pas assez sexy pour que les
chercheurs s'y intéressent. Mise à part le début de réécriture
d'iptables appelé [nftable](http://lwn.net/Articles/324989/) en 2009,
pas grand chose n'est arrivé en 2010. Parmi les choses remarquables, il
y a le support des [TCP Cookie
Transactions](http://kernelnewbies.org/Linux_2_6_33#head-2c3c3a8cb87d5b7a6f1182e418abf071cda22c8c)
et l'amélioration des "anciens" syncookies.

Les TCP syncookies sont utilisés pour ne pas créér d'entrées dans la
table des connexions tant qu'elles n'ont pas rééllement ouvertes, cela
est particulièrement utile lors d'un DoS par SYN flooding.\
Auparavant, les SYNcookies étaient considérés comme "à utiliser en
dernier recours" car ont perdait les options de négociation TCP (bit de
congestion, *window scaling* ou *selective acknowledgement*).

Cela est désormais terminé puisque [le noyau stocke désormais ces
informations](http://git.kernel.org/?s=4dfc2817025965a2fc78a18c50f540736a6b5c24)
dans les 9 bits de poids faible de l'option TCP Timestamp (à noter que
la page de manuel
[tcp(7)](http://www.kernel.org/doc/man-pages/online/pages/man7/tcp.7.html)
n'a toujours pas été mise à jour). Ce qui signifie que l'utilisation de
cette fonctionnalité n'est plus aussi impactante sur les performances
qu'auparavant.

Aveux d'échec
=============

[Le drame des
capabilities](http://permalink.gmane.org/gmane.linux.kernel.lsm/12196) :
> Quite frankly, the Linux capability system is largely a mess, with big
> bundled capacities that don't make much sense and are hideously
> inconvenient with the capability system used in user space (groups).\
> -hpa

[Trop de patches à relire pour la branche -stable du
noyau](http://permalink.gmane.org/gmane.linux.kernel/1068774) :\
> &gt; &gt; I realise it wasn't ready for stable as Linus only pulled it
> in\
> &gt; &gt; 2.6.37-rc3, but surely that means this neither of the
> changes\
> &gt; &gt; should have gone into 2.6.32.26.\
> &gt; Why didn't you respond to the review??\
> \
> I don't actually read those review emails, there are too many of them.

Conclusion
==========

Beaucoup de bonnes choses ont pris places dans le noyau Linux, en
majeure partie grâce au travail des différentes personnes citées dans ce
post, il est d'ailleurs frappant de se rendre compte que toutes ces
améliorations sont le résultat de chercheurs en sécurité plutôt que des
développeurs du noyau. C'est peut-être la raison pour laquelle chaque
patch a fait l'objet d'interminables discussions (admirons encore la
[patience de ces
derniers](http://thread.gmane.org/gmane.linux.kernel/1015999/focus=1018279))...\
Ce n'est d'ailleurs que maintenant que je comprends à quel point spender
avait raison dans sa [déclaration de guerre contre les
LSM](http://grsecurity.net/lsm.php). Est-ce que les mainteneurs du
sous-système "Security" ne seraient pas dans leur tour d'ivoire sans
comprendre les problématiques de la "vraie vie" ? Là où le sysadmin n'a
pas le temps d'utiliser la dernière release du noyau sur chaque serveur,
ni le courage d'écrire des règles SELinux qui seraient de toutes façons
contourner au premier bug noyau...\
Enfin, ce n'est que l'avis de quelqu'un du [security
circus](http://article.gmane.org/gmane.linux.kernel/706950)...

Malgré tout, on ne peut qu'être heureux de voir les progrès de cette
année. On peut presque espérer qu'on n'arrivera peut-être plus à
échapper à `mmap_min_addr`... Et que toutes les modifications
pro-actives qui ont été faites nécessiteront la combinaison de multiples
vulnérabilités pour être exploitables. Je ne dis pas qu'il n'y aura plus
d'exploits, loin de là, mais plutôt que le coût d'exploitation sera trop
élevé pour le pirate moyen. À ce moment là, les chercheurs devront se
plonger dans les bugs "logiques" comme les [vulnérabilités
`LD_PRELOAD`/`LD_AUDIT`](http://seclists.org/fulldisclosure/2010/Oct/257).


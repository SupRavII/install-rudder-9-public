# Architecture et flux reseau Rudder dans le homelab

## Composants logiques

- Rudder server : noeud central, expose l'UI/API, stocke la base de
  configuration (PostgreSQL) et la PKI interne. Heberge aussi son
  propre relais pour les noeuds qui se connectent directement.
- Rudder relay (optionnel) : relais regional, permet de demultiplier
  le serveur central pour les sites distants ou les zones isolees.
- Rudder agent : tourne sur chaque noeud manage, s'enregistre aupres
  d'un serveur ou d'un relais, recupere ses politiques, les applique,
  remonte un rapport et un inventaire.

## Implantation cible homelab

    +-------------------------------------+
    |  Rudder server (datacenter ou       |
    |  <node>)                            |
    |  - PostgreSQL                       |
    |  - Jetty/Scala UI + API             |
    |  - Relayd                           |
    |  - Agent local                      |
    +------------------+------------------+
                       |
                       | Tailscale 100.x.y.z
                       |
       +---------------+---------------+----------------+
       |                               |                |
    +--+---+   +-------+   +-------+   +-------+   +----+----+
    |<node>|   | <node> |   |<node>|   |satellites|  | <dns-master>     |
    +------+   +-------+   +-------+   +-------+   |  <frontend>   |
                                                   +---------+

Tous les agents pointent sur l'IP Tailscale du serveur Rudder.
Coherent avec les inventaires Ansible (regle generale du parc).

## Flux et ports

Depuis l'agent vers le serveur :

- TCP 443 HTTPS : retrieve policy, post inventaire, post rapport.

Depuis le serveur vers l'agent (optionnel) :

- TCP 5309 : push de declenchement immediat d'un run.

## PKI

Le serveur Rudder embarque sa propre autorite de certification dediee
a la signature des canaux serveur <-> agent. La PKI est independante
de celle utilisee pour les services web du homelab (Let's Encrypt sur
nginx). A l'installation, le serveur genere :

- une CA racine Rudder (/var/rudder/cfengine-community/ppkeys/)
- un certificat serveur signe par cette CA
- une cle agent par noeud, regeneree au premier inventaire

Les noeuds en "Pending" presentent leur cle publique au serveur. Tant
qu'on n'accepte pas explicitement le noeud dans l'UI, aucune politique
ne lui est poussee.

## Comparaison avec les autres outils du parc

- Ansible (audit-update-linux) : declaratif mais one-shot ou cron.
  Rudder fait du declaratif continu avec convergence permanente. Les
  deux cohabitent sans conflit, ne pas faire pointer les deux outils
  sur le meme fichier de conf.
- Icinga2 : observation et alerting. Rudder fait du remediement.
  Complementaires : Icinga voit le probleme, Rudder l'empeche de
  reapparaitre.
- OCS Inventory NG : inventaire pur sans remediement. Rudder couvre le
  meme perimetre inventaire (voir migration-ocs-rudder.md).

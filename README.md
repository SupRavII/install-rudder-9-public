> **SANITIZED PUBLIC MIRROR**
>
> This repo is an automated, sanitized public mirror of a private homelab
> documentation. Real IPs, hostnames, domain and personal references are
> replaced with placeholders (`<RUDDER_SERVER_TS>`, `<node>`, `example.com`,
> etc.). The source repo lives on a private Gitea instance and is the
> authoritative version.
>
> Sync script: `sync-rudder-public.sh` (in kzff-utils-scripts on the
> private Gitea, scheduled via cron).
>
> Source commit: e3965df

# install-rudder-9

Documentation d'installation, d'exploitation et de migration vers Rudder 9.0
(serveur + agents) pour le homelab <homelab>.

## Sommaire

- [AVERTISSEMENT LICENCE COMMUNITY VS ENTERPRISE](#avertissement-licence)
- [Presentation produit](#presentation-produit)
- [A quoi sert Rudder](#a-quoi-sert-rudder)
- [Architecture cible homelab](#architecture-cible-homelab)
- [Documentation detaillee](#documentation-detaillee)
- [Sources officielles](#sources-officielles)

## AVERTISSEMENT LICENCE

================================================================================

Rudder est diffuse en DEUX editions distinctes (https://www.rudder.io/fr/tarifs/) :

**Rudder Core (Community)** - GRATUIT, GPLv3 (utilisee dans ce projet) :
  - Configuration management declaratif continu
  - Inventaire materiel et logiciel
  - Reporting de conformite de base
  - Support : communaute uniquement

**Rudder Enterprise / Corporate Security Suite** - PAYANT (cout par noeud
par an, devis sur demande) :
  - Patch management coordonne automatise
  - Vulnerability management avec correlation CVE native
  - Security benchmarks CIS / ANSSI exploitables (sortis de beta en 9.0)
  - Support technique standard (Enterprise) ou premium avec delais
    garantis (Corporate)
  - Correctifs de securite garantis 18 mois / 24 mois
  - Responsable client dedie (Corporate)

**Les sections "Apports 9.0" et "Patch management / vulnerability management"
de la presentation ci-dessous decrivent des features GLOBALES Rudder 9.0,
incluant les features payantes. Dans une installation Community, l'UI
exposera ces sections mais les capacites avancees (correlation CVE,
benchmarks CIS deployables) necessitent une souscription.**

La Community reste largement suffisante pour le besoin homelab.

================================================================================

## Presentation produit

Rudder est une plateforme open source d'automatisation de configuration et
de conformite developpee par la societe francaise Rudder (ex-Normation).
Le coeur du moteur est ecrit en Scala (serveur web/API) et en Rust pour
l'agent moderne, qui a remplace progressivement l'ancien backend bati sur
CFEngine. Le projet est sous licence GPLv3 cote serveur et Apache 2.0
cote agent.

La version 9.0 est la branche stable courante en 2026. Principaux apports
par rapport a la branche 8.x :

- Support officiel de Debian 13 et RHEL/Rocky/AlmaLinux/Oracle Linux 10
  en serveur comme en agent.
- Security benchmarks sortis de beta (CIS, ANSSI...), avec vue par
  benchmark et drill-down par noeud.
- Vulnerability management filtrable par groupe pour exposer rapidement
  les categories de noeuds a risque.
- Patch management enrichi : declenchement d'actions globales avant ou
  apres une campagne de patch.
- Inventaire materiel/logiciel integre, sans dependance a un agent tiers
  type FusionInventory ou OCS.

## A quoi sert Rudder

Rudder repond a quatre besoins qui se recouvrent dans la vraie vie d'un
parc Linux/Windows :

1. Gestion de configuration declarative
   Definir l'etat attendu d'un parc (paquets, services, fichiers de
   conf, utilisateurs, regles de pare-feu...) et laisser l'agent
   converger vers cet etat a chaque run (par defaut toutes les 5 min).
   Modele continu, donc autoreparation si quelqu'un derive a la main.

2. Audit et conformite (compliance)
   Plutot que de forcer, on peut declarer une regle en mode audit :
   Rudder mesure l'ecart sans corriger. Sortie : un dashboard de
   conformite par regle, par noeud, par groupe, exportable et utilisable
   en revue ISO 27001 / PCI-DSS / ANSSI. Embarque des benchmarks CIS
   prets a l'emploi en 9.0.

3. Inventaire de parc
   Chaque agent remonte un inventaire complet (CPU, RAM, disques, MAC,
   IP, OS, paquets, processus, hyperviseur...) consultable dans l'UI ou
   via l'API. Couvre le besoin classique d'un OCS Inventory NG.

4. Patch management et vulnerability management
   Pilotage de campagnes de patch coordonnees (fenetres de maintenance,
   pre/post actions), correlation avec les CVE remontees par
   l'inventaire pour prioriser les correctifs.

Cas d'usage typique homelab : on remplace les playbooks Ansible
audit-update-linux pour la partie "etat permanent" (uniformiser
sshd_config, fail2ban, sudoers, chrony, motd...) et on garde Ansible
pour les operations one-shot (cutover, deploiement applicatif).

## Architecture cible homelab

Serveur Rudder : VM dediee dans le datacenter (ou <node> en repli
homelab). Expose en HTTPS via reverse-proxy nginx existant, acces
restreint au tailnet.

Relais : optionnel, un relais par site distant si latence ou coupure
WAN. Au stade actuel, un seul serveur central suffit pour les machines
@home + datacenter via Tailscale.

Agents : tous les noeuds Linux du parc (<node>, <node>, <node>, <node>,
<dns-master>, <frontend>, satellites Icinga2) puis <windows-node> et <windows-host> en Windows une fois
la base Linux stabilisee.

Ports a ouvrir entre agents et serveur :

- TCP 443 (HTTPS) : remontees agent vers serveur (politique + rapport).
- TCP 5309 : declenchement de run distant (push depuis le serveur vers
  l'agent). Non obligatoire si on accepte la latence de la prochaine
  remontee periodique.

## Documentation detaillee

- [Installation du serveur sur Debian/Ubuntu](docs/install-server-debian.md)
- [Installation de l'agent sur Debian/Ubuntu](docs/install-agent-debian.md)
- [Installation de l'agent sur RHEL/Rocky/AlmaLinux](docs/install-agent-rhel.md)
- [Installation de l'agent sur Windows (pieges parc <admin>)](docs/install-agent-windows.md)
- [Plan de migration OCS Inventory NG vers Rudder](docs/migration-ocs-rudder.md)
- [Architecture et flux reseau](docs/architecture.md)

## Sources officielles

- Site editeur : https://www.rudder.io/
- Documentation 9.0 : https://docs.rudder.io/reference/9.0/
- Quick install : https://docs.rudder.io/reference/9.0/installation/quick_install.html
- Serveur Debian/Ubuntu : https://docs.rudder.io/reference/9.0/installation/server/debian.html
- Agent Debian/Ubuntu : https://docs.rudder.io/reference/9.0/installation/agent/debian.html
- Agent RHEL : https://docs.rudder.io/reference/9.0/installation/agent/rhel.html
- Code source : https://github.com/Normation/rudder
- Releases : https://github.com/Normation/rudder/releases

# Migration OCS Inventory NG vers Rudder 9.0

OCS Inventory NG est une plateforme d'inventaire pur (parc materiel et
logiciel, deploiement de paquets via OCS-NG Agent + plugin GLPI).
Rudder couvre ce perimetre nativement et ajoute la gestion de
configuration declarative continue. La migration consiste donc moins a
"reimplementer OCS" qu'a remplacer le besoin d'OCS par un outil qui
fait plus.

## 1. Inventaire des fonctionnalites OCS a migrer

Avant tout, lister chez soi ce qu'OCS apporte aujourd'hui. Cas
courants :

- Collecte d'inventaire materiel/logiciel sur les postes et serveurs.
- Wake-on-LAN et inventaire reseau passif.
- Deploiement de paquets / scripts via le canal agent.
- Integration GLPI (synchro vers ticketing).
- Detection IPDiscover (machines non agentees).

Tout ce qui n'est pas couvert par Rudder doit rester sur OCS ou etre
deplace vers un autre outil avant l'extinction. Typiquement, la
synchronisation OCS -> GLPI doit etre redirigee vers GLPI Inventory
natif si on veut couper OCS completement.

## 2. Equivalences fonctionnelles

| Besoin OCS                         | Couverture Rudder 9.0                            |
|------------------------------------|--------------------------------------------------|
| Inventaire materiel                | Oui, agent natif, plus complet (CPU flags, NIC)  |
| Inventaire logiciel                | Oui, paquets natifs + commandes custom           |
| Deploiement de paquet              | Oui, technique "Packages" + patch management     |
| Deploiement de script              | Oui, technique "Run a command" ou technique perso|
| IPDiscover (decouverte)            | Non natif, conserver nmap/arp-scan ou GLPI       |
| Wake-on-LAN                        | Non, garder un outil dedie                       |
| Lien vers GLPI                     | Oui via GLPI Inventory (FusionInventory format)  |

## 3. Strategie en trois phases

### Phase 1 - Cohabitation (semaine 1-2)

- Installer le serveur Rudder selon docs/install-server-debian.md.
- Deployer l'agent Rudder sur 100 % du parc Linux via clush ou
  audit-update-linux (voir docs/install-agent-debian.md).
- Garder l'agent OCS en place, aucune coupure.
- Comparer les inventaires Rudder vs OCS sur 10 a 20 machines temoin
  pour valider la couverture (paquets, versions, CPU, RAM, disques).

### Phase 2 - Bascule de l'inventaire (semaine 3-4)

- Rerouter les consommateurs aval (export CSV, dashboards) vers l'API
  Rudder : /api/latest/nodes et /api/latest/inventory.
- Si GLPI est connecte a OCS via OCS Plugin, basculer GLPI sur GLPI
  Inventory natif (les agents Rudder generent un inventaire au format
  FusionInventory consommable par GLPI).
- Geler les nouvelles inscriptions cote OCS (desactiver les agents
  OCS sur les nouvelles machines), Rudder devient le seul a accepter
  les nouveaux noeuds.

### Phase 3 - Bascule des deploiements (semaine 5-8)

- Reecrire les paquets OCS en techniques Rudder. Modele :
  une technique = un cas d'usage (sshd_config, motd, paquets de base,
  fail2ban...).
- Migrer un cas a la fois, regle par regle, par groupe de noeuds. Ne
  pas tout migrer d'un coup.
- Une fois toutes les techniques en place et stables sur le parc :
  desinstaller l'agent OCS sur les machines, puis decommissionner le
  serveur OCS.

### Phase 4 - Decommissionnement OCS (semaine 9+)

- Snapshot final de la VM serveur OCS (Veeam ou export PVE).
- Sauvegarde de la base MySQL OCS pour archive (audit/conformite).
- Arret du service, retrait DNS, suppression de la VM apres 30 jours
  de quarantaine.

## 4. Points d'attention specifiques homelab

- L'agent OCS et l'agent Rudder peuvent cohabiter sans conflit sur la
  meme machine, ils n'utilisent pas les memes fichiers ni les memes
  ports. Pas besoin de coupure pendant la phase 1.
- Le proxy WinHTTP/PAC du parc (<frontend>:3128) doit autoriser
  repository.rudder.io en sortie HTTPS, et la conf APT doit utiliser
  ce proxy sur les noeuds qui n'ont pas d'acces direct.
- Pour les noeuds satellites Icinga2, valider que les checks
  existants ne sont pas casses par la convergence Rudder (typique :
  permissions de /var/log, drop-in systemd qu'on a poses a la main).
- Conserver une copie des techniques en clair dans le repo Gitea
  KZFF/install-rudder-9 ou un repo dedie KZFF/rudder-techniques pour
  versionner et reviewer les politiques.

## 5. Plan de rollback

A chaque phase :

- Phase 1 : neutre, rollback = desinstaller l'agent Rudder.
- Phase 2 : remettre l'export OCS comme source de verite GLPI, garder
  la base OCS active.
- Phase 3 : reactiver les paquets OCS sur les machines temoin si une
  technique Rudder dysfonctionne (regle Rudder en mode "Disabled"
  plutot que suppression).
- Phase 4 : restaurer le snapshot Veeam de la VM OCS sous 30 jours.

## 6. Critere de succes

- 100 % du parc Linux remonte un inventaire complet dans Rudder.
- GLPI affiche les memes noeuds via le canal Rudder/FusionInventory.
- Toutes les techniques deployees sont en mode "Enforce" et
  convergent vert sur l'ensemble des noeuds cibles depuis au moins 7
  jours consecutifs.
- L'agent OCS est absent des paquets installes (verifie par clush).
- La VM OCS est eteinte depuis 30 jours sans demande de restauration.

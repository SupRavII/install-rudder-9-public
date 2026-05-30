# Retour en Community apres essai Enterprise

Procedure executee le 2026-05-29 sur <rudder-host> a la fin de la periode
d'essai Enterprise (licence PPFNetworKPPF, 2026-05-13 au 2026-06-13).

## Contexte

L'essai Enterprise avait ete active pour tester le patch management,
le vulnerability management et les benchmarks CIS. <windows-node> et <windows-host>
(Windows 11 Pro) avaient ete integres comme noeuds DSC pendant l'essai.
Seuls 5 agents Linux restaient actifs au moment du rollback.

A la fin de la periode d'essai, retour en Community pour continuer le
suivi du parc homelab sans souscription payante.

## Ce qui a ete fait

### 1. Etat initial constate

- Depot APT : deja sur `https://download.rudder.io/apt/9.0/ bookworm main`
  (Community, sans credentials) - la bascule depot avait ete faite en
  cours d'essai ou lors d'une session precedente.
- `/etc/apt/auth.conf.d/rudder.conf` : absent (credentials deja nettoyes).
- 8 plugins Enterprise encore installes dans `/var/rudder/packages/` :
  - `rudder-plugin-benchmark-cis-debian-12`
  - `rudder-plugin-benchmark-cis-ubuntu-22-04`
  - `rudder-plugin-benchmark-cis-ubuntu-24-04`
  - `rudder-plugin-change-validation`
  - `rudder-plugin-cve`
  - `rudder-plugin-dsc`
  - `rudder-plugin-security-benchmarks`
  - `rudder-plugin-system-updates`

### 2. Suppression des plugins

    sudo bash -c '
    for p in \
      rudder-plugin-benchmark-cis-debian-12 \
      rudder-plugin-benchmark-cis-ubuntu-22-04 \
      rudder-plugin-benchmark-cis-ubuntu-24-04 \
      rudder-plugin-change-validation \
      rudder-plugin-cve \
      rudder-plugin-dsc \
      rudder-plugin-security-benchmarks \
      rudder-plugin-system-updates; do
        rudder package remove "$p"
    done'

Chaque suppression a declenche un restart automatique de rudder-jetty
(comportement normal pour les plugins avec JAR).

Note : `rudder package remove` doit etre execute en root. En utilisateur
standard il echoue sur la creation du log dans `/var/log/rudder/rudder-pkg/`.

### 3. Etat final verifie

- `/var/rudder/packages/` : contient uniquement `index.json` (vide de plugins).
- Services actifs : `rudder-jetty`, `rudder-relayd`, `rudder-agent`, `apache2`.
- `rudder-server` reste en version 9.0.6-debian12 Community.

## Ce qu'il n'a pas ete necessaire de faire

- Pas de reinstallation de `rudder-server` : le depot Community etait
  deja actif et la version installee est identique entre les deux canaux
  pour 9.0.6.
- Pas de migration de base PostgreSQL : aucune donnee Enterprise specifique
  (campagnes patch, scores CIS) n'avait ete generee.

## Nettoyage noeuds Windows (2026-05-30)

La suppression du plugin DSC a eu pour effet immediat de bloquer la
generation des politiques pour les noeuds <windows-node> et <windows-host> (agents DSC
Windows 11 Pro enregistres pendant l'essai Enterprise). Le serveur
generait une erreur bloquante a chaque mise a jour de politiques.

Actions realisees le 2026-05-30 :

1. Suppression des noeuds via l'API Rudder (<rudder-host>:<SSH_PORT>) :

       curl -X DELETE https://<rudder-host>:<SSH_PORT>/rudder/api/latest/nodes/548131b0-8d46-4c31-8923-b1bfa47e5c66 \
         -H "X-API-Token: <token>"
       curl -X DELETE https://<rudder-host>:<SSH_PORT>/rudder/api/latest/nodes/d1e79a14-2756-4905-b220-756180c6539f \
         -H "X-API-Token: <token>"

2. SSH sur <windows-node> et <windows-host> (port <SSH_PORT>, utilisateur <admin>/PowerShell) :
   Desinstallation de l'agent DSC 9.0.6 via MSI :

       msiexec /x {4B55EA5E-...} /quiet

3. Suppression du dossier residuel `C:\Program Files\Rudder`.

Etat final : parc Rudder = 6 noeuds Linux uniquement (<rudder-host>, <node>,
<node>, <node>, debian, <node>). Plus aucune erreur DSC.

Pour reinstaller un noeud Windows si retour Enterprise : voir
`docs/install-agent-windows.md`.

## Script automatise disponible

Pour un rollback plus complet incluant reinstallation et snapshot BDD,
voir `scripts/rollback-to-community.sh` dans ce repo.

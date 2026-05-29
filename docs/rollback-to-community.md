# Retour en Community apres essai Enterprise

Procedure executee le 2026-05-29 sur <rudder-host> a la fin de la periode
d'essai Enterprise (licence PPFNetworKPPF, 2026-05-13 au 2026-06-13).

## Contexte

L'essai Enterprise avait ete active pour tester le patch management,
le vulnerability management et les benchmarks CIS. Aucun agent Windows
n'avait ete integre (cf. contrainte licence agent Windows Enterprise-only
documentee dans le README). Seuls 5 agents Linux restaient actifs.

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
- Pas de desinstallation d'agents Windows : <windows-node> et <windows-host> n'avaient pas
  ete integres (bloquant agent Windows = Enterprise-only).

## Script automatise disponible

Pour un rollback plus complet incluant reinstallation et snapshot BDD,
voir `scripts/rollback-to-community.sh` dans ce repo.

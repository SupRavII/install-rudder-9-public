# Bascule Community vers Enterprise (essai 1 mois)

Procedure pour activer une licence d'essai Rudder Enterprise pendant 1 mois,
sans casser l'installation Community en place. Permet de tester l'agent
Windows + patch/vulnerability management + CIS benchmarks.

## Pre-requis

- Souscription Rudder.io valide (essai ou paye), avec login et password
  fournis par Rudder dans le mail de bienvenue
- Serveur Rudder Community deja en place (etat fin du PROJET_RUDER_FULL)
- Agents Linux deja deployes et acceptes
- Acces sortant proxy <frontend>:3128 vers download.rudder.io

## Etape 1 - Bascule du depot APT sur <rudder-host>

Conserver le depot Community en parallele ? Non, ils sont exclusifs : ils
servent les memes paquets via auth differente. On remplace le `.list`
Community par le `.list` souscription.

    # Sauvegarde
    sudo cp /etc/apt/sources.list.d/rudder.list /etc/apt/sources.list.d/rudder.list.community-backup

    # Nouveau .list pointant sur la version souscription
    sudo tee /etc/apt/sources.list.d/rudder.list <<EOF
    deb [arch=$(dpkg --print-architecture)] https://download.rudder.io/apt/9.0/ $(lsb_release -cs) main
    EOF

    # Credentials d'authentification (login + password recus de Rudder)
    sudo tee /etc/apt/auth.conf.d/rudder.conf <<EOF
    machine download.rudder.io login LOGIN password PASSWORD
    EOF
    sudo chmod 640 /etc/apt/auth.conf.d/rudder.conf

    # Refresh et upgrade
    sudo apt-get update
    sudo apt-get install --only-upgrade rudder-server

`apt-get install --only-upgrade` reinstalle les binaires depuis le canal
souscription tout en conservant la base PostgreSQL, les techniques en place,
les noeuds acceptes, les allowed-networks etc. Aucune perte de conf.

## Etape 2 - Activer les plugins Enterprise

Les plugins Enterprise (patch-management, compliance, vulnerability) sont
disponibles via le meme canal :

    # Lister les plugins disponibles
    sudo rudder package list

    # Installer les plugins voulus
    sudo rudder package install-file patch-management
    sudo rudder package install-file vulnerability
    sudo rudder package install-file compliance

    # OU installer tout
    sudo rudder package install-all

Apres install des plugins, regenerer les policies :

    sudo rudder server trigger-policy-generation

## Etape 3 - Installation de l'agent Windows sur <windows-node> et <windows-host>

Sur <rudder-host> (ou ta machine cliente), recuperer le script PS1 maintenu :

    https://git.example.com/<admin>/powershell-scripts-ppf/raw/branch/main/<windows-node>/install-rudder-agent.ps1

Sur <windows-node> (puis <windows-host>), creer le fichier de credentials de souscription :

    # En PowerShell admin
    New-Item -ItemType Directory -Path "C:\Users\<admin>\.secrets" -Force | Out-Null
    @"
    LOGIN_RUDDER
    PASSWORD_RUDDER
    "@ | Set-Content -Path "C:\Users\<admin>\.secrets\rudder-subscription.txt" -Encoding UTF8

    # ACL : limiter au compte <admin> + Administrators
    icacls "C:\Users\<admin>\.secrets\rudder-subscription.txt" /inheritance:r /grant:r "<admin>:F" /grant:r "Administrators:F"

Puis lancer le script :

    # PowerShell admin
    Set-ExecutionPolicy Bypass -Scope Process -Force
    & "C:\Users\<admin>\KZFF\powershell-scripts-ppf\<windows-node>\install-rudder-agent.ps1"

Le script :

- Verifie les credentials (parametres ou fichier .secrets)
- Telecharge le MSI depuis download.rudder.io en HTTPS authentifie
- Installe avec `msiexec /qn POLICYSERVER=<RUDDER_SERVER_TS>`
- Lance le premier inventaire
- Le noeud apparait en Pending dans l'UI Rudder

## Etape 4 - Accepter les noeuds Windows

Comme pour les Linux :

    TOKEN=$(sudo cat /var/rudder/run/api-token)

    # Lister les pending pour recuperer les IDs
    curl -sk -H "X-API-Token: $TOKEN" https://localhost/rudder/api/latest/nodes/pending

    # Accepter chaque ID
    curl -sk -X POST -H "X-API-Token: $TOKEN" -H "Content-Type: application/json" \
      https://localhost/rudder/api/latest/nodes/pending/<id_iapet> \
      -d '{"status":"accepted"}'

    curl -sk -X POST -H "X-API-Token: $TOKEN" -H "Content-Type: application/json" \
      https://localhost/rudder/api/latest/nodes/pending/<id_titan> \
      -d '{"status":"accepted"}'

## Etape 5 - Decouvrir les nouvelles fonctionnalites

Une fois en Enterprise avec plugins installes, l'UI Rudder expose :

- **Vulnerability management** : Tools > Vulnerability Management
  - Liste des CVE par noeud
  - Filtrage par groupe, severite, statut (patche / vulnerable)
  - Lien vers rapports CVE detailles

- **Patch management** : Configuration > Patch Management
  - Creation de campagnes de patch
  - Fenetres de maintenance par groupe
  - Pre/post actions (script avant / apres patch)
  - Reporting de campagne (taux de succes)

- **Security benchmarks (CIS / ANSSI)** : Configuration > Rules
  - Application de policies CIS deployables (etat enforce ou audit)
  - Drill-down par noeud avec heatmap de conformite
  - Export de rapports d'audit pour ISO 27001 / PCI-DSS

## Surveillance de la fin d'essai

Note la date de fin de licence ds qu'elle est connue (mail Rudder ou UI
Settings > License). 2-3 jours avant l'expiration :

- Soit tu prends une souscription payante (devis Rudder.io)
- Soit tu execute la procedure de retour Community (voir
  [rollback-to-community.sh](rollback-to-community.sh))

Si tu laisses expirer sans rien faire, les agents Windows continueront de
remonter inventaire mais les nouvelles politiques Enterprise echoueront a
la generation cote serveur. Le serveur Linux tombera en mode degrade
(licence expiree) jusqu'a basculer manuellement en Community.

## Plan de retour Community en fin d'essai

Voir le script `scripts/rollback-to-community.sh` dans ce repo pour :

1. Desinstaller les agents Windows <windows-node> + <windows-host>
2. Retirer les plugins Enterprise sur <rudder-host>
3. Rebasculer le depot APT sur la version Community
4. Reinstaller `rudder-server` Community
5. Nettoyer les credentials de souscription

Apres rollback, retour exactement a l'etat post-PROJET_RUDER_FULL :
serveur Community + 5 agents Linux, sans Windows.

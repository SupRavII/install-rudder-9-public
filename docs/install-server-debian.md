# Installation du serveur Rudder 9.0 sur Debian/Ubuntu

Cible recommandee : Debian 12 ou 13, Ubuntu 22.04 ou 24.04 LTS.

## 1. Prerequis

Specifications minimales pour un parc < 100 noeuds :

- 4 vCPU
- 8 Go RAM
- 40 Go disque, avec /var sur partition dediee (l'inventaire et les
  rapports vivent dans /var/rudder, ca grossit)
- Connectivite sortante vers repository.rudder.io en HTTPS

Etapes preparatoires :

    apt-get update
    apt-get install -y wget ca-certificates gnupg lsb-release

Si la machine est derriere le proxy homelab (<frontend>:3128), configurer
APT et l'environnement avant de continuer.

## 2. Importer la cle GPG officielle

    install -d -m 0755 /etc/apt/keyrings
    wget --quiet -O /etc/apt/keyrings/rudder_apt_key.gpg \
      "https://repository.rudder.io/apt/rudder_apt_key.gpg"

Empreinte attendue :

    <RUDDER_APT_KEY_FINGERPRINT>

Verification :

    gpg --show-keys /etc/apt/keyrings/rudder_apt_key.gpg

## 3. Ajouter le depot APT

Version communautaire :

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/rudder_apt_key.gpg] http://repository.rudder.io/apt/9.0/ $(lsb_release -cs) main" \
      > /etc/apt/sources.list.d/rudder.list

Ne PAS deposer le backup .bak dans /etc/apt/sources.list.d/ (apt
notifie sur extensions invalides).

## 4. Installer le paquet serveur

    apt-get update
    apt-get install -y rudder-server

Le meta-paquet rudder-server tire le serveur web (Jetty), l'API,
PostgreSQL, le moteur de techniques, l'agent local et la racine de PKI.
Compter 5 a 10 minutes d'installation.

## 5. Premier compte administrateur

    rudder server create-user -u <admin>

Mot de passe demande interactivement. Le compte est stocke dans
/opt/rudder/etc/rudder-users.xml.

## 6. Acces a l'interface web

    https://<adresse_serveur>/

Login avec le compte cree a l'etape 5. Premier reflexe : aller dans

    Settings > General > Allowed Networks

et ajouter les subnets autorises a enregistrer des noeuds (LAN homelab
<LAN_INTERNAL>/24 et tailnet <TAILSCALE_CGNAT_SUBNET>).

## 7. Services systemd a surveiller

    systemctl status rudder-server
    systemctl status rudder-relayd
    systemctl status rudder-agent
    systemctl status postgresql

Logs principaux :

- /var/log/rudder/webapp/   (Jetty, applicatif Scala)
- /var/log/rudder/agent.log (agent local du serveur)
- /var/log/rudder/relay/    (relais sortant vers les agents)

## 8. Sauvegarde

Au minimum, sauvegarder :

- /var/rudder/configuration-repository/ (techniques, regles, groupes)
- Base PostgreSQL rudder (pg_dump -U rudder rudder)
- /opt/rudder/etc/                       (conf et PKI)

A integrer au plan de backup Veeam Agent Linux du parc.

# Installation de l'agent Rudder 9.0 sur Debian/Ubuntu

Cible : tous les noeuds Linux du parc Debian/Ubuntu (<node>, <node>,
<node>, satellites Icinga2, <dns-master>, <frontend> une fois la migration validee).

## 1. Prerequis

    apt-get update
    apt-get install -y wget ca-certificates gnupg lsb-release

## 2. Importer la cle GPG

    install -d -m 0755 /etc/apt/keyrings
    wget --quiet -O /etc/apt/keyrings/rudder_apt_key.gpg \
      "https://repository.rudder.io/apt/rudder_apt_key.gpg"

## 3. Ajouter le depot APT

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/rudder_apt_key.gpg] http://repository.rudder.io/apt/9.0/ $(lsb_release -cs) main" \
      > /etc/apt/sources.list.d/rudder.list

## 4. Installer l'agent

    apt-get update
    apt-get install -y rudder-agent

L'agent en 9.0 est ecrit en Rust, ne tire plus CFEngine. Environ 30 Mo
de paquets, demarrage automatique du timer systemd toutes les 5 min.

## 5. Pointer le serveur

    rudder agent policy-server <ip_ou_hostname_serveur>

Recommandation homelab : passer par l'IP Tailscale du serveur Rudder
(100.x.y.z). Coherent avec la regle inventaires Ansible et evite les
casse-tetes DNS si le LAN tombe.

## 6. Premier inventaire et premier run

    rudder agent inventory
    rudder agent run -l

Le noeud apparait ensuite en "Pending" dans l'UI :

    Nodes > Pending nodes > Accept

Tant qu'il n'est pas accepte, aucune politique ne lui est poussee.

## 7. Verifier l'etat de l'agent

    rudder agent health
    systemctl status rudder-agent.timer
    systemctl status rudder-agent.service

Journal :

    journalctl -u rudder-agent.service -n 100 --no-pager

## 8. Reseau

Port sortant depuis l'agent vers le serveur :

- TCP 443 (remontee de rapport + recuperation de politique)

Port entrant sur l'agent depuis le serveur (optionnel) :

- TCP 5309 (push de declenchement de run)

Si 5309 n'est pas ouvert, le run suivant aura lieu au prochain tick
(5 min par defaut), c'est generalement acceptable.

## 9. Desinstaller

    apt-get purge rudder-agent
    rm -rf /var/rudder /opt/rudder /etc/apt/sources.list.d/rudder.list
    rm -f /etc/apt/keyrings/rudder_apt_key.gpg

## 10. Deploiement de masse via clush

Depuis <node> avec le groupe @home :

    clush -g home -b 'wget -q -O /etc/apt/keyrings/rudder_apt_key.gpg https://repository.rudder.io/apt/rudder_apt_key.gpg'
    clush -g home -b 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/rudder_apt_key.gpg] http://repository.rudder.io/apt/9.0/ $(lsb_release -cs) main" > /etc/apt/sources.list.d/rudder.list'
    clush -g home -b 'apt-get update && apt-get install -y rudder-agent'
    clush -g home -b 'rudder agent policy-server 100.X.Y.Z'
    clush -g home -b 'rudder agent inventory'

A integrer ensuite dans audit-update-linux comme playbook bootstrap
puis migrer la conf permanente vers Rudder lui-meme.

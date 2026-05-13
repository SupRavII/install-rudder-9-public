# Installation de l'agent Rudder 9.0 sur RHEL/Rocky/AlmaLinux/Oracle

Cible : noeuds RHEL-like du parc (le cas echeant, <frontend>/<dns-master> si migration
un jour). Procedure identique sur Rocky 8/9/10, AlmaLinux 8/9/10,
Oracle Linux 8/9/10 et RHEL 8/9/10.

## 1. Prerequis

    dnf install -y curl ca-certificates

## 2. Ajouter le depot Rudder

Creer /etc/yum.repos.d/rudder.repo :

    [rudder]
    name=Rudder 9.0
    baseurl=https://repository.rudder.io/rpm/9.0/RHEL_$releasever/
    gpgcheck=1
    gpgkey=https://repository.rudder.io/rpm/rudder_rpm_key.pub
    enabled=1

## 3. Importer la cle GPG

    rpm --import https://repository.rudder.io/rpm/rudder_rpm_key.pub

Empreinte a verifier identique a la branche APT :

    <RUDDER_APT_KEY_FINGERPRINT>

## 4. Installer l'agent

    dnf install -y rudder-agent

## 5. Pointer le serveur

    rudder agent policy-server 100.X.Y.Z

## 6. Premier run

    rudder agent inventory
    rudder agent run -l

Accepter le noeud depuis l'UI (Nodes > Pending).

## 7. SELinux

L'agent Rudder est livre avec sa policy SELinux dediee, applicable
sans desactiver le mode enforcing :

    semodule -l | grep rudder

Si un AVC denial apparait apres une regle custom, capturer le log :

    ausearch -m avc -ts recent -i

et corriger via une policy locale plutot que de passer en permissive.

## 8. Firewall

Ouvrir 443 sortant (vers le serveur) et eventuellement 5309 entrant
(push depuis le serveur) avec firewalld :

    firewall-cmd --permanent --add-port=5309/tcp
    firewall-cmd --reload

## 9. Desinstaller

    dnf remove -y rudder-agent
    rm -rf /var/rudder /opt/rudder /etc/yum.repos.d/rudder.repo

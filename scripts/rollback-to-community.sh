#!/bin/bash
# rollback-to-community.sh
#
# Retour de Rudder Enterprise (essai 1 mois) a Rudder Community
# sans perdre les noeuds Linux, leur conf, les techniques custom, ni la
# base PostgreSQL.
#
# A executer sur <rudder-host> en tant que root (sudo).
#
# Effets :
#   1. Desinstalle les plugins Enterprise
#   2. Remplace le depot APT par la version Community
#   3. Reinstalle rudder-server Community (downgrade)
#   4. Retire les credentials d'auth.conf.d
#   5. Affiche les actions a faire manuellement cote <windows-node>/<windows-host>
#
# Idempotent (peut etre relance sans casser quoi que ce soit).
# Pas de purge de la base : tout l'historique Linux est conserve.

set -e

if [ "$EUID" -ne 0 ]; then
    echo "[ERR] Ce script doit etre lance en root (sudo)."
    exit 1
fi

echo "=== Etape 1 - Snapshot avant rollback ==="
DATE=$(date +%Y%m%d-%H%M%S)
SNAP_DIR=/var/backups/rudder-rollback-${DATE}
mkdir -p "$SNAP_DIR"
cp -p /etc/apt/sources.list.d/rudder.list "$SNAP_DIR/" 2>/dev/null || true
cp -p /etc/apt/auth.conf.d/rudder.conf "$SNAP_DIR/" 2>/dev/null || true
sudo -u postgres pg_dump rudder | gzip > "$SNAP_DIR/rudder.sql.gz"
tar czf "$SNAP_DIR/configuration-repository.tar.gz" -C /var/rudder configuration-repository 2>/dev/null
echo "  Snapshot dans $SNAP_DIR"

echo ""
echo "=== Etape 2 - Lister et desinstaller les plugins Enterprise ==="
if command -v rudder &>/dev/null; then
    PLUGINS=$(rudder package list 2>/dev/null | grep -E "patch-management|vulnerability|compliance" | awk '{print $1}' || true)
    if [ -n "$PLUGINS" ]; then
        for p in $PLUGINS; do
            echo "  Suppression plugin $p"
            rudder package remove "$p" || echo "  (echec sur $p, on continue)"
        done
    else
        echo "  Aucun plugin Enterprise actif"
    fi
fi

echo ""
echo "=== Etape 3 - Bascule depot APT vers Community ==="
if [ -f /etc/apt/sources.list.d/rudder.list.community-backup ]; then
    cp /etc/apt/sources.list.d/rudder.list.community-backup /etc/apt/sources.list.d/rudder.list
    echo "  Restaure depuis backup community"
else
    # Reconstruction depuis zero
    cat > /etc/apt/sources.list.d/rudder.list <<EOF
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/rudder_apt_key.gpg] http://repository.rudder.io/apt/9.0/ $(lsb_release -cs) main
EOF
    echo "  Reconstruit"
fi

echo ""
echo "=== Etape 4 - Suppression credentials de souscription ==="
if [ -f /etc/apt/auth.conf.d/rudder.conf ]; then
    rm -f /etc/apt/auth.conf.d/rudder.conf
    echo "  /etc/apt/auth.conf.d/rudder.conf supprime"
else
    echo "  Pas de credentials a nettoyer"
fi

echo ""
echo "=== Etape 5 - Reinstall rudder-server depuis Community ==="
apt-get update -q
apt-get install --reinstall -y rudder-server

echo ""
echo "=== Etape 6 - Trigger policy regeneration ==="
if [ -f /var/rudder/run/api-token ]; then
    TOKEN=$(cat /var/rudder/run/api-token)
    curl -sk -X POST -H "X-API-Token: $TOKEN" https://localhost/rudder/api/latest/system/regenerate/policies | head -c 200
    echo ""
fi

echo ""
echo "=== Etape 7 - Statut services apres rollback ==="
for svc in rudder-jetty rudder-relayd rudder-agent postgresql apache2; do
    printf "  %-20s %s\n" "$svc" "$(systemctl is-active $svc 2>&1)"
done

echo ""
echo "=== Actions manuelles restantes cote Windows ==="
echo ""
echo "Sur <windows-node> et <windows-host> (en PowerShell admin) :"
echo ""
echo "  # Stop + uninstall agent Rudder Windows"
echo "  Stop-Service rudder-agent -EA SilentlyContinue"
echo "  \$msi = Get-WmiObject Win32_Product | Where-Object { \$_.Name -match \"Rudder\" }"
echo "  if (\$msi) { \$msi.Uninstall() }"
echo ""
echo "  # Cleanup config et credentials"
echo "  Remove-Item C:\\Program Files\\Rudder -Recurse -Force -EA SilentlyContinue"
echo "  Remove-Item C:\\Users\\<admin>\\.secrets\\rudder-subscription.txt -EA SilentlyContinue"
echo ""
echo "Apres uninstall agent <windows-node>/<windows-host>, supprimer les noeuds cote serveur :"
echo "  TOKEN=\$(sudo cat /var/rudder/run/api-token)"
echo "  # GET pour lister les IDs des deux noeuds Windows"
echo "  curl -sk -H \"X-API-Token: \$TOKEN\" https://localhost/rudder/api/latest/nodes | python3 -m json.tool"
echo "  # DELETE chaque ID"
echo "  curl -sk -X DELETE -H \"X-API-Token: \$TOKEN\" https://localhost/rudder/api/latest/nodes/<id_iapet>"
echo "  curl -sk -X DELETE -H \"X-API-Token: \$TOKEN\" https://localhost/rudder/api/latest/nodes/<id_titan>"
echo ""
echo "=== Rollback termine ==="
echo "Snapshot d'avant rollback : $SNAP_DIR"
echo "Etat cible : serveur Community + 5 agents Linux (etat post-PROJET_RUDER_FULL)"

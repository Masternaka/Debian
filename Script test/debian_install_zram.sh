#!/bin/bash

# ==============================================================================
#         SCRIPT D'INSTALLATION ET DE CONFIGURATION DE ZRAM POUR DEBIAN
# ==============================================================================
#
# Ce script effectue les actions suivantes :
#   1. Met à jour la liste des paquets.
#   2. Installe le paquet zram-tools.
#   3. Crée un fichier de configuration pour zram.
#   4. Redémarre le service zram-tools pour appliquer les changements.
#
# À exécuter avec les privilèges root : sudo ./nom_du_script.sh
# ==============================================================================

# S'assurer que le script est exécuté en tant que root
if [ "$(id -u)" -ne 0 ]; then
  echo "Ce script doit être exécuté en tant que root. Utilisez 'sudo'." >&2
  exit 1
fi

# --- 1. Mise à jour et Installation ---

echo " Mise à jour de la liste des paquets..."
apt-get update

echo " Installation de zram-tools..."
apt-get install -y zram-tools

# --- 2. Configuration ---

echo " Configuration de zram..."

# Création du fichier de configuration pour zram-tools
# Vous pouvez ajuster les valeurs ci-dessous :
#   ALGO : lz4 est rapide, zstd est plus efficace mais peut consommer plus de CPU.
#   PERCENT : Le pourcentage de RAM à allouer à zram. 50% est une valeur sûre.
#
# Note : Pour les systèmes avec beaucoup de RAM (16Go+), 25% peut être suffisant.
# Pour les systèmes avec peu de RAM (4Go ou moins), 75% peut être plus bénéfique.
cat > /etc/default/zramswap << EOL
# /etc/default/zramswap
# Configuration for zram-tools

# Compression algorithm
# lz4 est généralement le meilleur compromis entre vitesse et ratio de compression.
# zstd offre une meilleure compression au détriment d'un peu plus de CPU.
ALGO=zstd

# Percentage of RAM to use for zram
# 50% est un bon point de départ pour la plupart des systèmes.
PERCENT=50

# Priorité du swap. Un nombre plus élevé est utilisé en premier.
# 100 est une priorité très élevée, assurant que zram soit utilisé avant le swap sur disque.
PRIORITY=100
EOL

# --- 3. Démarrage du service ---

echo " Redémarrage du service zramswap pour appliquer la configuration..."
systemctl restart zramswap.service

echo ""
echo " Installation et configuration de zram terminées avec succès !"
echo ""
echo "--- Vérification du statut ---"
# Affiche le statut du service
systemctl status zramswap.service --no-pager
echo ""
# Affiche un résumé de la mémoire, y compris le swap zram
swapon --show
echo ""
# Affiche les détails des périphériques zram créés
zramctl

exit 0

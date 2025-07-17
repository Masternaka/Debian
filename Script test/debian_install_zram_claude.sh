#!/bin/bash

# Script d'installation et configuration de zram pour Debian
# Auteur: Assistant Claude
# Version: 1.0

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérifier si le script est exécuté en tant que root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Ce script doit être exécuté en tant que root"
        log_info "Utilisez: sudo $0"
        exit 1
    fi
}

# Vérifier la distribution
check_debian() {
    if ! command -v apt-get &> /dev/null; then
        log_error "Ce script est conçu pour Debian/Ubuntu"
        exit 1
    fi
    
    log_info "Système détecté: $(lsb_release -d 2>/dev/null | cut -f2 || echo "Debian/Ubuntu")"
}

# Installer les paquets nécessaires
install_packages() {
    log_info "Installation des paquets nécessaires..."
    
    apt-get update
    apt-get install -y zram-tools util-linux
    
    log_success "Paquets installés avec succès"
}

# Configurer zram
configure_zram() {
    log_info "Configuration de zram..."
    
    # Créer le fichier de configuration
    cat > /etc/default/zramswap << EOF
# Configuration zram
# Taille en pourcentage de la RAM totale (par défaut: 50%)
PERCENT=50

# Taille en MB (si définie, remplace PERCENT)
# SIZE=1024

# Algorithme de compression (lzo, lz4, zstd)
ALGO=lz4

# Nombre de périphériques zram (par défaut: nombre de CPU)
# CORES=4

# Priorité du swap zram (plus élevée = plus prioritaire)
PRIORITY=100
EOF

    log_success "Configuration zram créée dans /etc/default/zramswap"
}

# Créer le service systemd
create_systemd_service() {
    log_info "Création du service systemd pour zram..."
    
    cat > /etc/systemd/system/zramswap.service << EOF
[Unit]
Description=Compressed swap in RAM using zram
After=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/zramswap-start
ExecStop=/usr/local/bin/zramswap-stop

[Install]
WantedBy=multi-user.target
EOF

    log_success "Service systemd créé"
}

# Créer les scripts de démarrage et arrêt
create_scripts() {
    log_info "Création des scripts de démarrage et d'arrêt..."
    
    # Script de démarrage
    cat > /usr/local/bin/zramswap-start << 'EOF'
#!/bin/bash

# Charger la configuration
source /etc/default/zramswap

# Valeurs par défaut
PERCENT=${PERCENT:-50}
ALGO=${ALGO:-lz4}
CORES=${CORES:-$(nproc)}
PRIORITY=${PRIORITY:-100}

# Calculer la taille si pas définie
if [ -z "$SIZE" ]; then
    TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
    SIZE=$((TOTAL_RAM * PERCENT / 100))
fi

# Charger le module zram
modprobe zram num_devices=$CORES

# Configurer chaque périphérique zram
for i in $(seq 0 $((CORES-1))); do
    DEVICE="/dev/zram$i"
    
    # Définir l'algorithme de compression
    echo $ALGO > /sys/block/zram$i/comp_algorithm
    
    # Définir la taille
    echo ${SIZE}M > /sys/block/zram$i/disksize
    
    # Créer le swap
    mkswap $DEVICE
    
    # Activer le swap avec priorité
    swapon -p $PRIORITY $DEVICE
done

echo "zram swap activé avec succès"
EOF

    # Script d'arrêt
    cat > /usr/local/bin/zramswap-stop << 'EOF'
#!/bin/bash

# Désactiver tous les swaps zram
for device in /dev/zram*; do
    if [ -b "$device" ]; then
        swapoff "$device" 2>/dev/null || true
    fi
done

# Réinitialiser les périphériques zram
for i in /sys/block/zram*/reset; do
    if [ -f "$i" ]; then
        echo 1 > "$i" 2>/dev/null || true
    fi
done

# Décharger le module zram
rmmod zram 2>/dev/null || true

echo "zram swap désactivé"
EOF

    # Rendre les scripts exécutables
    chmod +x /usr/local/bin/zramswap-start
    chmod +x /usr/local/bin/zramswap-stop
    
    log_success "Scripts créés et rendus exécutables"
}

# Activer et démarrer le service
enable_service() {
    log_info "Activation du service zramswap..."
    
    systemctl daemon-reload
    systemctl enable zramswap.service
    systemctl start zramswap.service
    
    log_success "Service zramswap activé et démarré"
}

# Vérifier l'installation
verify_installation() {
    log_info "Vérification de l'installation..."
    
    sleep 2
    
    # Vérifier si zram est actif
    if swapon --show | grep -q zram; then
        log_success "zram swap est actif !"
        echo
        echo "Statut du swap:"
        swapon --show
        echo
        echo "Utilisation mémoire:"
        free -h
        echo
        echo "Périphériques zram:"
        ls -la /dev/zram* 2>/dev/null || echo "Aucun périphérique zram trouvé"
    else
        log_error "zram swap n'est pas actif"
        return 1
    fi
}

# Créer un script de surveillance
create_monitoring_script() {
    log_info "Création d'un script de surveillance..."
    
    cat > /usr/local/bin/zram-status << 'EOF'
#!/bin/bash

echo "=== Statut zram ==="
echo

echo "Périphériques zram:"
for device in /dev/zram*; do
    if [ -b "$device" ]; then
        zram_num=$(basename "$device" | sed 's/zram//')
        echo "  $device:"
        echo "    Taille: $(cat /sys/block/zram$zram_num/disksize | numfmt --to=iec)"
        echo "    Utilisé: $(cat /sys/block/zram$zram_num/mem_used_total | numfmt --to=iec)"
        echo "    Compression: $(cat /sys/block/zram$zram_num/comp_algorithm | grep -o '\[.*\]' | tr -d '[]')"
        echo "    Ratio: $(cat /sys/block/zram$zram_num/compr_data_size):$(cat /sys/block/zram$zram_num/orig_data_size)"
        echo
    fi
done

echo "Swap actuel:"
swapon --show

echo
echo "Utilisation mémoire:"
free -h
EOF

    chmod +x /usr/local/bin/zram-status
    
    log_success "Script de surveillance créé: /usr/local/bin/zram-status"
}

# Fonction principale
main() {
    log_info "Démarrage de l'installation de zram pour Debian"
    echo
    
    check_root
    check_debian
    install_packages
    configure_zram
    create_systemd_service
    create_scripts
    enable_service
    verify_installation
    create_monitoring_script
    
    echo
    log_success "Installation de zram terminée avec succès !"
    echo
    echo "Commandes utiles:"
    echo "  - Vérifier le statut: systemctl status zramswap"
    echo "  - Surveiller zram: /usr/local/bin/zram-status"
    echo "  - Arrêter zram: systemctl stop zramswap"
    echo "  - Démarrer zram: systemctl start zramswap"
    echo "  - Configuration: /etc/default/zramswap"
    echo
    echo "Pour modifier la configuration, éditez /etc/default/zramswap puis:"
    echo "  systemctl restart zramswap"
}

# Exécuter le script principal
main "$@"
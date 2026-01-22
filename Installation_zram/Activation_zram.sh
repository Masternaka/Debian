#!/bin/bash

# ==============================================================================
# Script pour l'installation, configuration et désinstallation
# de ZRAM sur Debian/Ubuntu.
#
# La configuration est prédéfinie dans les variables ci-dessous.
#
# Utilisation:
# 1. Sauvegardez ce script sous un nom, par exemple: Activation_zram.sh
# 2. Rendez-le exécutable: chmod +x Activation_zram.sh
# 3. Exécutez-le: sudo ./Activation_zram.sh
# ==============================================================================

# --- Paramètres de Configuration (à modifier si besoin) ---

# Algorithme de compression. Options: zstd (recommandé), lz4, lzo-rle, lzo
ZRAM_COMP_ALGO="zstd"

# Taille du périphérique zram.
# 'ram / 2' (50% de la RAM totale) est une excellente valeur par défaut.
# Autres exemples : '4G', '8192M', 'ram / 4'.
ZRAM_SIZE="ram / 2"

# Priorité du swap. Une valeur élevée assure que ZRAM est utilisé en premier.
ZRAM_PRIORITY=100

# Type de système de fichiers. Pour un swap ZRAM, utiliser 'swap'.
ZRAM_FS_TYPE="swap"

# Variables de contrôle
PERFORM_TEST=false
VERBOSE=false
LOG_FILE="/var/log/zram-install.log"

# --- Variables de couleur ---
C_RESET='\e[0m'
C_RED='\e[0;31m'
C_GREEN='\e[0;32m'
C_YELLOW='\e[0;33m'
C_BLUE='\e[0;34m'
C_BOLD='\e[1m'
C_CYAN='\e[0;36m'

# --- Variables globales ---
CONFIG_FILE="/etc/systemd/zram-generator.conf.d/99-zram.conf"
BACKUP_DIR="/etc/systemd/zram-generator.conf.d/backups"
EXIT_SUCCESS=0
EXIT_ERROR=1
EXIT_INSUFFICIENT_PERMS=2
EXIT_MISSING_DEPENDENCIES=3

# --- Fonctions utilitaires ---

# Initialisation du fichier log
init_log_file() {
    # Créer le répertoire si nécessaire
    mkdir -p "$(dirname "$LOG_FILE")"

    # Vérifier les permissions d'écriture
    if ! touch "$LOG_FILE" 2>/dev/null; then
        LOG_FILE="/tmp/zram-install.log"
        print_message "WARN" "Impossible d'écrire dans /var/log, utilisation de /tmp à la place"
    fi

    # Initialiser le log
    log_message "--- Démarrage du script ZRAM v2.0 (Debian) ---"
}

# Fonction de logging
log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" >> "$LOG_FILE"
}

# Fonction d'affichage améliorée
print_message() {
    local type="$1"
    local message="$2"
    local timestamp=$(date '+%H:%M:%S')

    # Logging automatique
    log_message "[$type] $message"

    case "$type" in
        "INFO") echo -e "${C_BLUE}[$timestamp] [INFO]${C_RESET} ${message}" ;;
        "SUCCESS") echo -e "${C_GREEN}[$timestamp] [SUCCESS]${C_RESET} ${message}" ;;
        "WARN") echo -e "${C_YELLOW}[$timestamp] [WARN]${C_RESET} ${message}" ;;
        "ERROR") echo -e "${C_RED}[$timestamp] [ERROR]${C_RESET} ${message}" >&2 ;;
        "DEBUG")
            if [ "$VERBOSE" = true ]; then
                echo -e "${C_CYAN}[$timestamp] [DEBUG]${C_RESET} ${message}"
            fi
            ;;
        *) echo "[$timestamp] ${message}" ;;
    esac
}

# Fonction de nettoyage en cas d'erreur
cleanup_on_error() {
    print_message "ERROR" "Une erreur s'est produite. Nettoyage en cours..."

    # Arrêter le service ZRAM s'il est actif
    if systemctl is-active --quiet systemd-zram-setup@zram0.service 2>/dev/null; then
        print_message "INFO" "Arrêt du service ZRAM..."
        systemctl stop systemd-zram-setup@zram0.service 2>/dev/null
    fi

    # Recharger systemd
    systemctl daemon-reload 2>/dev/null

    print_message "ERROR" "Nettoyage terminé. Consultez les logs pour plus d'informations."
    exit 1
}

# Vérification des privilèges root
check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        print_message "ERROR" "Ce script doit être exécuté avec les privilèges root (sudo)."
        exit 1
    fi
}

# Détection de la distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID="$ID"
        DISTRO_VERSION="$VERSION_ID"
        print_message "INFO" "Distribution détectée: $NAME $VERSION"
    else
        print_message "ERROR" "Impossible de détecter la distribution"
        exit 1
    fi

    # Vérifier que c'est bien Debian ou Ubuntu
    case "$DISTRO_ID" in
        debian|ubuntu|linuxmint|pop)
            print_message "SUCCESS" "Distribution compatible détectée"
            ;;
        *)
            print_message "WARN" "Distribution non officiellement supportée: $DISTRO_ID"
            print_message "WARN" "Le script peut fonctionner mais n'a pas été testé sur cette distribution"
            ;;
    esac
}

# Validation des paramètres de configuration
validate_config() {
    print_message "DEBUG" "Validation de la configuration..."

    # Vérifier l'algorithme de compression
    case "$ZRAM_COMP_ALGO" in
        zstd|lz4|lzo-rle|lzo)
            print_message "DEBUG" "Algorithme de compression valide: $ZRAM_COMP_ALGO"
            ;;
        *)
            print_message "ERROR" "Algorithme de compression non supporté: $ZRAM_COMP_ALGO"
            print_message "INFO" "Algorithmes supportés: zstd, lz4, lzo-rle, lzo"
            exit 1
            ;;
    esac

    # Vérifier la taille ZRAM
    if [[ ! "$ZRAM_SIZE" =~ ^[0-9]+[GMK]?$ ]] && [[ "$ZRAM_SIZE" != "ram / 2" ]] && [[ "$ZRAM_SIZE" != "ram / 4" ]]; then
        print_message "ERROR" "Format de taille invalide: $ZRAM_SIZE"
        print_message "INFO" "Formats acceptés: '4G', '8192M', 'ram / 2', 'ram / 4'"
        exit 1
    fi

    # Vérifier la priorité
    if ! [[ "$ZRAM_PRIORITY" =~ ^[0-9]+$ ]] || [ "$ZRAM_PRIORITY" -lt 0 ] || [ "$ZRAM_PRIORITY" -gt 32767 ]; then
        print_message "ERROR" "Priorité invalide (0-32767): $ZRAM_PRIORITY"
        exit 1
    fi

    print_message "SUCCESS" "Configuration validée avec succès"
}

# Vérification des prérequis système
check_system_requirements() {
    print_message "INFO" "Vérification des prérequis système..."

    # Vérifier la version du kernel
    local kernel_version=$(uname -r | cut -d. -f1-2)
    local kernel_major=$(echo "$kernel_version" | cut -d. -f1)
    local kernel_minor=$(echo "$kernel_version" | cut -d. -f2)

    if [ "$kernel_major" -lt 3 ] || ([ "$kernel_major" -eq 3 ] && [ "$kernel_minor" -lt 15 ]); then
        print_message "WARN" "Version de kernel ancienne détectée: $kernel_version"
        print_message "WARN" "ZRAM nécessite au minimum le kernel 3.15"
    else
        print_message "SUCCESS" "Version de kernel compatible: $kernel_version"
    fi

    # Vérifier la RAM disponible
    local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    print_message "INFO" "Mémoire totale détectée: ${ram_gb}GB"

    if [ "$ram_gb" -lt 2 ]; then
        print_message "WARN" "RAM faible (${ram_gb}GB). ZRAM peut ne pas être très bénéfique (recommandé: 2GB+)."
    elif [ "$ram_gb" -lt 4 ]; then
        print_message "INFO" "RAM modérée (${ram_gb}GB). ZRAM sera bénéfique. Valeur recommandée: ram/4 ou ram/2."
    elif [ "$ram_gb" -lt 8 ]; then
        print_message "SUCCESS" "RAM suffisante (${ram_gb}GB). Configuration ZRAM optimale. Valeur recommandée: ram/2."
    else
        print_message "SUCCESS" "RAM importante (${ram_gb}GB). Configuration ZRAM très optimale. Valeur recommandée: ram/2 ou 4GB fixe."
    fi

    # Vérifier si systemd est disponible
    if ! command -v systemctl &>/dev/null; then
        print_message "ERROR" "systemd requis mais non trouvé"
        exit 1
    fi

    # Vérifier si apt est disponible
    if ! command -v apt &>/dev/null && ! command -v apt-get &>/dev/null; then
        print_message "ERROR" "apt/apt-get requis mais non trouvé"
        exit 1
    fi

    print_message "SUCCESS" "Tous les prérequis sont satisfaits"
}

# Sauvegarde des configurations existantes
backup_existing_config() {
    local config_file="$1"

    if [ -f "$config_file" ]; then
        mkdir -p "$BACKUP_DIR"
        local backup_file="${BACKUP_DIR}/99-zram.conf.backup.$(date +%Y%m%d_%H%M%S)"

        if cp "$config_file" "$backup_file"; then
            print_message "SUCCESS" "Configuration existante sauvegardée: $backup_file"
        else
            print_message "WARN" "Impossible de sauvegarder la configuration existante"
        fi
    fi
}

# Installation du paquet zram-generator
install_package() {
    print_message "INFO" "Vérification de l'installation de 'zram-tools' et 'systemd-zram-generator'..."

    # Mise à jour de la liste des paquets
    print_message "INFO" "Mise à jour de la liste des paquets..."
    if ! apt-get update -qq 2>&1 | tee -a "$LOG_FILE" | grep -q ""; then
        print_message "WARN" "Échec possible de la mise à jour (vérifiez les logs)"
    fi

    # Vérifier si zram-tools est installé
    local zram_tools_installed=false
    if dpkg -l | grep -q "^ii.*zram-tools"; then
        print_message "SUCCESS" "'zram-tools' est déjà installé."
        zram_tools_installed=true
    fi

    # Vérifier si systemd-zram-generator est disponible
    local use_zram_generator=false
    if apt-cache show systemd-zram-generator &>/dev/null; then
        use_zram_generator=true
        print_message "INFO" "Package 'systemd-zram-generator' disponible dans les dépôts"
        
        if dpkg -l | grep -q "^ii.*systemd-zram-generator"; then
            print_message "SUCCESS" "'systemd-zram-generator' est déjà installé."
            local version=$(dpkg -l | grep systemd-zram-generator | awk '{print $3}')
            print_message "INFO" "Version installée: $version"
        else
            print_message "INFO" "Installation de 'systemd-zram-generator'..."
            if DEBIAN_FRONTEND=noninteractive apt-get install -y systemd-zram-generator 2>&1 | tee -a "$LOG_FILE"; then
                print_message "SUCCESS" "'systemd-zram-generator' a été installé avec succès."
            else
                print_message "WARN" "Échec de l'installation de systemd-zram-generator, tentative avec zram-tools"
                use_zram_generator=false
            fi
        fi
    else
        print_message "INFO" "'systemd-zram-generator' non disponible dans les dépôts"
    fi

    # Fallback sur zram-tools si nécessaire
    if ! $use_zram_generator; then
        if ! $zram_tools_installed; then
            print_message "INFO" "Installation de 'zram-tools' (alternative)..."
            if DEBIAN_FRONTEND=noninteractive apt-get install -y zram-tools 2>&1 | tee -a "$LOG_FILE"; then
                print_message "SUCCESS" "'zram-tools' a été installé avec succès."
            else
                print_message "ERROR" "L'installation a échoué."
                exit 1
            fi
        fi
        
        # Configurer zram-tools
        configure_zram_tools
    fi
}

# Configuration alternative avec zram-tools
configure_zram_tools() {
    print_message "INFO" "Configuration de ZRAM via zram-tools..."
    
    local zram_config="/etc/default/zramswap"
    
    # Sauvegarder la config existante
    if [ -f "$zram_config" ]; then
        cp "$zram_config" "${zram_config}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Calculer la taille en fonction de la RAM
    local ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local zram_size_kb
    
    if [[ "$ZRAM_SIZE" == "ram / 2" ]]; then
        zram_size_kb=$((ram_kb / 2))
    elif [[ "$ZRAM_SIZE" == "ram / 4" ]]; then
        zram_size_kb=$((ram_kb / 4))
    elif [[ "$ZRAM_SIZE" =~ ^([0-9]+)G$ ]]; then
        zram_size_kb=$((${BASH_REMATCH[1]} * 1024 * 1024))
    elif [[ "$ZRAM_SIZE" =~ ^([0-9]+)M$ ]]; then
        zram_size_kb=$((${BASH_REMATCH[1]} * 1024))
    else
        print_message "WARN" "Format de taille non reconnu, utilisation de 50% de la RAM"
        zram_size_kb=$((ram_kb / 2))
    fi
    
    # Créer le fichier de configuration
    cat > "$zram_config" <<EOF
# Configuration ZRAM générée par Activation_zram.sh v2.0
# Date: $(date)

# Pourcentage de RAM à allouer (non utilisé si SIZE est défini)
PERCENT=50

# Taille fixe en kB (prioritaire sur PERCENT)
SIZE=$zram_size_kb

# Algorithme de compression
ALGO=$ZRAM_COMP_ALGO

# Priorité du swap
PRIORITY=$ZRAM_PRIORITY
EOF

    print_message "SUCCESS" "Configuration zram-tools créée: $zram_config"
}

# Configuration de ZRAM
configure_zram() {
    print_message "INFO" "Application de la configuration ZRAM..."
    print_message "INFO" "  - Algorithme : ${C_BOLD}${ZRAM_COMP_ALGO}${C_RESET}"
    print_message "INFO" "  - Taille       : ${C_BOLD}${ZRAM_SIZE}${C_RESET}"
    print_message "INFO" "  - Priorité     : ${C_BOLD}${ZRAM_PRIORITY}${C_RESET}"
    print_message "INFO" "  - Type FS      : ${C_BOLD}${ZRAM_FS_TYPE}${C_RESET}"

    # Sauvegarder la configuration existante
    backup_existing_config "$CONFIG_FILE"

    # Créer le répertoire de configuration
    mkdir -p "$(dirname "$CONFIG_FILE")"

    # Créer le fichier de configuration
    cat <<EOF > "$CONFIG_FILE"
# Fichier de configuration pour zram-generator
# Généré par le script Activation_zram.sh v2.0 (Debian)
# Date: $(date)
#
# Documentation:
#   compression-algorithm: Algorithme de compression (zstd, lz4, lzo-rle, lzo)
#   zram-size: Taille du device ZRAM (ex: 4G, ram/2, ram/4)
#   swap-priority: Priorité du swap (0-32767, plus élevé = utilisé en premier)
#   fs-type: Type de système de fichiers (swap)

[zram0]
compression-algorithm = ${ZRAM_COMP_ALGO}
zram-size = ${ZRAM_SIZE}
swap-priority = ${ZRAM_PRIORITY}
fs-type = ${ZRAM_FS_TYPE}
EOF

    if [ -f "$CONFIG_FILE" ]; then
        # Définir les permissions appropriées
        chmod 644 "$CONFIG_FILE"
        print_message "SUCCESS" "Fichier de configuration créé/mis à jour: $CONFIG_FILE"
    else
        print_message "ERROR" "Échec de la création du fichier de configuration"
        exit 1
    fi
}

# Activation de ZRAM
activate_zram() {
    print_message "INFO" "Rechargement de systemd et activation de ZRAM..."

    # Recharger systemd
    if systemctl daemon-reload; then
        print_message "SUCCESS" "systemd rechargé avec succès"
    else
        print_message "ERROR" "Échec du rechargement de systemd"
        exit 1
    fi

    # Vérifier quel service utiliser
    if systemctl list-unit-files | grep -q "systemd-zram-setup@"; then
        # Utiliser systemd-zram-generator
        print_message "INFO" "Utilisation de systemd-zram-generator..."
        
        if systemctl start systemd-zram-setup@zram0.service; then
            print_message "SUCCESS" "Service ZRAM démarré avec succès"
        else
            print_message "ERROR" "Échec du démarrage du service ZRAM"
            print_message "INFO" "Vérifiez les logs: journalctl -u systemd-zram-setup@zram0.service"
            exit 1
        fi

        if systemctl enable systemd-zram-setup@zram0.service; then
            print_message "SUCCESS" "Service ZRAM activé au démarrage"
        else
            print_message "WARN" "Impossible d'activer le service au démarrage"
        fi
    elif systemctl list-unit-files | grep -q "zramswap"; then
        # Utiliser zram-tools
        print_message "INFO" "Utilisation de zram-tools..."
        
        if systemctl start zramswap.service; then
            print_message "SUCCESS" "Service zramswap démarré avec succès"
        else
            print_message "ERROR" "Échec du démarrage du service zramswap"
            exit 1
        fi

        if systemctl enable zramswap.service; then
            print_message "SUCCESS" "Service zramswap activé au démarrage"
        else
            print_message "WARN" "Impossible d'activer le service au démarrage"
        fi
    else
        print_message "ERROR" "Aucun service ZRAM trouvé"
        exit 1
    fi

    # Attendre un peu pour que le service s'initialise
    sleep 2
}

# Test de performance ZRAM
test_zram_performance() {
    print_message "INFO" "Test de performance ZRAM..."

    # Vérifier que ZRAM est actif
    if ! [ -b "/dev/zram0" ]; then
        print_message "WARN" "ZRAM non actif, impossible de tester les performances"
        return 1
    fi

    # Test d'écriture simple
    local test_file="/tmp/zram_test_$$"
    local test_size="100M"

    print_message "INFO" "Test d'écriture de $test_size..."

    if dd if=/dev/zero of="$test_file" bs=1M count=100 2>/dev/null; then
        print_message "SUCCESS" "Test d'écriture réussi"

        # Test de lecture
        print_message "INFO" "Test de lecture..."
        if dd if="$test_file" of=/dev/null bs=1M 2>/dev/null; then
            print_message "SUCCESS" "Test de lecture réussi"
        else
            print_message "WARN" "Test de lecture échoué"
        fi

        # Nettoyage
        rm -f "$test_file"
    else
        print_message "WARN" "Test d'écriture échoué"
    fi

    print_message "SUCCESS" "Tests de performance terminés"
}

# Vérification complète du statut ZRAM
verify_zram() {
    print_message "INFO" "Vérification complète du statut ZRAM..."

    # Vérifier le service (essayer les deux types)
    local service_active=false
    if systemctl is-active --quiet systemd-zram-setup@zram0.service 2>/dev/null; then
        print_message "SUCCESS" "Service systemd-zram-setup actif"
        service_active=true
    elif systemctl is-active --quiet zramswap.service 2>/dev/null; then
        print_message "SUCCESS" "Service zramswap actif"
        service_active=true
    fi

    if ! $service_active; then
        print_message "ERROR" "Aucun service ZRAM actif"
        return 1
    fi

    # Vérifier le périphérique
    if [ -b "/dev/zram0" ]; then
        print_message "SUCCESS" "Périphérique /dev/zram0 détecté"
    else
        print_message "ERROR" "Périphérique /dev/zram0 non trouvé"
        return 1
    fi

    # Afficher les statistiques détaillées
    echo -e "\n${C_YELLOW}--- Statistiques ZRAM ---${C_RESET}"
    if command -v zramctl &>/dev/null; then
        zramctl
    else
        cat /proc/swaps | grep zram
    fi

    echo -e "\n${C_YELLOW}--- Swap actif ---${C_RESET}"
    swapon --show

    # Vérifier l'utilisation
    if command -v zramctl &>/dev/null; then
        local zram_usage=$(zramctl | awk 'NR>1 {print $4}' | head -1)
        if [ -n "$zram_usage" ] && [ "$zram_usage" != "0" ]; then
            print_message "SUCCESS" "ZRAM utilisé: $zram_usage"
        else
            print_message "INFO" "ZRAM configuré mais pas encore utilisé"
        fi
    fi

    # Afficher les informations de compression
    echo -e "\n${C_YELLOW}--- Informations de compression ---${C_RESET}"
    if [ -f "/sys/block/zram0/comp_algorithm" ]; then
        echo "Algorithme actuel: $(cat /sys/block/zram0/comp_algorithm)"
    fi

    if [ -f "/sys/block/zram0/compr_data_size" ]; then
        echo "Données compressées: $(cat /sys/block/zram0/compr_data_size) bytes"
    fi

    if [ -f "/sys/block/zram0/orig_data_size" ]; then
        echo "Données originales: $(cat /sys/block/zram0/orig_data_size) bytes"
    fi

    print_message "SUCCESS" "Vérification ZRAM terminée"
}

# Désinstallation de ZRAM
uninstall_zram() {
    local full_uninstall=false
    if [[ "$1" == "--purge" ]]; then
        full_uninstall=true
    fi

    print_message "INFO" "Désinstallation de ZRAM..."

    # Arrêter les services ZRAM
    print_message "INFO" "Arrêt des services ZRAM..."
    
    if systemctl is-active --quiet systemd-zram-setup@zram0.service 2>/dev/null; then
        if systemctl stop systemd-zram-setup@zram0.service; then
            print_message "SUCCESS" "Service systemd-zram-setup arrêté"
        fi
        systemctl disable systemd-zram-setup@zram0.service 2>/dev/null
    fi
    
    if systemctl is-active --quiet zramswap.service 2>/dev/null; then
        if systemctl stop zramswap.service; then
            print_message "SUCCESS" "Service zramswap arrêté"
        fi
        systemctl disable zramswap.service 2>/dev/null
    fi

    # Supprimer le fichier de configuration
    if [ -f "$CONFIG_FILE" ]; then
        print_message "INFO" "Suppression du fichier de configuration..."
        if rm -f "$CONFIG_FILE"; then
            print_message "SUCCESS" "Fichier de configuration supprimé"
        fi
    fi
    
    if [ -f "/etc/default/zramswap" ]; then
        print_message "INFO" "Suppression de la configuration zram-tools..."
        rm -f "/etc/default/zramswap"
    fi

    # Recharger systemd
    systemctl daemon-reload
    print_message "SUCCESS" "ZRAM a été désactivé"

    # Désinstaller les paquets si demandé
    if $full_uninstall; then
        print_message "INFO" "Désinstallation des paquets ZRAM..."
        
        if dpkg -l | grep -q "^ii.*systemd-zram-generator"; then
            if apt-get remove --purge -y systemd-zram-generator 2>&1 | tee -a "$LOG_FILE"; then
                print_message "SUCCESS" "Paquet 'systemd-zram-generator' désinstallé"
            fi
        fi
        
        if dpkg -l | grep -q "^ii.*zram-tools"; then
            if apt-get remove --purge -y zram-tools 2>&1 | tee -a "$LOG_FILE"; then
                print_message "SUCCESS" "Paquet 'zram-tools' désinstallé"
            fi
        fi
        
        # Nettoyage
        apt-get autoremove -y 2>&1 | tee -a "$LOG_FILE"
    else
        print_message "INFO" "Les paquets ZRAM sont conservés. Utilisez 'uninstall --purge' pour les supprimer."
    fi

    print_message "SUCCESS" "Désinstallation terminée"
}

# Fonction de rollback
rollback_installation() {
    print_message "INFO" "Rollback de l'installation..."

    # Arrêter les services
    systemctl stop systemd-zram-setup@zram0.service 2>/dev/null
    systemctl stop zramswap.service 2>/dev/null

    # Supprimer les configurations
    rm -f "$CONFIG_FILE"
    rm -f "/etc/default/zramswap"

    # Recharger systemd
    systemctl daemon-reload

    print_message "SUCCESS" "Rollback terminé"
}

# Affichage des informations de configuration
show_config_info() {
    echo -e "\n${C_BOLD}Configuration ZRAM:${C_RESET}"
    echo "  Algorithme: $ZRAM_COMP_ALGO"
    echo "  Taille: $ZRAM_SIZE"
    echo "  Priorité: $ZRAM_PRIORITY"
    echo "  Type FS: $ZRAM_FS_TYPE"
    echo "  Fichier de config: $CONFIG_FILE"
    echo "  Log: $LOG_FILE"
    echo
}

# Parsing des arguments en ligne de commande
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --size)
                ZRAM_SIZE="$2"
                shift 2
                ;;
            --algorithm)
                ZRAM_COMP_ALGO="$2"
                shift 2
                ;;
            --priority)
                ZRAM_PRIORITY="$2"
                shift 2
                ;;
            --test)
                PERFORM_TEST=true
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                COMMAND="$1"
                shift
                ;;
        esac
    done
}

# Affichage de l'aide
show_usage() {
    echo "Usage: sudo $0 [COMMAND] [OPTIONS]"
    echo
    echo "Commandes:"
    echo "  install          (défaut) Installe et configure ZRAM avec les paramètres du script."
    echo "  uninstall        Désactive ZRAM et supprime sa configuration."
    echo "  uninstall --purge  Fait la même chose que 'uninstall' et supprime aussi les paquets."
    echo "  verify           Vérifie le statut actuel de ZRAM."
    echo "  test             Teste les performances de ZRAM."
    echo "  rollback         Annule l'installation et restaure l'état précédent."
    echo
    echo "
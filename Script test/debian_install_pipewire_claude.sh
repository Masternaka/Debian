#!/bin/bash

# Script interactif d'installation de PipeWire sur Debian 12
# Auteur : Assistant
# Date : $(date)

set -e  # Arrêter le script en cas d'erreur

# Variables
PAQUETS_PIPEWIRE="pipewire-audio"
PAQUETS_OUTILS="pavucontrol pulseaudio-utils alsa-utils"
SERVICES_PIPEWIRE=(pipewire.service pipewire-pulse.service wireplumber.service)

# Fonctions
commande_existe() {
    command -v "$1" >/dev/null 2>&1
}

verifier_commandes() {
    local commandes=(sudo apt systemctl grep)
    for cmd in "${commandes[@]}"; do
        if ! commande_existe "$cmd"; then
            echo "Erreur : la commande '$cmd' est requise mais n'est pas installée."
            exit 1
        fi
    done
}

afficher_resume() {
    echo
    echo "=== Résumé de l'installation ==="
    echo "- PipeWire et outils installés : $PAQUETS_PIPEWIRE $PAQUETS_OUTILS"
    echo "- Services activés et démarrés : ${SERVICES_PIPEWIRE[*]}"
    echo
    echo "Notes importantes :"
    echo "- Il est recommandé de redémarrer votre session ou votre système."
    echo "- Utilisez 'pavucontrol' pour gérer les paramètres audio."
    echo "- Pour voir les périphériques : pactl list short sinks"
    echo
    echo "Commandes utiles :"
    echo "- État des services : systemctl --user status pipewire pipewire-pulse wireplumber"
    echo "- Redémarrer PipeWire : systemctl --user restart pipewire"
    echo "- Logs : journalctl --user -u pipewire"
    echo
    echo "Installation de PipeWire terminée avec succès !"
    echo "Redémarrez votre session pour une utilisation optimale."
}

verifier_root() {
    if [[ $EUID -eq 0 ]]; then
        echo "Ce script ne doit pas être exécuté en tant que root."
        echo "Utilisez un utilisateur normal avec sudo."
        exit 1
    fi
}

verifier_debian() {
    if commande_existe lsb_release; then
        VERSION=$(lsb_release -cs)
    else
        VERSION=$(grep -oE '^[a-zA-Z]+' /etc/debian_version 2>/dev/null || echo "")
    fi
    if [[ "$VERSION" != "bookworm" ]]; then
        echo "Avertissement : Ce script est conçu pour Debian 12 (Bookworm)"
        read -p "Continuer quand même ? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

mise_a_jour_paquets() {
    echo "1. Mise à jour des paquets..."
    sudo apt update
}

installer_pipewire() {
    echo "2. Installation du meta-paquet PipeWire..."
    sudo apt install -y $PAQUETS_PIPEWIRE
}

installer_outils() {
    echo "3. Installation des outils de contrôle audio..."
    sudo apt install -y $PAQUETS_OUTILS
}

arreter_pulseaudio() {
    echo "4. Arrêt des services PulseAudio existants..."
    systemctl --user stop pulseaudio.service pulseaudio.socket 2>/dev/null || true
    systemctl --user disable pulseaudio.service pulseaudio.socket 2>/dev/null || true
}

activer_services_pipewire() {
    echo "5. Activation des services PipeWire..."
    for service in "${SERVICES_PIPEWIRE[@]}"; do
        systemctl --user enable "$service"
    done
}

demarrer_services_pipewire() {
    echo "6. Démarrage des services PipeWire..."
    for service in "${SERVICES_PIPEWIRE[@]}"; do
        systemctl --user start "$service"
    done
}

verifier_services() {
    echo "7. Vérification de l'installation..."
    sleep 2
    for service in "${SERVICES_PIPEWIRE[@]}"; do
        if systemctl --user is-active --quiet "$service"; then
            echo "✓ $service est actif"
        else
            echo "✗ Erreur : $service n'est pas actif"
        fi
    done
}

# Script principal
clear
printf "\n=== Installation interactive de PipeWire sur Debian 12 ===\n\n"

verifier_commandes
verifier_root
verifier_debian
mise_a_jour_paquets
installer_pipewire
installer_outils
arreter_pulseaudio
activer_services_pipewire
demarrer_services_pipewire
verifier_services
afficher_resume
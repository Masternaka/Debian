#!/bin/bash

# Script d'installation et configuration de Samba sur Linux Mint
# À exécuter avec sudo

set -e

echo "=========================================="
echo "Installation et Configuration de Samba"
echo "=========================================="
echo

# Vérifier si le script est exécuté en tant que root
if [ "$EUID" -ne 0 ]; then
    echo "Erreur: Ce script doit être exécuté avec sudo"
    exit 1
fi

# Mise à jour des paquets
echo "Mise à jour de la liste des paquets..."
apt update

# Installation de Samba
echo "Installation de Samba..."
apt install -y samba samba-common-bin

# Sauvegarde du fichier de configuration original
echo "Sauvegarde de la configuration originale..."
if [ ! -f /etc/samba/smb.conf.backup ]; then
    cp /etc/samba/smb.conf /etc/samba/smb.conf.backup
    echo "Configuration originale sauvegardée dans /etc/samba/smb.conf.backup"
fi

# Demander si l'utilisateur veut utiliser son propre fichier de configuration
echo
echo "=========================================="
echo "Configuration de Samba"
echo "=========================================="
read -p "Voulez-vous utiliser votre propre fichier smb.conf ? (o/N): " USE_CUSTOM_CONFIG

if [[ $USE_CUSTOM_CONFIG =~ ^[Oo]$ ]]; then
    read -p "Chemin complet vers votre fichier smb.conf: " CUSTOM_CONFIG_PATH

    if [ -f "$CUSTOM_CONFIG_PATH" ]; then
        echo "Copie de votre configuration personnalisée..."
        cp "$CUSTOM_CONFIG_PATH" /etc/samba/smb.conf
        echo "Configuration personnalisée installée avec succès!"

        # Vérifier la validité de la configuration
        echo "Vérification de la configuration..."
        if testparm -s /etc/samba/smb.conf > /dev/null 2>&1; then
            echo "✓ Configuration valide"
        else
            echo "⚠ Attention: Des erreurs ont été détectées dans la configuration"
            read -p "Voulez-vous voir les détails ? (o/N): " SHOW_ERRORS
            if [[ $SHOW_ERRORS =~ ^[Oo]$ ]]; then
                testparm -s /etc/samba/smb.conf
            fi
        fi

        # Demander si l'utilisateur veut configurer des utilisateurs Samba
        echo
        read -p "Voulez-vous ajouter/configurer des utilisateurs Samba maintenant ? (o/N): " CONFIG_USERS
        if [[ $CONFIG_USERS =~ ^[Oo]$ ]]; then
            while true; do
                read -p "Nom d'utilisateur (ou 'q' pour terminer): " SAMBA_USER
                if [[ $SAMBA_USER == "q" ]]; then
                    break
                fi

                # Vérifier si l'utilisateur système existe
                if id "$SAMBA_USER" &>/dev/null; then
                    echo "Configuration du mot de passe Samba pour $SAMBA_USER:"
                    smbpasswd -a "$SAMBA_USER"
                else
                    echo "⚠ L'utilisateur système $SAMBA_USER n'existe pas."
                    read -p "Voulez-vous créer cet utilisateur ? (o/N): " CREATE_USER
                    if [[ $CREATE_USER =~ ^[Oo]$ ]]; then
                        useradd -m "$SAMBA_USER"
                        echo "Définir le mot de passe système pour $SAMBA_USER:"
                        passwd "$SAMBA_USER"
                        echo "Définir le mot de passe Samba pour $SAMBA_USER:"
                        smbpasswd -a "$SAMBA_USER"
                    fi
                fi
            done
        fi

        # Passer directement au redémarrage des services
        SKIP_INTERACTIVE_CONFIG=true
    else
        echo "Erreur: Le fichier $CUSTOM_CONFIG_PATH n'existe pas."
        echo "Passage à la configuration interactive..."
        SKIP_INTERACTIVE_CONFIG=false
    fi
else
    SKIP_INTERACTIVE_CONFIG=false
fi

# Configuration interactive si pas de fichier personnalisé
if [ "$SKIP_INTERACTIVE_CONFIG" = false ]; then
    # Demander le nom du partage
    # Demander le nom du partage
    read -p "Nom du partage (par défaut: Partage): " SHARE_NAME
    SHARE_NAME=${SHARE_NAME:-Partage}

    # Demander le chemin du dossier à partager
    read -p "Chemin du dossier à partager (par défaut: /home/$SUDO_USER/Partage): " SHARE_PATH
    SHARE_PATH=${SHARE_PATH:-/home/$SUDO_USER/Partage}

    # Créer le dossier s'il n'existe pas
    if [ ! -d "$SHARE_PATH" ]; then
        echo "Création du dossier $SHARE_PATH..."
        mkdir -p "$SHARE_PATH"
        chown -R $SUDO_USER:$SUDO_USER "$SHARE_PATH"
        chmod 775 "$SHARE_PATH"
    fi

    # Demander si le partage doit être accessible en lecture seule
    read -p "Accès en lecture seule ? (o/N): " READ_ONLY
    if [[ $READ_ONLY =~ ^[Oo]$ ]]; then
        READ_ONLY_VALUE="yes"
    else
        READ_ONLY_VALUE="no"
    fi

    # Demander si le partage doit être public
    read -p "Accès public (sans mot de passe) ? (o/N): " PUBLIC_ACCESS
    if [[ $PUBLIC_ACCESS =~ ^[Oo]$ ]]; then
        PUBLIC_VALUE="yes"
        GUEST_OK="yes"
    else
        PUBLIC_VALUE="no"
        GUEST_OK="no"
    fi

    # Ajouter la configuration du partage
    echo
    echo "Ajout de la configuration du partage..."
    cat >> /etc/samba/smb.conf << EOF

[$SHARE_NAME]
   comment = Partage Samba sur Linux Mint
   path = $SHARE_PATH
   browseable = yes
   read only = $READ_ONLY_VALUE
   guest ok = $GUEST_OK
   create mask = 0775
   directory mask = 0775
   valid users = $SUDO_USER
EOF

    # Si accès non public, configurer l'utilisateur Samba
    if [[ ! $PUBLIC_ACCESS =~ ^[Oo]$ ]]; then
        echo
        echo "Configuration de l'utilisateur Samba..."
        echo "Veuillez entrer un mot de passe pour l'utilisateur $SUDO_USER:"
        smbpasswd -a $SUDO_USER
    fi
fi

# Redémarrer le service Samba
echo
echo "Redémarrage du service Samba..."
systemctl restart smbd
systemctl restart nmbd

# Activer Samba au démarrage
systemctl enable smbd
systemctl enable nmbd

# Configurer le pare-feu si ufw est actif
if systemctl is-active --quiet ufw; then
    echo
    echo "Configuration du pare-feu..."
    ufw allow samba
fi

# Afficher les informations de connexion
echo
echo "=========================================="
echo "Installation terminée avec succès!"
echo "=========================================="
echo

if [ "$SKIP_INTERACTIVE_CONFIG" = true ]; then
    echo "Configuration personnalisée appliquée depuis: $CUSTOM_CONFIG_PATH"
    echo
    echo "Partages configurés:"
    testparm -s /etc/samba/smb.conf 2>/dev/null | grep -A 1 "^\[" | grep -v "^--$"
else
    echo "Informations de connexion:"
    echo "- Nom du partage: $SHARE_NAME"
    echo "- Chemin: $SHARE_PATH"
    echo "- Accès lecture seule: $READ_ONLY_VALUE"
    echo "- Accès public: $PUBLIC_VALUE"
    echo
    echo "Pour accéder au partage depuis:"
    echo "- Windows: \\\\$(hostname -I | awk '{print $1}')\\$SHARE_NAME"
    echo "- Linux: smb://$(hostname -I | awk '{print $1}')/$SHARE_NAME"
    echo "- macOS: smb://$(hostname -I | awk '{print $1}')/$SHARE_NAME"
    echo
    echo "Utilisateur: $SUDO_USER"
    if [[ ! $PUBLIC_ACCESS =~ ^[Oo]$ ]]; then
        echo "Mot de passe: celui que vous venez de définir"
    fi
fi

echo
echo "Pour voir l'état de Samba: sudo systemctl status smbd"
echo "Pour modifier la config: sudo nano /etc/samba/smb.conf"
echo "=========================================="

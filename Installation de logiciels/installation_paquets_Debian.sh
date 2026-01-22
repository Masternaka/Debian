#!/bin/bash
set -e

# Vérifier si l'utilisateur est root
if [ "$EUID" -ne 0 ]; then 
  echo "Veuillez exécuter ce script en tant que root (sudo)."
  exit 1
fi

# Mettre à jour les dépôts et les paquets existants
echo "Mise à jour des dépôts et des paquets existants..."
apt update && apt upgrade -y

# Liste des paquets à installer via apt
apt_packages=(
  micro
  git
  curl
  wget
  btop
  fastfetch
  kitty
  lshw
  fwupd
  p7zip-full
  meld
)

# Installation des paquets avec apt
echo "Installation des paquets via apt..."
for package in "${apt_packages[@]}"; do
  if dpkg -s "$package" &> /dev/null; then
    echo "$package est déjà installé."
  else
    echo "Installation de $package..."
    if apt install -y "$package"; then
      echo "$package installé avec succès."
    else
      echo "Erreur lors de l'installation de $package."
      exit 1
    fi
  fi
done

echo "Nettoyage des paquets inutiles..."
apt autoremove -y

echo "Installation terminée !"

#!/bin/bash

# Vérifier si l'utilisateur est root
if [ "$EUID" -ne 0 ]
then 
  echo "Veuillez exécuter ce script en tant que root (sudo)."
  exit
fi

# Mettre à jour les dépôts et les paquets existants
echo "Mise à jour des dépôts et des paquets existants..."
apt update && apt upgrade -y

# Liste des paquets à installer via apt
apt_packages=(
  vim
  git
  curl
  htop
  firefox-esr
  build-essential
  zsh
  neofetch
  terminator
  tmux
)

# Installation des paquets avec apt
echo "Installation des paquets via apt..."
for package in "${apt_packages[@]}"
do
  if dpkg -l | grep -q $package
  then
    echo "$package est déjà installé."
  else
    apt install -y $package
  fi
done

echo "Installation terminée!"

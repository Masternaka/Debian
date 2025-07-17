#!/bin/bash

# Ce script installe PipeWire sur Debian 12 et le configure comme système audio par défaut.

echo "Mise à jour des listes de paquets..."
sudo apt update

echo "Installation du paquet pipewire-audio et des dépendances nécessaires..."
# Le paquet pipewire-audio tire généralement les dépendances nécessaires comme pipewire et wireplumber.
# wireplumber est le gestionnaire de sessions recommandé pour PipeWire.
sudo apt install -y pipewire-audio

echo "Vérification du statut des services PipeWire..."
# Les services PipeWire sont généralement activés par défaut après l'installation.
# Nous vérifions ici si pipewire et wireplumber sont bien actifs.
systemctl --user status pipewire.service
systemctl --user status pipewire-pulse.service
systemctl --user status wireplumber.service

echo "Activation des services PipeWire pour l'utilisateur si ce n'est pas déjà fait..."
# Assurez-vous que les services sont activés pour l'utilisateur actuel
systemctl --user enable pipewire.service
systemctl --user enable pipewire-pulse.service
systemctl --user enable wireplumber.service

echo "Redémarrage des services PipeWire pour s'assurer qu'ils sont actifs..."
systemctl --user restart pipewire.service
systemctl --user restart pipewire-pulse.service
systemctl --user restart wireplumber.service

echo "Vérification que PipeWire est le serveur audio par défaut..."
# Cela devrait afficher "PipeWire" ou des informations pertinentes si tout est configuré correctement.
pactl info | grep "Server Name"

echo "Installation de pavucontrol pour une gestion graphique du volume (facultatif)..."
sudo apt install -y pavucontrol

echo ""
echo "Installation de PipeWire terminée."
echo "Il est recommandé de redémarrer votre session utilisateur ou l'ordinateur pour que tous les changements prennent effet."
echo "Après le redémarrage, vous pouvez vérifier que PipeWire fonctionne en exécutant 'pactl info' et en cherchant 'Server Name: PipeWire'."
echo "Vous pouvez également utiliser 'pavucontrol' pour gérer vos périphériques audio."
# Explications :
Mise à jour des paquets :

apt update && apt upgrade -y : met à jour les informations des paquets et met à jour tous les paquets installés.
Installation des paquets via apt :

La liste des paquets apt_packages contient uniquement des logiciels disponibles dans les dépôts Debian officiels. Par exemple :
vim pour l'édition de texte.
git pour le contrôle de version.
curl pour les transferts de données via la ligne de commande.
htop pour la surveillance des ressources système.
firefox-esr pour une version stable et sécurisée de Firefox.
build-essential pour les outils de développement.
zsh pour un shell interactif plus puissant.
neofetch pour afficher des informations système dans le terminal.
terminator pour un terminal avec plusieurs panneaux.
tmux pour la gestion de fenêtres de terminal.
Installation conditionnelle :

Le script vérifie si chaque paquet est déjà installé avec dpkg -l | grep -q $package. Si le paquet est déjà présent, il passe au suivant.
Instructions :
Crée un fichier avec le script ci-dessus, par exemple :

nano install_packages_debian.sh
Rends le fichier exécutable :

chmod +x install_packages_debian.sh
Exécute le script avec les droits root :

sudo ./install_packages_debian.sh

Cela te permettra d'installer rapidement des paquets natifs Debian sans dépendances externes.

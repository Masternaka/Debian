: <<'README'
###############################################################################
# installation_zsh_plugins_debian_antidote.sh
#
# Script d'installation automatisée pour un environnement Zsh moderne sur Debian
#
# Ce script installe et configure :
#   - Zsh (shell)
#   - Antidote (gestionnaire de plugins Zsh)
#   - Oh My Posh (prompt moderne, thème Catppuccin Mocha)
#   - JetBrains Mono (police recommandée pour le terminal)
#   - zoxide (cd intelligent)
#   - fzf (fuzzy finder)
#   - Plugins Zsh populaires :
#       * zsh-autosuggestions
#       * zsh-syntax-highlighting
#       * zsh-completions
#       * zsh-history-substring-search
#
# Fonctionnement :
#   - Installe les dépendances nécessaires via apt et curl
#   - Installe Antidote pour gérer les plugins Zsh
#   - Installe Oh My Posh et télécharge le thème Catppuccin Mocha
#   - Installe JetBrains Mono pour une meilleure lisibilité du terminal
#   - Configure le fichier ~/.zshrc pour initialiser Antidote, Oh My Posh, zoxide, fzf et les plugins
#   - Change le shell par défaut vers Zsh si besoin
#
# Prérequis :
#   - Système Debian ou dérivé (testé sur Debian 12+)
#   - Accès sudo pour installer les paquets
#
# Utilisation :
#   1. Rendez le script exécutable : chmod +x installation_zsh_plugins_debian_antidote.sh
#   2. Lancez-le : ./installation_zsh_plugins_debian_antidote.sh
#   3. Déconnectez-vous/reconnectez-vous pour activer Zsh si besoin
#
# Après installation :
#   - Le prompt utilisera le thème Catppuccin Mocha d’Oh My Posh
#   - Les plugins Zsh seront gérés par Antidote
#   - zoxide et fzf seront disponibles
#
# Pour toute personnalisation, modifiez ~/.zsh_plugins.txt ou ~/.zshrc
###############################################################################
README

#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Vérifier si on est sur Debian
if ! grep -q "Debian" /etc/os-release 2>/dev/null; then
    warn "Ce script est conçu pour Debian. Continuez à vos risques et périls."
fi

info "Mise à jour des paquets système..."
sudo apt update

info "Installation de zsh, git, curl, unzip, fzf, zoxide..."
sudo apt install -y zsh git curl unzip fzf zoxide

# Installer JetBrains Mono
info "Installation de la police JetBrains Mono..."
FONTS_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONTS_DIR"
if fc-list | grep -q "JetBrains Mono"; then
    warn "JetBrains Mono déjà installée"
else
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    JETBRAINS_VERSION="2.304"
    curl -L -o jetbrains-mono.zip "https://github.com/JetBrains/JetBrainsMono/releases/download/v${JETBRAINS_VERSION}/JetBrainsMono-${JETBRAINS_VERSION}.zip"
    unzip -q jetbrains-mono.zip -d jetbrains-mono
    find jetbrains-mono -name "*.ttf" -exec cp {} "$FONTS_DIR" \;
    fc-cache -f -v
    cd "$HOME"
    rm -rf "$TEMP_DIR"
    info "JetBrains Mono installée"
fi

# Installer Antidote
info "Installation d'Antidote..."
ANTIDOTE_DIR="${ZDOTDIR:-$HOME}/.antidote"
if [ -d "$ANTIDOTE_DIR" ]; then
    warn "Antidote déjà installé"
else
    git clone --depth=1 https://github.com/mattmc3/antidote.git "$ANTIDOTE_DIR"
    info "Antidote installé"
fi

# Installer Oh My Posh
info "Installation de Oh My Posh..."
if ! command -v oh-my-posh &> /dev/null; then
    curl -s https://ohmyposh.dev/install.sh | bash -s -- -d ~/.local/bin
    info "Oh My Posh installé"
else
    info "Oh My Posh déjà installé"
fi

# Télécharger le thème Catppuccin Mocha pour Oh My Posh
THEME_DIR="$HOME/.poshthemes"
mkdir -p "$THEME_DIR"
if [ ! -f "$THEME_DIR/catppuccin_mocha.omp.json" ]; then
    curl -o "$THEME_DIR/catppuccin_mocha.omp.json" https://raw.githubusercontent.com/catppuccin/oh-my-posh/main/themes/catppuccin_mocha.omp.json
    info "Thème Catppuccin Mocha téléchargé"
fi

# Préparer la liste des plugins pour Antidote
PLUGINS_FILE="$HOME/.zsh_plugins.txt"
cat > "$PLUGINS_FILE" <<EOF
zsh-users/zsh-autosuggestions
zsh-users/zsh-syntax-highlighting
zsh-users/zsh-completions
zsh-users/zsh-history-substring-search
EOF

# Sauvegarde de l'ancien .zshrc
if [ -f "$HOME/.zshrc" ]; then
    cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
    info "Sauvegarde de .zshrc effectuée"
fi

# Générer un nouveau .zshrc minimaliste pour Antidote + Oh My Posh + plugins + zoxide + fzf
cat > "$HOME/.zshrc" <<'EOF'
# Initialisation d'Antidote
source "$HOME/.antidote/antidote.zsh"
antidote bundle <"$HOME/.zsh_plugins.txt" > "$HOME/.zsh_plugins.zsh"
source "$HOME/.zsh_plugins.zsh"

# Initialisation de Oh My Posh avec le thème Catppuccin Mocha
eval "$(oh-my-posh init zsh --config ~/.poshthemes/catppuccin_mocha.omp.json)"

# zoxide
eval "$(zoxide init zsh)"

# fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Configuration pour zsh-history-substring-search
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down
EOF

info "Configuration du .zshrc terminée"

# Changer le shell par défaut vers zsh
info "Changement du shell par défaut vers zsh..."
if [ "$SHELL" != "$(which zsh)" ]; then
    chsh -s $(which zsh)
    info "Shell par défaut changé vers zsh"
    warn "Vous devrez vous déconnecter et reconnecter pour que le changement prenne effet"
else
    info "zsh est déjà votre shell par défaut"
fi

info "Installation terminée !"

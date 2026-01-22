#!/bin/bash

# Script d'installation de zsh, oh-my-zsh, powerlevel10k, JetBrains Mono, zoxide, fzf et plugins
# Pour Ubuntu 24.04

set -e  # Arrêter le script en cas d'erreur

echo "=========================================="
echo "Installation de zsh et des outils associés"
echo "=========================================="

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérifier si on est sur Ubuntu
if ! grep -q "Ubuntu" /etc/os-release 2>/dev/null; then
    warn "Ce script est conçu pour Ubuntu. Continuez à vos risques et périls."
fi

# Mettre à jour les paquets
info "Mise à jour des paquets système..."
sudo apt update

# Installer zsh
info "Installation de zsh..."
if command -v zsh &> /dev/null; then
    warn "zsh est déjà installé"
else
    sudo apt install -y zsh
    info "zsh installé avec succès"
fi

# Vérifier la version de zsh
ZSH_VERSION=$(zsh --version | awk '{print $2}')
info "Version de zsh installée: $ZSH_VERSION"

# Installer git si nécessaire
info "Vérification de git..."
if ! command -v git &> /dev/null; then
    info "Installation de git..."
    sudo apt install -y git
else
    info "git est déjà installé"
fi

# Installer curl si nécessaire
info "Vérification de curl..."
if ! command -v curl &> /dev/null; then
    info "Installation de curl..."
    sudo apt install -y curl
else
    info "curl est déjà installé"
fi

# Installer unzip si nécessaire (pour décompresser la police)
info "Vérification de unzip..."
if ! command -v unzip &> /dev/null; then
    info "Installation de unzip..."
    sudo apt install -y unzip
else
    info "unzip est déjà installé"
fi

# Installer la police JetBrains Mono
info "Installation de la police JetBrains Mono..."
FONTS_DIR="$HOME/.local/share/fonts"
JETBRAINS_FONT_DIR="$FONTS_DIR/JetBrainsMono"

# Créer le répertoire des polices si nécessaire
mkdir -p "$FONTS_DIR"

# Vérifier si la police est déjà installée
if fc-list | grep -q "JetBrains Mono" 2>/dev/null; then
    warn "JetBrains Mono est déjà installée"
else
    info "Téléchargement de JetBrains Mono..."
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Télécharger la dernière version de JetBrains Mono
    JETBRAINS_VERSION="2.304"
    curl -L -o jetbrains-mono.zip "https://github.com/JetBrains/JetBrainsMono/releases/download/v${JETBRAINS_VERSION}/JetBrainsMono-${JETBRAINS_VERSION}.zip"
    
    if [ -f "jetbrains-mono.zip" ]; then
        info "Extraction de JetBrains Mono..."
        unzip -q jetbrains-mono.zip -d jetbrains-mono
        
        # Copier les fichiers de police dans le répertoire des polices
        find jetbrains-mono -name "*.ttf" -exec cp {} "$FONTS_DIR" \;
        
        # Rafraîchir le cache des polices
        fc-cache -f -v
        
        # Nettoyer les fichiers temporaires
        cd "$HOME"
        rm -rf "$TEMP_DIR"
        
        info "JetBrains Mono installée avec succès"
    else
        error "Échec du téléchargement de JetBrains Mono"
        warn "Vous pouvez l'installer manuellement depuis https://www.jetbrains.com/lp/mono/"
    fi
fi

# Installer oh-my-zsh
info "Installation de oh-my-zsh..."
if [ -d "$HOME/.oh-my-zsh" ]; then
    warn "oh-my-zsh est déjà installé"
else
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    info "oh-my-zsh installé avec succès"
fi

# Installer powerlevel10k
info "Installation de powerlevel10k..."
P10K_DIR="$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
if [ -d "$P10K_DIR" ]; then
    warn "powerlevel10k est déjà installé"
    info "Mise à jour de powerlevel10k..."
    cd "$P10K_DIR" && git pull
else
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
    info "powerlevel10k installé avec succès"
fi

# Installer zsh-autosuggestions
info "Installation de zsh-autosuggestions..."
AUTOSUGGESTIONS_DIR="$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
if [ -d "$AUTOSUGGESTIONS_DIR" ]; then
    warn "zsh-autosuggestions est déjà installé"
    info "Mise à jour de zsh-autosuggestions..."
    cd "$AUTOSUGGESTIONS_DIR" && git pull
else
    git clone https://github.com/zsh-users/zsh-autosuggestions "$AUTOSUGGESTIONS_DIR"
    info "zsh-autosuggestions installé avec succès"
fi

# Installer zsh-syntax-highlighting
info "Installation de zsh-syntax-highlighting..."
SYNTAX_HIGHLIGHTING_DIR="$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
if [ -d "$SYNTAX_HIGHLIGHTING_DIR" ]; then
    warn "zsh-syntax-highlighting est déjà installé"
    info "Mise à jour de zsh-syntax-highlighting..."
    cd "$SYNTAX_HIGHLIGHTING_DIR" && git pull
else
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$SYNTAX_HIGHLIGHTING_DIR"
    info "zsh-syntax-highlighting installé avec succès"
fi

# Installer zsh-completions
info "Installation de zsh-completions..."
COMPLETIONS_DIR="$HOME/.oh-my-zsh/custom/plugins/zsh-completions"
if [ -d "$COMPLETIONS_DIR" ]; then
    warn "zsh-completions est déjà installé"
    info "Mise à jour de zsh-completions..."
    cd "$COMPLETIONS_DIR" && git pull
else
    git clone https://github.com/zsh-users/zsh-completions "$COMPLETIONS_DIR"
    info "zsh-completions installé avec succès"
fi

# Installer zsh-history-substring-search
info "Installation de zsh-history-substring-search..."
HISTORY_SUBSTRING_DIR="$HOME/.oh-my-zsh/custom/plugins/zsh-history-substring-search"
if [ -d "$HISTORY_SUBSTRING_DIR" ]; then
    warn "zsh-history-substring-search est déjà installé"
    info "Mise à jour de zsh-history-substring-search..."
    cd "$HISTORY_SUBSTRING_DIR" && git pull
else
    git clone https://github.com/zsh-users/zsh-history-substring-search.git "$HISTORY_SUBSTRING_DIR"
    info "zsh-history-substring-search installé avec succès"
fi

# Installer zoxide et fzf via Homebrew
info "Vérification de Homebrew..."
if ! command -v brew &> /dev/null; then
    error "Homebrew n'est pas installé. Veuillez l'installer d'abord."
    warn "Visitez https://brew.sh pour installer Homebrew"
else
    info "Homebrew est installé"
    
    # Installer zoxide
    info "Installation de zoxide via Homebrew..."
    if command -v zoxide &> /dev/null; then
        warn "zoxide est déjà installé"
    else
        brew install zoxide
        info "zoxide installé avec succès"
    fi
    
    # Installer fzf
    info "Installation de fzf via Homebrew..."
    if command -v fzf &> /dev/null; then
        warn "fzf est déjà installé"
    else
        brew install fzf
        info "fzf installé avec succès"
    fi
    
    # Installer les raccourcis clavier et la complétion pour fzf
    if command -v fzf &> /dev/null && [ ! -f ~/.fzf.zsh ]; then
        info "Installation des raccourcis clavier et de la complétion pour fzf..."
        $(brew --prefix)/opt/fzf/install --all --no-bash --no-fish
        info "Configuration de fzf terminée"
    fi
fi

# Configurer le fichier .zshrc
info "Configuration du fichier .zshrc..."

# Créer une sauvegarde du .zshrc existant s'il existe
if [ -f "$HOME/.zshrc" ]; then
    BACKUP_FILE="$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$HOME/.zshrc" "$BACKUP_FILE"
    info "Sauvegarde créée: $BACKUP_FILE"
fi

# Créer ou modifier le .zshrc
ZSH_CONFIG="$HOME/.zshrc"

# Si le fichier n'existe pas, le créer avec la configuration de base
if [ ! -f "$ZSH_CONFIG" ]; then
    cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$ZSH_CONFIG"
fi

# Modifier le thème pour powerlevel10k
if grep -q "ZSH_THEME=" "$ZSH_CONFIG"; then
    sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$ZSH_CONFIG"
else
    echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> "$ZSH_CONFIG"
fi

# Ajouter les plugins si pas déjà présents
if ! grep -q "plugins=(" "$ZSH_CONFIG" || ! grep -q "zsh-autosuggestions\|zsh-syntax-highlighting\|zsh-completions\|zsh-history-substring-search" "$ZSH_CONFIG"; then
    # Trouver la ligne plugins= et la modifier
    if grep -q "^plugins=(" "$ZSH_CONFIG"; then
        # Remplacer la ligne plugins existante
        sed -i 's/^plugins=(.*)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions zsh-history-substring-search)/' "$ZSH_CONFIG"
    else
        # Ajouter la ligne plugins après ZSH_THEME
        sed -i '/^ZSH_THEME=/a plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions zsh-history-substring-search)' "$ZSH_CONFIG"
    fi
fi

# Ajouter la configuration pour zsh-history-substring-search
if ! grep -q "zsh-history-substring-search" "$ZSH_CONFIG"; then
    cat >> "$ZSH_CONFIG" << 'EOF'

# Configuration pour zsh-history-substring-search
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down
EOF
fi

# Ajouter la configuration pour zoxide
if command -v zoxide &> /dev/null; then
    if ! grep -q "zoxide init" "$ZSH_CONFIG"; then
        cat >> "$ZSH_CONFIG" << 'EOF'

# Configuration pour zoxide (cd intelligent)
eval "$(zoxide init zsh)"
EOF
        info "Configuration de zoxide ajoutée au .zshrc"
    fi
fi

# Ajouter la configuration pour fzf
if command -v fzf &> /dev/null; then
    if ! grep -q "fzf" "$ZSH_CONFIG"; then
        cat >> "$ZSH_CONFIG" << 'EOF'

# Configuration pour fzf (fuzzy finder)
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
EOF
        info "Configuration de fzf ajoutée au .zshrc"
    fi
fi

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

echo ""
echo "=========================================="
echo -e "${GREEN}Installation terminée avec succès!${NC}"
echo "=========================================="
echo ""
echo "Résumé de l'installation:"
echo "  ✓ zsh"
echo "  ✓ oh-my-zsh"
echo "  ✓ powerlevel10k"
echo "  ✓ JetBrains Mono (police)"
echo "  ✓ zsh-autosuggestions"
echo "  ✓ zsh-syntax-highlighting"
echo "  ✓ zsh-completions"
echo "  ✓ zsh-history-substring-search"
echo "  ✓ zoxide (via Homebrew)"
echo "  ✓ fzf (via Homebrew)"
echo ""
echo "Prochaines étapes:"
echo "  1. Déconnectez-vous et reconnectez-vous pour utiliser zsh"
echo "  2. Lancez 'p10k configure' pour configurer powerlevel10k"
echo "  3. Profitez de votre nouveau shell!"
echo ""

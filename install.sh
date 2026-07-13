#!/bin/bash
# =============================================================================
# Dotfiles Install — macOS Window Management + Lily58
# Corre esto después de clonar el repo: ./install.sh
# =============================================================================
set -e

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
echo "📦 Instalando dotfiles desde $DOTFILES..."

# ── 1. Scripts de auto-arranque ──────────────────────────────────────────
echo "→ Copiando scripts a ~/.local/bin..."
mkdir -p "$HOME/.local/bin"
cp "$DOTFILES/local/bin/"* "$HOME/.local/bin/"
chmod +x "$HOME/.local/bin/"*.sh
# disk-ready.sh va a /usr/local/bin (requiere sudo)
if [ -f "$DOTFILES/local/bin/disk-ready.sh" ]; then
    sudo cp "$DOTFILES/local/bin/disk-ready.sh" /usr/local/bin/
    sudo chmod +x /usr/local/bin/disk-ready.sh
fi

# ── 2. Configs de window management ──────────────────────────────────────
echo "→ Copiando configs..."
mkdir -p "$HOME/.config/yabai" "$HOME/.config/skhd" "$HOME/.config/sketchybar"
cp "$DOTFILES/config/yabai/yabairc" "$HOME/.config/yabai/"
cp "$DOTFILES/config/skhd/skhdrc" "$HOME/.config/skhd/"
cp "$DOTFILES/config/sketchybar/sketchybarrc" "$HOME/.config/sketchybar/"

# ── 3. .app wrappers (protegen permisos TCC) ─────────────────────────────
echo "→ Copiando .app wrappers..."
mkdir -p "$HOME/Applications"
cp -r "$DOTFILES/Applications/skhd-protected.app" "$HOME/Applications/"
cp -r "$DOTFILES/Applications/sketchybar-protected.app" "$HOME/Applications/"

# ── 4. LaunchAgents ──────────────────────────────────────────────────────
echo "→ Copiando LaunchAgents..."
mkdir -p "$HOME/Library/LaunchAgents"
cp "$DOTFILES/Library/LaunchAgents/"* "$HOME/Library/LaunchAgents/"

# ── 5. Lily58 keymap ─────────────────────────────────────────────────────
echo "→ Copiando keymap Lily58..."
cp "$DOTFILES/lily58/keymap.c" "$HOME/qmk_firmware/keyboards/lily58/keymaps/saul/keymap.c" 2>/dev/null || \
    echo "  ⚠️  No se encontró ~/qmk_firmware. Copiá manualmente lily58/keymap.c a tu repo QMK."

# ── 6. Ocultar barra de menú ─────────────────────────────────────────────
echo "→ Ocultando barra de menú..."
defaults write NSGlobalDomain _HIHideMenuBar -bool true

# ── 7. Permisos de Accessibility ─────────────────────────────────────────
echo ""
echo "⚠️  FALTA MANUAL: Andá a System Settings → Privacy & Security → Accessibility"
echo "   y agregá estos .app con el botón '+':"
echo "     • ~/Applications/skhd-protected.app"
echo "     • ~/Applications/sketchybar-protected.app"
echo "     • /opt/homebrew/bin/yabai"
echo ""
echo "Luego reiniciá para aplicar todo."
echo "✅ Instalación completa."

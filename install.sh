#!/usr/bin/env bash
set -euo pipefail

echo "[1/7] Installing prerequisites..."
sudo apt update
sudo apt install -y --no-install-recommends \
    git curl ca-certificates unzip wget ripgrep fd-find xclip software-properties-common fontconfig

echo "[2/7] Removing any existing Neovim config/state (backup + clean)..."
ts="$(date +%Y%m%d_%H%M%S)"

for p in \
    "$HOME/.config/nvim" \
    "$HOME/.local/share/nvim" \
    "$HOME/.local/state/nvim" \
    "$HOME/.cache/nvim"
do
    if [ -e "$p" ]; then
        mv "$p" "${p}.bak.${ts}" || true
    fi
done

rm -rf \
    "$HOME/.config/nvim" \
    "$HOME/.local/share/nvim" \
    "$HOME/.local/state/nvim" \
    "$HOME/.cache/nvim"

echo "[3/7] Installing Neovim..."
if ! grep -q neovim-ppa /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
    sudo add-apt-repository -y ppa:neovim-ppa/unstable
fi
sudo apt update
sudo apt install -y neovim

echo "[4/7] Installing NvChad starter..."
git clone --depth 1 https://github.com/NvChad/starter "$HOME/.config/nvim"
rm -rf "$HOME/.config/nvim/.git"

echo "[5/7] Fetching hacker-vim and applying overrides (WITHOUT replacing NvChad lua/)..."
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

git clone --depth 1 https://github.com/nosachamos/hacker-vim "$tmpdir/hacker-vim"

if [ ! -d "$tmpdir/hacker-vim/lua" ]; then
    echo "ERROR: repo does not contain a lua/ directory at the root."
    exit 1
fi

# Apply only the intended override files so NvChad keeps lua/configs/*, options.lua, autocmds.lua, etc.
if [ -f "$tmpdir/hacker-vim/lua/chadrc.lua" ]; then
    cp -a "$tmpdir/hacker-vim/lua/chadrc.lua" "$HOME/.config/nvim/lua/chadrc.lua"
else
    echo "ERROR: repo missing lua/chadrc.lua (expected NvChad override)."
    exit 1
fi

if [ -d "$tmpdir/hacker-vim/lua/plugins" ]; then
    rm -rf "$HOME/.config/nvim/lua/plugins"
    cp -a "$tmpdir/hacker-vim/lua/plugins" "$HOME/.config/nvim/lua/plugins"
else
    echo "ERROR: repo missing lua/plugins/ (expected NvChad override)."
    exit 1
fi

echo "[6/7] Headless plugin install (Lazy sync)..."
nvim --headless "+Lazy! sync" +qa || true
nvim --headless "+Lazy! sync" +qa || true

echo "[7/7] (Optional) Kitty + Nerd Font setup..."
if ! command -v kitty >/dev/null 2>&1; then
    sudo apt install -y kitty
fi

FONT_DIR="$HOME/.local/share/fonts"
if ! fc-list | grep -i "JetBrainsMono" | grep -qi "Nerd"; then
    mkdir -p "$FONT_DIR"
    wget -qO /tmp/JetBrainsMono.zip "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip"
    unzip -o /tmp/JetBrainsMono.zip -d "$FONT_DIR"
    fc-cache -fv
    rm -f /tmp/JetBrainsMono.zip
fi

KITTY_CONF="$HOME/.config/kitty/kitty.conf"
mkdir -p "$(dirname "$KITTY_CONF")"
if ! grep -q "JetBrainsMono Nerd Font" "$KITTY_CONF" 2>/dev/null; then
    {
        echo "font_family JetBrainsMono Nerd Font"
        echo "bold_font JetBrainsMono Nerd Font Bold"
        echo "italic_font JetBrainsMono Nerd Font Italic"
        echo "bold_italic_font JetBrainsMono Nerd Font Bold Italic"
    } >> "$KITTY_CONF"
fi

echo ""
echo "Done."
echo "Config: $(nvim --headless "+lua print(vim.fn.stdpath('config'))" +qa)"
echo "Run: nvim"

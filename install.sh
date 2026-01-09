#!/usr/bin/env bash
set -euo pipefail

echo "[1/8] Installing prerequisites..."
sudo apt update
sudo apt install -y --no-install-recommends \
    git curl ca-certificates unzip wget ripgrep fd-find xclip software-properties-common fontconfig

echo "[2/8] Removing any existing Neovim binaries (best-effort)..."
if dpkg -s neovim >/dev/null 2>&1; then
    sudo apt remove -y neovim
fi

if command -v snap >/dev/null 2>&1; then
    if snap list | awk 'NR>1 {print $1}' | grep -qx "nvim"; then
        sudo snap remove nvim
    fi
    if snap list | awk 'NR>1 {print $1}' | grep -qx "neovim"; then
        sudo snap remove neovim
    fi
fi

echo "[3/8] Removing any existing Neovim config/state (backup + clean)..."
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

echo "[4/8] Installing Neovim..."
if ! grep -q neovim-ppa /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
    sudo add-apt-repository -y ppa:neovim-ppa/unstable
fi
sudo apt update
sudo apt install -y neovim

echo "[5/8] Installing NvChad starter..."
git clone --depth 1 https://github.com/NvChad/starter "$HOME/.config/nvim"
rm -rf "$HOME/.config/nvim/.git"

echo "[6/8] Fetching hacker-vim and applying custom overlay (lua/custom)..."
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

git clone --depth 1 https://github.com/nosachamos/hacker-vim "$tmpdir/hacker-vim"

if [ ! -d "$tmpdir/hacker-vim/lua/custom" ]; then
    echo "ERROR: repo does not contain lua/custom/ (expected NvChad overlay)."
    exit 1
fi

# Apply only the intended overlay so NvChad keeps its core lua/ tree.
rm -rf "$HOME/.config/nvim/lua/custom"
cp -a "$tmpdir/hacker-vim/lua/custom" "$HOME/.config/nvim/lua/custom"

echo "[7/8] Headless plugin install (Lazy sync)..."
nvim --headless "+Lazy! sync" +qa || true
nvim --headless "+Lazy! sync" +qa || true

echo "[8/8] (Optional) Kitty + Nerd Font setup..."
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

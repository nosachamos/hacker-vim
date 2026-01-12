#!/usr/bin/env bash
set -euo pipefail

echo "[1/9] Installing prerequisites..."
sudo apt update
sudo apt install -y --no-install-recommends \
    git curl ca-certificates unzip wget ripgrep fd-find xclip software-properties-common fontconfig python3 python3-venv

echo "[2/9] Removing any existing Neovim binaries (best-effort)..."
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

echo "[3/9] Removing any existing Neovim config/state (backup + clean)..."
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

echo "[4/9] Installing Neovim..."
if ! grep -q neovim-ppa /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
    sudo add-apt-repository -y ppa:neovim-ppa/unstable
fi
sudo apt update
sudo apt install -y neovim
hash -r

echo "[5/9] Ensuring Python debug adapter (debugpy) is available..."
if apt-cache show python3-debugpy >/dev/null 2>&1; then
    if ! sudo apt install -y python3-debugpy; then
        echo "NOTE: Failed to install python3-debugpy. Install debugpy in your venv: python -m pip install debugpy"
    fi
else
    echo "NOTE: python3-debugpy not available via apt. Install debugpy in your venv: python -m pip install debugpy"
fi

echo "[6/9] Installing NvChad starter..."
git clone --depth 1 https://github.com/NvChad/starter "$HOME/.config/nvim"
rm -rf "$HOME/.config/nvim/.git"

echo "[7/9] Fetching hacker-vim and applying custom overlay (lua/custom)..."
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

if [ -f "$tmpdir/hacker-vim/lua/chadrc.lua" ]; then
    cp -a "$tmpdir/hacker-vim/lua/chadrc.lua" "$HOME/.config/nvim/lua/chadrc.lua"
fi
if [ -f "$tmpdir/hacker-vim/lua/autocmds.lua" ]; then
    cp -a "$tmpdir/hacker-vim/lua/autocmds.lua" "$HOME/.config/nvim/lua/autocmds.lua"
fi

plugins_init="$HOME/.config/nvim/lua/plugins/init.lua"
if [ -f "$plugins_init" ]; then
    if [ ! -f "$tmpdir/hacker-vim/lua/plugins/custom.lua" ]; then
        echo "ERROR: repo missing lua/plugins/custom.lua (expected NvChad overlay)."
        exit 1
    fi

    mkdir -p "$HOME/.config/nvim/lua/plugins"
    cp -a "$tmpdir/hacker-vim/lua/plugins/custom.lua" "$HOME/.config/nvim/lua/plugins/custom.lua"

    if ! grep -q 'plugins.custom' "$plugins_init"; then
        python3 - "$plugins_init" <<'PY'
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

insert_line = '  { import = "plugins.custom" },\n'
for i in range(len(lines) - 1, -1, -1):
    if lines[i].strip() == "}":
        lines.insert(i, insert_line)
        break
else:
    raise SystemExit("ERROR: could not find closing '}' in lua/plugins/init.lua")

with open(path, "w", encoding="utf-8") as f:
    f.writelines(lines)
PY
    fi
fi

echo "[8/9] Headless plugin install (Lazy sync)..."
nvim --headless "+Lazy! sync" +qa || true
nvim --headless "+Lazy! sync" +qa || true

echo "[9/9] (Optional) Kitty + Nerd Font setup..."
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

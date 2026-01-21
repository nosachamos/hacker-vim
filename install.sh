#!/usr/bin/env bash
set -euo pipefail

NVIM_BIN="nvim"

echo "[1/10] Installing prerequisites..."
sudo apt update
sudo apt install -y --no-install-recommends \
    git curl ca-certificates unzip wget ripgrep fd-find xclip software-properties-common fontconfig python3 python3-venv

echo "[2/10] Removing any existing Neovim binaries (best-effort)..."
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

echo "[3/10] Removing any existing Neovim config/state (backup + clean)..."
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

echo "[4/10] Installing Neovim..."
needs_update=0

# Ensure the unstable PPA exists and is enabled (some machines only have the stable PPA).
if ! grep -Rqs "neovim-ppa/unstable" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
    sudo add-apt-repository -y ppa:neovim-ppa/unstable
    needs_update=1
else
    for f in /etc/apt/sources.list.d/*.sources; do
        if [ -f "$f" ] && grep -q "neovim-ppa/unstable" "$f" && grep -q "^Enabled: no" "$f"; then
            sudo sed -i 's/^Enabled: no/Enabled: yes/' "$f"
            needs_update=1
        fi
    done
fi

if [ ! -f /etc/apt/preferences.d/neovim-ppa ]; then
    sudo tee /etc/apt/preferences.d/neovim-ppa >/dev/null <<'EOF'
Package: neovim neovim-runtime
Pin: release o=LP-PPA-neovim-ppa-unstable
Pin-Priority: 1001
EOF
    needs_update=1
fi

sudo apt update

# Unhold Neovim packages if they were pinned/held previously.
held_pkgs="$(apt-mark showhold | awk '/^(neovim|neovim-runtime)$/ {print}' || true)"
if [ -n "$held_pkgs" ]; then
    echo "Unholding: $held_pkgs"
    sudo apt-mark unhold $held_pkgs
fi

get_versions() {
    apt-cache madison "$1" | awk '{print $3}' | sort -Vu
}

get_versions_ppa() {
    apt-cache madison "$1" | awk '/neovim-ppa\\/unstable/ {print $3}' | sort -Vu
}

common_versions="$(comm -12 <(get_versions neovim) <(get_versions neovim-runtime) || true)"
common_ppa_versions="$(comm -12 <(get_versions_ppa neovim) <(get_versions_ppa neovim-runtime) || true)"

best_version=""
if [ -n "$common_ppa_versions" ]; then
    best_version="$(echo "$common_ppa_versions" | tail -n1)"
else
    echo "NOTE: neovim-ppa/unstable packages not found in apt cache; falling back to other sources."
    best_version="$(echo "$common_versions" | tail -n1)"
fi

if [ -z "$best_version" ]; then
    echo "ERROR: No matching neovim/neovim-runtime versions found in apt."
    echo "Ensure the PPA is reachable, then rerun."
    exit 1
fi

echo "Selected Neovim version: $best_version"
sudo apt install -y --allow-downgrades "neovim=${best_version}" "neovim-runtime=${best_version}"
hash -r
NVIM_BIN="$(command -v nvim || echo nvim)"
nvim_ver="$("$NVIM_BIN" --version 2>/dev/null | head -n1 | awk '{print $2}' | sed 's/^v//')"
if [ -z "$nvim_ver" ] || dpkg --compare-versions "$nvim_ver" lt "0.10.0"; then
    echo "ERROR: Neovim $nvim_ver is too old for NvChad (requires >= 0.10)."
    echo "Fix: ensure the neovim-ppa/unstable PPA is enabled, publishing for your Ubuntu release, and then rerun."
    exit 1
fi

echo "[5/10] Ensuring Python debug adapter (debugpy) is available..."
if apt-cache show python3-debugpy >/dev/null 2>&1; then
    if ! sudo apt install -y python3-debugpy; then
        echo "NOTE: Failed to install python3-debugpy. Install debugpy in your venv: python -m pip install debugpy"
    fi
else
    echo "NOTE: python3-debugpy not available via apt. Install debugpy in your venv: python -m pip install debugpy"
fi

echo "[6/10] Installing NvChad starter..."
git clone --depth 1 https://github.com/NvChad/starter "$HOME/.config/nvim"
rm -rf "$HOME/.config/nvim/.git"

init_lua="$HOME/.config/nvim/init.lua"
if [ -f "$init_lua" ]; then
    python3 - "$init_lua" <<'PY'
import sys

path = sys.argv[1]
text = open(path, "r", encoding="utf-8").read()

if "vim.uv = vim.loop" in text or "vim.uv=vim.loop" in text:
    sys.exit(0)

shim = (
    "if vim.uv == nil then\n"
    "  vim.uv = vim.loop\n"
    "end\n\n"
)

with open(path, "w", encoding="utf-8") as f:
    f.write(shim + text)
PY

    python3 - "$init_lua" <<'PY'
import sys

path = sys.argv[1]
text = open(path, "r", encoding="utf-8").read()

if 'pcall(dofile, vim.g.base46_cache .. "defaults")' in text:
    sys.exit(0)

lines = text.splitlines(keepends=True)
new_lines = []
inserted_loader = False
replaced_any = False

def indent_of(line):
    return line[: len(line) - len(line.lstrip())]

for line in lines:
    stripped = line.strip()

    if "dofile" in stripped and "vim.g.base46_cache" in stripped and ("\"defaults\"" in stripped or "'defaults'" in stripped):
        indent = indent_of(line)
        if not inserted_loader and "base46.load_all_highlights" not in text:
            new_lines.append(indent + 'if vim.fn.filereadable(vim.g.base46_cache .. "defaults") == 0 then\n')
            new_lines.append(indent + '  local ok, base46 = pcall(require, "base46")\n')
            new_lines.append(indent + "  if ok then\n")
            new_lines.append(indent + "    base46.load_all_highlights()\n")
            new_lines.append(indent + "  end\n")
            new_lines.append(indent + "end\n")
            inserted_loader = True
        new_lines.append(indent + 'pcall(dofile, vim.g.base46_cache .. "defaults")\n')
        replaced_any = True
        continue

    if "dofile" in stripped and "vim.g.base46_cache" in stripped and ("\"statusline\"" in stripped or "'statusline'" in stripped):
        indent = indent_of(line)
        new_lines.append(indent + 'pcall(dofile, vim.g.base46_cache .. "statusline")\n')
        replaced_any = True
        continue

    new_lines.append(line)

if replaced_any:
    with open(path, "w", encoding="utf-8") as f:
        f.writelines(new_lines)
else:
    sys.stderr.write("NOTE: base46 cache lines not found; skipping init.lua patch.\n")
PY
fi

echo "[7/10] Fetching hacker-vim and applying custom overlay (lua/custom)..."
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
if [ -d "$tmpdir/hacker-vim/lua/themes" ]; then
    rm -rf "$HOME/.config/nvim/lua/themes"
    cp -a "$tmpdir/hacker-vim/lua/themes" "$HOME/.config/nvim/lua/themes"
fi
if [ -d "$tmpdir/hacker-vim/after" ]; then
    rm -rf "$HOME/.config/nvim/after"
    cp -a "$tmpdir/hacker-vim/after" "$HOME/.config/nvim/after"
fi

if [ -f "$tmpdir/hacker-vim/lua/chadrc.lua" ]; then
    cp -a "$tmpdir/hacker-vim/lua/chadrc.lua" "$HOME/.config/nvim/lua/chadrc.lua"
fi
if [ -f "$tmpdir/hacker-vim/lua/autocmds.lua" ]; then
    cp -a "$tmpdir/hacker-vim/lua/autocmds.lua" "$HOME/.config/nvim/lua/autocmds.lua"
fi
if [ -f "$tmpdir/hacker-vim/lua/mappings.lua" ]; then
    cp -a "$tmpdir/hacker-vim/lua/mappings.lua" "$HOME/.config/nvim/lua/mappings.lua"
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

echo "[8/10] Headless plugin install (Lazy sync)..."
"$NVIM_BIN" --headless "+Lazy! sync" +qa || true
"$NVIM_BIN" --headless "+Lazy! sync" +qa || true

echo "[8.5/10] Installing Mason tools (pyright, ts server, ruff, eslint_d)..."
"$NVIM_BIN" --headless "+MasonInstall pyright typescript-language-server ruff eslint_d" +qa || true

echo "[9/10] (Optional) Kitty + Nerd Font setup..."
kitty_installed=0
if command -v kitty >/dev/null 2>&1; then
    kitty_installed=1
fi

FONT_DIR="$HOME/.local/share/fonts"
font_installed=0
if ls "$FONT_DIR"/JetBrainsMonoNerdFont* >/dev/null 2>&1; then
    font_installed=1
fi

if [ "$font_installed" -eq 0 ]; then
    for d in /usr/local/share/fonts /usr/share/fonts; do
        if [ -d "$d" ] && find "$d" -maxdepth 3 -type f \( -iname "JetBrainsMonoNerdFont*.ttf" -o -iname "JetBrainsMonoNerdFont*.otf" \) -print -quit | grep -q .; then
            font_installed=1
            break
        fi
    done
fi

if [ "$font_installed" -eq 0 ] && command -v fc-list >/dev/null 2>&1; then
    if fc-list | grep -i "JetBrainsMono" | grep -qi "Nerd"; then
        font_installed=1
    fi
fi

KITTY_CONF="$HOME/.config/kitty/kitty.conf"
kitty_conf_ok=0
if [ -f "$KITTY_CONF" ] && grep -q "JetBrainsMono Nerd Font" "$KITTY_CONF" 2>/dev/null; then
    kitty_conf_ok=1
fi

if [ "$kitty_installed" -eq 1 ] && [ "$font_installed" -eq 1 ] && [ "$kitty_conf_ok" -eq 1 ]; then
    echo "Kitty + Nerd Font already installed/configured; skipping."
else
    if [ "$kitty_installed" -ne 1 ]; then
        sudo apt install -y kitty
        kitty_installed=1
    fi

    if [ "$font_installed" -ne 1 ]; then
        mkdir -p "$FONT_DIR"
        wget -qO /tmp/JetBrainsMono.zip "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip"
        unzip -o /tmp/JetBrainsMono.zip -d "$FONT_DIR"
        fc-cache -fv
        rm -f /tmp/JetBrainsMono.zip
        font_installed=1
    fi

    if [ "$kitty_installed" -eq 1 ] && [ "$font_installed" -eq 1 ]; then
        mkdir -p "$(dirname "$KITTY_CONF")"
        if ! grep -q "JetBrainsMono Nerd Font" "$KITTY_CONF" 2>/dev/null; then
            {
                echo "font_family JetBrainsMono Nerd Font"
                echo "bold_font JetBrainsMono Nerd Font Bold"
                echo "italic_font JetBrainsMono Nerd Font Italic"
                echo "bold_italic_font JetBrainsMono Nerd Font Bold Italic"
            } >> "$KITTY_CONF"
        fi
    fi
fi

echo "[10/10] (Optional) GNOME Terminal font setup..."
gnome_terminal_available=0
if command -v gsettings >/dev/null 2>&1; then
    if gsettings list-schemas 2>/dev/null | grep -qx "org.gnome.Terminal.ProfilesList"; then
        gnome_terminal_available=1
    fi
fi

if [ "$font_installed" -eq 1 ] && [ "$gnome_terminal_available" -eq 1 ] && [ -t 0 ]; then
    font_name=""
    if command -v fc-list >/dev/null 2>&1; then
        if fc-list | grep -qi "JetBrainsMono Nerd Font Mono"; then
            font_name="JetBrainsMono Nerd Font Mono"
        elif fc-list | grep -qi "JetBrainsMono Nerd Font"; then
            font_name="JetBrainsMono Nerd Font"
        fi
    fi

    if [ -n "$font_name" ]; then
        default_profile="$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null | tr -d "'")" || default_profile=""
        if [ -z "$default_profile" ]; then
            echo "NOTE: Could not read GNOME Terminal default profile; skipping."
        else
            profile_path="/org/gnome/terminal/legacy/profiles:/:${default_profile}/"
            current_font="$(gsettings get "org.gnome.Terminal.Legacy.Profile:${profile_path}" font 2>/dev/null | tr -d "'")" || current_font=""
            if [ -z "$current_font" ]; then
                echo "NOTE: Could not read GNOME Terminal font; skipping."
            elif echo "$current_font" | grep -q "JetBrainsMono Nerd Font"; then
                echo "GNOME Terminal font already set to JetBrainsMono Nerd Font; skipping."
            else
                read -r -p "Set GNOME Terminal font to ${font_name}? [y/N] " reply
                if [[ "$reply" =~ ^[Yy]$ ]]; then
                    font_size="$(echo "$current_font" | awk '{print $NF}')"
                    if ! echo "$font_size" | grep -Eq '^[0-9]+$'; then
                        font_size="11"
                    fi
                    new_font="${font_name} ${font_size}"
                    if ! gsettings set "org.gnome.Terminal.Legacy.Profile:${profile_path}" use-system-font false; then
                        echo "NOTE: Failed to disable system font in GNOME Terminal; skipping."
                    fi
                    if gsettings set "org.gnome.Terminal.Legacy.Profile:${profile_path}" font "$new_font"; then
                        echo "GNOME Terminal font set to ${new_font}."
                    else
                        echo "NOTE: Failed to set GNOME Terminal font."
                    fi
                else
                    echo "Skipping GNOME Terminal font change."
                fi
            fi
        fi
    else
        echo "JetBrainsMono Nerd Font not available to GNOME Terminal; skipping."
    fi
else
    echo "NOTE: GNOME Terminal setup skipped (requires GNOME Terminal + Nerd Font + interactive TTY)."
fi

echo ""
echo "Done."
echo "Config: $("$NVIM_BIN" --headless "+lua print(vim.fn.stdpath('config'))" +qa)"
echo "Run: nvim"

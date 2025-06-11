#!/bin/bash

# Check if Neovim is already installed
if command -v nvim >/dev/null 2>&1; then
    echo "Neovim is already installed. Will remove existing installation..."
    sudo apt remove --purge neovim -y

    # Backup existing Neovim configuration
    mv ~/.config/nvim{,.bak} 2>/dev/null
    mv ~/.local/share/nvim{,.bak} 2>/dev/null
    mv ~/.local/state/nvim{,.bak} 2>/dev/null
    mv ~/.cache/nvim{,.bak} 2>/dev/null

    rm -rf ~/.config/nvim
    rm -rf ~/.local/share/nvim
    rm -rf ~/.local/state/nvim
    rm -rf ~/.cache/nvim
fi

echo "Installing Neovim..."

# Add official Neovim PPA
if ! grep -q neovim-ppa /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
    sudo add-apt-repository -y ppa:neovim-ppa/unstable
fi
sudo apt update

# Install Neovim and dependencies
sudo apt install neovim

git clone https://github.com/NvChad/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git

# Now install the hacker vim files
git clone https://github.com/nosachamos/hacker-vim /tmp/hacker-vim

# Copy or merge the lua/ directory
cp -rf /tmp/hacker-vim/lua/* ~/.config/nvim/lua/

# Clean up
rm -rf /tmp/hacker-vim

# Install Kitty if not installed
if ! command -v kitty >/dev/null 2>&1; then
    echo "Installing Kitty terminal..."
    sudo apt install -y kitty
fi

# Check if JetBrainsMono Nerd Font is installed
FONT_DIR="$HOME/.local/share/fonts"
FONT_NAME="JetBrainsMono Nerd Font"
FONT_FILE_PATTERN="*JetBrainsMonoNerdFont*"

if ! fc-list | grep -i "JetBrainsMono" | grep -qi "Nerd"; then
    echo "JetBrainsMono Nerd Font not found. Installing..."
    mkdir -p "$FONT_DIR"
    wget -qO /tmp/JetBrainsMono.zip "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip"
    unzip -o /tmp/JetBrainsMono.zip -d "$FONT_DIR"
    fc-cache -fv
    rm /tmp/JetBrainsMono.zip
else
    echo "JetBrainsMono Nerd Font is already installed."
fi

# Configure Kitty to use JetBrainsMono Nerd Font
KITTY_CONF="$HOME/.config/kitty/kitty.conf"
mkdir -p "$(dirname "$KITTY_CONF")"
if ! grep -q "JetBrainsMono Nerd Font" "$KITTY_CONF" 2>/dev/null; then
    echo "Setting JetBrainsMono Nerd Font in kitty.conf"
    echo "font_family JetBrainsMono Nerd Font" >> "$KITTY_CONF"
    echo "bold_font JetBrainsMono Nerd Font Bold" >> "$KITTY_CONF"
    echo "italic_font JetBrainsMono Nerd Font Italic" >> "$KITTY_CONF"
    echo "bold_italic_font JetBrainsMono Nerd Font Bold Italic" >> "$KITTY_CONF"
fi

# Move the real nvim binary and replace with a smart wrapper
if command -v nvim >/dev/null 2>&1; then
    REAL_NVIM_PATH=$(command -v nvim)
    if [ "$REAL_NVIM_PATH" = "/usr/bin/nvim" ] && [ ! -f /usr/bin/nvim-bin ]; then
        echo "Renaming real nvim binary to /usr/bin/nvim-bin..."
        sudo mv /usr/bin/nvim /usr/bin/nvim-bin

        echo "Creating smart nvim wrapper..."
        sudo tee /usr/bin/nvim > /dev/null <<'EOF'
#!/bin/bash

# If already in Kitty, just launch nvim-bin
if [ "$TERM" = "xterm-kitty" ] || [ -n "$KITTY_WINDOW_ID" ]; then
    exec /usr/bin/nvim-bin "$@"
else
    exec kitty /usr/bin/nvim-bin "$@"
fi
EOF
        sudo chmod +x /usr/bin/nvim
    fi
fi

echo ""
echo "JetBrainsMono Nerd Font is installed and configured for Kitty."
echo ""
echo "HackerVim installed successfully!"
echo ""
echo "Run neovim to start."

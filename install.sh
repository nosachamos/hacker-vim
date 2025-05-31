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

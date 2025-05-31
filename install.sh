#!/bin/bash

# Check if Neovim is already installed
if command -v nvim >/dev/null 2>&1; then
  echo "Neovim is already installed. Will remove existing installation..."
  sudo apt remove --purge neovim

  # Backup existing Neovim configuration
  mv ~/.config/nvim{,.bak} 2>/dev/null
  mv ~/.local/share/nvim{,.bak} 2>/dev/null
  mv ~/.local/state/nvim{,.bak} 2>/dev/null
  mv ~/.cache/nvim{,.bak} 2>/dev/null
fi

echo "Installing Neovim..."

# Add official Neovim PPA
sudo add-apt-repository -y ppa:neovim-ppa/stable
sudo apt update

# Install Neovim and dependencies
sudo apt install neovim

git clone https://github.com/NvChad/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git

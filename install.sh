#!/bin/bash

# Check if Neovim is already installed
if ! command -v nvim >/dev/null 2>&1; then
  echo "Neovim not found. Installing..."

  # Add official Neovim PPA
  sudo add-apt-repository -y ppa:neovim-ppa/stable
  sudo apt update

  # Install Neovim
  sudo apt install -y neovim
else
  echo "Neovim is already installed. Skipping installation."

  # Backup existing Neovim configuration
  mv ~/.config/nvim{,.bak} 2>/dev/null
  mv ~/.local/share/nvim{,.bak} 2>/dev/null
  mv ~/.local/state/nvim{,.bak} 2>/dev/null
  mv ~/.cache/nvim{,.bak} 2>/dev/null
fi

git clone https://github.com/LazyVim/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git

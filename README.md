# hacker-vim

Run the installation process:

```
curl -sSL "https://raw.githubusercontent.com/nosachamos/hacker-vim/master/install.sh?$(date +%s)" | bash
```

This repo is an NVChad overlay. Custom config and plugins live in `lua/custom` and are copied into `~/.config/nvim/lua/custom` by the installer (currently includes neoscroll + VimBeGood). A small compatibility shim is also installed at `lua/chadrc.lua`, and for newer NvChad starters the installer adds an import in `lua/plugins/init.lua` to load `lua/plugins/custom.lua`.

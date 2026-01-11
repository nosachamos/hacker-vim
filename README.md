# hacker-vim

Run the installation process:

```
curl -sSL "https://raw.githubusercontent.com/nosachamos/hacker-vim/master/install.sh?$(date +%s)" | bash
```

This repo is an NVChad overlay. Custom config and plugins live in `lua/custom` and are copied into `~/.config/nvim/lua/custom` by the installer (currently includes neoscroll, VimBeGood, and Python debugging via nvim-dap). A small compatibility shim is also installed at `lua/chadrc.lua`, and for newer NvChad starters the installer adds an import in `lua/plugins/init.lua` to load `lua/plugins/custom.lua`.

Python debugging keybindings (nvim-dap):
- F5 continue
- F10 step over
- F11 step into
- F12 step out
- <leader>db toggle breakpoint
- <leader>dB conditional breakpoint
- <leader>dl log point
- <leader>dr open REPL
- <leader>dR run last
- <leader>dq terminate
- <leader>du toggle UI
- <leader>dt test method (python)
- <leader>dT test class (python)
- visual <leader>ds debug selection

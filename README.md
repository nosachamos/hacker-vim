# hacker-vim

Run the installation process:

```
curl -sSL "https://raw.githubusercontent.com/nosachamos/hacker-vim/master/install.sh?$(date +%s)" | bash
```

This repo is an NVChad overlay. Custom config and plugins live in `lua/custom` and are copied into `~/.config/nvim/lua/custom` by the installer (currently includes neoscroll, VimBeGood, Python debugging via nvim-dap, and nvim-tree showing gitignored/hidden files by default). A small compatibility shim is also installed at `lua/chadrc.lua`, and for newer NvChad starters the installer adds an import in `lua/plugins/init.lua` to load `lua/plugins/custom.lua`.
It also includes an autocmd that creates missing parent directories on save.

Features include:
- neoscroll for smooth scrolling with going page up / down;
- automatic directory creation when doing :e (we all want it);
- plugins for out-of-the-box python debugging;
- an easy way of saving and launching various app configs per project;
- much more

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
- <leader>dL reload project configs
- <leader>dt test method (python)
- <leader>dT test class (python)
- visual <leader>ds debug selection

Debugpy install note:
- The installer will try `apt install python3-debugpy` when available.
- If you debug inside a venv (recommended), install debugpy in that venv: `python -m pip install debugpy`.
 - The overlay auto-detects venvs named `.venv`, `venv`, `env`, or `environment` in the repo root.

Project debug configs (saved per repo):
- Create `.nvim/dap.lua` in the repo root; it must return a table keyed by filetype.
- Example:

```lua
return {
  python = {
    {
      type = "python",
      request = "launch",
      name = "API server",
      program = "${workspaceFolder}/app/main.py",
      cwd = "${workspaceFolder}",
      args = { "--port", "8000" },
      env = { APP_ENV = "dev" },
    },
  },
}
```

- Alternatively, drop a VS Code config at `.vscode/launch.json` and it will be loaded.
- Pick a config from the list when you press `F5`.
- If configs don't appear, run `<leader>dL` or `:DapReloadConfigs` to reload (it searches upward from the current buffer's directory).

local cached_python_path = nil
local cached_python_root = nil
local warned_missing_debugpy = false

local function has_debugpy(python)
  if not python or python == "" then
    return false
  end

  if vim.fn.executable(python) ~= 1 then
    return false
  end

  vim.fn.system({ python, "-c", "import debugpy" })
  return vim.v.shell_error == 0
end

local function resolve_python(root_dir)
  local search_root = root_dir
  if not search_root or search_root == "" then
    search_root = vim.fn.getcwd()
  end

  if cached_python_path and cached_python_root == search_root then
    return cached_python_path
  end

  local candidates = {}
  local venv = os.getenv("VIRTUAL_ENV")
  if venv then
    table.insert(candidates, venv .. "/bin/python")
  end

  local cwd = search_root
  for _, name in ipairs({ ".venv", "venv", "env", "environment" }) do
    local venv_dir = vim.fn.finddir(name, cwd .. ";")
    if venv_dir ~= "" then
      table.insert(candidates, vim.fn.fnamemodify(venv_dir, ":p") .. "/bin/python")
    end
  end

  local system_python = vim.fn.exepath("python3")
  if system_python ~= "" then
    table.insert(candidates, system_python)
  end

  table.insert(candidates, "python3")
  table.insert(candidates, "python")

  for _, python in ipairs(candidates) do
    if has_debugpy(python) then
      cached_python_path = python
      cached_python_root = search_root
      return python
    end
  end

  if not warned_missing_debugpy then
    warned_missing_debugpy = true
    vim.schedule(function()
      vim.notify(
        "debugpy not found. Install in your venv: python -m pip install debugpy (recommended) or apt install python3-debugpy",
        vim.log.levels.WARN
      )
    end)
  end

  cached_python_path = system_python ~= "" and system_python or "python3"
  cached_python_root = search_root
  return cached_python_path
end

local base_dap_configurations = nil
local dap_project_root = nil

local function find_upwards(relpath, start_dir)
  if not start_dir or start_dir == "" then
    start_dir = vim.fn.getcwd()
  end

  local found = vim.fn.findfile(relpath, start_dir .. ";")
  if found == "" then
    return nil
  end

  return vim.fn.fnamemodify(found, ":p")
end

local function buffer_dir()
  local bufname = vim.api.nvim_buf_get_name(0)
  if bufname == "" then
    return vim.fn.getcwd()
  end

  local abs = vim.fn.fnamemodify(bufname, ":p")
  if vim.fn.filereadable(abs) == 1 then
    return vim.fn.fnamemodify(abs, ":p:h")
  end
  if vim.fn.isdirectory(abs) == 1 then
    return abs
  end

  return vim.fn.getcwd()
end

local function merge_dap_configurations(dap, configs)
  if type(configs) ~= "table" then
    return
  end

  dap.configurations = dap.configurations or {}

  for filetype, entries in pairs(configs) do
    if type(entries) == "table" then
      dap.configurations[filetype] = dap.configurations[filetype] or {}
      for _, entry in ipairs(entries) do
        table.insert(dap.configurations[filetype], entry)
      end
    end
  end
end

local function load_project_dap_configs(dap, opts)
  opts = opts or {}
  local quiet = opts.quiet or false

  dap.configurations = dap.configurations or {}
  if base_dap_configurations then
    dap.configurations = vim.deepcopy(base_dap_configurations)
  end

  local start_dir = buffer_dir()
  if start_dir == "" then
    return
  end

  local dap_lua = find_upwards(".nvim/dap.lua", start_dir)
  local launch_json = find_upwards(".vscode/launch.json", start_dir)

  local project_root = start_dir
  if dap_lua then
    project_root = vim.fn.fnamemodify(dap_lua, ":h:h")
  elseif launch_json then
    project_root = vim.fn.fnamemodify(launch_json, ":h:h")
  end

  local loaded_any = false
  if dap_lua and vim.fn.filereadable(dap_lua) == 1 then
    local ok, configs = pcall(dofile, dap_lua)
    if ok and type(configs) == "table" then
      merge_dap_configurations(dap, configs)
      loaded_any = true
    else
      vim.notify("Failed to load " .. dap_lua .. ": " .. tostring(configs), vim.log.levels.ERROR)
    end
  end

  if launch_json and vim.fn.filereadable(launch_json) == 1 then
    local ok, vscode = pcall(require, "dap.ext.vscode")
    if ok then
      vscode.load_launchjs(launch_json, { python = { "python" } })
      loaded_any = true
    else
      vim.notify("Failed to load dap.ext.vscode: " .. tostring(vscode), vim.log.levels.ERROR)
    end
  end

  if not quiet then
    if loaded_any then
      vim.notify("Loaded project DAP configs from " .. project_root, vim.log.levels.INFO)
    else
      vim.notify("No project DAP configs found from " .. start_dir, vim.log.levels.WARN)
    end
  end

  dap_project_root = project_root or start_dir
end

local function ensure_python_adapter(dap)
  dap.adapters = dap.adapters or {}
  local python_path = resolve_python(dap_project_root or buffer_dir())
  local adapter = dap.adapters.python

  if type(adapter) == "table" then
    local is_debugpy = adapter.type == "executable"
      and type(adapter.args) == "table"
      and adapter.args[1] == "-m"
      and adapter.args[2] == "debugpy.adapter"
    if is_debugpy and adapter.command == python_path then
      return
    end
  elseif adapter ~= nil then
    return
  end

  dap.adapters.python = {
    type = "executable",
    command = python_path,
    args = { "-m", "debugpy.adapter" },
  }
end

local function has_configs_for(dap, filetype)
  local configs = dap.configurations and dap.configurations[filetype]
  return type(configs) == "table" and #configs > 0
end

local function select_and_run(dap, configs, prompt)
  if type(configs) ~= "table" or #configs == 0 then
    return
  end

  vim.ui.select(configs, {
    prompt = prompt or "Select DAP config",
    format_item = function(item)
      return item.name or "Unnamed"
    end,
  }, function(choice)
    if choice then
      dap.run(choice)
    end
  end)
end

local function smart_continue(dap)
  load_project_dap_configs(dap, { quiet = true })

  local ft = vim.bo.filetype
  if has_configs_for(dap, ft) then
    if ft == "python" then
      ensure_python_adapter(dap)
    end
    dap.continue()
    return
  end

  if has_configs_for(dap, "python") then
    ensure_python_adapter(dap)
    select_and_run(dap, dap.configurations.python, "Select Python config")
    return
  end

  local filetypes = {}
  for key, value in pairs(dap.configurations or {}) do
    if type(value) == "table" and #value > 0 then
      table.insert(filetypes, key)
    end
  end
  table.sort(filetypes)

  if #filetypes == 1 then
    select_and_run(dap, dap.configurations[filetypes[1]], "Select DAP config")
    return
  end

  if #filetypes > 1 then
    vim.ui.select(filetypes, { prompt = "Select DAP filetype" }, function(choice)
      if choice then
        select_and_run(dap, dap.configurations[choice], "Select DAP config")
      end
    end)
    return
  end

  vim.notify("No DAP configurations found. Add .nvim/dap.lua or .vscode/launch.json.", vim.log.levels.WARN)
end

local function neogit_action(action)
  return function()
    local ok, neogit = pcall(require, "neogit")
    if not ok then
      vim.notify("Neogit not loaded", vim.log.levels.WARN)
      return
    end

    local cmd_ok = pcall(vim.cmd, "Neogit " .. action)
    if cmd_ok then
      return
    end

    local popup_ok, popup = pcall(require, "neogit.popups." .. action)
    if popup_ok and type(popup.open) == "function" then
      popup.open()
      return
    end

    neogit.open({ kind = "tab" })
  end
end

return {
  {
    "karb94/neoscroll.nvim",
    lazy = false,
    config = function()
      require("neoscroll").setup({
        duration_multiplier = 0.25,
        easing = "quadratic",
      })
    end,
  },
  {
    "ThePrimeagen/vim-be-good",
    cmd = "VimBeGood",
  },
  {
    "nvim-tree/nvim-tree.lua",
    opts = function(_, opts)
      opts.git = opts.git or {}
      opts.git.enable = true
      opts.git.ignore = false

      opts.filters = opts.filters or {}
      opts.filters.dotfiles = false
      opts.filters.custom = {}

      return opts
    end,
  },
  {
    "NeogitOrg/neogit",
    cmd = "Neogit",
    keys = {
      {
        "<leader>gg",
        function()
          require("neogit").open({ kind = "tab" })
        end,
        desc = "Neogit",
      },
      { "<leader>gc", neogit_action("commit"), desc = "Neogit commit" },
      { "<leader>gp", neogit_action("pull"), desc = "Neogit pull" },
      { "<leader>gP", neogit_action("push"), desc = "Neogit push" },
      { "<leader>gm", neogit_action("merge"), desc = "Neogit merge" },
      { "<leader>gr", neogit_action("reset"), desc = "Neogit reset" },
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "sindrets/diffview.nvim",
      "nvim-telescope/telescope.nvim",
      "lewis6991/gitsigns.nvim",
    },
    config = function()
      require("neogit").setup({
        integrations = {
          diffview = true,
          telescope = true,
        },
      })
    end,
  },
  {
    "mfussenegger/nvim-dap",
    lazy = false,
    config = function()
      local dap = require("dap")

      vim.fn.sign_define("DapBreakpoint", { text = "B", texthl = "DiagnosticError", linehl = "DapBreakpointLine" })
      vim.fn.sign_define("DapBreakpointCondition", { text = "C", texthl = "DiagnosticWarn", linehl = "DapBreakpointLine" })
      vim.fn.sign_define("DapLogPoint", { text = "L", texthl = "DiagnosticInfo", linehl = "DapBreakpointLine" })
      vim.fn.sign_define("DapStopped", { text = ">", texthl = "DiagnosticWarn", linehl = "Visual" })
      vim.fn.sign_define("DapBreakpointRejected", { text = "R", texthl = "DiagnosticHint", linehl = "DapBreakpointLine" })

      local map = vim.keymap.set
      map("n", "<F5>", function()
        smart_continue(dap)
      end, { desc = "DAP continue" })
      map("n", "<F10>", dap.step_over, { desc = "DAP step over" })
      map("n", "<F11>", dap.step_into, { desc = "DAP step into" })
      map("n", "<F12>", dap.step_out, { desc = "DAP step out" })
      map("n", "<Leader>db", dap.toggle_breakpoint, { desc = "DAP toggle breakpoint" })
      map("n", "<Leader>dB", function()
        dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
      end, { desc = "DAP conditional breakpoint" })
      map("n", "<Leader>dl", function()
        dap.set_breakpoint(nil, nil, vim.fn.input("Log point message: "))
      end, { desc = "DAP log point" })
      map("n", "<Leader>dr", dap.repl.open, { desc = "DAP REPL" })
      map("n", "<Leader>dR", dap.run_last, { desc = "DAP run last" })
      map("n", "<Leader>dq", dap.terminate, { desc = "DAP terminate" })
      map("n", "<Leader>dL", function()
        load_project_dap_configs(dap, { quiet = false })
      end, { desc = "DAP load project configs" })

      vim.api.nvim_create_user_command("DapReloadConfigs", function()
        load_project_dap_configs(dap, { quiet = false })
      end, {})
    end,
  },
  {
    "rcarriga/nvim-dap-ui",
    dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
    lazy = false,
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      dapui.setup({
        layouts = {
          {
            elements = {
              { id = "scopes", size = 0.35 },
              { id = "breakpoints", size = 0.15 },
              { id = "stacks", size = 0.25 },
              { id = "watches", size = 0.25 },
            },
            size = 50,
            position = "right",
          },
          {
            elements = {
              { id = "repl", size = 0.5 },
              { id = "console", size = 0.5 },
            },
            size = 12,
            position = "bottom",
          },
        },
      })

      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end

      vim.keymap.set("n", "<Leader>du", dapui.toggle, { desc = "DAP UI toggle" })
      vim.api.nvim_create_user_command("DapUiOpen", function()
        dapui.open()
      end, {})
      vim.api.nvim_create_user_command("DapUiClose", function()
        dapui.close()
      end, {})
      vim.api.nvim_create_user_command("DapUiToggle", function()
        dapui.toggle()
      end, {})
    end,
  },
  {
    "mfussenegger/nvim-dap-python",
    dependencies = { "mfussenegger/nvim-dap" },
    ft = "python",
    config = function()
      local dap = require("dap")
      local dap_python = require("dap-python")
      local python_path = resolve_python()

      dap_python.setup(python_path)
      dap_python.test_runner = "pytest"

      dap.configurations.python = {
        {
          type = "python",
          request = "launch",
          name = "Launch file",
          program = "${file}",
          pythonPath = python_path,
        },
        {
          type = "python",
          request = "launch",
          name = "Launch file (args)",
          program = "${file}",
          pythonPath = python_path,
          args = function()
            local input = vim.fn.input("Args: ")
            return vim.split(input, " ", { trimempty = true })
          end,
        },
        {
          type = "python",
          request = "launch",
          name = "Launch module",
          module = function()
            return vim.fn.input("Module: ")
          end,
          pythonPath = python_path,
        },
        {
          type = "python",
          request = "launch",
          name = "Pytest: current file",
          module = "pytest",
          args = { "${file}" },
          pythonPath = python_path,
          justMyCode = false,
        },
        {
          type = "python",
          request = "attach",
          name = "Attach to process",
          processId = require("dap.utils").pick_process,
          pythonPath = python_path,
        },
      }

      vim.keymap.set("n", "<Leader>dt", function()
        dap_python.test_method()
      end, { desc = "DAP Python test method" })
      vim.keymap.set("n", "<Leader>dT", function()
        dap_python.test_class()
      end, { desc = "DAP Python test class" })
      vim.keymap.set("v", "<Leader>ds", function()
        dap_python.debug_selection()
      end, { desc = "DAP Python debug selection" })

      if not base_dap_configurations then
        base_dap_configurations = vim.deepcopy(dap.configurations)
      end
      load_project_dap_configs(dap, { quiet = true })
    end,
  },
}

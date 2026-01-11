local cached_python_path = nil
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

local function resolve_python()
  if cached_python_path then
    return cached_python_path
  end

  local candidates = {}
  local venv = os.getenv("VIRTUAL_ENV")
  if venv then
    table.insert(candidates, venv .. "/bin/python")
  end

  local cwd = vim.fn.getcwd()
  for _, name in ipairs({ ".venv", "venv" }) do
    table.insert(candidates, cwd .. "/" .. name .. "/bin/python")
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
  return cached_python_path
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
    "mfussenegger/nvim-dap",
    lazy = false,
    config = function()
      local dap = require("dap")

      vim.fn.sign_define("DapBreakpoint", { text = "B", texthl = "DiagnosticError" })
      vim.fn.sign_define("DapBreakpointCondition", { text = "C", texthl = "DiagnosticWarn" })
      vim.fn.sign_define("DapLogPoint", { text = "L", texthl = "DiagnosticInfo" })
      vim.fn.sign_define("DapStopped", { text = ">", texthl = "DiagnosticWarn", linehl = "Visual" })
      vim.fn.sign_define("DapBreakpointRejected", { text = "R", texthl = "DiagnosticHint" })

      local map = vim.keymap.set
      map("n", "<F5>", dap.continue, { desc = "DAP continue" })
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
    end,
  },
  {
    "rcarriga/nvim-dap-ui",
    dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
    lazy = false,
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      dapui.setup()

      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end

      vim.keymap.set("n", "<Leader>du", dapui.toggle, { desc = "DAP UI toggle" })
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
    end,
  },
}

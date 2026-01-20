local map = vim.keymap.set

local function dap_call(fn_name)
  return function()
    local ok, dap = pcall(require, "dap")
    if not ok then
      vim.notify("nvim-dap not loaded", vim.log.levels.WARN)
      return
    end
    dap[fn_name]()
  end
end

map("n", "<F10>", dap_call("step_over"), { desc = "DAP step over" })
map("n", "<F11>", dap_call("step_into"), { desc = "DAP step into" })
map("n", "<F12>", dap_call("step_out"), { desc = "DAP step out" })

map("v", "<leader>fg", function()
  require("telescope.builtin").grep_string({
    search = vim.fn.getreg("v"),
  })
end, { desc = "Grep visual selection", silent = true })

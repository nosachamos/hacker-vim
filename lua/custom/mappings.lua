local map = vim.keymap.set

local function get_visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  if start_pos[2] == 0 or end_pos[2] == 0 then
    return ""
  end

  if start_pos[2] > end_pos[2] or (start_pos[2] == end_pos[2] and start_pos[3] > end_pos[3]) then
    start_pos, end_pos = end_pos, start_pos
  end

  local lines = vim.api.nvim_buf_get_text(
    0,
    start_pos[2] - 1,
    start_pos[3] - 1,
    end_pos[2] - 1,
    end_pos[3],
    {}
  )
  return table.concat(lines, "\n"):gsub("\n", " ")
end

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
  local text = get_visual_selection()
  vim.cmd("normal! <Esc>")
  if text ~= "" then
    require("telescope.builtin").live_grep({
      default_text = text,
    })
  end
end, { desc = "Grep visual selection", silent = true })

map("v", "<C-c>", '"+y', { desc = "Copy to system clipboard", silent = true })
map("n", "<C-v>", '"+p', { desc = "Paste from system clipboard", silent = true })
map("i", "<C-v>", "<C-r>+", { desc = "Paste from system clipboard", silent = true })
map("v", "<C-v>", '"_d"+P', { desc = "Paste over selection from system clipboard", silent = true })

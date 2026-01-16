vim.api.nvim_create_autocmd("BufWritePre", {
  callback = function()
    local dir = vim.fn.fnamemodify(vim.fn.expand("<afile>"), ":p:h")
    if vim.fn.isdirectory(dir) == 0 then
      vim.fn.mkdir(dir, "p")
    end
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "NvimTree",
  callback = function()
    vim.opt_local.winfixwidth = true
  end,
})

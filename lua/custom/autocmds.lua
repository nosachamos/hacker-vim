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

vim.opt.colorcolumn = "140"

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    vim.api.nvim_set_hl(0, "ColorColumn", { bg = "none" })
    vim.api.nvim_set_hl(0, "VirtColumn", { fg = "#252525" })
  end,
})

local function buf_map(bufnr, mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
end

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local bufnr = args.buf

    buf_map(bufnr, "n", "gl", function()
      vim.diagnostic.open_float(nil, { scope = "cursor", focus = false })
    end, "Line diagnostics")
    buf_map(bufnr, "n", "]d", vim.diagnostic.goto_next, "Next diagnostic")
    buf_map(bufnr, "n", "[d", vim.diagnostic.goto_prev, "Prev diagnostic")
    buf_map(bufnr, "n", "]e", function()
      vim.diagnostic.goto_next({ severity = vim.diagnostic.severity.ERROR })
    end, "Next error")
    buf_map(bufnr, "n", "[e", function()
      vim.diagnostic.goto_prev({ severity = vim.diagnostic.severity.ERROR })
    end, "Prev error")

    if vim.bo[bufnr].filetype == "python" then
      local function organize_imports()
        vim.lsp.buf.code_action({
          apply = true,
          context = { only = { "source.organizeImports" } },
        })
      end
      buf_map(bufnr, "n", "<C-S-o>", organize_imports, "Organize imports")
      buf_map(bufnr, "n", "<C-O>", organize_imports, "Organize imports")
    end
  end,
})

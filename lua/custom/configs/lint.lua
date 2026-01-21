local ok, lint = pcall(require, "lint")
if not ok then
  return
end

local function has_eslint_config(start_dir)
  if not start_dir or start_dir == "" then
    return false
  end

  local config_files = {
    ".eslintrc",
    ".eslintrc.js",
    ".eslintrc.cjs",
    ".eslintrc.json",
    ".eslintrc.yaml",
    ".eslintrc.yml",
    "eslint.config.js",
    "eslint.config.cjs",
    "eslint.config.mjs",
    "package.json",
  }

  for _, name in ipairs(config_files) do
    local found = vim.fn.findfile(name, start_dir .. ";")
    if found ~= "" then
      if name == "package.json" then
        local ok_read, lines = pcall(vim.fn.readfile, found)
        if ok_read then
          local ok_decode, data = pcall(vim.json.decode, table.concat(lines, "\n"))
          if ok_decode and type(data) == "table" and data.eslintConfig then
            return true
          end
        end
      else
        return true
      end
    end
  end

  return false
end

lint.linters_by_ft = {
  python = { "ruff" },
  javascript = { "eslint_d" },
  javascriptreact = { "eslint_d" },
  typescript = { "eslint_d" },
  typescriptreact = { "eslint_d" },
}

if lint.linters.eslint_d then
  lint.linters.eslint_d.condition = function(ctx)
    if vim.fn.executable("eslint_d") ~= 1 then
      return false
    end
    local bufname = ctx and ctx.filename or vim.api.nvim_buf_get_name(0)
    local start_dir = bufname ~= "" and vim.fn.fnamemodify(bufname, ":p:h") or vim.fn.getcwd()
    return has_eslint_config(start_dir)
  end
end

if lint.linters.ruff then
  lint.linters.ruff.condition = function()
    return vim.fn.executable("ruff") == 1
  end
end

vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
  callback = function()
    lint.try_lint()
  end,
})

vim.api.nvim_create_user_command("Lint", function()
  lint.try_lint()
end, {})

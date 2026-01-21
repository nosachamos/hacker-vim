local base_ok, base = pcall(require, "plugins.configs.lspconfig")
if not base_ok then
  base_ok, base = pcall(require, "nvchad.configs.lspconfig")
end

local on_attach = nil
local capabilities = nil
if base_ok and type(base) == "table" then
  on_attach = base.on_attach
  capabilities = base.capabilities
end

if not capabilities then
  local cmp_ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
  if cmp_ok and type(cmp_nvim_lsp.default_capabilities) == "function" then
    capabilities = cmp_nvim_lsp.default_capabilities()
  end
end

local function setup_server(server, config)
  config = config or {}
  if on_attach and config.on_attach == nil then
    config.on_attach = on_attach
  end
  if capabilities and config.capabilities == nil then
    config.capabilities = capabilities
  end

  if vim.lsp and type(vim.lsp.config) == "function" and type(vim.lsp.enable) == "function" then
    local ok = pcall(vim.lsp.config, server, config)
    if ok then
      vim.lsp.enable(server)
      return
    end
  end

  local ok, lspconfig = pcall(require, "lspconfig")
  if not ok then
    return
  end

  if lspconfig[server] and type(lspconfig[server].setup) == "function" then
    lspconfig[server].setup(config)
  end
end

setup_server("pyright", {})
setup_server("ts_ls", {})

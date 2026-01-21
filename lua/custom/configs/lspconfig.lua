local ok, lspconfig = pcall(require, "lspconfig")
if not ok then
  return
end

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

lspconfig.pyright.setup({
  on_attach = on_attach,
  capabilities = capabilities,
})

lspconfig.tsserver.setup({
  on_attach = on_attach,
  capabilities = capabilities,
})

local M = {}

-- Hacker: Catppuccin palette with pure black backgrounds.
M.base_30 = {
  white = "#D9E0EE",
  darker_black = "#000000",
  black = "#000000", -- nvim bg
  black2 = "#000000",
  one_bg = "#000000", -- real bg of onedark
  one_bg2 = "#000000",
  one_bg3 = "#000000",
  grey = "#474656",
  grey_fg = "#4e4d5d",
  grey_fg2 = "#555464",
  light_grey = "#605f6f",
  red = "#FF6B68",
  baby_pink = "#ffa5c3",
  pink = "#F5C2E7",
  line = "#676769", -- for lines like vertsplit
  green = "#00FF00",
  vibrant_green = "#00FF00",
  nord_blue = "#8bc2f0",
  blue = "#89B4FA",
  yellow = "#FFFF00",
  sun = "#ffe9b6",
  purple = "#d0a9e5",
  dark_purple = "#a770bc",
  teal = "#B5E8E0",
  orange = "#FFAD66",
  cyan = "#89DCEB",
  statusline_bg = "#000000",
  lightbg = "#000000",
  pmenu_bg = "#ABE9B3",
  folder_bg = "#6699FF",
  lavender = "#c7d1ff",
}

M.base_16 = {
  base00 = "#000000",
  base01 = "#282737",
  base02 = "#2f2e3e",
  base03 = "#383747",
  base04 = "#414050",
  base05 = "#bfc6d4",
  base06 = "#ccd3e1",
  base07 = "#D9E0EE",
  base08 = "#F38BA8",
  base09 = "#F8BD96",
  base0A = "#FAE3B0",
  base0B = "#00FF00",
  base0C = "#89DCEB",
  base0D = "#89B4FA",
  base0E = "#CBA6F7",
  base0F = "#F38BA8",
}

M.polish_hl = {
  defaults = {
    Normal = { bg = "#000000" },
    NormalNC = { bg = "#000000" },
    NormalFloat = { bg = "#000000" },
  },
  nvimtree = {
    NvimTreeNormal = { bg = "#000000" },
    NvimTreeNormalNC = { bg = "#000000" },
  },
  treesitter = {
    ["@variable"] = { fg = M.base_30.lavender },
    ["@property"] = { fg = M.base_30.teal },
    ["@variable.builtin"] = { fg = M.base_30.red },
  },
}

M.type = "dark"

return M

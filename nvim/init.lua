local opt = vim.opt

opt.number = true

opt.autoindent = true
opt.smartindent = true

opt.tabstop = 4
opt.softtabstop = 4
opt.shiftwidth = 4

opt.expandtab = true

opt.cursorline = true

require("config.lazy")


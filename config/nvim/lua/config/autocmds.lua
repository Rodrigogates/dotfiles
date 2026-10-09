-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
--
--Set colorscheme to vaporwave
vim.cmd("colorscheme  vaporwave")

--Set line number to nonrelative
vim.cmd("set norelativenumber")

-- Al salir de nvim, deja el cursor como barra
vim.api.nvim_create_autocmd("VimLeave", {
  callback = function()
    vim.opt.guicursor = "a:ver25-blinkon500-blinkoff500"
  end,
})
